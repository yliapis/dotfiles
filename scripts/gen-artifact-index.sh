#!/usr/bin/env bash
# gen-artifact-index.sh — regenerate an ai-coding/indexes/ census from the
# plugin tree.
#
# Sources (the only place a maintainer edits):
#   ai-coding/plugins/<plugin>/skills/<name>/SKILL.md   --kind skills
#   ai-coding/plugins/<plugin>/commands/*.md            --kind commands
#
# Outputs (generated, never edited by hand):
#   ai-coding/indexes/skills.md
#   ai-coding/indexes/commands.md
#
# A census carries no generation timestamp and sorts slugs in the C locale, so
# one tree always renders byte-identical output and --check can fail a drifted
# index. The hand-dated censuses this replaces outlived their source root by
# three skills and one directory move, because nothing regenerated them.
#
# Deliberately bash + coreutils only: no zsh, no rsync. A cloud VM that failed
# to install either must still be able to run this.
#
# Run `gen-artifact-index.sh --help` for the full CLI.

set -euo pipefail

PROG="$(basename -- "$0")"
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
REPO_ROOT="$(dirname -- "$SCRIPT_DIR")"

SRC_PLUGINS="$REPO_ROOT/ai-coding/plugins"

# Table cells hold a prefix of the source text, cut back to a word boundary so
# the cut never lands inside a multi-byte character.
TEXT_MAX=100
TEXT_CUT=97

KIND=""
MODE="write"
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $PROG --kind <skills|commands> [options]

Regenerate ai-coding/indexes/<kind>.md from the plugin tree. Renders the slug,
path, parameter flag, and truncated description (skills) or title (commands) of
every artifact. Output is deterministic: no timestamp, C-locale slug order,
byte-identical across runs.

Options:
      --kind <k>    skills | commands. Required.
      --check       Report drift and exit non-zero if the committed index
                    differs from the plugin tree. Writes nothing.
  -n, --dry-run     Print the rendered index to stdout. Writes nothing.
  -h, --help        Show this help and exit.

Exit status:
  0  success (index written, already current, or --check found no drift)
  1  --check found drift
  2  invalid arguments, missing sources, or an artifact missing required text
EOF
}

die() { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --kind)       [ $# -ge 2 ] || die "--kind needs a value"; KIND="$2"; shift 2 ;;
    --kind=*)     KIND="${1#--kind=}"; shift ;;
    --check)      MODE="check"; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    --)           shift; break ;;
    *)            usage >&2; die "unknown option: $1" ;;
  esac
done

case "$KIND" in
  skills|commands) ;;
  '') usage >&2; die "--kind is required (skills or commands)" ;;
  *)  die "unknown --kind '$KIND' (expected: skills, commands)" ;;
esac

OUT_REL="ai-coding/indexes/$KIND.md"
OUT_FILE="$REPO_ROOT/$OUT_REL"

[ -d "$SRC_PLUGINS" ] || die "plugin source missing: $SRC_PLUGINS"

TMP_RUN="$(mktemp -d "${TMPDIR:-/tmp}/gen-artifact-index.XXXXXX")"
trap 'rm -rf -- "$TMP_RUN"' EXIT

# --- source enumeration ---------------------------------------------------

