#!/usr/bin/env zsh
# install.sh — bootstrap or refresh this dotfiles repo on the local machine.
#
# Usage:
#   source install.sh                 # initial bootstrap (README entry point)
#   ./install.sh                      # same, as a subprocess (make install)
#   ./install.sh --refresh            # maintenance refresh (make refresh)
#   GUI_INSTALL=1 ./install.sh        # Linux: also run the Brewfile
#   INSTALL_OLLAMA=0 ./install.sh     # skip ollama during bootstrap
#   CLEAR_CACHE=1 ./install.sh --refresh
#
# Modes:
#   install   (default) platform/shell detect, Homebrew, optional Brewfile,
#                       copy home-config/, wire shell extras, run
#                       scripts/install-*.sh, optional ollama.
#   refresh   (--refresh) optional brew bundle / full re-bootstrap, brew
#                       upgrades, sync-coding-tools.sh, optional install-*.sh.
#
# Flags:
#   --refresh             Set MODE=refresh (maintenance path above).
#   <positional>          Optional; if set, overrides GUI_INSTALL (legacy:
#                         pass 1 to force Brewfile on non-macOS). Prefer the
#                         GUI_INSTALL env var.
#
# Environment variables (all optional; defaults shown):
#   MODE=install          install | refresh. --refresh sets refresh.
#   GUI_INSTALL=          Empty by default. On macOS the Brewfile always runs;
#                         on Linux set to 1 (or pass positional 1) to run it.
#   INSTALL_OLLAMA=1      Bootstrap only: install ollama when missing.
#   CLEAR_CACHE=0         Refresh only: brew bundle cleanup --force when 1.
#   RERUN_INSTALL=0       Refresh only: when 1, re-run full bootstrap instead
#                         of just brew bundle.
#   REFRESH_BREWFILE=1    Refresh only: run brew bundle unless RERUN_INSTALL=1.
#   REFRESH_SCRIPTS=1     Refresh only: re-run scripts/install-*.sh when 1.

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

MODE=${MODE:-install}
GUI_INSTALL=${GUI_INSTALL:-}
INSTALL_OLLAMA=${INSTALL_OLLAMA:-1}
CLEAR_CACHE=${CLEAR_CACHE:-0}
RERUN_INSTALL=${RERUN_INSTALL:-0}
REFRESH_BREWFILE=${REFRESH_BREWFILE:-1}
REFRESH_SCRIPTS=${REFRESH_SCRIPTS:-1}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh)
      MODE=refresh
      shift
      ;;
    *)
      break
      ;;
  esac
done

GUI_INSTALL=${1:-$GUI_INSTALL}

run_install_scripts() {
  if [ ! -d "$DOTFILES_ROOT/scripts" ]; then
    return 0
  fi
  for script in "$DOTFILES_ROOT/scripts"/install-*.sh; do
    [ -f "$script" ] || continue
    echo "running $(basename "$script")"
    bash "$script"
  done
}

copy_home_config() {
  local src_dir="$DOTFILES_ROOT/home-config"
  if [ ! -d "$src_dir" ]; then
    echo "Error: missing home-config dir: $src_dir"
    exit 1
  fi
  echo "copying $src_dir/ into $HOME (overwriting)"
  cp -af "$src_dir/." "$HOME/"
}

# Managed shell extras: single source line in ~/.zshrc / ~/.bashrc that points at
# the shared entrypoint. The entrypoint dispatches to the per-shell extras file.
ensure_dotfiles_shell_extras_source() {
  local snippet="$HOME/.shell_extras.sh"
  if [ ! -f "$snippet" ]; then
    echo "Error: missing shell extras: $snippet"
    exit 1
  fi
  if grep -qF '# dotfiles: shell extras (managed by dotfiles/install.sh)' "$DEFAULT_PROFILE_FILE" 2>/dev/null; then
    return 0
  fi
  print '' >> "$DEFAULT_PROFILE_FILE"
  print '# dotfiles: shell extras (managed by dotfiles/install.sh)' >> "$DEFAULT_PROFILE_FILE"
  printf '[ -f %q ] && . %q\n' "$snippet" "$snippet" >> "$DEFAULT_PROFILE_FILE"
}

detect_platform() {
  case "$OSTYPE" in
    darwin*)
      echo "macos detected"
      ;;
    linux-gnu*)
      echo "linux-gnu detected (likely ubuntu)"
      ;;
    "")
      echo "Error: OSTYPE undefined, try sourcing this script or setting the variable properly"
      exit 1
      ;;
    *)
      echo "unsupported platform detected: $OSTYPE"
      exit 1
      ;;
  esac
}

detect_shell() {
  if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/opt/homebrew/bin/zsh" ]; then
    echo "zsh detected"
    SHELL_DETECTED="zsh"
  elif [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/opt/homebrew/bin/bash" ]; then
    echo "bash detected"
    SHELL_DETECTED="bash"
  else
    echo "unsupported shell detected: $SHELL"
    exit 1
  fi

  if [ "$SHELL_DETECTED" = "zsh" ]; then
    DEFAULT_PROFILE_FILE="$HOME/.zshrc"
  elif [ "$SHELL_DETECTED" = "bash" ]; then
    DEFAULT_PROFILE_FILE="$HOME/.bashrc"
  fi
}

ensure_curl() {
  if command -v curl > /dev/null 2>&1; then
    return 0
  fi
  case "$OSTYPE" in
    linux-gnu*)
      sudo apt install --update curl
      ;;
    *)
      echo "curl expected to be installed; exiting"
      exit 1
      ;;
  esac
}

