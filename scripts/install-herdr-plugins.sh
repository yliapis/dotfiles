#!/usr/bin/env bash
# install-herdr-plugins.sh — GitHub herdr plugins. Idempotent; safe to re-run
# from install.sh (picked up by the scripts/install-*.sh glob).
#
# herdr plugin install clones into ~/.config/herdr/plugins/github and runs each
# manifest [[build]] step. Use --yes so refresh/bootstrap stays noninteractive.
# The CLI still prints a multi-line install preview; default is quiet
# (Installed/Config only). Pass -v/--verbose or VERBOSE=1 for the full preview.
# Failures always dump the full output.
#
# Companion / relocate notes (not installed here):
#   herdr-push  herdr plugin install dcolinmorgan/herdr-push
#               (herdr-remote phone/Telegram path; zero extra brew deps)
#   rust/cargo  only if a plugin's fetch-or-build falls back to source
#               (herdr-file-viewer). Relocate `brew "rust"` into the Brewfile
#               if you hit that path regularly.

set -euo pipefail

VERBOSE=${VERBOSE:-0}

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--verbose) VERBOSE=1; shift ;;
    *)
      echo "[install-herdr-plugins] unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v herdr >/dev/null 2>&1; then
  echo "[install-herdr-plugins] herdr not found on PATH; skipping (install Brewfile first)"
  exit 0
fi

echo "[install-herdr-plugins] installing herdr plugins"

install_plugin() {
  local spec="$1"
  echo "[install-herdr-plugins] herdr plugin install $spec --yes"
  if [ "$VERBOSE" = "1" ]; then
    herdr plugin install "$spec" --yes
    return
  fi
  local output status=0
  output=$(herdr plugin install "$spec" --yes 2>&1) || status=$?
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
    return "$status"
  fi
  printf '%s\n' "$output" | awk '
    /^Plugin install preview:/ { skip=1; next }
    skip && /^[[:space:]]/ { next }
    { skip=0 }
    NF { print }
  '
}

failed=0
install_plugin smarzban/herdr-file-viewer || failed=1
install_plugin persiyanov/herdr-reviewr || failed=1
install_plugin dcolinmorgan/herdr-remote || failed=1
install_plugin nicosuave/memex || failed=1
exit "$failed"
