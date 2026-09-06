#!/usr/bin/env bash
# install-herdr-plugins.sh — GitHub herdr plugins. Idempotent; safe to re-run
# from install.sh (picked up by the scripts/install-*.sh glob).
#
# herdr plugin install clones into ~/.config/herdr/plugins/github and runs each
# manifest [[build]] step. Both are slow, so a plugin is reinstalled only when
# it is missing or upstream has moved: herdr plugin list --json reports the
# commit each plugin was installed from (source.resolved_commit) and
# git ls-remote reports what upstream HEAD is on now. Equal SHAs mean skip.
# Reinstall everything with -f/--force or FORCE=1.
#
# The specs below are unpinned (no --ref), so HEAD is the right comparison; a
# spec pinned to a ref would have to compare against that ref instead.
#
# When the comparison cannot be made — jq missing, plugin list unreadable, or
# ls-remote offline — the plugin is reinstalled rather than skipped, so a failed
# check never leaves a stale plugin behind.
#
# Use --yes so refresh/bootstrap stays noninteractive. The CLI still prints a
# multi-line install preview; default is quiet (Installed/Config only). Pass
# -v/--verbose or VERBOSE=1 for the full preview. Failures always dump the full
# output.
#
# Companion / relocate notes (not installed here):
#   herdr-push  herdr plugin install dcolinmorgan/herdr-push
#               (herdr-remote phone/Telegram path; zero extra brew deps)
#   rust/cargo  only if a plugin's fetch-or-build falls back to source
#               (herdr-file-viewer). Relocate `brew "rust"` into the Brewfile
#               if you hit that path regularly.

set -euo pipefail

VERBOSE=${VERBOSE:-0}
FORCE=${FORCE:-0}

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--verbose) VERBOSE=1; shift ;;
    -f|--force) FORCE=1; shift ;;
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

# Snapshot the installed set once, then match every spec against it. Left empty
# when it cannot be read, which makes every plugin look uninstalled.
PLUGIN_LIST_JSON=""
if [ "$FORCE" = "1" ]; then
  echo "[install-herdr-plugins] force: reinstalling every plugin"
elif ! command -v jq >/dev/null 2>&1; then
  echo "[install-herdr-plugins] jq not found; reinstalling every plugin"
else
  PLUGIN_LIST_JSON=$(herdr plugin list --json 2>/dev/null) || PLUGIN_LIST_JSON=""
fi

echo "[install-herdr-plugins] installing herdr plugins"

# Commit owner/repo was installed from; empty when it is not in the snapshot.
# Matches on source.owner/source.repo because the plugin id is a manifest name
# that need not resemble the repo (persiyanov/herdr-reviewr -> persiyanov.reviewr).
installed_commit() {
  [ -n "$PLUGIN_LIST_JSON" ] || return 0
  printf '%s' "$PLUGIN_LIST_JSON" | jq -r --arg repo "$1" '
    first(
      .result.plugins[]?
      | .source
      | select(.kind == "github" and (.owner + "/" + .repo) == $repo)
      | .resolved_commit
    ) // empty
  '
}

# Commit upstream HEAD points at; empty when the remote cannot be reached.
remote_commit() {
  git ls-remote "https://github.com/$1" HEAD 2>/dev/null | awk 'NR == 1 { print $1 }'
}

# Skip when the installed commit already matches upstream HEAD.
needs_install() {
  local spec="$1" repo have want
  [ "$FORCE" = "1" ] && return 0
  repo=$(printf '%s' "$spec" | cut -d/ -f1,2)
  have=$(installed_commit "$repo") || have=""
  [ -n "$have" ] || return 0
  want=$(remote_commit "$repo") || want=""
  if [ -z "$want" ]; then
    echo "[install-herdr-plugins] $spec upstream unreachable; reinstalling"
    return 0
  fi
  if [ "$have" = "$want" ]; then
    echo "[install-herdr-plugins] $spec up to date at ${have:0:12}; skipping"
    return 1
  fi
  echo "[install-herdr-plugins] $spec ${have:0:12} -> ${want:0:12}"
  return 0
}

install_plugin() {
  local spec="$1"
  needs_install "$spec" || return 0
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
