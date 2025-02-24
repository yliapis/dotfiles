#!/usr/bin/env sh

echo "begining dotfiles install"

# platform guard
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "macos detected"
elif [[ "$OSTYPE" == "linux-gnu" ]]; then
  echo "linux-gnu detected (likely ubuntu)"
elif [ -z $OSTYPE ]; then
  echo "Error: OSTYPE undefined, try sourcing this script or setting the variable properly"
  exit 1
else
  echo "unsupported platform detected: $OSTYPE"
  exit 1
fi


# shell customization
if [[ $SHELL == "/bin/zsh" ]]; then
  echo "zsh detected"
  SHELL_DETECTED="zsh"
elif [[ $SHELL == "/bin/bash" ]]; then
  echo "bash detected"
  SHELL_DETECTED="bash"
else
  echo "unsupported shell detected: $SHELL"
  exit 1
fi

# shell specific setup
if [[ $SHELL_DETECTED == "zsh" ]]; then
  DEFAULT_PROFILE_FILE="$HOME/.zshrc"
  # install oh-my-zsh
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "oh-my-zsh already installed"
  else
    echo "installing oh-my-zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
elif [[ $SHELL_DETECTED == "bash" ]]; then
  DEFAULT_PROFILE_FILE="$HOME/.bashrc"
fi

if ! command -v curl &> /dev/null; then
  if [[ $OSTYPE == "linux-gnu" ]]; then
    sudo apt install --update curl
  else
    echo "curl expected to be installed; exiting"
    exit 1
  fi
fi

# install tilix on linux
if [ $OSTYPE = "linux-gnu" ]; then
  echo "installing tilix terminal emulator"
  sudo apt-get install tilix
fi

if [[ -f $DEFAULT_PROFILE_FILE ]]; then
  echo "profile file exists"
else
  echo "profile file does not exist, creating"
  touch $DEFAULT_PROFILE_FILE
fi

# install homebrew
if ! command -v brew &> /dev/null; then
  echo "installing homebrew"
  # install
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # get brew root path
  if [[ $OSTYPE == "darwin"* ]]; then
    BREW_ROOT="/opt/homebrew/"
  elif [[ $OSTYPE == "linux-gnu" ]]; then
    BREW_ROOT="/home/linuxbrew/.linuxbrew/"
  fi
  # add to profile and activate
  BREW_ACTIVATION_COMMAND='eval $('$BREW_ROOT'/bin/brew shellenv)'
  (echo; echo $BREW_ACTIVATION_COMMAND) >> $DEFAULT_PROFILE_FILE
  eval $BREW_ACTIVATION_COMMAND
fi

# turn off homebrew analytics
# https://docs.brew.sh/Analytics
brew analytics off

# install defaults from Brewfile based on OS
if [ $OSTYPE = "darwin"* ] || [ "$BREW_FULL_INSTALL" = "1" ]; then
  echo "Running full brew install from Brewfile"
  brew bundle --file=Brewfile
else
  echo "non macos detected OR BREW_FULL_INSTALL not set to 1"
  echo "Skipping brew install from Brewfile"
fi

# fzf setup
if [[ $SHELL_DETECTED == "zsh" ]]; then
  echo "# Set up fzf key bindings and fuzzy completion" >> $DEFAULT_PROFILE_FILE
  echo "source <(fzf --zsh)" >> $DEFAULT_PROFILE_FILE
  # Set up fzf key bindings and fuzzy completion
  source <(fzf --zsh)
fi
