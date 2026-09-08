#!/usr/bin/env zsh
# install.sh — bootstrap or refresh this dotfiles repo on the local machine.
#
# Usage:
#   source install.sh                 # initial bootstrap (README entry point)
#   ./install.sh                      # same, as a subprocess (make install)
#   ./install.sh --refresh            # maintenance refresh (make refresh)
#   BREW_BUNDLE=1 ./install.sh        # Linux: also run the Brewfile
#   GUI_INSTALL=1 ./install.sh        # deprecated alias for BREW_BUNDLE=1
#   INSTALL_OLLAMA=1 ./install.sh     # also install ollama when missing
#   HERDR_PLUGIN_INSTALL=1 ./install.sh   # also install herdr plugins
#   APT_UPGRADE=1 ./install.sh        # Linux: also run apt update/upgrade
#   BREW_BUNDLE_MAS=1 ./install.sh --refresh  # also run Brewfile.mas
#   CLEAR_CACHE=1 ./install.sh --refresh
#
# Modes:
#   install   (default) platform/shell detect, Homebrew, optional Brewfile,
#                       copy home-config/, wire shell extras, run
#                       scripts/install-*.sh.
#   refresh   (--refresh) optional brew bundle / full re-bootstrap, brew
#                       upgrades, sync-coding-tools.sh, optional install-*.sh.
#
# Flags:
#   --refresh             Set MODE=refresh (maintenance path above).
#   <positional>          Optional; if set, overrides BREW_BUNDLE (legacy:
#                         pass 1 to force Brewfile on non-macOS). Prefer the
#                         BREW_BUNDLE env var.
#
# Environment variables (all optional; defaults shown):
#   MODE=install          install | refresh. --refresh sets refresh.
#   BREW_BUNDLE=          Empty by default. On macOS the Brewfile always runs;
#                         on Linux set to 1 (or pass positional 1) to run it.
#                         make install passes BREW_BUNDLE=1 unless you
#                         override it. GUI_INSTALL is a deprecated alias.
#   BREW_BUNDLE_MAS=      Unset by default. When 1, run Brewfile.mas (mas apps).
#                         On macOS install, empty/unset self-sets to 1; on
#                         Linux install and on refresh it stays unset unless
#                         you pass BREW_BUNDLE_MAS=1.
#   HERDR_PLUGIN_INSTALL=0
#                         Opt in to scripts/install-herdr-plugins.sh when 1;
#                         off by default in both modes. The script stays
#                         runnable directly regardless of this setting.
#   APT_UPGRADE=0         Both modes, Linux only: apt-get update plus
#                         apt-get upgrade when 1. No-op where apt-get is
#                         absent, macOS included.
#   INSTALL_OLLAMA=0      Bootstrap only: install ollama when missing
#                         when 1.
#   CLEAR_CACHE=0         Refresh only: brew bundle cleanup --force when 1.
#   RERUN_INSTALL=0       Refresh only: when 1, re-run full bootstrap instead
#                         of just brew bundle.
#   REFRESH_BREWFILE=1    Refresh only: run brew bundle unless RERUN_INSTALL=1.
#   REFRESH_SCRIPTS=1     Refresh only: re-run scripts/install-*.sh when 1.

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

MODE=${MODE:-install}
BREW_BUNDLE=${BREW_BUNDLE:-${GUI_INSTALL:-}}
INSTALL_OLLAMA=${INSTALL_OLLAMA:-0}
CLEAR_CACHE=${CLEAR_CACHE:-0}
RERUN_INSTALL=${RERUN_INSTALL:-0}
REFRESH_BREWFILE=${REFRESH_BREWFILE:-1}
REFRESH_SCRIPTS=${REFRESH_SCRIPTS:-1}
HERDR_PLUGIN_INSTALL=${HERDR_PLUGIN_INSTALL:-0}
APT_UPGRADE=${APT_UPGRADE:-0}

# Homebrew >= 6.0 upgrades `auto_updates true` casks on a plain `brew upgrade`
# (and through `brew bundle`). Those apps ship their own updaters, and some need
# root to swap themselves out: Docker Desktop's cask uninstall deletes files
# under /Library/PrivilegedHelperTools, so brew shells out to sudo. An unattended
# refresh has no tty to answer the password prompt, and the upgrade then dies
# *after* the app artifact is moved out of /Applications, leaving the machine
# with no Docker Desktop at all. Let the self-updating casks update themselves.
export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1

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

BREW_BUNDLE=${1:-$BREW_BUNDLE}

REFRESH_FAILURES=()

# Run one step, recording a failure instead of aborting so later steps still
# run. do_bootstrap and do_refresh report the collected names and exit non-zero.
run_step() {
  local label=$1
  shift
  "$@" && return 0
  echo "Error: $label failed"
  REFRESH_FAILURES+=("$label")
  return 0
}

