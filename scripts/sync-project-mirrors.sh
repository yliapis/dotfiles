#!/bin/sh
# sync-project-mirrors.sh — regenerate the repo-root mirrors that Cursor,
# Claude Code, and OpenCode scan when this repo is the open project.
#
# Sources (canonical; edit these):
#   ai-coding/plugins/<plugin>/commands/<name>.md
#   ai-coding/plugins/<plugin>/skills/<name>/
#
# Mirrors (generated; do not edit by hand):
#   .cursor/{commands,skills}
#   .claude/{commands,skills}
#   .opencode/{commands,skills}
#
# Every plugin's items are flattened into one directory per tool per type, so
# a name may only be claimed by one plugin; collisions abort the run.
#
# Copy mode is the default because skill discovery is not one code path. A plain
# directory scan stats a symlinked skill directory and accepts it; other
# implementations require a resolved link to stay inside the directory being
# scanned, and every mirror link points out of its mirror directory into
# ai-coding/plugins. Real copies are accepted either way. Symlink mode remains
# available for a working copy where live edits matter more than discovery.
#
# Deliberately POSIX sh using only cp/diff/ln: the cloud bootstrap that
# installs zsh and rsync can fail, and mirrors must still be regenerable.

set -eu

SCRIPT_NAME=${0##*/}
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(dirname -- "$SCRIPT_DIR")
SRC_PLUGINS=$REPO_ROOT/ai-coding/plugins

MODE=copy
TARGETS=cursor,claude,opencode
DRY_RUN=0
VERBOSE=0
CHECK=0
drift=0

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Regenerate the repo-root project mirrors of ai-coding/plugins commands and
skills for Cursor, Claude Code, and OpenCode. Idempotent; prunes mirror
entries whose source is gone.

Options:
      --mode <m>        copy | symlink (default: copy). Copy mode is what
                        makes skills auto-attach; symlink mode makes repo
                        edits live at the cost of discovery.
      --targets <list>  Comma-separated subset of: cursor,claude,opencode
                        (default: all).
      --check           Report mirrors that are out of date and exit 1
                        without writing. Implies --dry-run.
  -n, --dry-run         Show actions without writing.
  -v, --verbose         Print already-current entries too.
  -h, --help            Show this help and exit.

Exit status:
  0  mirrors are current (or were brought current)
  1  --check found drift
  2  invalid arguments, missing source, or a flattening collision
EOF
}

die() {
  printf '%s: error: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 2
}

log() { [ "$VERBOSE" -eq 1 ] && printf '%s\n' "$*"; return 0; }

action() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
  else
    printf '%s\n' "$*"
  fi
}

while [ $# -gt 0 ]; do
  case $1 in
    --mode) [ $# -ge 2 ] || die "--mode requires a value"; MODE=$2; shift 2 ;;
    --mode=*) MODE=${1#--mode=}; shift ;;
    --targets) [ $# -ge 2 ] || die "--targets requires a value"; TARGETS=$2; shift 2 ;;
    --targets=*) TARGETS=${1#--targets=}; shift ;;
    --check) CHECK=1; DRY_RUN=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) usage >&2; die "unexpected argument: $1" ;;
  esac
done

case $MODE in
  copy|symlink) ;;
  *) die "unknown --mode '$MODE' (expected: copy, symlink)" ;;
esac

tool_dir() {
  case $1 in
    cursor) printf '%s\n' .cursor ;;
    claude) printf '%s\n' .claude ;;
    opencode) printf '%s\n' .opencode ;;
    *) die "unknown target '$1' (expected: cursor, claude, opencode)" ;;
  esac
}

tools=$(printf '%s\n' "$TARGETS" | tr ',' ' ')
selected=''
for tool in $tools; do
  tool_dir "$tool" >/dev/null
  selected="$selected $tool"
done
[ -n "${selected# }" ] || die "no targets selected"

[ -d "$SRC_PLUGINS" ] || die "plugin source missing: $SRC_PLUGINS"

# --- source enumeration ---------------------------------------------------
#
# Each source line is "<mirror name>\t<absolute source path>". Names are
# collected separately so pruning can test mirror entries for membership.

commands_src=''
skills_src=''

