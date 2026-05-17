#!/usr/bin/env zsh
# sync-coding-tools.sh — mirror AI-coding commands and skills from this
# dotfiles repo into the home-directory locations used by Cursor and Claude
# Code, via rsync. Idempotent; re-running with no source changes prints
# nothing under itemize-changes.
#
# Sources (under this repo, do not modify by hand here):
#   ai-coding/plugins/ai-coding/commands/*.md          slash commands
#   ai-coding/plugins/ai-coding/skills/<name>/SKILL.md skills
#   ai-coding/{marketplace.json,.claude-plugin,.cursor-plugin}
#                                                      plugin / marketplace metadata
#
# Targets:
#   cursor    ~/.cursor/commands/<name>.md
#             ~/.cursor/skills-cursor/<name>/SKILL.md
#             ~/.cursor/plugins/local/ai-coding
#   claude    ~/.claude/commands/<name>.md
#             ~/.claude/skills/<name>/SKILL.md
#             ~/.claude/plugins/marketplaces/yliapis-dotfiles
#
# Run `sync-coding-tools.sh --help` for the full CLI.

set -euo pipefail

SCRIPT_PATH="${0:A}"
REPO_ROOT="${SCRIPT_PATH:h}"

SRC_COMMANDS="$REPO_ROOT/ai-coding/plugins/ai-coding/commands"
SRC_SKILLS="$REPO_ROOT/ai-coding/plugins/ai-coding/skills"
SRC_MARKETPLACE="$REPO_ROOT/ai-coding"

DRY_RUN=0
VERBOSE=0
TARGETS="cursor,claude"

usage() {
  cat <<EOF
Usage: ${0:t} [options]

Mirror AI-coding commands and skills from this dotfiles repo into the
home-directory locations used by Cursor and Claude Code, via rsync.

Sources:
  commands     ai-coding/plugins/ai-coding/commands/*.md
  skills       ai-coding/plugins/ai-coding/skills/<name>/
  plugin       ai-coding/{marketplace.json,.claude-plugin,.cursor-plugin}

Targets:
  cursor       ~/.cursor/commands, ~/.cursor/skills-cursor,
               ~/.cursor/plugins/local/ai-coding
  claude       ~/.claude/commands, ~/.claude/skills,
               ~/.claude/plugins/marketplaces/yliapis-dotfiles

Options:
  -n, --dry-run         Show actions without writing (rsync --dry-run).
      --targets <list>  Comma-separated subset of: cursor,claude
                        (default: cursor,claude).
  -v, --verbose         Pass -v through to rsync; print all itemize-changes.
  -h, --help            Show this help and exit.

Exit status:
  0  success
  1  rsync failed for at least one destination
  2  invalid arguments or missing source path
EOF
}

die() { print -u2 -- "${0:t}: error: $*"; exit 2; }

# --- CLI parsing ----------------------------------------------------------

while (( $# )); do
  case "$1" in
    -n|--dry-run)   DRY_RUN=1; shift ;;
    --targets)      [[ $# -ge 2 ]] || die "--targets requires a value"; TARGETS="$2"; shift 2 ;;
    --targets=*)    TARGETS="${1#--targets=}"; shift ;;
    -v|--verbose)   VERBOSE=1; shift ;;
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

# --- destinations --------------------------------------------------------

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

dest_plugin_dir() {
  case "$1" in
    cursor) print -- "$HOME/.cursor/plugins/local/ai-coding" ;;
    claude) print -- "$HOME/.claude/plugins/marketplaces/yliapis-dotfiles" ;;
    *) die "no plugin dir for tool '$1'" ;;
  esac
}

plugin_meta_subdir() {
  case "$1" in
    cursor) print -- ".cursor-plugin" ;;
    claude) print -- ".claude-plugin" ;;
    *) die "no plugin meta subdir for tool '$1'" ;;
  esac
}

# --- rsync invocation ----------------------------------------------------
#
# -aL: archive mode + dereference symlinks (the .cursor-plugin/.claude-plugin
# marketplace.json entries are symlinks; we want real files at the dest).
# --itemize-changes: one summary line per change, so dry-run output is useful.

typeset -a RSYNC_BASE
RSYNC_BASE=(rsync -aL --itemize-changes)
(( DRY_RUN )) && RSYNC_BASE+=(--dry-run)
(( VERBOSE )) && RSYNC_BASE+=(-v)

rsync_count_errors=0

run_rsync() {
  if ! "${RSYNC_BASE[@]}" "$@"; then
    rsync_count_errors=$(( rsync_count_errors + 1 ))
    print -u2 -- "${0:t}: rsync failed for: $*"
  fi
}

# --- per-tool sync --------------------------------------------------------

sync_tool() {
  local tool="$1"
  local cmds_dst skills_dst plugin_dst plugin_sub
  cmds_dst="$(dest_commands_dir "$tool")"
  skills_dst="$(dest_skills_dir "$tool")"
  plugin_dst="$(dest_plugin_dir "$tool")"
  plugin_sub="$(plugin_meta_subdir "$tool")"

  print -- "==> $tool commands -> $cmds_dst"
  mkdir -p "$cmds_dst"
  run_rsync "$SRC_COMMANDS"/*.md "$cmds_dst/"

  print -- "==> $tool skills   -> $skills_dst"
  mkdir -p "$skills_dst"
  run_rsync "$SRC_SKILLS"/ "$skills_dst"/

  print -- "==> $tool plugin   -> $plugin_dst"
  if [[ -L "$plugin_dst" ]]; then
    (( DRY_RUN )) || rm -f "$plugin_dst"
  fi
  mkdir -p "$plugin_dst/$plugin_sub"
  run_rsync "$SRC_MARKETPLACE/marketplace.json" "$plugin_dst/marketplace.json"
  if [[ -d "$SRC_MARKETPLACE/$plugin_sub" ]]; then
    run_rsync "$SRC_MARKETPLACE/$plugin_sub"/ "$plugin_dst/$plugin_sub"/
  fi
}

# --- main ----------------------------------------------------------------

print -- "${0:t}: repo_root=$REPO_ROOT"
print -- "${0:t}: targets=${(j:,:)TOOLS}"
(( DRY_RUN )) && print -- "${0:t}: dry-run; no filesystem changes will be made"
print -- ""

for tool in "${TOOLS[@]}"; do
  sync_tool "$tool"
  print -- ""
done

if (( rsync_count_errors > 0 )); then
  print -u2 -- "${0:t}: $rsync_count_errors rsync invocation(s) failed"
  exit 1
fi

print -- "${0:t}: ok"
