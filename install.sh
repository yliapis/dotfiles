#!/usr/bin/env bash


echo "begining dotfiles install"


# platform guard
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "macos detected"
else
  echo "unsupported platform detected: $OSTYPE"
  exit 1
fi


# install homebrew
if ! command -v brew &> /dev/null; then
  echo "installing homebrew"
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
fi
