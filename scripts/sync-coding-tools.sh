#!/usr/bin/env zsh
# sync-coding-tools.sh — mirror the commands, skills, and agents carried by the
# ai-coding plugins (plus marketplace metadata) from this dotfiles repo into
# the home-dir locations used by Cursor, Claude Code, OpenCode, and the
# cross-platform .agents tree.
#
# Two modes:
#   copy     (default) rsync, deterministic, source-of-truth is the dotfiles
#                      repo at the moment of the last run.
#   symlink            ln -sfn, edits in the repo are live immediately;
#                      pre-existing non-symlink targets are backed up under
#                      ~/.dotfiles-backup/<UTC-timestamp>/ before replacement.
#
# Sources (in this repo, do not modify by hand here):
#   ai-coding/plugins/<plugin>/commands/*.md           slash commands
#   ai-coding/plugins/<plugin>/skills/<name>/SKILL.md  skills
#   ai-coding/plugins/<plugin>/agents/*.md             subagent definitions
#   .cursor-plugin/marketplace.json (Cursor),
#   .claude-plugin/marketplace.json (Claude) + ai-coding/plugins/
#                                                      marketplace metadata
#
# Commands, skills, and agents from every plugin are flattened into one
# destination directory per tool; the marketplace is mirrored whole, since the
# repo root is itself the marketplace root. Agents are optional: plugin sets
# that carry none are synced without them.
#
# Targets (roots overridable via env; subpaths are fixed under each root).
# SYNC_CODING_TOOLS_DEST is the parent (default: $HOME). Per-tool homes
# default under that dest unless you set a tool-specific override.
#   cursor    $SYNC_CODING_TOOLS_CURSOR_HOME/commands          (default: $DEST/.cursor)
#             $SYNC_CODING_TOOLS_CURSOR_HOME/skills/<name>
#             $SYNC_CODING_TOOLS_CURSOR_HOME/agents
#             $SYNC_CODING_TOOLS_CURSOR_HOME/plugins/local/ai-coding
#   claude    $SYNC_CODING_TOOLS_CLAUDE_HOME/commands          (default: $DEST/.claude)
#             $SYNC_CODING_TOOLS_CLAUDE_HOME/skills/<name>
#             $SYNC_CODING_TOOLS_CLAUDE_HOME/agents
#             $SYNC_CODING_TOOLS_CLAUDE_HOME/plugins/marketplaces/yliapis-dotfiles
#   opencode  $SYNC_CODING_TOOLS_OPENCODE_HOME/commands        (default: $DEST/.config/opencode)
#             $SYNC_CODING_TOOLS_OPENCODE_HOME/skills/<name>
#             $SYNC_CODING_TOOLS_OPENCODE_HOME/agents
#   agents    $SYNC_CODING_TOOLS_AGENTS_HOME/skills/<name>     (default: $DEST/.agents)
#             Codex and other .agents clients read skills only; commands
#             and agents are not synced here.
#
# Run `sync-coding-tools.sh --help` for the full CLI.

set -euo pipefail

SCRIPT_PATH="${0:A}"
REPO_ROOT="${SCRIPT_PATH:h:h}"

SRC_PLUGINS="$REPO_ROOT/ai-coding/plugins"
SRC_MARKETPLACE="$REPO_ROOT"

