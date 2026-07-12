#!/bin/sh
# shellcheck disable=SC2086 # word splitting is intentional throughout (set -f, validated tokens)
#
# bootstrap-packages.sh — ensure baseline system packages on linux hosts and
# containers across the major package managers:
#
#   apt (debian/ubuntu)      dnf/dnf5/microdnf/yum (fedora/rhel/centos)
#   pacman (arch)            apk (alpine)             zypper (opensuse)
#
# macOS is a deliberate no-op: its packages come from the Brewfile. But
# install.sh skips the Brewfile on non-macOS unless GUI_INSTALL=1, and minimal
# images often lack tools this repo's own machinery depends on (zsh for
# scripts, rsync for sync-coding-tools.sh, curl/git/build tools for
# Homebrew). This script installs that floor from declarative lists:
#
#   packages/base.txt   always (headless baseline)
#   packages/gui.txt    only when GUI_INSTALL=1 (mirrors the Brewfile gate)
#
# Lists map one logical name to per-manager package names; the format is
# documented in packages/base.txt. POSIX sh on purpose: minimal containers
# (alpine, debian-slim) ship neither bash nor zsh. Idempotent: installed
# packages are detected via the manager's own database and skipped; when
# nothing is missing, no sudo or network call is made at all.

set -euf

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
PACKAGES_DIR="$REPO_ROOT/packages"
GUI_INSTALL="${GUI_INSTALL:-}"

MANAGERS="apt dnf pacman apk zypper"

usage() {
  cat <<'EOF'
Usage: bootstrap-packages.sh [--dry-run] [--manager MGR] [LIST_FILE...]

Ensure baseline system packages are installed. The package manager is
auto-detected (apt, dnf/dnf5/microdnf/yum, pacman, apk, zypper); hosts
without a supported manager (e.g. macOS, which uses the Brewfile) print a
notice and exit 0. Without LIST_FILE arguments the defaults are
packages/base.txt, plus packages/gui.txt when GUI_INSTALL=1.

Options:
  --dry-run      Print missing packages without installing (never needs sudo).
  --manager MGR  Force a manager family: apt|dnf|pacman|apk|zypper. Useful
                 with --dry-run to preview resolution for another distro;
                 refuses to install when it contradicts the detected manager.
  -h, --help     Show this help.

Exit codes:
  0  everything installed, nothing to do, or unsupported host (skipped)
  1  bad usage, unreadable/invalid package list, or failed install
EOF
}

log() { echo "[bootstrap-packages] $*"; }
die() {
  echo "[bootstrap-packages] Error: $*" >&2
  exit 1
}

DRY_RUN=0
FORCE_MGR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --manager) [ $# -ge 2 ] || die "--manager needs a value"; FORCE_MGR=$2; shift 2 ;;
    --manager=*) FORCE_MGR=${1#*=}; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) usage >&2; die "unknown option: $1" ;;
    *) break ;;
  esac
done
# remaining "$@" are explicit list files (default lists chosen after detection)

if [ -n "$FORCE_MGR" ]; then
  case " $MANAGERS " in
    *" $FORCE_MGR "*) ;;
    *) die "unknown --manager '$FORCE_MGR' (expected one of: $MANAGERS)" ;;
  esac
fi

# --- detect the package manager family and concrete tool --------------------
MGR="" PM_BIN=""
if command -v apt-get > /dev/null 2>&1; then
  MGR=apt PM_BIN=apt-get
elif command -v dnf > /dev/null 2>&1; then
  MGR=dnf PM_BIN=dnf
elif command -v dnf5 > /dev/null 2>&1; then
  MGR=dnf PM_BIN=dnf5
elif command -v microdnf > /dev/null 2>&1; then
  MGR=dnf PM_BIN=microdnf
elif command -v yum > /dev/null 2>&1; then
  MGR=dnf PM_BIN=yum
elif command -v pacman > /dev/null 2>&1; then
  MGR=pacman PM_BIN=pacman
elif command -v zypper > /dev/null 2>&1; then
  MGR=zypper PM_BIN=zypper
elif command -v apk > /dev/null 2>&1; then
  MGR=apk PM_BIN=apk
fi

if [ -n "$FORCE_MGR" ] && [ "$FORCE_MGR" != "$MGR" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    case "$FORCE_MGR" in
      apt) MGR=apt PM_BIN=apt-get ;;
      *) MGR=$FORCE_MGR PM_BIN=$FORCE_MGR ;;
    esac
  else
    die "--manager $FORCE_MGR contradicts detected manager '${MGR:-none}'; only allowed with --dry-run"
  fi
fi

if [ -z "$MGR" ]; then
  if [ "$(uname -s)" = "Darwin" ]; then
    log "macOS detected; system packages come from the Brewfile - nothing to do"
  else
    log "no supported package manager found ($MANAGERS); install the packages/*.txt equivalents manually"
  fi
  exit 0
fi

if [ $# -eq 0 ]; then
  if [ "$GUI_INSTALL" = "1" ]; then
    set -- "$PACKAGES_DIR/base.txt" "$PACKAGES_DIR/gui.txt"
  else
    set -- "$PACKAGES_DIR/base.txt"
  fi
fi

# --- parse the lists ---------------------------------------------------------
# Entry format (documented in packages/base.txt):
#   NAME [mgr=names ...]   names are comma-separated; '-' skips that manager
PACKAGES=""

validate_name() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9@._+-]*$'
}

