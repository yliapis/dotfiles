#!/usr/bin/env bash
# sync-project-mirrors.sh — regenerate the nine repo-root project mirrors that
# Cursor, Claude Code, and OpenCode read when this repository is the workspace.
#
# Sources (the only place a maintainer edits):
#   ai-coding/plugins/<plugin>/commands/*.md           slash commands
#   ai-coding/plugins/<plugin>/skills/<name>/          skills (whole directory)
#   ai-coding/plugins/<plugin>/agents/*.md             subagent definitions
#
# Mirrors (generated, never edited by hand):
#   {.cursor,.claude,.opencode}/{commands,skills,agents}
#
# Every plugin's items are flattened into one directory per tool per kind, so a
# name may be claimed by only one plugin; a collision aborts rather than letting
# one plugin silently shadow another.
#
# Mirror entries are real files and directories, not symlinks. Skill discovery
# in at least one shipped client resolves a link and drops the entry when the
# real path leaves the scanned directory, so a symlinked mirror is invisible to
# it. Regenerate after editing ai-coding/plugins/ instead of editing a mirror.
#
# Deliberately bash + coreutils only: no zsh, no rsync. A cloud VM that failed
# to install either must still be able to run this.
#
# Run `sync-project-mirrors.sh --help` for the full CLI.

set -euo pipefail

PROG="$(basename -- "$0")"
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
REPO_ROOT="$(dirname -- "$SCRIPT_DIR")"

SRC_PLUGINS="$REPO_ROOT/ai-coding/plugins"
TOOLS="cursor claude opencode"
KINDS="commands skills agents"

MODE="write"
DRY_RUN=0
VERBOSE=0

usage() {
  cat <<EOF
Usage: $PROG [options]

Regenerate the nine repo-root project mirrors
({.cursor,.claude,.opencode}/{commands,skills,agents}) from ai-coding/plugins/.
Mirror entries are byte-identical copies of their source, never symlinks.
Idempotent; a mirror already in sync is left untouched.

Options:
      --check       Report drift and exit non-zero if any mirror differs from
                    its source. Writes nothing.
  -n, --dry-run     Show the writes that would happen. Writes nothing.
  -v, --verbose     Also print entries that are already in sync.
  -h, --help        Show this help and exit.

Behavior:
  create/update  a mirror entry missing, symlinked, or differing from its
                 source is rewritten as a plain copy.
  prune          a mirror entry whose source no longer exists is removed,
                 including stale files nested inside a mirrored skill.
  collide        two plugins claiming one flattened name abort the run.

Exit status:
  0  success (write mode applied, or --check found no drift)
  1  --check found drift
  2  invalid arguments, missing sources, or a flattened-name collision
EOF
}

die() { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 2; }
log() { if [ "$VERBOSE" -eq 1 ]; then printf '%s\n' "$*"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --check)    MODE="check"; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    --)         shift; break ;;
    *)          usage >&2; die "unknown option: $1" ;;
  esac
done

[ -d "$SRC_PLUGINS" ] || die "plugin source missing: $SRC_PLUGINS"

TMP_RUN="$(mktemp -d "${TMPDIR:-/tmp}/sync-project-mirrors.XXXXXX")"
trap 'rm -rf -- "$TMP_RUN"' EXIT

# --- source enumeration ---------------------------------------------------