run_install_scripts() {
  if [ ! -d "$DOTFILES_ROOT/scripts" ]; then
    return 0
  fi
  local failed=0
  for script in "$DOTFILES_ROOT/scripts"/install-*.sh; do
    [ -f "$script" ] || continue
    if [ "$script" = "$DOTFILES_ROOT/scripts/install-herdr-plugins.sh" ] && [ "$HERDR_PLUGIN_INSTALL" != "1" ]; then
      echo "HERDR_PLUGIN_INSTALL not set to 1; skipping $(basename "$script")"
      continue
    fi
    echo "running $(basename "$script")"
    if ! bash "$script"; then
      echo "Error: $(basename "$script") failed"
      failed=1
    fi
  done
  return "$failed"
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

# Ubuntu/Debian system packages: the apt counterpart to upgrade_brew. Guarded on
# the platform and on apt-get so macOS and any non-apt Linux skip it instead of
# failing. `sudo env DEBIAN_FRONTEND=...` rather than a leading assignment: sudo
# scrubs the environment, and setting the variable on sudo's own command line
# needs the sudoers setenv permission, while env is just a command sudo runs.
# Without it an unattended run stalls on a conffile or service-restart prompt.
upgrade_apt() {
  if [[ "$APT_UPGRADE" != "1" ]]; then
    echo "APT_UPGRADE not set to 1; skipping apt update/upgrade"
    return 0
  fi
  case "$OSTYPE" in
    linux-gnu*) ;;
    *) return 0 ;;
  esac
  if ! command -v apt-get > /dev/null 2>&1; then
    echo "apt-get not found; skipping apt update/upgrade"
    return 0
  fi
  echo "updating apt package lists"
  sudo apt-get update || return 1
  echo "upgrading apt packages"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
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

run_brewfile() {
  echo "Running full brew install from Brewfile"
  brew bundle --file="$DOTFILES_ROOT/Brewfile"
}

run_brewfile_mas() {
  if [[ "$BREW_BUNDLE_MAS" != "1" ]]; then
    return 0
  fi
  if [[ "$OSTYPE" != darwin* ]]; then
    echo "BREW_BUNDLE_MAS=1 but not macOS; skipping Brewfile.mas"
    return 0
  fi
  echo "Running mas brew install from Brewfile.mas"
  brew bundle --file="$DOTFILES_ROOT/Brewfile.mas"
}

run_brewfile_if_enabled() {
  if [[ "$OSTYPE" == darwin* ]] || [ "$BREW_BUNDLE" = "1" ]; then
    run_brewfile
  else
    echo "non macos detected and BREW_BUNDLE not set to 1; skipping Brewfile"
  fi
}

ensure_ollama() {
  if [ "$INSTALL_OLLAMA" != "1" ]; then
    echo "INSTALL_OLLAMA not set to 1; skipping ollama"
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
  run_step "brew upgrade" brew upgrade
  # --greedy-latest, not --greedy: HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS above
  # does not apply to --greedy, which would drag the self-updating casks back in.
  # --greedy-latest still covers `version :latest` casks, which brew cannot
  # version-compare and would otherwise never upgrade.
  run_step "brew upgrade --cask" brew upgrade --cask --greedy-latest
}

cleanup_brew_cache() {
  if [[ "$CLEAR_CACHE" == "1" ]]; then
    # Union both brewfiles so mas apps are not treated as orphans.
    brew bundle cleanup --force \
      --file=<(cat "$DOTFILES_ROOT/Brewfile" "$DOTFILES_ROOT/Brewfile.mas")
  fi
}

do_bootstrap() {
  echo "beginning dotfiles install"

  detect_platform
  detect_shell
  run_step "apt upgrade" upgrade_apt
  ensure_curl
  ensure_tilix
  ensure_profile_file
  ensure_homebrew
  disable_brew_analytics
  run_step "brew bundle" run_brewfile_if_enabled
  run_step "brew bundle (mas)" run_brewfile_mas
  copy_home_config
  ensure_dotfiles_shell_extras_source
  run_install_scripts
  ensure_ollama

  if (( ${#REFRESH_FAILURES[@]} )); then
    echo "dotfiles install finished with failures: ${REFRESH_FAILURES[*]}"
    exit 1
  fi

  echo "dotfiles install complete"
}

do_refresh() {
  cd "$DOTFILES_ROOT" || exit 1

  if [[ "$RERUN_INSTALL" == "1" ]]; then
    do_bootstrap
  else
    if [[ "$REFRESH_BREWFILE" == "1" ]]; then
      run_step "brew bundle" run_brewfile
    fi
    run_step "brew bundle (mas)" run_brewfile_mas
  fi

  run_step "brew bundle cleanup" cleanup_brew_cache
  upgrade_brew
  run_step "apt upgrade" upgrade_apt
  run_step "sync-coding-tools.sh" sync_coding_tools

  if [[ "$REFRESH_SCRIPTS" == "1" ]]; then
    run_step "install scripts" run_install_scripts
  fi

  # TODO: add snap refresh script

  if (( ${#REFRESH_FAILURES[@]} )); then
    echo "dotfiles refresh finished with failures: ${REFRESH_FAILURES[*]}"
    exit 1
  fi

  echo "dotfiles refresh complete"
}

if [[ "$MODE" == "refresh" ]]; then
  do_refresh
else
  # install: empty/unset BREW_BUNDLE_MAS self-sets to 1 on macOS only.
  if [[ -z "$BREW_BUNDLE_MAS" && "$OSTYPE" == darwin* ]]; then
    BREW_BUNDLE_MAS=1
  fi
  do_bootstrap
fi
