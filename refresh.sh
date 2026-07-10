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
# home-config copy mode for existing files that differ: keep | overwrite | prompt
HOME_CONFIG_MODE=${HOME_CONFIG_MODE:-keep}

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

# mirror managed dotfiles (home-config/) into $HOME. New files are always
# copied; for existing files that differ from the repo, HOME_CONFIG_MODE
# decides: keep them (default), overwrite them, or prompt per file.
sync_home_config() {
  local src_root="$DOTFILES_ROOT/home-config" src rel dst ans
  case "$HOME_CONFIG_MODE" in
    keep|overwrite|prompt) ;;
    *)
      echo "unknown HOME_CONFIG_MODE '$HOME_CONFIG_MODE' (expected: keep, overwrite, prompt); skipping home-config sync" >&2
      return 1
      ;;
  esac
  echo "syncing home-config/ into $HOME (HOME_CONFIG_MODE=$HOME_CONFIG_MODE)"
  for src in "$src_root"/**/*(.DN); do
    rel="${src#"$src_root/"}"
    dst="$HOME/$rel"
    if [[ ! -e "$dst" ]]; then
      mkdir -p "${dst:h}"
      cp -a "$src" "$dst"
      echo "  new     $rel"
    elif ! cmp -s "$src" "$dst"; then
      case "$HOME_CONFIG_MODE" in
        overwrite)
          cp -af "$src" "$dst"
          echo "  update  $rel"
          ;;
        keep)
          echo "  keep    $rel (differs from repo; HOME_CONFIG_MODE=overwrite to replace)"
          ;;
        prompt)
          read "ans?  overwrite $rel with repo version? [y/N] "
          if [[ "$ans" == [yY]* ]]; then
            cp -af "$src" "$dst"
            echo "  update  $rel"
          else
            echo "  keep    $rel"
          fi
          ;;
      esac
    fi
  done
}
sync_home_config

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