typeset -a SRC_COMMANDS SRC_SKILLS SRC_AGENTS
SRC_COMMANDS=("$SRC_PLUGINS"/*/commands/*.md(N))
SRC_SKILLS=("$SRC_PLUGINS"/*/skills/*(N/))
SRC_AGENTS=("$SRC_PLUGINS"/*/agents/*.md(N))

BACKUP_ROOT="$HOME/.dotfiles-backup"
LOG_FILE="$HOME/.cache/dotfiles/sync.log"

# Parent dest, then per-tool roots. Override DEST to redirect the whole tree
# (e.g. tests). A tool-specific *_HOME still wins over DEST.
: "${SYNC_CODING_TOOLS_DEST:=$HOME}"
: "${SYNC_CODING_TOOLS_CURSOR_HOME:=$SYNC_CODING_TOOLS_DEST/.cursor}"
: "${SYNC_CODING_TOOLS_CLAUDE_HOME:=$SYNC_CODING_TOOLS_DEST/.claude}"
: "${SYNC_CODING_TOOLS_OPENCODE_HOME:=$SYNC_CODING_TOOLS_DEST/.config/opencode}"
: "${SYNC_CODING_TOOLS_AGENTS_HOME:=$SYNC_CODING_TOOLS_DEST/.agents}"

DRY_RUN=0
VERBOSE=0
UNLINK=0
MODE="copy"
TARGETS="cursor,claude,opencode,agents"

usage() {
  cat <<EOF
Usage: ${SCRIPT_PATH:t} [options]

Mirror ai-coding commands, skills, and agents from this dotfiles repo into the
home locations used by Cursor, Claude Code, OpenCode, and the cross-platform
.agents tree. Idempotent; safe to re-run.

Modes:
  copy         (default) rsync-based; deterministic snapshot of the repo at
               sync time.
  symlink      ln -sfn back to the repo; edits in the repo go live without
               re-syncing. Non-symlink targets are backed up under
               ${BACKUP_ROOT/$HOME/~}/<UTC-timestamp>/ before replacement.

Options:
  -n, --dry-run         Show actions without writing.
      --targets <list>  Comma-separated subset of:
                        cursor,claude,opencode,agents
                        (default: all).
      --mode <m>        copy | symlink (default: copy).
      --unlink          Reverse a previous sync: remove symlinks that point
                        into this repo and remove copies that match the repo
                        sources, restoring from the newest backup when one
                        exists. Honors --dry-run, --targets, --verbose.
  -v, --verbose         Print every action; pass -v through to rsync.
  -h, --help            Show this help and exit.

Environment (override dest and tool home roots):
  SYNC_CODING_TOOLS_DEST           Parent dest    (default: \$HOME)
  SYNC_CODING_TOOLS_CURSOR_HOME    Cursor root    (default: \$DEST/.cursor)
  SYNC_CODING_TOOLS_CLAUDE_HOME    Claude root    (default: \$DEST/.claude)
  SYNC_CODING_TOOLS_OPENCODE_HOME  OpenCode root  (default: \$DEST/.config/opencode)
  SYNC_CODING_TOOLS_AGENTS_HOME    .agents root   (default: \$DEST/.agents)

  Under each Cursor, Claude, and OpenCode root the script writes commands/,
  skills/, and agents/. The .agents root receives skills/ only (Codex and
  other .agents clients discover skills there). Cursor also gets
  plugins/local/ai-coding; Claude gets
  plugins/marketplaces/yliapis-dotfiles. OpenCode and .agents have no
  plugin destination. Cursor skills stay at <root>/skills (never skills-cursor).

Exit status:
  0  success
  1  rsync or symlink step failed for at least one destination
  2  invalid arguments / missing source / unsupported option

Audit log:
  Every run appends one line to ${LOG_FILE/$HOME/~} with timestamp, mode,
  targets, dry-run flag, exit code, and elapsed wall-clock seconds.
EOF
}

die() { print -u2 -- "${0:t}: error: $*"; exit 2; }
log() { (( VERBOSE )) && print -- "$*"; }

# --- CLI parsing ----------------------------------------------------------

while (( $# )); do
  case "$1" in
    -n|--dry-run)   DRY_RUN=1; shift ;;
    --targets)      [[ $# -ge 2 ]] || die "--targets requires a value"; TARGETS="$2"; shift 2 ;;
    --targets=*)    TARGETS="${1#--targets=}"; shift ;;
    --mode)         [[ $# -ge 2 ]] || die "--mode requires a value"; MODE="$2"; shift 2 ;;
    --mode=*)       MODE="${1#--mode=}"; shift ;;
    --unlink)       UNLINK=1; shift ;;
    -v|--verbose)   VERBOSE=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; break ;;
    -*)             usage >&2; die "unknown option: $1" ;;
    *)              usage >&2; die "unexpected argument: $1" ;;
  esac
done

case "$MODE" in
  copy|symlink) ;;
  *) die "unknown --mode '$MODE' (expected: copy, symlink)" ;;
esac

typeset -a TOOLS
TOOLS=()
for tool in ${(s:,:)TARGETS}; do
  [[ -z "$tool" ]] && continue
  case "$tool" in
    cursor|claude|opencode|agents) TOOLS+=("$tool") ;;
    *) die "unknown target '$tool' (expected: cursor, claude, opencode, agents)" ;;
  esac
done
(( ${#TOOLS[@]} > 0 )) || die "no targets selected"

[[ -d "$SRC_PLUGINS" ]] || die "plugin source missing: $SRC_PLUGINS"
(( ${#SRC_COMMANDS[@]} )) || die "no commands found under $SRC_PLUGINS/*/commands/"
(( ${#SRC_SKILLS[@]}   )) || die "no skills found under   $SRC_PLUGINS/*/skills/"

# --- destinations --------------------------------------------------------

tool_home() {
  case "$1" in
    cursor)   print -- "$SYNC_CODING_TOOLS_CURSOR_HOME" ;;
    claude)   print -- "$SYNC_CODING_TOOLS_CLAUDE_HOME" ;;
    opencode) print -- "$SYNC_CODING_TOOLS_OPENCODE_HOME" ;;
    agents)   print -- "$SYNC_CODING_TOOLS_AGENTS_HOME" ;;
    *) die "no home root for tool '$1'" ;;
  esac
}