ensure_tilix() {
  case "$OSTYPE" in
    linux-gnu*)
      echo "installing tilix terminal emulator"
      sudo apt-get install tilix
      ;;
  esac
}

ensure_profile_file() {
  if [ -f "$DEFAULT_PROFILE_FILE" ]; then
    echo "profile file exists"
  else
    echo "profile file does not exist, creating"
    touch "$DEFAULT_PROFILE_FILE"
  fi
}

ensure_homebrew() {
  if command -v brew &> /dev/null; then
    return 0
  fi
  echo "installing homebrew"
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  case "$OSTYPE" in
    darwin*)    BREW_ROOT="/opt/homebrew" ;;
    linux-gnu*) BREW_ROOT="/home/linuxbrew/.linuxbrew" ;;
  esac
  # activate for this script session; persistent PATH setup lives in ~/.shell_extras.sh
  eval "$("$BREW_ROOT/bin/brew" shellenv)"
}

disable_brew_analytics() {
  # https://docs.brew.sh/Analytics
  brew analytics off
}

# Emit space-separated mas app ids from the Brewfile that are already installed
# and not outdated. brew bundle + mas often re-downloads every run when
# inventory detection fails; HOMEBREW_BUNDLE_MAS_SKIP avoids that while keeping
# Brewfile entries declared for cleanup. Ids (not names) so spaced app names
# still match the skipper.
mas_satisfied_skip_ids() {
  local brewfile="$DOTFILES_ROOT/Brewfile"
  local mas_list="" mas_outdated="" line id skips=()

  [[ -f "$brewfile" ]] || return 0

  if command -v mas >/dev/null 2>&1; then
    mas_list="$(mas list 2>/dev/null || true)"
    mas_outdated="$(mas outdated 2>/dev/null || true)"
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*mas[[:space:]]+ ]] || continue
    id="$(sed -n 's/.*id:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' <<<"$line")"
    [[ -n "$id" ]] || continue

    if printf '%s\n' "$mas_outdated" | grep -q "^${id}[[:space:]]"; then
      continue
    fi

    if printf '%s\n' "$mas_list" | grep -q "^${id}[[:space:]]"; then
      skips+=("$id")
      continue
    fi

    # Fallback when mas inventory misses an installed App Store app.
    if command -v mdfind >/dev/null 2>&1 \
      && [[ -n "$(mdfind "kMDItemAppStoreAdamID == ${id}" 2>/dev/null)" ]]; then
      skips+=("$id")
    fi
  done < "$brewfile"

  (( ${#skips[@]} )) || return 0
  printf '%s\n' "${skips[*]}"
}

run_brewfile() {
  echo "Running full brew install from Brewfile"
  local mas_skip="${HOMEBREW_BUNDLE_MAS_SKIP:-}"
  local satisfied
  satisfied="$(mas_satisfied_skip_ids)"
  if [[ -n "$satisfied" ]]; then
    mas_skip="${mas_skip:+$mas_skip }$satisfied"
    echo "mas apps already installed (and not outdated); skipping: $satisfied"
  fi
  HOMEBREW_BUNDLE_MAS_SKIP="$mas_skip" brew bundle --file="$DOTFILES_ROOT/Brewfile"
}

run_brewfile_if_gui() {
  if [[ "$OSTYPE" == darwin* ]] || [ "$GUI_INSTALL" = "1" ]; then
    run_brewfile
  else
    echo "non macos detected and GUI_INSTALL not set to 1; skipping Brewfile"
  fi
}

ensure_ollama() {
  if [ "$INSTALL_OLLAMA" != "1" ]; then
    return 0
  fi
  if command -v ollama &> /dev/null; then
    return 0
  fi
  echo "ollama not installed, installing"
  curl -fsSL https://ollama.com/install.sh | $SHELL
}

sync_coding_tools() {
  if [[ -x "$DOTFILES_ROOT/scripts/sync-coding-tools.sh" ]]; then
    "$DOTFILES_ROOT/scripts/sync-coding-tools.sh"
  fi
}

upgrade_brew() {
  brew upgrade
  brew upgrade --cask --greedy
}

cleanup_brew_cache() {
  if [[ "$CLEAR_CACHE" == "1" ]]; then
    brew bundle cleanup --force --file="$DOTFILES_ROOT/Brewfile"
  fi
}

do_bootstrap() {
  echo "begining dotfiles install"

  detect_platform
  detect_shell
  ensure_curl
  ensure_tilix
  ensure_profile_file
  ensure_homebrew
  disable_brew_analytics
  run_brewfile_if_gui
  copy_home_config
  ensure_dotfiles_shell_extras_source
  run_install_scripts
  ensure_ollama

  echo "dotfiles install complete"
}

do_refresh() {
  cd "$DOTFILES_ROOT" || exit 1

  if [[ "$RERUN_INSTALL" == "1" ]]; then
    do_bootstrap
  elif [[ "$REFRESH_BREWFILE" == "1" ]]; then
    run_brewfile
  fi

  cleanup_brew_cache
  upgrade_brew
  sync_coding_tools

  if [[ "$REFRESH_SCRIPTS" == "1" ]]; then
    run_install_scripts
  fi

  # TODO: add snap refresh script
  # TODO: add system refresh

  echo "dotfiles refresh complete"
}

if [[ "$MODE" == "refresh" ]]; then
  do_refresh
else
  do_bootstrap
fi
