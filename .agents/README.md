# `.agents/` — Codex tree

Codex reads a tool-neutral `.agents/` tree at the repository root, not a
`.codex/` one like Cursor's `.cursor/`, Claude Code's `.claude/`, or OpenCode's
`.opencode/`. This directory holds what Codex reads when this repository is the
workspace:

| Path | Contents | Generated? |
| --- | --- | --- |
| `.agents/skills/<name>/` | Flattened per-skill mirror of `ai-coding/plugins/*/skills/<name>/`, byte-identical non-symlink copies. | Yes — `make mirrors`. |
| `.agents/plugins/marketplace.json` | Marketplace catalog naming every plugin at `./ai-coding/plugins/<name>`, parallel to `.cursor-plugin/marketplace.json` and `.claude-plugin/marketplace.json`. | No — hand-written. |

Each plugin also carries a `.codex-plugin/plugin.json` manifest beside its
existing `.cursor-plugin/plugin.json` and `.claude-plugin/plugin.json`, which is
the file Codex requires to resolve a plugin from the catalog.

## Where Codex reads each artifact kind

Research recorded here so the layout choices are traceable. Codex's skill,
prompt, subagent, and plugin roots each differ, so only some map onto this
repository's shared `ai-coding/plugins/*/{commands,skills,agents}` sources.

### Skills — mirrored to `.agents/skills/`

Codex scans skills from `.agents/skills/`, walking up from the working directory
to the repository root, and from `$HOME/.agents/skills/` for personal skills. It
treats `$CODEX_HOME/skills` (`~/.codex/skills`) as a deprecated compatibility
location. A skill is a directory holding a `SKILL.md`. This matches the shared
`ai-coding/plugins/*/skills/<name>/` sources exactly, so skills mirror cleanly to
`.agents/skills/<name>/` in the repo and sync to `~/.agents/skills/` at home.

### Commands — not mirrored (no repo path; home path deprecated)

Codex reads custom prompts only from `$CODEX_HOME/prompts` (`~/.codex/prompts`),
home-only, and OpenAI documents them as deprecated in favor of skills.
Project-scoped prompts under a repo `.codex/prompts` are an open, unimplemented
feature request. Codex therefore has **no repo-root path for commands**, and its
one home path is both deprecated and outside `.agents/`. Commands are left out of
the Codex mirror and the Codex home sync; the shared commands still reach Cursor,
Claude Code, and OpenCode.

### Subagents — not mirrored (home-only, incompatible format)

Codex reads custom subagents only from `~/.codex/agents/*.toml`, home-only, as
**TOML** with fields such as `model`, `model_reasoning_effort`, and
`developer_instructions`. That schema does not match this repository's shared
markdown agent files, whose frontmatter stays inside the `name` / `description` /
`mode: subagent` intersection that Cursor, Claude Code, and OpenCode accept.
There is no repo-root subagents path either. Agents are left out of the Codex
mirror and the Codex home sync rather than written in a format Codex cannot read.

### Marketplace — added (`.agents/plugins/marketplace.json` + `.codex-plugin/`)

Codex reads a repository marketplace from `$REPO_ROOT/.agents/plugins/
marketplace.json` and a personal one from `~/.agents/plugins/marketplace.json`.
A plugin source needs a `.codex-plugin/plugin.json`. The catalog's `source`
paths are repo-root-relative (`./ai-coding/plugins/<name>`), matching the
existing Cursor and Claude catalogs and the "repo root is the marketplace root"
model that `scripts/sync-coding-tools.sh` already relies on. The catalog schema
mirrors those two catalogs.

## Sync targets

- `make mirrors` / `make mirrors-check` — regenerate or drift-check
  `.agents/skills/` alongside the other mirrors.
- `make sync-codex` (or `./scripts/sync-coding-tools.sh --targets codex`) —
  copy skills to `~/.agents/skills/` and the marketplace bundle to
  `~/.agents/plugins/yliapis-dotfiles/`. Commands and agents are skipped with a
  printed reason.

## Sources

- Skills: <https://developers.openai.com/codex/skills>
- Custom prompts (deprecated): <https://developers.openai.com/codex/custom-prompts>
- Project-scoped prompts feature request: <https://github.com/openai/codex/issues/9848>
- Subagents (TOML, home-only): <https://developers.openai.com/codex/subagents>
- Plugin marketplace: <https://developers.openai.com/codex/plugins/build>
