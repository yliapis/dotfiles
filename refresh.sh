#!/usr/bin/env zsh

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_ROOT" || exit 1

# refresh Brewfile installs
CLEAR_CACHE=${CLEAR_CACHE:-0}
# rerun install.sh
RERUN_INSTALL=${RERUN_INSTALL:-0}
# refresh Brewfile
REFRESH_BREWFILE=${REFRESH_BREWFILE:-1}
# run scripts/install-*.sh installers
REFRESH_SCRIPTS=${REFRESH_SCRIPTS:-1}

# keep the linux baseline packages current (no-op on macOS or when complete)
sh "$DOTFILES_ROOT/scripts/bootstrap-packages.sh"

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
if [[ -x "$DOTFILES_ROOT/scripts/sync-coding-tools.sh" ]]; then
  "$DOTFILES_ROOT/scripts/sync-coding-tools.sh"
fi

if [[ "$REFRESH_SCRIPTS" == "1" ]] && [ -d "$DOTFILES_ROOT/scripts" ]; then
  for script in "$DOTFILES_ROOT/scripts"/install-*.sh; do
    [ -f "$script" ] || continue
    echo "running $(basename "$script")"
    bash "$script"
  done
fi

# refresh snap installations
# TODO: add snap refresh script

# refresh system
# TODO: add system refresh
