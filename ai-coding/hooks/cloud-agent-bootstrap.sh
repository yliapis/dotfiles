#!/usr/bin/env bash
# cloud-agent-bootstrap.sh — environment setup for cloud coding agents.
#
# Provider-agnostic: any agent provider that can run a setup command at VM
# boot can call this script. Two are wired up today, both through this
# directory:
#
#   Cursor       .cursor/environment.json "install" runs this script directly.
#   Claude Code  .claude/settings.json registers a SessionStart hook that runs
#                session-start.sh, the adapter beside this file, which execs
#                this script.
#
# Source of truth for both. `make mirrors` copies this directory to
# .claude/hooks/, so edit here and regenerate; never edit the mirror.
#
# Runs before the agent starts work, so it must stay idempotent and
# non-interactive: providers may snapshot the result and re-run the script
# on partially cached state.
#
# Intentionally slimmer than ./install.sh: no Homebrew, Brewfile, or ollama.
# Cloud VMs are headless, and those installs only slow down boots. This only
# provisions the tools the repo's own scripts and workflows need, leaving the
# agent free to run them per task.

set -euo pipefail

# User-local binaries (npm NPM_CONFIG_PREFIX=~/.local, uv, pip --user, etc.).
# Same prepend as home-config/.shell_extras.sh; cloud skips that file, so do it
# here for this process and any child installs that land under ~/.local/bin.
mkdir -p "${HOME}/.local/bin"
if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

# zsh runs every repo script, rsync backs the make sync targets, and the
# linter covers a repo whose deliverables are shell scripts. curl fetches
# the standalone uv installer (uv is not an apt package). ripgrep provides rg.
packages=()
command -v zsh >/dev/null 2>&1 || packages+=(zsh)
command -v rsync >/dev/null 2>&1 || packages+=(rsync)
command -v shellcheck >/dev/null 2>&1 || packages+=(shellcheck)
command -v curl >/dev/null 2>&1 || packages+=(curl)
command -v rg >/dev/null 2>&1 || packages+=(ripgrep)

if ((${#packages[@]})); then
  echo "[cloud-agent-bootstrap] installing: ${packages[*]}"
  export DEBIAN_FRONTEND=noninteractive
  # Acquire::Check-Date=false: a cloud VM can boot with its clock behind real
  # time, and apt then rejects every release file as "not valid yet" and exits
  # 100, which under `set -e` ends the run before anything installs. This
  # relaxes only the Date/Valid-Until window; GPG signature verification is a
  # separate check and stays on.
  sudo -E apt-get -o Acquire::Check-Date=false update
  sudo -E apt-get install -y "${packages[@]}"
else
  echo "[cloud-agent-bootstrap] required packages already present"
fi

# Work items live in backlog/ and the repo's docs point agents at `backlog task
# list`, so the CLI belongs on a cloud VM too. It is not an apt package, and
# cloud skips the Brewfile, so fall through whatever package manager the
# provider image happens to ship. Non-fatal by design: an image with none of
# them, or with a global prefix this user cannot write, should still boot.
install_backlog() {
  if command -v npm >/dev/null 2>&1; then
    echo "[cloud-agent-bootstrap] installing: backlog.md (npm)"
    local npm_prefix npm_env=()
    npm_prefix="$(npm config get prefix 2>/dev/null || true)"
    if [ -n "$npm_prefix" ] && [ ! -w "$npm_prefix" ]; then
      mkdir -p "${HOME}/.local/bin"
      npm_env=(env NPM_CONFIG_PREFIX="${HOME}/.local")
    fi
    "${npm_env[@]}" npm install -g --no-fund --no-audit backlog.md
  elif command -v brew >/dev/null 2>&1; then
    echo "[cloud-agent-bootstrap] installing: backlog-md (brew)"
    brew install backlog-md
  elif command -v bun >/dev/null 2>&1; then
    echo "[cloud-agent-bootstrap] installing: backlog.md (bun)"
    bun add -g backlog.md
  else
    echo "[cloud-agent-bootstrap] no npm, brew, or bun on PATH; skipping backlog.md"
  fi
}

if command -v backlog >/dev/null 2>&1; then
  echo "[cloud-agent-bootstrap] backlog already present"
else
  install_backlog ||
    echo "[cloud-agent-bootstrap] warning: backlog.md install failed; continuing"
fi

if command -v uv >/dev/null 2>&1; then
  echo "[cloud-agent-bootstrap] uv already present"
else
  echo "[cloud-agent-bootstrap] installing: uv"
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh ||
    echo "[cloud-agent-bootstrap] warning: uv install failed; continuing"
fi

echo "[cloud-agent-bootstrap] done"
