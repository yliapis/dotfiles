#!/usr/bin/env zsh
# sync-coding-tools.sh — symlink AI-coding commands and skills from this
# dotfiles repo into the home-directory locations used by Cursor and Claude
# Code, so edits in the repo become live immediately.
#
# Sources:
#   commands  ai-coding/plugins/ai-coding/commands/*.md
#   skills    ai-coding/plugins/ai-coding/skills/<name>/    (whole directory)
#
# Targets:
#   cursor    ~/.cursor/commands/<name>.md    ~/.cursor/skills-cursor/<name>
#   claude    ~/.claude/commands/<name>.md    ~/.claude/skills/<name>
#
# Non-symlink files/dirs at a target path are moved to
# ~/.dotfiles-backup/<UTC-timestamp>/<home-relative-path> before being
# replaced. `--unlink` reverses the operation, restoring the most recent
# backup when one is present.

set -euo pipefail

SCRIPT_PATH="${0:A}"
REPO_ROOT="${SCRIPT_PATH:h}"

SRC_COMMANDS="$REPO_ROOT/ai-coding/plugins/ai-coding/commands"
SRC_SKILLS="$REPO_ROOT/ai-coding/plugins/ai-coding/skills"
BACKUP_ROOT="$HOME/.dotfiles-backup"

DRY_RUN=0
UNLINK=0
TARGETS="cursor,claude"

