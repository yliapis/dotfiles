# Managed by dotfiles/install.sh — overwritten on each install.
# Single entrypoint sourced from both ~/.zshrc and ~/.bashrc. Runs
# shell-agnostic setup, then per-shell tool init for the running shell.

# User-local binaries (pip --user, npm NPM_CONFIG_PREFIX=~/.local, etc.)
case ":$PATH:" in *:"$HOME/.local/bin":*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac

# Set up Homebrew. Prefer brew already on PATH; otherwise look up the
# canonical install locations so a fresh shell still gets brew on PATH.
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
else
  printf 'warning: brew not found on PATH; run dotfiles/install.sh to install Homebrew\n' >&2
fi

# fzf and starship both take the shell name as an argument; derive it
# from the running shell and reuse it for both.
if [ -n "$ZSH_VERSION" ]; then
  _dotfiles_shell="zsh"
elif [ -n "$BASH_VERSION" ]; then
  _dotfiles_shell="bash"
fi

if [ -n "$_dotfiles_shell" ]; then
  # fzf key bindings and fuzzy completion
  source <(fzf --"$_dotfiles_shell")
  # starship prompt
  eval "$(starship init "$_dotfiles_shell")"
fi
unset _dotfiles_shell