for f in "$SRC_PLUGINS"/*/commands/*.md; do
  [ -f "$f" ] || continue
  commands_src="$commands_src${f##*/}	$f
"
done

for d in "$SRC_PLUGINS"/*/skills/*/; do
  d=${d%/}
  [ -d "$d" ] || continue
  [ -f "$d/SKILL.md" ] || die "skill directory has no SKILL.md: $d"
  skills_src="$skills_src${d##*/}	$d
"
done

[ -n "$commands_src" ] || die "no commands found under $SRC_PLUGINS/*/commands/"
[ -n "$skills_src" ] || die "no skills found under $SRC_PLUGINS/*/skills/"

names_of() { printf '%s' "$1" | cut -f1; }

assert_unique() {
  dupes=$(names_of "$1" | sort | uniq -d)
  [ -z "$dupes" ] || die "two plugins claim the same $2 name: $(printf '%s' "$dupes" | tr '\n' ' ')"
}

assert_unique "$commands_src" command
assert_unique "$skills_src" skill

# --- mirror maintenance ---------------------------------------------------

# Mirror entries point two levels up, matching their .cursor/<type>/ depth.
link_target() { printf '../../%s\n' "${1#"$REPO_ROOT"/}"; }

is_current() {
  src=$1 dst=$2
  if [ "$MODE" = symlink ]; then
    [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$(link_target "$src")" ]
  else
    [ ! -L "$dst" ] && [ -e "$dst" ] && diff -r -q -- "$src" "$dst" >/dev/null 2>&1
  fi
}

write_entry() {
  src=$1 dst=$2
  [ "$DRY_RUN" -eq 1 ] && return 0
  rm -rf -- "$dst"
  if [ "$MODE" = symlink ]; then
    ln -sfn -- "$(link_target "$src")" "$dst"
  else
    cp -RL -- "$src" "$dst"
  fi
}

sync_dir() {
  mirror=$1 sources=$2 label=$3
  mkdir -p "$mirror"

  printf '%s' "$sources" | while IFS='	' read -r name src; do
    [ -n "$name" ] || continue
    dst=$mirror/$name
    if is_current "$src" "$dst"; then
      log "ok      $dst"
    else
      action "$MODE  $dst"
      write_entry "$src" "$dst"
      printf 'drift\n' >>"$drift_flag"
    fi
  done

  expected=$(names_of "$sources")
  for entry in "$mirror"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name=${entry##*/}
    if printf '%s\n' "$expected" | grep -qxF -- "$name"; then
      continue
    fi
    action "prune   $entry (no $label source)"
    [ "$DRY_RUN" -eq 1 ] || rm -rf -- "$entry"
    printf 'drift\n' >>"$drift_flag"
  done
}

# A subshell runs each mirror loop (pipe into `while`), so drift is recorded in
# a temp file rather than a variable the parent shell would never see.
drift_flag=$(mktemp)
trap 'rm -f -- "$drift_flag"' EXIT INT TERM

cd -- "$REPO_ROOT"

printf '%s: repo_root=%s\n' "$SCRIPT_NAME" "$REPO_ROOT"
printf '%s: targets=%s  mode=%s  dry_run=%s  check=%s\n' \
  "$SCRIPT_NAME" "${selected# }" "$MODE" "$DRY_RUN" "$CHECK"
printf '\n'

for tool in $selected; do
  dir=$(tool_dir "$tool")
  printf '==> %s commands -> %s/commands\n' "$tool" "$dir"
  sync_dir "$dir/commands" "$commands_src" command
  printf '==> %s skills   -> %s/skills\n' "$tool" "$dir"
  sync_dir "$dir/skills" "$skills_src" skill
  printf '\n'
done

if [ -s "$drift_flag" ]; then
  drift=1
fi

if [ "$CHECK" -eq 1 ]; then
  if [ "$drift" -eq 1 ]; then
    printf '%s: mirrors are out of date; run make mirrors\n' "$SCRIPT_NAME" >&2
    exit 1
  fi
  printf '%s: mirrors are current\n' "$SCRIPT_NAME"
  exit 0
fi

printf '%s: ok\n' "$SCRIPT_NAME"