usage() {
  cat <<EOF
Usage: ${0:t} [options]

Symlink AI-coding commands and skills from this dotfiles repo into the
home-directory locations used by Cursor and Claude Code, so edits in the
repo become live without re-syncing.

Sources:
  commands  ai-coding/plugins/ai-coding/commands/*.md
  skills    ai-coding/plugins/ai-coding/skills/<name>/    (whole directory)

Targets:
  cursor    ~/.cursor/commands/<name>.md    ~/.cursor/skills-cursor/<name>
  claude    ~/.claude/commands/<name>.md    ~/.claude/skills/<name>

Options:
  -n, --dry-run            Print actions without changing the filesystem.
      --targets <list>     Comma-separated subset of: cursor,claude
                           (default: cursor,claude).
      --unlink             Remove symlinks pointing into this repo and,
                           when a matching backup exists under
                           ~/.dotfiles-backup/, restore the most recent copy.
  -h, --help               Show this help and exit.

Non-symlink files/dirs at a target path are moved to
~/.dotfiles-backup/<UTC-timestamp>/<home-relative-path> before being
replaced. Re-running with no source changes prints "ok" for each link.
EOF
}

die() { print -u2 -- "${0:t}: error: $*"; exit 2; }

# --- CLI parsing ------------------------------------------------------------

while (( $# )); do
  case "$1" in
    -n|--dry-run)   DRY_RUN=1; shift ;;
    --targets)      [[ $# -ge 2 ]] || die "--targets requires a value"; TARGETS="$2"; shift 2 ;;
    --targets=*)    TARGETS="${1#--targets=}"; shift ;;
    --unlink)       UNLINK=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; break ;;
    -*)             usage >&2; die "unknown option: $1" ;;
    *)              usage >&2; die "unexpected argument: $1" ;;
  esac
done

typeset -a TOOLS
TOOLS=()
for tool in ${(s:,:)TARGETS}; do
  [[ -z "$tool" ]] && continue
  case "$tool" in
    cursor|claude) TOOLS+=("$tool") ;;
    *) die "unknown target '$tool' (expected: cursor, claude)" ;;
  esac
done
(( ${#TOOLS[@]} > 0 )) || die "no targets selected"

[[ -d "$SRC_COMMANDS" ]] || die "commands source missing: $SRC_COMMANDS"
[[ -d "$SRC_SKILLS"   ]] || die "skills source missing:   $SRC_SKILLS"

# --- per-tool destination paths --------------------------------------------

dest_commands_dir() {
  case "$1" in
    cursor) print -- "$HOME/.cursor/commands" ;;
    claude) print -- "$HOME/.claude/commands" ;;
    *) die "no commands dir for tool '$1'" ;;
  esac
}

dest_skills_dir() {
  case "$1" in
    cursor) print -- "$HOME/.cursor/skills-cursor" ;;
    claude) print -- "$HOME/.claude/skills" ;;
    *) die "no skills dir for tool '$1'" ;;
  esac
}

# --- action helpers --------------------------------------------------------

prefix=""
(( DRY_RUN )) && prefix="[dry-run] "

action() { print -- "${prefix}$*"; }

home_rel() {
  local path="$1"
  if [[ "$path" == "$HOME/"* ]]; then
    print -- "${path#"$HOME/"}"
  else
    print -- "${path#/}"
  fi
}

# Lazily-created backup directory; one per run.
backup_dir=""
ensure_backup_dir() {
  if [[ -z "$backup_dir" ]]; then
    local ts; ts="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
    backup_dir="$BACKUP_ROOT/$ts"
    (( DRY_RUN )) || mkdir -p "$backup_dir"
  fi
  print -- "$backup_dir"
}

backup_existing() {
  local target="$1"
  local rel; rel="$(home_rel "$target")"
  local b;   b="$(ensure_backup_dir)"
  local dst="$b/$rel"
  action "backup  $target -> $dst"
  if (( ! DRY_RUN )); then
    mkdir -p "${dst:h}"
    mv -- "$target" "$dst"
  fi
}

ensure_parent_dir() {
  local target="$1"
  local parent="${target:h}"
  if [[ ! -d "$parent" ]]; then
    action "mkdir   $parent"
    (( DRY_RUN )) || mkdir -p "$parent"
  fi
}

link_one() {
  local src="$1" dst="$2"
  ensure_parent_dir "$dst"
  if [[ -L "$dst" ]]; then
    local cur; cur="$(readlink "$dst")"
    if [[ "$cur" == "$src" ]]; then
      action "ok      $dst"
      return 0
    fi
    action "relink  $dst -> $src"
  elif [[ -e "$dst" ]]; then
    backup_existing "$dst"
    action "link    $dst -> $src"
  else
    action "link    $dst -> $src"
  fi
  (( DRY_RUN )) || ln -sfn -- "$src" "$dst"
}

# Newest-first because backup dirs are sortable ISO-8601 UTC timestamps.
restore_from_backup() {
  local target="$1"
  local rel; rel="$(home_rel "$target")"
  [[ -d "$BACKUP_ROOT" ]] || return 1
  local ts_dir candidate
  for ts_dir in "$BACKUP_ROOT"/*(/NOn); do
    candidate="$ts_dir/$rel"
    if [[ -e "$candidate" || -L "$candidate" ]]; then
      action "restore $target <- $candidate"
      if (( ! DRY_RUN )); then
        mkdir -p "${target:h}"
        cp -a -- "$candidate" "$target"
      fi
      return 0
    fi
  done
  return 1
}

unlink_one() {
  local dst="$1"
  [[ -L "$dst" ]] || return 0
  local resolved; resolved="${dst:A}"
  if [[ "$resolved" != "$REPO_ROOT" && "$resolved" != "$REPO_ROOT"/* ]]; then
    return 0
  fi
  action "unlink  $dst"
  (( DRY_RUN )) || rm -- "$dst"
  restore_from_backup "$dst" || true
}

# --- per-(tool, type) sync -------------------------------------------------

sync_commands() {
  local tool="$1"
  local dest_dir; dest_dir="$(dest_commands_dir "$tool")"
  local src
  for src in "$SRC_COMMANDS"/*.md(N); do
    link_one "$src" "$dest_dir/${src:t}"
  done
}

sync_skills() {
  local tool="$1"
  local dest_dir; dest_dir="$(dest_skills_dir "$tool")"
  local src
  for src in "$SRC_SKILLS"/*(N/); do
    link_one "$src" "$dest_dir/${src:t}"
  done
}

unlink_dir() {
  local dest_dir="$1"
  [[ -d "$dest_dir" ]] || return 0
  local f
  for f in "$dest_dir"/*(@N); do
    unlink_one "$f"
  done
}

# --- main ------------------------------------------------------------------

if (( DRY_RUN )); then
  print -- "${0:t}: dry-run; no filesystem changes will be made"
fi
print -- "${0:t}: repo_root=$REPO_ROOT"
print -- "${0:t}: targets=${(j:,:)TOOLS}"
print -- "${0:t}: mode=$( (( UNLINK )) && print -n unlink || print -n link )"
print -- ""

for tool in "${TOOLS[@]}"; do
  print -- "# $tool"
  if (( UNLINK )); then
    unlink_dir "$(dest_commands_dir "$tool")"
    unlink_dir "$(dest_skills_dir   "$tool")"
  else
    sync_commands "$tool"
    sync_skills   "$tool"
  fi
  print -- ""
done

if [[ -n "$backup_dir" ]]; then
  print -- "${0:t}: backups stored at $backup_dir"
fi