# Prints "<slug><TAB><repo-relative path>" per artifact, sorted by slug. A
# flattened slug is claimed by one plugin only; `make mirrors` already fails the
# tree when two plugins collide, so this stays a plain listing.
artifact_sources() {
  local dir slug file
  {
    case "$KIND" in
      skills)
        for dir in "$SRC_PLUGINS"/*/skills/*/; do
          dir="${dir%/}"
          [ -d "$dir" ] || continue
          file="$dir/SKILL.md"
          [ -f "$file" ] || die "skill has no SKILL.md: ${dir#"$REPO_ROOT"/}"
          printf '%s\t%s\n' "$(basename -- "$dir")" "${file#"$REPO_ROOT"/}"
        done
        ;;
      commands)
        for file in "$SRC_PLUGINS"/*/commands/*.md; do
          [ -f "$file" ] || continue
          slug="$(basename -- "$file")"
          printf '%s\t%s\n' "${slug%.md}" "${file#"$REPO_ROOT"/}"
        done
        ;;
    esac
  } | LC_ALL=C sort
}

# Prints "<has_parameters><TAB><escaped truncated text>" for one artifact. The
# text is the frontmatter description for a skill and the H1 title for a
# command.
artifact_facts() {
  local file="$1"
  LC_ALL=C awk -v mode="$KIND" -v max="$TEXT_MAX" -v cut="$TEXT_CUT" '
    NR == 1 && mode == "skills" {
      if ($0 != "---") { print "!no-frontmatter"; exit }
      fm = 1
      next
    }
    fm && $0 == "---" { fm = 0; next }
    fm && /^description: / { value = substr($0, 14); next }
    fm { next }
    mode == "commands" && value == "" && /^# / { value = substr($0, 3) }
    /^## Parameters[[:space:]]*$/ { params = 1 }
    END {
      if (value == "") { print "!no-text"; exit }
      if (value ~ /^".*"$/) value = substr(value, 2, length(value) - 2)
      if (length(value) > max) {
        value = substr(value, 1, cut)
        sub(/[^ ]*$/, "", value)
        sub(/ +$/, "", value)
        value = value "..."
      }
      gsub(/\\/, "\\\\&", value)
      gsub(/\|/, "\\\\&", value)
      gsub(/</, "\\&lt;", value)
      gsub(/>/, "\\&gt;", value)
      printf "%s\t%s\n", (params ? "yes" : "no"), value
    }
  ' "$file"
}

# --- rendering ------------------------------------------------------------

render_header() {
  local count="$1"

  if [ "$KIND" = "skills" ]; then
    cat <<EOF
# Skills Index

Canonical census of live skills under \`ai-coding/plugins/*/skills/\`. Generated
by \`make skills-index\`; edit the skill and regenerate rather than editing this
file. \`make skills-index-check\` fails when it has drifted.

- **Source root:** \`ai-coding/plugins/*/skills/\`
- **Count:** $count

## Parameter surface

Pass a \`slug\` (or full \`path\`) from this index to a command's \`{artifact}\` /
\`{artifacts}\` parameter, such as applying
[\`stop-slop\`](../plugins/writing/skills/stop-slop/SKILL.md) across every skill.
Enumerate every row when no filter is given. Descriptions are cut to $TEXT_MAX
characters at a word boundary.

| # | slug | path | has_parameters | description |
|---:|---|---|---|---|
EOF
  else
    cat <<EOF
# Commands Index

Canonical census of live slash commands under
\`ai-coding/plugins/*/commands/\`. Generated by \`make commands-index\`; edit the
command and regenerate rather than editing this file.
\`make commands-index-check\` fails when it has drifted.

- **Source root:** \`ai-coding/plugins/*/commands/\`
- **Count:** $count

## Parameter surface

Pass a \`slug\` (or full \`path\`) from this index to a command's \`{artifact}\` /
\`{artifacts}\` parameter, such as applying
[\`stop-slop\`](../plugins/writing/skills/stop-slop/SKILL.md) across every
command. Enumerate every row when no filter is given. Titles are cut to
$TEXT_MAX characters at a word boundary.

| # | slug | invocation | path | has_parameters | title |
|---:|---|---|---|---|---|
EOF
  fi
}

render() {
  local rows="$1" count slug path facts has_params text n=0

  count="$(wc -l <"$rows" | tr -d ' ')"
  render_header "$count"

  while IFS=$'\t' read -r slug path; do
    [ -n "$slug" ] || continue
    facts="$(artifact_facts "$REPO_ROOT/$path")"
    case "$facts" in
      '!no-frontmatter') die "skill has no YAML frontmatter: $path" ;;
      '!no-text')        die "artifact has no description or title: $path" ;;
    esac
    n=$((n + 1))
    IFS=$'\t' read -r has_params text <<EOF
$facts
EOF
    if [ "$KIND" = "skills" ]; then
      printf "| %d | \`%s\` | \`%s\` | %s | %s |\n" \
        "$n" "$slug" "$path" "$has_params" "$text"
    else
      printf "| %d | \`%s\` | \`/%s\` | \`%s\` | %s | %s |\n" \
        "$n" "$slug" "$slug" "$path" "$has_params" "$text"
    fi
  done <"$rows"

  cat <<'EOF'

## Slug list

Comma-separated slugs for command parameters:

```text
EOF
  cut -f1 <"$rows" | paste -sd, - | sed 's/,/, /g'
  cat <<'EOF'
```

## Path list

```text
EOF
  cut -f2 <"$rows"
  cat <<'EOF'
```
EOF
}

# --- main -----------------------------------------------------------------

rows="$TMP_RUN/artifacts.tsv"
artifact_sources >"$rows"
[ -s "$rows" ] || die "no $KIND found under $SRC_PLUGINS/*/$KIND/"

rendered="$TMP_RUN/index.md"
render "$rows" >"$rendered"
count="$(wc -l <"$rows" | tr -d ' ')"

if [ "$DRY_RUN" -eq 1 ]; then
  cat -- "$rendered"
  exit 0
fi

if [ "$MODE" = "check" ]; then
  if [ ! -e "$OUT_FILE" ]; then
    printf '%s: %s is missing; run %s\n' \
      "$PROG" "$OUT_REL" "'make $KIND-index'" >&2
    exit 1
  fi
  if cmp -s -- "$rendered" "$OUT_FILE"; then
    printf '%s: %s matches ai-coding/plugins/ (%s %s)\n' \
      "$PROG" "$OUT_REL" "$count" "$KIND"
    exit 0
  fi
  printf '%s: %s drifted from ai-coding/plugins/; run %s\n' \
    "$PROG" "$OUT_REL" "'make $KIND-index'" >&2
  diff -u -- "$OUT_FILE" "$rendered" >&2 || true
  exit 1
fi

if [ -e "$OUT_FILE" ] && cmp -s -- "$rendered" "$OUT_FILE"; then
  printf '%s: %s already current (%s %s)\n' "$PROG" "$OUT_REL" "$count" "$KIND"
  exit 0
fi

mkdir -p -- "$(dirname -- "$OUT_FILE")"
cp -- "$rendered" "$OUT_FILE"
printf '%s: wrote %s (%s %s)\n' "$PROG" "$OUT_REL" "$count" "$KIND"
