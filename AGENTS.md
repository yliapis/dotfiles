# AGENTS.md

## Cursor Cloud specific instructions

This repo is a **dotfiles + AI-coding tooling** project (no web app / backend / test
suite). The "product" is a set of POSIX/zsh shell scripts that install dotfiles and
mirror the `ai-coding/` commands + skills into the home locations used by Cursor and
Claude Code.

### Setup / update
- Environment setup is driven by the repo's own `install.sh` (see `README.md`:
  `source install.sh`). The scripts are **zsh** (`#!/usr/bin/env zsh`) and use the
  `print` builtin, so run them with `zsh`, not `bash`.
- `install.sh` reads `$SHELL` to pick the profile file; if `$SHELL` is empty it exits
  with `unsupported shell detected`. Always invoke with `SHELL` set, e.g.
  `SHELL=/bin/bash zsh install.sh`.
- On Linux the **Brewfile is skipped by default** (only runs when `GUI_INSTALL=1`).
  Do **not** set `GUI_INSTALL=1` on Linux — the Brewfile is macOS/cask-heavy and
  `brew bundle` will fail on nearly every `cask` line.
- Optional heavy steps: `INSTALL_OLLAMA=0` skips the ollama download. Homebrew is
  installed by `install.sh` (idempotent; skipped when `brew` is already present).
- `install.sh` runs `sudo apt-get install tilix` without `-y`; on non-interactive
  Linux this prompts and aborts. It is **non-fatal** (the script is not `set -e`) and
  can be ignored.
- The `fzf: command not found` / `starship: command not found` warnings printed on
  every shell startup come from `~/.shell_extras.sh` and are expected on Linux (those
  tools live in the skipped Brewfile). Harmless.

### Lint / test toolchain
- There is no CI config and no automated test suite. Linters used by the repo are
  `shellcheck`, `shfmt`, `yamllint` (declared in `Brewfile`). On Linux these plus
  `zsh` and `rsync` are **not** installed by `install.sh` (they are macOS-Brewfile
  items); this environment installs them via `apt`.
- `shellcheck` cannot parse the zsh scripts (`install.sh`, `refresh.sh`,
  `scripts/sync-coding-tools.sh`). Use `zsh -n <file>` to syntax-check those; run
  `shellcheck` only on the bash/sh scripts (`scripts/install-doc-tools.sh`,
  `snap_installs.sh`). `shfmt` uses tabs; existing bash/sh scripts are 2-space, so
  `shfmt -d` will report diffs (pre-existing, do not auto-reformat).

### Running the core functionality
- The main product action is the AI-coding tools sync. Use the `Makefile`:
  `make dry-run` (preview), `make status` (what's out of sync), `make sync`
  (copy commands+skills into `~/.cursor` and `~/.claude`), `make unlink` (reverse).
  The `Makefile` sets `SHELL := /bin/zsh`, so `zsh` must be installed.
- The sync is idempotent; a second `make sync` copies nothing. An audit line is
  appended to `~/.cache/dotfiles/sync.log` on every run.
- Syncing is **not** performed by `install.sh` — run `make sync` explicitly.
- Avoid `refresh.sh` / `make refresh` on Linux: it force-runs `brew bundle` on the
  full (cask-heavy) Brewfile with no `GUI_INSTALL` guard and also runs
  `brew upgrade --cask --greedy`, both of which error on Linux.
