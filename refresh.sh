#!/usr/bin/env zsh

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_ROOT" || exit 1

# refresh Brewfile installs
CLEAR_CACHE=${CLEAR_CACHE:-0}
# rerun install.sh
RERUN_INSTALL=${RERUN_INSTALL:-0}
# refresh Brewfile
REFRESH_BREWFILE=${REFRESH_BREWFILE:-1}

if [[ "$RERUN_INSTALL" == "1" ]]; then
  source "$DOTFILES_ROOT/install.sh"
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
if [[ -f "$DOTFILES_ROOT/Makefile" ]]; then
  make -C "$DOTFILES_ROOT" sync
fi

# refresh snap installations
# TODO: add snap refresh script

# refresh system
# TODO: add system refresh
