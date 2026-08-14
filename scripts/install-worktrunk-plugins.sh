#!/usr/bin/env bash
# install-worktrunk-plugins.sh — Worktrunk agent plugins. Idempotent; safe to
# re-run from install.sh (picked up by the scripts/install-*.sh glob).
#
# wt config plugins <target> install --yes wires Claude Code, Codex, and
# OpenCode. --yes keeps refresh/bootstrap noninteractive.
#
# Companion / relocate notes (not installed here):
#   gemini      gemini extensions install https://github.com/max-sixty/worktrunk
#   statusline  wt config plugins claude install-statusline
#               (writes ~/.claude/settings.json; personal preference)
#   fish/nu     wt config shell install
#               (bash/zsh init lives in home-config/.shell_extras.sh)

set -euo pipefail

if ! command -v wt >/dev/null 2>&1; then
  echo "[install-worktrunk-plugins] wt not found on PATH; skipping (install Brewfile first)"
  exit 0
fi

echo "[install-worktrunk-plugins] installing worktrunk agent plugins"

install_plugin() {
  local target="$1"
  local cli="$2"
  if ! command -v "$cli" >/dev/null 2>&1; then
    echo "[install-worktrunk-plugins] $cli not found on PATH; skipping $target plugin"
    return 0
  fi
  echo "[install-worktrunk-plugins] wt config plugins $target install --yes"
  wt config plugins "$target" install --yes
}

install_plugin claude claude
install_plugin codex codex
install_plugin opencode opencode
