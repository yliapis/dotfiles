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
  DEFAULT_PROFILE_FILE="$HOME/.zshenv"
  # install oh-my-zsh
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
elif [[ $SHELL == "/bin/bash" ]]; then
  echo "bash detected"
  DEFAULT_PROFILE_FILE="$HOME/.bashrc"
else
  echo "unsupported shell detected: $SHELL"
  exit 1
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
