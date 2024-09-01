#!/usr/bin/env bash


echo "begining dotfiles install"

# platform guard
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "macos detected"
  DEFAULT_PROFILE_FILE="$HOME/.zprofile"
else
  echo "unsupported platform detected: $OSTYPE"
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
