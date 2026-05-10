# Managed by dotfiles/install.sh — overwritten on each install.
# Single entrypoint sourced from both ~/.zshrc and ~/.bashrc. Runs
# shell-agnostic setup, then dispatches to the per-shell extras file.

# Set up Homebrew. Expected to be on PATH already; warn if missing.
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
else
  printf 'warning: brew not found on PATH; run dotfiles/install.sh to install Homebrew\n' >&2
fi

# Dispatch to per-shell extras based on the running shell.
if [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.shell_extras.zsh" ]; then
  . "$HOME/.shell_extras.zsh"
elif [ -n "$BASH_VERSION" ] && [ -f "$HOME/.shell_extras.bash" ]; then
  . "$HOME/.shell_extras.bash"
fi
