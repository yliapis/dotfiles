#!/usr/bin/env zsh

echo "begining dotfiles install"

# INPUT_VARIABLES
GUI_INSTALL=${1:-$GUI_INSTALL}

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
  # add to profile and activate
  BREW_ACTIVATION_COMMAND='eval $('$BREW_ROOT'/bin/brew shellenv)'
  (echo; echo "$BREW_ACTIVATION_COMMAND") >> "$DEFAULT_PROFILE_FILE"
  eval "$BREW_ACTIVATION_COMMAND"
fi

# turn off homebrew analytics
# https://docs.brew.sh/Analytics
brew analytics off

# install defaults from Brewfile based on OS
case "$OSTYPE" in
  darwin*)
    echo "Running full brew install from Brewfile"
    brew bundle --file=Brewfile
    ;;
  *)
    if [ "$GUI_INSTALL" = "1" ]; then
      echo "Running full brew install from Brewfile"
      brew bundle --file=Brewfile
    else
      echo "non macos detected OR GUI_INSTALL not set to 1"
      echo "Skipping brew install from Brewfile"
    fi
    ;;
esac

# fzf setup
if [ "$SHELL_DETECTED" = "zsh" ]; then
  echo "# Set up fzf key bindings and fuzzy completion" >> "$DEFAULT_PROFILE_FILE"
  echo "source <(fzf --zsh)" >> "$DEFAULT_PROFILE_FILE"
  # Set up fzf key bindings and fuzzy completion
  eval "$(fzf --zsh)"
elif [ "$SHELL_DETECTED" = "bash" ]; then
  echo "# Set up fzf key bindings and fuzzy completion" >> "$DEFAULT_PROFILE_FILE"
  echo "source <(fzf --bash)" >> "$DEFAULT_PROFILE_FILE"
  # Set up fzf key bindings and fuzzy completion
  source <(fzf --bash)
fi

# starship setup
if [ "$SHELL_DETECTED" = "zsh" ]; then
  echo "# Set up starship prompt" >> "$DEFAULT_PROFILE_FILE"
  echo "eval \"\$(starship init zsh)\"" >> "$DEFAULT_PROFILE_FILE"
  # Set up starship prompt
  eval "$(starship init zsh)"
elif [ "$SHELL_DETECTED" = "bash" ]; then
  echo "# Set up starship prompt" >> "$DEFAULT_PROFILE_FILE"
  echo "eval \"\$(starship init bash)\"" >> "$DEFAULT_PROFILE_FILE"
  # Set up starship prompt
  eval "$(starship init bash)"
fi

echo "dotfiles install complete"