dest_commands_dir() {
  print -- "$(tool_home "$1")/commands"
}

# Cursor skills go to <cursor-home>/skills, never .../skills-cursor: the
# shipped client registers skills-cursor as its own root with scope "builtin"
# and source "builtin", so anything written there is presented as the client's
# content rather than as the user's skills. <cursor-home>/skills is the root it
# registers with scope "user", which is what a global sync of this repo wants.
dest_skills_dir() {
  print -- "$(tool_home "$1")/skills"
}

dest_agents_dir() {
  print -- "$(tool_home "$1")/agents"
}

# The .agents tree is skills-only. Codex and other clients discover
# $HOME/.agents/skills. Commands and markdown agents are not a documented
# .agents layout.
tool_syncs_kind() {
  case "$1:$2" in
    agents:skills) return 0 ;;
    agents:*) return 1 ;;
    *:commands|*:skills|*:agents) return 0 ;;
    *) return 1 ;;
  esac
}

# Empty output means the tool has no plugin-marketplace concept to mirror.
dest_plugin_dir() {
  case "$1" in
    cursor)   print -- "$SYNC_CODING_TOOLS_CURSOR_HOME/plugins/local/ai-coding" ;;
    claude)   print -- "$SYNC_CODING_TOOLS_CLAUDE_HOME/plugins/marketplaces/yliapis-dotfiles" ;;
    opencode|agents) print -- "" ;;
    *) die "no plugin dir for tool '$1'" ;;
  esac
}

plugin_meta_subdir() {
  case "$1" in
    cursor)   print -- ".cursor-plugin" ;;
    claude)   print -- ".claude-plugin" ;;
    opencode|agents) print -- "" ;;
    *) die "no plugin meta subdir for tool '$1'" ;;
  esac
}

# --- audit log ------------------------------------------------------------

start_epoch=$(date +%s)

append_log() {
  local exit_code="$1"
  local elapsed=$(( $(date +%s) - start_epoch ))
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "${LOG_FILE:h}" 2>/dev/null || return 0
  print -- "$ts mode=$MODE targets=${(j:,:)TOOLS} dry_run=$DRY_RUN unlink=$UNLINK exit=$exit_code elapsed_s=$elapsed" >> "$LOG_FILE" 2>/dev/null || true
}

trap 'append_log $?' EXIT

# --- copy-mode (rsync) ----------------------------------------------------
#
# -aL: archive + dereference symlinks so destinations always get real files,
# even if a source entry is ever a symlink into the repo.
# --itemize-changes: one summary line per change so dry-run output is useful.

typeset -a RSYNC_BASE
RSYNC_BASE=(rsync -aL --itemize-changes)
(( DRY_RUN )) && RSYNC_BASE+=(--dry-run)
(( VERBOSE )) && RSYNC_BASE+=(-v)

rsync_errors=0

run_rsync() {
  if ! "${RSYNC_BASE[@]}" "$@"; then
    rsync_errors=$(( rsync_errors + 1 ))
    print -u2 -- "${0:t}: rsync failed for: $*"
  fi
}

