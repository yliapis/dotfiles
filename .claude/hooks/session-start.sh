#!/usr/bin/env bash
# session-start.sh — Claude Code SessionStart hook.
#
# Claude Code's equivalent of the "install" hook in .cursor/environment.json:
# both providers call the same scripts/cloud-agent-bootstrap.sh so the two
# cloud environments never drift. All of the package logic lives there.
#
# Local sessions are skipped. A developer's machine is already provisioned by
# ./install.sh, and a hook has no business running apt-get on it.

set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Claude Code sets CLAUDE_PROJECT_DIR to the repo root; fall back to walking up
# from this script so the hook still works when invoked by hand.
repo_root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

exec bash "$repo_root/scripts/cloud-agent-bootstrap.sh"
