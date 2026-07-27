#!/usr/bin/env zsh

# Thin wrapper: maintenance mode lives in install.sh --refresh.
DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$DOTFILES_ROOT/install.sh" --refresh "$@"