copy_sync_tool() {
  local tool="$1"
  local cmds_dst skills_dst agents_dst plugin_dst meta_subdir
  cmds_dst="$(dest_commands_dir "$tool")"
  skills_dst="$(dest_skills_dir "$tool")"
  agents_dst="$(dest_agents_dir "$tool")"
  plugin_dst="$(dest_plugin_dir "$tool")"
  meta_subdir="$(plugin_meta_subdir "$tool")"

  if tool_syncs_kind "$tool" commands; then
    print -- "==> $tool commands -> $cmds_dst"
    mkdir -p "$cmds_dst"
    run_rsync "${SRC_COMMANDS[@]}" "$cmds_dst/"
  fi

  if tool_syncs_kind "$tool" skills; then
    print -- "==> $tool skills   -> $skills_dst"
    mkdir -p "$skills_dst"
    run_rsync "${SRC_SKILLS[@]}" "$skills_dst"/
  fi

  if tool_syncs_kind "$tool" agents; then
    if (( ${#SRC_AGENTS[@]} )); then
      print -- "==> $tool agents   -> $agents_dst"
      mkdir -p "$agents_dst"
      run_rsync "${SRC_AGENTS[@]}" "$agents_dst/"
    else
      print -- "==> $tool agents   (skipped: none found)"
    fi
  fi

  if [[ -z "$plugin_dst" ]]; then
    print -- "==> $tool plugin   (skipped)"
    return 0
  fi
  print -- "==> $tool plugin   -> $plugin_dst"
  if [[ -L "$plugin_dst" ]]; then
    (( DRY_RUN )) || rm -f "$plugin_dst"
  fi
  mkdir -p "$plugin_dst/$meta_subdir" "$plugin_dst/ai-coding"
  run_rsync "$SRC_MARKETPLACE/$meta_subdir"/ "$plugin_dst/$meta_subdir"/
  run_rsync "$SRC_PLUGINS" "$plugin_dst/ai-coding"/
}

# --- symlink-mode (with backup) ------------------------------------------

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

link_one() {
  local src="$1" dst="$2"
  mkdir -p "${dst:h}"
  if [[ -L "$dst" ]]; then
    local cur; cur="$(readlink "$dst")"
    if [[ "$cur" == "$src" ]]; then
      log "ok      $dst"
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

symlink_sync_tool() {
  local tool="$1"
  local cmds_dst skills_dst agents_dst plugin_dst
  cmds_dst="$(dest_commands_dir "$tool")"
  skills_dst="$(dest_skills_dir "$tool")"
  agents_dst="$(dest_agents_dir "$tool")"
  plugin_dst="$(dest_plugin_dir "$tool")"

  if tool_syncs_kind "$tool" commands; then
    print -- "==> $tool commands -> $cmds_dst  (symlink)"
    local f
    for f in "${SRC_COMMANDS[@]}"; do
      link_one "$f" "$cmds_dst/${f:t}"
    done
  fi

  if tool_syncs_kind "$tool" skills; then
    print -- "==> $tool skills   -> $skills_dst  (symlink)"
    local d
    for d in "${SRC_SKILLS[@]}"; do
      link_one "$d" "$skills_dst/${d:t}"
    done
  fi

  if tool_syncs_kind "$tool" agents; then
    if (( ${#SRC_AGENTS[@]} )); then
      print -- "==> $tool agents   -> $agents_dst  (symlink)"
      local a
      for a in "${SRC_AGENTS[@]}"; do
        link_one "$a" "$agents_dst/${a:t}"
      done
    else
      print -- "==> $tool agents   (skipped: none found)"
    fi
  fi

  if [[ -z "$plugin_dst" ]]; then
    print -- "==> $tool plugin   (skipped)"
    return 0
  fi
  print -- "==> $tool plugin   -> $plugin_dst  (symlink)"
  if [[ -L "$plugin_dst" ]]; then
    local cur; cur="$(readlink "$plugin_dst")"
    if [[ "$cur" == "$SRC_MARKETPLACE" ]]; then
      log "ok      $plugin_dst"
    else
      action "relink  $plugin_dst -> $SRC_MARKETPLACE"
      (( DRY_RUN )) || ln -sfn -- "$SRC_MARKETPLACE" "$plugin_dst"
    fi
  elif [[ -e "$plugin_dst" ]]; then
    backup_existing "$plugin_dst"
    action "link    $plugin_dst -> $SRC_MARKETPLACE"
    (( DRY_RUN )) || ln -sfn -- "$SRC_MARKETPLACE" "$plugin_dst"
  else
    mkdir -p "${plugin_dst:h}"
    action "link    $plugin_dst -> $SRC_MARKETPLACE"
    (( DRY_RUN )) || ln -sfn -- "$SRC_MARKETPLACE" "$plugin_dst"
  fi
}

# --- unlink (reverse of sync) --------------------------------------------

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
  if [[ -L "$dst" ]]; then
    local resolved; resolved="${dst:A}"
    if [[ "$resolved" == "$REPO_ROOT" || "$resolved" == "$REPO_ROOT"/* ]]; then
      action "unlink  $dst"
      (( DRY_RUN )) || rm -- "$dst"
      restore_from_backup "$dst" || true
    fi
    return 0
  fi
  # Copy-mode artifact: remove iff dst exists, source exists, and contents match.
  local rel="$2" src="$3"
  if [[ -n "$src" && -f "$src" && -f "$dst" ]]; then
    if cmp -s -- "$src" "$dst"; then
      action "remove  $dst"
      (( DRY_RUN )) || rm -- "$dst"
      restore_from_backup "$dst" || true
    else
      log "diff    $dst (different from repo source; leaving in place)"
    fi
  fi
}

unlink_tool() {
  local tool="$1"
  local cmds_dst skills_dst agents_dst plugin_dst
  cmds_dst="$(dest_commands_dir "$tool")"
  skills_dst="$(dest_skills_dir "$tool")"
  agents_dst="$(dest_agents_dir "$tool")"
  plugin_dst="$(dest_plugin_dir "$tool")"

  if tool_syncs_kind "$tool" commands; then
    print -- "==> $tool commands <- $cmds_dst"
    local f
    for f in "${SRC_COMMANDS[@]}"; do
      unlink_one "$cmds_dst/${f:t}" "${f:t}" "$f"
    done
  fi

  if tool_syncs_kind "$tool" skills; then
    print -- "==> $tool skills   <- $skills_dst"
    local d
    for d in "${SRC_SKILLS[@]}"; do
      unlink_one "$skills_dst/${d:t}" "${d:t}" "$d"
    done
  fi

  if tool_syncs_kind "$tool" agents; then
    if (( ${#SRC_AGENTS[@]} )); then
      print -- "==> $tool agents   <- $agents_dst"
      local a
      for a in "${SRC_AGENTS[@]}"; do
        unlink_one "$agents_dst/${a:t}" "${a:t}" "$a"
      done
    else
      print -- "==> $tool agents   (skipped: none found)"
    fi
  fi

  if [[ -z "$plugin_dst" ]]; then
    print -- "==> $tool plugin   (skipped)"
    return 0
  fi
  print -- "==> $tool plugin   <- $plugin_dst"
  if [[ -L "$plugin_dst" ]]; then
    local resolved; resolved="${plugin_dst:A}"
    if [[ "$resolved" == "$SRC_MARKETPLACE" || "$resolved" == "$SRC_MARKETPLACE"/* ]]; then
      action "unlink  $plugin_dst"
      (( DRY_RUN )) || rm -- "$plugin_dst"
    fi
  fi
}

# --- main ----------------------------------------------------------------

print -- "${0:t}: repo_root=$REPO_ROOT"
print -- "${0:t}: targets=${(j:,:)TOOLS}  mode=$MODE  dry_run=$DRY_RUN  unlink=$UNLINK"
print -- "${0:t}: audit_log=$LOG_FILE"
print -- ""

if (( UNLINK )); then
  for tool in "${TOOLS[@]}"; do
    unlink_tool "$tool"
    print -- ""
  done
elif [[ "$MODE" == "symlink" ]]; then
  for tool in "${TOOLS[@]}"; do
    symlink_sync_tool "$tool"
    print -- ""
  done
  if [[ -n "$backup_dir" ]]; then
    print -- "${0:t}: backups stored at $backup_dir"
  fi
else
  for tool in "${TOOLS[@]}"; do
    copy_sync_tool "$tool"
    print -- ""
  done
fi

if (( rsync_errors > 0 )); then
  print -u2 -- "${0:t}: $rsync_errors rsync invocation(s) failed"
  exit 1
fi

print -- "${0:t}: ok"
