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

echo "[cloud-agent-bootstrap] done"
