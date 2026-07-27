#!/usr/bin/env bash
# session-start.sh — Claude Code SessionStart hook.
#
# Claude Code's counterpart to Cursor's .cursor/environment.json "install"
# command. Both entry points end at cloud-agent-bootstrap.sh beside this file,
# so the two cloud agent environments provision identically; shared setup
# belongs in that script, and only Claude-specific wiring belongs here.
#
# Registered in .claude/settings.json. Runs synchronously, so the session does
# not begin until the bootstrap finishes and no task can race a half-installed
# VM.
#
# Source of truth is ai-coding/hooks/; `make mirrors` copies this directory to
# .claude/hooks/, which is the path settings.json actually invokes. The
# bootstrap is resolved as a sibling rather than by repo-relative path so the
# file behaves identically from either location.

set -euo pipefail

# Local Claude Code sessions run on an already-provisioned machine that
# ./install.sh owns, and apt-get on a developer's own laptop would be an
# unwelcome surprise. Only the remote VM needs bootstrapping.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

hooks_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"

exec bash "$hooks_dir/cloud-agent-bootstrap.sh"
