# Managed by dotfiles/install.sh — overwritten on each install.
# bash-specific extras. Sourced by .shell_extras.sh after common setup.

# Set up fzf key bindings and fuzzy completion
source <(fzf --bash)

# Set up starship prompt
eval "$(starship init bash)"
