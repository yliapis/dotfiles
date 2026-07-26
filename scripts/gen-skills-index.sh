#!/usr/bin/env bash
# gen-skills-index.sh — regenerate the skills census that commands read as an
# {artifacts} parameter surface.
#
# Source (the only place a maintainer edits):
#   ai-coding/plugins/<plugin>/skills/<name>/SKILL.md
#
# Output (generated, never edited by hand):
#   ai-coding/indexes/skills.md
#
# The census carries no generation timestamp and sorts slugs in the C locale, so
# one tree always renders byte-identical output and --check can fail a drifted
# index. The hand-dated census this replaces outlived its source root by three
# skills and one directory move, because nothing regenerated it.
#
# Deliberately bash + coreutils only: no zsh, no rsync. A cloud VM that failed
# to install either must still be able to run this.
#
# Run `gen-skills-index.sh --help` for the full CLI.

set -euo pipefail

PROG="$(basename -- "$0")"
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
REPO_ROOT="$(dirname -- "$SCRIPT_DIR")"

SRC_PLUGINS="$REPO_ROOT/ai-coding/plugins"
OUT_REL="ai-coding/indexes/skills.md"
OUT_FILE="$REPO_ROOT/$OUT_REL"

# Table cells hold a prefix of the description, cut back to a word boundary so
# the cut never lands inside a multi-byte character.
DESC_MAX=100
DESC_CUT=97

MODE="write"
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $PROG [options]

Regenerate $OUT_REL from ai-coding/plugins/*/skills/*/SKILL.md. Renders the
slug, path, parameter flag, and truncated description of every skill. Output is
deterministic: no timestamp, C-locale slug order, byte-identical across runs.

Options:
      --check       Report drift and exit non-zero if the committed index
                    differs from the plugin tree. Writes nothing.
  -n, --dry-run     Print the rendered index to stdout. Writes nothing.
  -h, --help        Show this help and exit.

Exit status:
  0  success (index written, already current, or --check found no drift)
  1  --check found drift
  2  invalid arguments, missing sources, or a skill missing required frontmatter
EOF
}

die() { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --check)      MODE="check"; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    --)           shift; break ;;
    *)            usage >&2; die "unknown option: $1" ;;
  esac
done

[ -d "$SRC_PLUGINS" ] || die "plugin source missing: $SRC_PLUGINS"

TMP_RUN="$(mktemp -d "${TMPDIR:-/tmp}/gen-skills-index.XXXXXX")"
trap 'rm -rf -- "$TMP_RUN"' EXIT

# --- source enumeration ---------------------------------------------------

# Prints "<slug><TAB><repo-relative SKILL.md path>" per skill, sorted by slug.
# A flattened slug is claimed by one plugin only; `make mirrors` already fails
# the tree when two plugins collide, so this stays a plain listing.
skill_sources() {
  local dir slug skill
  {
    for dir in "$SRC_PLUGINS"/*/skills/*/; do
      dir="${dir%/}"
      [ -d "$dir" ] || continue
      slug="$(basename -- "$dir")"
      skill="$dir/SKILL.md"
      [ -f "$skill" ] || die "skill has no SKILL.md: ${dir#"$REPO_ROOT"/}"
      printf '%s\t%s\n' "$slug" "${skill#"$REPO_ROOT"/}"
    done
  } | LC_ALL=C sort
}

# Prints "<has_parameters><TAB><escaped truncated description>" for one skill.
skill_facts() {
  local skill="$1"
  LC_ALL=C awk -v max="$DESC_MAX" -v cut="$DESC_CUT" '
    NR == 1 {
      if ($0 != "---") { print "!no-frontmatter"; exit }
      fm = 1
      next
    }
    fm && $0 == "---" { fm = 0; next }
    fm && /^description: / { desc = substr($0, 14); next }
    !fm && /^## Parameters[[:space:]]*$/ { params = 1 }
    END {
      if (desc == "") { print "!no-description"; exit }
      if (desc ~ /^".*"$/) desc = substr(desc, 2, length(desc) - 2)
      if (length(desc) > max) {
        desc = substr(desc, 1, cut)
        sub(/[^ ]*$/, "", desc)
        sub(/ +$/, "", desc)
        desc = desc "..."
      }
      gsub(/\\/, "\\\\&", desc)
      gsub(/\|/, "\\\\&", desc)
      gsub(/</, "\\&lt;", desc)
      gsub(/>/, "\\&gt;", desc)
      printf "%s\t%s\n", (params ? "yes" : "no"), desc
    }
  ' "$skill"
}

# --- rendering ------------------------------------------------------------

render() {
  local rows="$1" count slug path facts has_params desc n=0

  count="$(wc -l <"$rows" | tr -d ' ')"

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
Enumerate every row when no filter is given. Descriptions are cut to $DESC_MAX
characters at a word boundary.

| # | slug | path | has_parameters | description |
|---:|---|---|---|---|
EOF

  while IFS=$'\t' read -r slug path; do
    [ -n "$slug" ] || continue
    facts="$(skill_facts "$REPO_ROOT/$path")"
    case "$facts" in
      '!no-frontmatter') die "skill has no YAML frontmatter: $path" ;;
      '!no-description') die "skill frontmatter has no description: $path" ;;
    esac
    n=$((n + 1))
    IFS=$'\t' read -r has_params desc <<EOF
$facts
EOF
    printf "| %d | \`%s\` | \`%s\` | %s | %s |\n" "$n" "$slug" "$path" "$has_params" "$desc"
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

rows="$TMP_RUN/skills.tsv"
skill_sources >"$rows"
[ -s "$rows" ] || die "no skills found under $SRC_PLUGINS/*/skills/"

rendered="$TMP_RUN/skills.md"
render "$rows" >"$rendered"
count="$(wc -l <"$rows" | tr -d ' ')"

if [ "$DRY_RUN" -eq 1 ]; then
  cat -- "$rendered"
  exit 0
fi

if [ "$MODE" = "check" ]; then
  if [ ! -e "$OUT_FILE" ]; then
    printf '%s: %s is missing; run %s\n' "$PROG" "$OUT_REL" "'make skills-index'" >&2
    exit 1
  fi
  if cmp -s -- "$rendered" "$OUT_FILE"; then
    printf '%s: %s matches ai-coding/plugins/ (%s skills)\n' "$PROG" "$OUT_REL" "$count"
    exit 0
  fi
  printf '%s: %s drifted from ai-coding/plugins/; run %s\n' \
    "$PROG" "$OUT_REL" "'make skills-index'" >&2
  diff -u -- "$OUT_FILE" "$rendered" >&2 || true
  exit 1
fi

if [ -e "$OUT_FILE" ] && cmp -s -- "$rendered" "$OUT_FILE"; then
  printf '%s: %s already current (%s skills)\n' "$PROG" "$OUT_REL" "$count"
  exit 0
fi

mkdir -p -- "$(dirname -- "$OUT_FILE")"
cp -- "$rendered" "$OUT_FILE"
printf '%s: wrote %s (%s skills)\n' "$PROG" "$OUT_REL" "$count"
