#!/usr/bin/env zsh

echo "begining dotfiles install"

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

# INPUT_VARIABLES
GUI_INSTALL=${1:-$GUI_INSTALL}
# OPTIONAL_VARIABLES
INSTALL_OLLAMA=${INSTALL_OLLAMA:-1}


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

ensure_brew_shellenv_in_profile() {
  command -v brew >/dev/null 2>&1 || return 0
  if grep -q 'brew shellenv' "$DEFAULT_PROFILE_FILE" 2>/dev/null; then
    return 0
  fi
  print '' >> "$DEFAULT_PROFILE_FILE"
  print 'eval "$(brew shellenv)"' >> "$DEFAULT_PROFILE_FILE"
}

# install homebrew
if ! command -v brew &> /dev/null; then
  echo "installing homebrew"
  # install
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # get brew root path
  case "$OSTYPE" in
    darwin*)
      BREW_ROOT="/opt/homebrew/"
      ;;
    linux-gnu*)
      BREW_ROOT="/home/linuxbrew/.linuxbrew/"
      ;;
  esac
  # activate for this script session (profile updated via ensure_brew_shellenv_in_profile)
  BREW_ACTIVATION_COMMAND='eval $('$BREW_ROOT'/bin/brew shellenv)'
  eval "$BREW_ACTIVATION_COMMAND"
fi

# turn off homebrew analytics
# https://docs.brew.sh/Analytics
brew analytics off

ensure_brew_shellenv_in_profile

# install defaults from Brewfile based on OS
case "$OSTYPE" in
  darwin*)
    echo "Running full brew install from Brewfile"
    brew bundle --file="$DOTFILES_ROOT/Brewfile"
    ;;
  *)
    if [ "$GUI_INSTALL" = "1" ]; then
      echo "Running full brew install from Brewfile"
      brew bundle --file="$DOTFILES_ROOT/Brewfile"
    else
      echo "non macos detected OR GUI_INSTALL not set to 1"
      echo "Skipping brew install from Brewfile"
    fi
    ;;
esac

# Managed shell extras: single source line in ~/.zshrc / ~/.bashrc; content lives in repo.
ensure_dotfiles_shell_extras_source() {
  local snippet="$DOTFILES_ROOT/home_config/shell_extras.zsh"
  if [ "$SHELL_DETECTED" = "bash" ]; then
    snippet="$DOTFILES_ROOT/home_config/shell_extras.bash"
  fi
  if [ ! -f "$snippet" ]; then
    echo "Error: missing managed shell extras: $snippet"
    exit 1
  fi
  if grep -qF '# dotfiles: shell extras (managed by dotfiles/install.sh)' "$DEFAULT_PROFILE_FILE" 2>/dev/null; then
    return 0
  fi
  print '' >> "$DEFAULT_PROFILE_FILE"
  print '# dotfiles: shell extras (managed by dotfiles/install.sh)' >> "$DEFAULT_PROFILE_FILE"
  printf '[ -f %q ] && . %q\n' "$snippet" "$snippet" >> "$DEFAULT_PROFILE_FILE"
}

ensure_dotfiles_shell_extras_source


# ollama setup
if [ "$INSTALL_OLLAMA" = "1" ]; then
  # check if ollama is already installed
  if ! command -v ollama &> /dev/null; then
    echo "ollama not installed, installing"
    curl -fsSL https://ollama.com/install.sh | $SHELL
  fi
fi

echo "dotfiles install complete"