# Prints "<flattened-name><TAB><absolute source path>" per item, sorted by name.
kind_sources() {
  local kind="$1" path
  {
    case "$kind" in
      commands|agents)
        for path in "$SRC_PLUGINS"/*/"$kind"/*.md; do
          [ -f "$path" ] || continue
          printf '%s\t%s\n' "$(basename -- "$path")" "$path"
        done
        ;;
      skills)
        for path in "$SRC_PLUGINS"/*/skills/*/; do
          path="${path%/}"
          [ -d "$path" ] || continue
          printf '%s\t%s\n' "$(basename -- "$path")" "$path"
        done
        ;;
      *) die "unknown kind: $kind" ;;
    esac
  } | LC_ALL=C sort
}

relpath() { printf '%s\n' "${1#"$REPO_ROOT"/}"; }

check_collisions() {
  local kind duplicates name found=0
  for kind in $KINDS; do
    duplicates="$(kind_sources "$kind" | cut -f1 | uniq -d)"
    [ -n "$duplicates" ] || continue
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      found=1
      printf '%s: error: two plugins claim the flattened %s name %s:\n' \
        "$PROG" "$kind" "$name" >&2
      kind_sources "$kind" | while IFS=$'\t' read -r item path; do
        [ "$item" = "$name" ] || continue
        printf '  %s\n' "$(relpath "$path")" >&2
      done
    done <<EOF
$duplicates
EOF
  done
  [ "$found" -eq 0 ] || return 1
}

# --- comparison -----------------------------------------------------------

# Relative paths of every regular file under a directory, sorted.
dir_files() { ( CDPATH='' cd -- "$1" && find . -type f | LC_ALL=C sort ); }

# Echoes ok | missing | symlink | type | differs.
compare_entry() {
  local src="$1" dest="$2" rel
  if [ -L "$dest" ]; then printf 'symlink\n'; return 0; fi
  if [ ! -e "$dest" ]; then printf 'missing\n'; return 0; fi
  if [ -d "$src" ]; then
    [ -d "$dest" ] || { printf 'type\n'; return 0; }
    if [ -n "$(find "$dest" -type l -print 2>/dev/null | head -n 1)" ]; then
      printf 'symlink\n'; return 0
    fi
    [ "$(dir_files "$src")" = "$(dir_files "$dest")" ] || { printf 'differs\n'; return 0; }
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      cmp -s -- "$src/$rel" "$dest/$rel" || { printf 'differs\n'; return 0; }
    done <<EOF
$(dir_files "$src")
EOF
    printf 'ok\n'
  else
    [ -f "$dest" ] || { printf 'type\n'; return 0; }
    if cmp -s -- "$src" "$dest"; then printf 'ok\n'; else printf 'differs\n'; fi
  fi
}

write_entry() {
  local src="$1" dest="$2" rel
  rm -rf -- "$dest"
  if [ -d "$src" ]; then
    mkdir -p -- "$dest"
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      mkdir -p -- "$dest/$(dirname -- "$rel")"
      cp -- "$src/$rel" "$dest/$rel"
    done <<EOF
$(dir_files "$src")
EOF
  else
    mkdir -p -- "$(dirname -- "$dest")"
    cp -- "$src" "$dest"
  fi
}

# --- main -----------------------------------------------------------------

check_collisions || exit 2

created=0
updated=0
pruned=0
in_sync=0
drifted=0

prefix=""
[ "$DRY_RUN" -eq 1 ] && prefix="[dry-run] "
[ "$MODE" = "check" ] && prefix="[check] "

apply() {
  local verb="$1" src="$2" dest="$3"
  printf '%s%-7s %s\n' "$prefix" "$verb" "$(relpath "$dest")"
  if [ "$MODE" = "check" ]; then
    drifted=$((drifted + 1))
    return 0
  fi
  [ "$DRY_RUN" -eq 1 ] && return 0
  if [ "$verb" = "prune" ]; then rm -rf -- "$dest"; else write_entry "$src" "$dest"; fi
}

for tool in $TOOLS; do
  for kind in $KINDS; do
    dest_dir="$REPO_ROOT/.$tool/$kind"
    names="$TMP_RUN/$tool.$kind.names"
    kind_sources "$kind" | cut -f1 >"$names"

    if [ ! -d "$dest_dir" ] && [ "$MODE" = "write" ] && [ "$DRY_RUN" -eq 0 ]; then
      mkdir -p -- "$dest_dir"
    fi

    while IFS=$'\t' read -r name src; do
      [ -n "$name" ] || continue
      dest="$dest_dir/$name"
      case "$(compare_entry "$src" "$dest")" in
        ok)      in_sync=$((in_sync + 1)); log "        ok      $(relpath "$dest")" ;;
        missing) created=$((created + 1)); apply create "$src" "$dest" ;;
        *)       updated=$((updated + 1)); apply update "$src" "$dest" ;;
      esac
    done < <(kind_sources "$kind")

    [ -d "$dest_dir" ] || continue
    while IFS= read -r existing; do
      [ -n "$existing" ] || continue
      name="$(basename -- "$existing")"
      if grep -Fxq -- "$name" "$names"; then continue; fi
      pruned=$((pruned + 1))
      apply prune "" "$existing"
    done < <(find "$dest_dir" -mindepth 1 -maxdepth 1 | LC_ALL=C sort)
  done
done

printf '%s: created=%d updated=%d pruned=%d in_sync=%d\n' \
  "$PROG" "$created" "$updated" "$pruned" "$in_sync"

if [ "$MODE" = "check" ]; then
  if [ "$drifted" -gt 0 ]; then
    printf "%s: %d mirror entries drifted from ai-coding/plugins/; run 'make mirrors'\n" \
      "$PROG" "$drifted" >&2
    exit 1
  fi
  printf '%s: mirrors match ai-coding/plugins/\n' "$PROG"
fi

exit 0
