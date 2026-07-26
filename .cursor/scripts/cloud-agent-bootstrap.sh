#!/usr/bin/env bash
# cloud-agent-bootstrap.sh — environment setup for Cursor Cloud Agents.
#
# Referenced by .cursor/environment.json ("install"), so Cursor runs it on
# every cloud VM boot before the agent starts work. It must stay idempotent
# and non-interactive: the result is snapshotted for faster future boots and
# the script may re-run on partially cached state.
#
# Intentionally slimmer than ./install.sh: no Homebrew, Brewfile, or ollama.
# The cloud VM is headless and those installs only slow down boots. This
# installs just what the repo's own tooling needs, then mirrors the ai-coding
# commands + skills into the home locations via scripts/sync-coding-tools.sh.
#
# Set SYNC_CLOUD_AGENT_BOOTSTRAP=1 (e.g. as a Cloud Agents secret) to also
# mirror this script into ~/.cursor/scripts/ during the sync step.

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

# Mirror ai-coding commands + skills into ~/.cursor and ~/.claude. Also acts
# as a boot-time smoke test of the repo's core sync flow.
echo "[cloud-agent-bootstrap] running scripts/sync-coding-tools.sh"
"$REPO_ROOT/scripts/sync-coding-tools.sh"

echo "[cloud-agent-bootstrap] done"
