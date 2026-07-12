# AGENTS.md

## Cursor Cloud specific instructions

Dotfiles + AI-coding tooling repo. Shell scripts install dotfiles and mirror
`ai-coding/` commands + skills into the Cursor and Claude home locations. No web app,
backend, CI, or test suite.

### Setup / update
- Setup runs the repo's own `install.sh`. Scripts are zsh, so run them with `zsh`.
- `install.sh` needs `$SHELL` set, e.g. `SHELL=/bin/bash zsh install.sh`.
- Do not set `GUI_INSTALL=1` on Linux; the Brewfile is macOS-only and will fail.
- `INSTALL_OLLAMA=0` skips the ollama download. Homebrew install is idempotent.
- The `tilix` apt prompt and the `fzf`/`starship` not-found warnings are non-fatal.

### Lint
- Use `zsh -n` to check the zsh scripts; `shellcheck` only parses the bash/sh scripts.
- `shellcheck`, `shfmt`, `yamllint`, `zsh`, `rsync` come from the macOS Brewfile and
  are installed via `apt` on Linux, not by `install.sh`.

### Run
- Core action is the sync: `make sync` copies commands + skills into `~/.cursor` and
  `~/.claude`. Use `make dry-run` to preview and `make unlink` to reverse.
- Sync is idempotent and not run by `install.sh`; invoke `make sync` explicitly.
- Avoid `refresh.sh` / `make refresh` on Linux; it force-runs the Brewfile and errors.
