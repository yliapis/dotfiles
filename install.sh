#!/usr/bin/env bash


echo "begining dotfiles install"

# platform guard
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "macos detected"
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
  # add to profile and activate
  (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $DEFAULT_PROFILE_FILE
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# turn off homebrew analytics
# https://docs.brew.sh/Analytics
brew analytics off

# install defaults from Brewfile
brew bundle --file=Brewfile
