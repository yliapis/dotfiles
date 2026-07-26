#!/usr/bin/env bash
# cloud-agent-bootstrap.sh — environment setup for cloud coding agents.
#
# Provider-agnostic: any agent provider that can run a setup command at VM
# boot can call this script. Cursor is wired up today via the "install" hook
# in .cursor/environment.json.
#
# Runs before the agent starts work, so it must stay idempotent and
# non-interactive: providers may snapshot the result and re-run the script
# on partially cached state.
#
# Intentionally slimmer than ./install.sh: no Homebrew, Brewfile, or ollama.
# Cloud VMs are headless, and those installs only slow down boots. This only
# provisions the interpreters and tools the repo's own scripts need, leaving
# the agent free to run them per task.

set -euo pipefail

# zsh runs every repo script, rsync backs the make sync targets, and the
# linter covers a repo whose deliverables are shell scripts.
packages=()
command -v zsh >/dev/null 2>&1 || packages+=(zsh)
command -v rsync >/dev/null 2>&1 || packages+=(rsync)
command -v shellcheck >/dev/null 2>&1 || packages+=(shellcheck)

if ((${#packages[@]})); then
  echo "[cloud-agent-bootstrap] installing: ${packages[*]}"
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt-get update
  sudo -E apt-get install -y "${packages[@]}"
else
  echo "[cloud-agent-bootstrap] required packages already present"
fi

echo "[cloud-agent-bootstrap] done"
