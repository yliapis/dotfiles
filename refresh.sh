#!/usr/bin/env zsh

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_ROOT" || exit 1

# refresh Brewfile installs
CLEAR_CACHE=${CLEAR_CACHE:-0}
brew bundle --file="$DOTFILES_ROOT/Brewfile"
if [[ "$CLEAR_CACHE" == "1" ]]; then
  brew bundle cleanup --force --file="$DOTFILES_ROOT/Brewfile"
fi
brew upgrade
# refresh brew casks
brew upgrade --cask --greedy

# refresh snap installations
# TODO: add snap refresh script

# refresh system
# TODO: add system refresh
