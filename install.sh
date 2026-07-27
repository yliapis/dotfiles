#!/usr/bin/env zsh

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

# MODE: install (default) | refresh
MODE=${MODE:-install}
# INPUT_VARIABLES (install mode)
GUI_INSTALL=${GUI_INSTALL:-}
# OPTIONAL_VARIABLES
INSTALL_OLLAMA=${INSTALL_OLLAMA:-1}
# refresh-mode knobs (also honored when MODE=refresh / --refresh)
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

# Positional $1 remains GUI_INSTALL for install mode (and RERUN_INSTALL refresh).
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

do_bootstrap() {
  echo "begining dotfiles install"

  # platform guard
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

  # shell customization
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

  # shell specific setup
  if [ "$SHELL_DETECTED" = "zsh" ]; then
    DEFAULT_PROFILE_FILE="$HOME/.zshrc"
  elif [ "$SHELL_DETECTED" = "bash" ]; then
    DEFAULT_PROFILE_FILE="$HOME/.bashrc"
  fi

  if ! command -v curl > /dev/null 2>&1; then
    case "$OSTYPE" in
      linux-gnu*)
        sudo apt install --update curl
        ;;
      *)
        echo "curl expected to be installed; exiting"
        exit 1
        ;;
    esac
  fi

  # install tilix on linux
  case "$OSTYPE" in
    linux-gnu*)
      echo "installing tilix terminal emulator"
      sudo apt-get install tilix
      ;;
  esac

  if [ -f "$DEFAULT_PROFILE_FILE" ]; then
    echo "profile file exists"
  else
    echo "profile file does not exist, creating"
    touch "$DEFAULT_PROFILE_FILE"
  fi

  # install homebrew
  if ! command -v brew &> /dev/null; then
    echo "installing homebrew"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    case "$OSTYPE" in
      darwin*)    BREW_ROOT="/opt/homebrew" ;;
      linux-gnu*) BREW_ROOT="/home/linuxbrew/.linuxbrew" ;;
    esac
    # activate for this script session; persistent PATH setup lives in ~/.shell_extras.sh
    eval "$("$BREW_ROOT/bin/brew" shellenv)"
  fi

  # turn off homebrew analytics
  # https://docs.brew.sh/Analytics
  brew analytics off

  # install defaults from Brewfile (skipped on non-macOS unless GUI_INSTALL=1)
  if [[ "$OSTYPE" == darwin* ]] || [ "$GUI_INSTALL" = "1" ]; then
    echo "Running full brew install from Brewfile"
    brew bundle --file="$DOTFILES_ROOT/Brewfile"
  else
    echo "non macos detected and GUI_INSTALL not set to 1; skipping Brewfile"
  fi

  copy_home_config
  ensure_dotfiles_shell_extras_source
  run_install_scripts

  # ollama setup
  if [ "$INSTALL_OLLAMA" = "1" ]; then
    if ! command -v ollama &> /dev/null; then
      echo "ollama not installed, installing"
      curl -fsSL https://ollama.com/install.sh | $SHELL
    fi
  fi

  echo "dotfiles install complete"
}

do_refresh() {
  cd "$DOTFILES_ROOT" || exit 1

  if [[ "$RERUN_INSTALL" == "1" ]]; then
    do_bootstrap
  elif [[ "$REFRESH_BREWFILE" == "1" ]]; then
    brew bundle --file="$DOTFILES_ROOT/Brewfile"
  fi

  if [[ "$CLEAR_CACHE" == "1" ]]; then
    brew bundle cleanup --force --file="$DOTFILES_ROOT/Brewfile"
  fi
  brew upgrade
  # refresh brew casks
  brew upgrade --cask --greedy

  # sync AI coding tools (commands + skills) into the user's home directory
  if [[ -x "$DOTFILES_ROOT/scripts/sync-coding-tools.sh" ]]; then
    "$DOTFILES_ROOT/scripts/sync-coding-tools.sh"
  fi

  if [[ "$REFRESH_SCRIPTS" == "1" ]]; then
    run_install_scripts
  fi

  # refresh snap installations
  # TODO: add snap refresh script

  # refresh system
  # TODO: add system refresh

  echo "dotfiles refresh complete"
}

if [[ "$MODE" == "refresh" ]]; then
  do_refresh
else
  do_bootstrap
fi
