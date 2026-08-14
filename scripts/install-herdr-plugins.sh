#!/usr/bin/env bash
# install-herdr-plugins.sh — GitHub herdr plugins. Idempotent; safe to re-run
# from install.sh (picked up by the scripts/install-*.sh glob).
#
# herdr plugin install clones into ~/.config/herdr/plugins/github and runs each
# manifest [[build]] step. Use --yes so refresh/bootstrap stays noninteractive.
#
# Companion / relocate notes (not installed here):
#   herdr-push  herdr plugin install dcolinmorgan/herdr-push
#               (herdr-remote phone/Telegram path; zero extra brew deps)
#   rust/cargo  only if a plugin's fetch-or-build falls back to source
#               (herdr-file-viewer). Relocate `brew "rust"` into the Brewfile
#               if you hit that path regularly.

set -euo pipefail

if ! command -v herdr >/dev/null 2>&1; then
  echo "[install-herdr-plugins] herdr not found on PATH; skipping (install Brewfile first)"
  exit 0
fi

echo "[install-herdr-plugins] installing herdr plugins"

install_plugin() {
  local spec="$1"
  echo "[install-herdr-plugins] herdr plugin install --yes $spec"
  herdr plugin install --yes "$spec"
}

install_plugin smarzban/herdr-file-viewer
install_plugin persiyanov/herdr-reviewr
install_plugin dcolinmorgan/herdr-remote
install_plugin nicosuave/memex
