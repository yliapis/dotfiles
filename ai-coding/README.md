# ai-coding

Skills and slash commands for AI coding agents, packaged as five Claude Code
plugins and served from a marketplace at the repo root. The same content is
also mirrored into Cursor, OpenCode, and Codex home directories by the sync
scripts, so one source of truth feeds every tool.

## The five plugins

Plugins group artifacts by workflow, so you can install the parts you use
without carrying the rest.

| Plugin | Skills | Commands |
|---|---|---|
| `design-suite` | design-skill, designer-controller, declarative-design, deterministic-design | `/designer`, `/ralph-design` |
| `git-delivery` | conventional-commits, minimal-diffs, ticket-breakdown | `/merge-commit-push`, `/address-worklist-commit-loop` |
| `orchestration` | agent-swarm, worktree-task | — |
| `session-state` | trajectory-snapshot, file-dump | `/save-session-state`, `/soft-shutdown`, `/wrap-up` |
| `writing` | stop-slop, prompt-template-library | `/meta-prompt`, `/critique` |

## Layout

```
.claude-plugin/marketplace.json      marketplace manifest (repo root)
ai-coding/
  plugins/<plugin>/
    .claude-plugin/plugin.json       plugin manifest
    skills/<name>/SKILL.md           auto-discovered by Claude Code
    commands/<name>.md               auto-discovered by Claude Code
  scripts/sync                       symlink sync for cursor/claude/opencode/codex
  indexes/                           dated censuses of the live artifacts
  parameters/                        parameter wiki (concern-first reference)
  trajectories/                      design working notes
  samples/                           leftover artifacts from past runs
```

Both manifest directories are named `.claude-plugin/`, and `skills/` and
`commands/` are discovered automatically from the plugin root — neither is
declared in `plugin.json`.

### Everything a plugin needs lives inside it

Installing a plugin copies its directory into `~/.claude/plugins/cache/`, so a
file that points anywhere outside its own plugin directory breaks once
installed. Two consequences worth remembering when adding content:

- No symlinks inside a plugin directory.
- Reference sibling files relatively. The prompt template catalog lives at
  `plugins/writing/skills/prompt-template-library/templates/` and its SKILL.md
  refers to it as `templates/...`, not by a repo-rooted path.

## Install as a Claude Code plugin

```sh
/plugin marketplace add yliapis/dotfiles
/plugin install design-suite@yliapis-dotfiles
```

Install whichever of the five you want; each is independent. Components are
namespaced by plugin name, so `designer` from `design-suite` resolves as
`design-suite:designer`. Note that current Claude Code loads `commands/`
entries as flat skill files, so `claude plugin details <plugin>` lists commands
and skills together under one count.

To validate the manifests after editing them:

```sh
claude plugin validate .                        # marketplace
claude plugin validate ai-coding/plugins/writing # one plugin
```

`validate` checks the schema only. It does not resolve plugin sources, so a
manifest can validate and still fail to install; run an actual install against
a local checkout when you change `source` paths.

## Sync into other tools

Cursor, OpenCode, and Codex have no plugin marketplace, so the sync scripts
flatten every plugin's `commands/` and `skills/` into one directory per tool.
Because they flatten, a basename may be claimed by only one plugin.

`scripts/sync-coding-tools.sh` is what `make sync` and `refresh.sh` call. It
handles Cursor and Claude, in copy mode (rsync, the default) or symlink mode,
and mirrors the marketplace so the destination is itself installable:

```sh
make sync          # copy into Cursor and Claude home dirs
make symlink       # symlink instead, so repo edits go live immediately
make dry-run       # show what sync would do
make unlink        # reverse a previous sync
```

`ai-coding/scripts/sync` is the POSIX-shell alternative. It is symlink-only but
covers OpenCode and Codex as well, and takes explicit tool and type arguments:

```sh
sh ai-coding/scripts/sync --tool codex --type command --type skill --dry-run
```

## Adding a skill or command

1. Pick the plugin whose workflow it belongs to, and drop it at
   `plugins/<plugin>/skills/<name>/SKILL.md` or
   `plugins/<plugin>/commands/<name>.md`.
2. Keep the basename unique across all five plugins, or the sync scripts will
   abort rather than let one artifact overwrite another.
3. Keep every path it references inside its own plugin directory.
4. Bump the plugin's `version` in both `plugin.json` and the matching
   marketplace entry; `claude plugin tag` checks that the two agree.