check_names() {
  # $1: comma-separated package names, $2: source list (for error messages)
  _cn_rest="$1,"
  while [ -n "$_cn_rest" ]; do
    _cn_name=${_cn_rest%%,*}
    _cn_rest=${_cn_rest#*,}
    validate_name "$_cn_name" || die "invalid package name '$_cn_name' in $2"
  done
}

add_packages() {
  # $1: comma-separated, already validated package names (deduplicated)
  _ap_rest="$1,"
  while [ -n "$_ap_rest" ]; do
    _ap_pkg=${_ap_rest%%,*}
    _ap_rest=${_ap_rest#*,}
    case " $PACKAGES " in
      *" $_ap_pkg "*) ;;
      *) PACKAGES="$PACKAGES $_ap_pkg" ;;
    esac
  done
}

parse_line() {
  # $1: raw line, $2: source list (for error messages)
  _pl_src=$2
  set -- ${1%%#*}
  [ $# -eq 0 ] && return 0
  _pl_name=$1
  shift
  check_names "$_pl_name" "$_pl_src"
  _pl_val=$_pl_name
  # every override is validated, even for other managers, so a typo in the
  # list fails loudly on whatever host parses it first
  for _pl_tok in "$@"; do
    case "$_pl_tok" in
      *=*) ;;
      *) die "unexpected token '$_pl_tok' in $_pl_src (overrides look like dnf=name1,name2)" ;;
    esac
    _pl_key=${_pl_tok%%=*}
    _pl_ov=${_pl_tok#*=}
    case " $MANAGERS " in
      *" $_pl_key "*) ;;
      *) die "unknown manager key '$_pl_key' in $_pl_src; expected one of: $MANAGERS" ;;
    esac
    [ -n "$_pl_ov" ] || die "empty override '$_pl_tok' for '$_pl_name' in $_pl_src (use '-' to skip a manager)"
    [ "$_pl_ov" = "-" ] || check_names "$_pl_ov" "$_pl_src"
    if [ "$_pl_key" = "$MGR" ]; then
      _pl_val=$_pl_ov
    fi
  done
  [ "$_pl_val" = "-" ] && return 0
  add_packages "$_pl_val"
}

for _list in "$@"; do
  [ -f "$_list" ] || die "missing package list: $_list"
  # shellcheck disable=SC2094 # $_list is only passed along for error messages
  while IFS= read -r _line || [ -n "$_line" ]; do
    parse_line "$_line" "$_list"
  done < "$_list"
done

set -- $PACKAGES
TOTAL=$#
if [ "$TOTAL" -eq 0 ]; then
  log "no packages listed for $MGR; nothing to do"
  exit 0
fi

# --- find what is missing ----------------------------------------------------
case "$MGR" in
  apt) QUERY_BIN=dpkg-query ;;
  dnf | zypper) QUERY_BIN=rpm ;;
  pacman) QUERY_BIN=pacman ;;
  apk) QUERY_BIN=apk ;;
esac
HAVE_QUERY=1
# only absent when --manager forces a foreign family (dry-run only)
command -v "$QUERY_BIN" > /dev/null 2>&1 || HAVE_QUERY=0

is_installed() {
  [ "$HAVE_QUERY" -eq 1 ] || return 1
  case "$MGR" in
    apt) dpkg-query -W -f '${Status}' "$1" 2> /dev/null | grep -q 'install ok installed' ;;
    dnf | zypper) rpm -q "$1" > /dev/null 2>&1 ;;
    pacman) pacman -Qq "$1" > /dev/null 2>&1 ;;
    apk) apk info -e "$1" > /dev/null 2>&1 ;;
  esac
}

MISSING=""
for _pkg in $PACKAGES; do
  is_installed "$_pkg" || MISSING="$MISSING $_pkg"
done

set -- $MISSING
NMISS=$#
if [ "$NMISS" -eq 0 ]; then
  log "all $TOTAL listed packages already installed ($MGR)"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  if [ "$HAVE_QUERY" -eq 1 ]; then
    log "would install via $PM_BIN ($NMISS of $TOTAL listed): $*"
  else
    log "would install via $PM_BIN ($NMISS of $TOTAL listed; installed state unknown on this host): $*"
  fi
  exit 0
fi

# --- install -----------------------------------------------------------------
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo > /dev/null 2>&1; then
    sudo "$@"
  else
    die "need root or sudo to run: $*"
  fi
}

log "installing via $PM_BIN ($NMISS of $TOTAL listed): $*"
case "$MGR" in
  apt)
    as_root apt-get update
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
    ;;
  dnf)
    as_root "$PM_BIN" install -y "$@"
    ;;
  pacman)
    # -Sy + install is the usual container bootstrap; on long-running arch
    # systems prefer a full -Syu first to avoid partial upgrades.
    as_root pacman -Sy --needed --noconfirm "$@"
    ;;
  apk)
    as_root apk add --no-cache "$@"
    ;;
  zypper)
    as_root zypper --non-interactive install --no-recommends "$@"
    ;;
esac
log "done"
