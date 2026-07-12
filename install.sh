#!/usr/bin/env zsh

echo "begining dotfiles install"

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

# INPUT_VARIABLES
GUI_INSTALL=${1:-$GUI_INSTALL}
# OPTIONAL_VARIABLES
INSTALL_OLLAMA=${INSTALL_OLLAMA:-1}


# platform guard
case "$OSTYPE" in
  darwin*)
    echo "macos detected"
    ;;
  linux-gnu*)
    echo "linux-gnu detected (likely ubuntu)"
    ;;
  "")
    echo "Error: OSTYPE undefined, try sourcing this script or setting the variable properly"
    exit 1
    ;;
  *)
    echo "unsupported platform detected: $OSTYPE"
    exit 1
    ;;
esac


# shell customization
if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/opt/homebrew/bin/zsh" ]; then
  echo "zsh detected"
  SHELL_DETECTED="zsh"
elif [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/opt/homebrew/bin/bash" ]; then
  echo "bash detected"
  SHELL_DETECTED="bash"
else
  echo "unsupported shell detected: $SHELL"
  exit 1
fi

# shell specific setup
if [ "$SHELL_DETECTED" = "zsh" ]; then
  DEFAULT_PROFILE_FILE="$HOME/.zshrc"
elif [ "$SHELL_DETECTED" = "bash" ]; then
  DEFAULT_PROFILE_FILE="$HOME/.bashrc"
fi

# baseline system packages (curl, zsh, rsync, ...) declared in packages/*.txt,
# installed with the detected package manager (apt/dnf/pacman/apk/zypper);
# no-op on macOS, which relies on system tools + the Brewfile. The GUI list
# (tilix) only applies when GUI_INSTALL=1.
GUI_INSTALL="$GUI_INSTALL" sh "$DOTFILES_ROOT/scripts/bootstrap-packages.sh" || {
  echo "Error: system package bootstrap failed; exiting"
  exit 1
}

# curl drives the Homebrew and ollama installs below; ships with macOS and is
# in packages/base.txt for linux, so this only trips on unusual hosts.
if ! command -v curl > /dev/null 2>&1; then
  echo "Error: curl expected to be installed; exiting"
  exit 1
fi

if [ -f "$DEFAULT_PROFILE_FILE" ]; then
  echo "profile file exists"
else
  echo "profile file does not exist, creating"
  touch "$DEFAULT_PROFILE_FILE"
fi

# install homebrew
if ! command -v brew &> /dev/null; then
  echo "installing homebrew"
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  case "$OSTYPE" in
    darwin*)    BREW_ROOT="/opt/homebrew" ;;
    linux-gnu*) BREW_ROOT="/home/linuxbrew/.linuxbrew" ;;
  esac
  # activate for this script session; persistent PATH setup lives in ~/.shell_extras.sh
  eval "$("$BREW_ROOT/bin/brew" shellenv)"
fi

# turn off homebrew analytics
# https://docs.brew.sh/Analytics
brew analytics off

# install defaults from Brewfile (skipped on non-macOS unless GUI_INSTALL=1)
if [[ "$OSTYPE" == darwin* ]] || [ "$GUI_INSTALL" = "1" ]; then
  echo "Running full brew install from Brewfile"
  brew bundle --file="$DOTFILES_ROOT/Brewfile"
else
  echo "non macos detected and GUI_INSTALL not set to 1; skipping Brewfile"
fi

# Mirror managed dotfiles from this repo into $HOME (overwrites).
copy_home_config() {
  local src_dir="$DOTFILES_ROOT/home-config"
  if [ ! -d "$src_dir" ]; then
    echo "Error: missing home-config dir: $src_dir"
    exit 1
  fi
  echo "copying $src_dir/ into $HOME (overwriting)"
  cp -af "$src_dir/." "$HOME/"
}

copy_home_config

# Managed shell extras: single source line in ~/.zshrc / ~/.bashrc that points at
# the shared entrypoint. The entrypoint dispatches to the per-shell extras file.
ensure_dotfiles_shell_extras_source() {
  local snippet="$HOME/.shell_extras.sh"
  if [ ! -f "$snippet" ]; then
    echo "Error: missing shell extras: $snippet"
    exit 1
  fi
  if grep -qF '# dotfiles: shell extras (managed by dotfiles/install.sh)' "$DEFAULT_PROFILE_FILE" 2>/dev/null; then
    return 0
  fi
  print '' >> "$DEFAULT_PROFILE_FILE"
  print '# dotfiles: shell extras (managed by dotfiles/install.sh)' >> "$DEFAULT_PROFILE_FILE"
  printf '[ -f %q ] && . %q\n' "$snippet" "$snippet" >> "$DEFAULT_PROFILE_FILE"
}

ensure_dotfiles_shell_extras_source

# Modular installers (any scripts/install-*.sh is auto-run)
if [ -d "$DOTFILES_ROOT/scripts" ]; then
  for script in "$DOTFILES_ROOT/scripts"/install-*.sh; do
    [ -f "$script" ] || continue
    echo "running $(basename "$script")"
    bash "$script"
  done
fi

# ollama setup
if [ "$INSTALL_OLLAMA" = "1" ]; then
  # check if ollama is already installed
  if ! command -v ollama &> /dev/null; then
    echo "ollama not installed, installing"
    curl -fsSL https://ollama.com/install.sh | $SHELL
  fi
fi

echo "dotfiles install complete"
