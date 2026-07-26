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
# Cloud VMs are headless, and those installs only slow down boots. Installs
# just what the repo's own tooling needs, then mirrors the ai-coding
# commands + skills into the home locations via scripts/sync-coding-tools.sh.
# SYNC_CLOUD_AGENT_BOOTSTRAP=1 (env var or provider secret) additionally
# mirrors this script itself; see scripts/sync-coding-tools.sh --help.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# zsh: every repo script is zsh; rsync: sync copy mode; shellcheck: lint for
# a repo whose deliverables are shell scripts.
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

# Doubles as a boot-time smoke test of the repo's core sync flow.
echo "[cloud-agent-bootstrap] running scripts/sync-coding-tools.sh"
"$REPO_ROOT/scripts/sync-coding-tools.sh"

echo "[cloud-agent-bootstrap] done"
