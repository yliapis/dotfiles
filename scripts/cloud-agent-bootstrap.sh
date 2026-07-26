#!/usr/bin/env bash
# cloud-agent-bootstrap.sh — environment setup for cloud coding agents.
#
# Provider-agnostic: any agent provider that can run a setup command at VM
# boot can call this script. Wired up today for Cursor via the "install" hook
# in .cursor/environment.json, and for Claude Code via the SessionStart hook
# in .claude/hooks/session-start.sh.
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
  # Providers differ: some hand the agent an unprivileged user with sudo,
  # others run the setup step as root in a container with no sudo at all.
  if [ "$(id -u)" -eq 0 ]; then
    sudo_cmd=()
  else
    sudo_cmd=(sudo -E)
  fi
  "${sudo_cmd[@]}" apt-get update
  "${sudo_cmd[@]}" apt-get install -y "${packages[@]}"
else
  echo "[cloud-agent-bootstrap] required packages already present"
fi

echo "[cloud-agent-bootstrap] done"
