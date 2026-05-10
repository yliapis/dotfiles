#!/usr/bin/env zsh

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_ROOT" || exit 1

# refresh Brewfile installs
brew bundle --file="$DOTFILES_ROOT/Brewfile"
brew upgrade
# refresh brew casks
brew upgrade --cask --greedy

# refresh snap installations
# TODO: add snap refresh script

# refresh system
# TODO: add system refresh
