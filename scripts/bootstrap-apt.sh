#!/usr/bin/env bash
# bootstrap-apt.sh — ensure baseline system packages on Debian/Ubuntu hosts.
#
# The Brewfile is the full toolset, but install.sh skips it on non-macOS
# unless GUI_INSTALL=1, and minimal VM images often lack tools this repo's
# own machinery depends on (zsh for scripts, rsync for sync-coding-tools.sh,
# curl/git/build tools for Homebrew). This script installs that floor from
# declarative lists:
#
#   packages/apt-base.txt   always (headless baseline + Homebrew prereqs)
#   packages/apt-gui.txt    only when GUI_INSTALL=1 (mirrors the Brewfile gate)
#
# Written in bash on purpose: zsh may be exactly what is missing. Idempotent:
# installed packages are detected via dpkg and skipped; when nothing is
# missing, no sudo or apt call is made at all. Installs run noninteractively
# with --no-install-recommends to keep VMs lean. Hosts without apt-get
# (macOS, non-Debian Linux) print a notice and exit 0; on such distros,
# install the packages/apt-*.txt equivalents with the native package manager.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="$REPO_ROOT/packages"
GUI_INSTALL="${GUI_INSTALL:-}"

usage() {
  cat <<'EOF'
Usage: bootstrap-apt.sh [--dry-run] [LIST_FILE...]

Ensure baseline apt packages are installed (Debian/Ubuntu only; hosts without
apt-get print a notice and exit 0). Without LIST_FILE arguments the defaults
are packages/apt-base.txt, plus packages/apt-gui.txt when GUI_INSTALL=1.

Options:
  --dry-run    Print missing packages without installing (never needs sudo).
  -h, --help   Show this help.

Exit codes:
  0  everything installed, nothing to do, or unsupported host (skipped)
  1  bad option, unreadable/invalid package list, or failed install
EOF
}

DRY_RUN=0
LIST_FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "[bootstrap-apt] Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) LIST_FILES+=("$1") ;;
  esac
  shift
done

if ! command -v apt-get > /dev/null 2>&1; then
  echo "[bootstrap-apt] no apt-get on this host; skipping (macOS uses the Brewfile; other distros: install the packages/apt-*.txt equivalents manually)"
  exit 0
fi

if [ ${#LIST_FILES[@]} -eq 0 ]; then
  LIST_FILES=("$PACKAGES_DIR/apt-base.txt")
  if [ "$GUI_INSTALL" = "1" ]; then
    LIST_FILES+=("$PACKAGES_DIR/apt-gui.txt")
  fi
fi

# Parse lists: strip comments and blank lines, validate Debian package-name
# syntax so typos fail loudly instead of surfacing later inside apt.
PACKAGES=()
for list in "${LIST_FILES[@]}"; do
  if [ ! -f "$list" ]; then
    echo "[bootstrap-apt] Error: missing package list: $list" >&2
    exit 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    pkg="${line%%#*}"
    pkg="${pkg#"${pkg%%[![:space:]]*}"}"
    pkg="${pkg%"${pkg##*[![:space:]]}"}"
    [ -z "$pkg" ] && continue
    if ! [[ "$pkg" =~ ^[a-z0-9][a-z0-9+.-]*$ ]]; then
      echo "[bootstrap-apt] Error: invalid package name '$pkg' in $list" >&2
      exit 1
    fi
    PACKAGES+=("$pkg")
  done < "$list"
done

if [ ${#PACKAGES[@]} -eq 0 ]; then
  echo "[bootstrap-apt] no packages listed; nothing to do"
  exit 0
fi

is_installed() {
  dpkg-query -W -f '${Status}' "$1" 2> /dev/null | grep -q 'install ok installed'
}

MISSING=()
for pkg in "${PACKAGES[@]}"; do
  is_installed "$pkg" || MISSING+=("$pkg")
done

if [ ${#MISSING[@]} -eq 0 ]; then
  echo "[bootstrap-apt] all ${#PACKAGES[@]} listed packages already installed"
  exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "[bootstrap-apt] would install (${#MISSING[@]} of ${#PACKAGES[@]} listed): ${MISSING[*]}"
  exit 0
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo > /dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "[bootstrap-apt] Error: need root or sudo to install: ${MISSING[*]}" >&2
    exit 1
  fi
fi

echo "[bootstrap-apt] installing (${#MISSING[@]} of ${#PACKAGES[@]} listed): ${MISSING[*]}"
$SUDO apt-get update
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${MISSING[@]}"
echo "[bootstrap-apt] done"
