#!/usr/bin/env zsh

# refresh Brewfile installs
brew bundle --file=Brewfile
brew upgrade
# refresh brew casks
brew upgrade --cask --greedy

# refresh snap installations
# TODO: add snap refresh script

# refresh system
# TODO: add system refresh
