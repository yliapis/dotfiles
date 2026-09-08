---
id: TKT-009
title: Add Codex support to ai-coding
status: To Do
assignee: []
created_date: '2026-07-27 01:45'
updated_date: '2026-09-08 01:58'
labels:
  - agents
  - ai-coding
  - codex
  - 'estimate:L'
  - mirrors
  - sync
dependencies: []
references:
  - 'README.md:19-22'
  - 'scripts/sync-project-mirrors.sh:34'
  - 'scripts/sync-coding-tools.sh:131-134'
  - '.cursor-plugin/marketplace.json:5'
  - 'https://developers.openai.com/codex/skills'
priority: low
type: feat
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Codex support to ai-coding @ `ai-coding/`; the marketplace metadata in this repository already names Codex, yet no mirror, sync target, or Makefile target serves it.

### Context and Evidence

Cursor, Claude Code, and OpenCode each have project mirrors and a home-dir sync target; Codex has neither, and its skill roots differ from all three.

- README.md documents `.cursor/`, `.claude/`, and `.opencode/` as the three mirror trees generated from `ai-coding/plugins/`, with no Codex tree. (README.md:19-22)
- `scripts/sync-project-mirrors.sh` hard-codes `TOOLS="cursor claude opencode"`, and `scripts/sync-coding-tools.sh` rejects any `--targets` value outside `cursor|claude|opencode`. (scripts/sync-project-mirrors.sh:34, scripts/sync-coding-tools.sh:131-134)
- Both marketplace manifests describe these plugins as shared across Cursor, Claude Code, OpenCode, and Codex, so the metadata claims support the scripts do not provide. (.cursor-plugin/marketplace.json:5)
- A pre-symlink-era script preserved in the samples tree mapped codex:command to ~/.codex/prompts and codex:skill to ~/.codex/skills, which no longer matches the skill roots Codex documents. (ai-coding/samples/misc-leftovers/dotfiles-pre-symlink-3c99292.diff:17796-17798)
- Codex reads skills from `.agents/skills` walking up to the repository root and from `$HOME/.agents/skills`, treating `$CODEX_HOME/skills` as a deprecated compatibility location. (https://developers.openai.com/codex/skills)

### Scope

#### In Scope

- ai-coding/
- .agents/skills/
- scripts/sync-project-mirrors.sh
- scripts/sync-coding-tools.sh
- Makefile
- AGENTS.md
- README.md

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Research records where Codex reads repo-root commands and agents, and the chosen in-repo paths for them are written down alongside `.agents/skills/`
- [ ] #2 Regenerated mirrors place every skill at `.agents/skills/<name>/` as a byte-identical non-symlink copy of `ai-coding/plugins/*/skills/<name>/`, with commands and agents mirrored to the researched paths
- [ ] #3 One script reachable from `make mirrors` and `make mirrors-check` covers the Codex layout, prunes entries whose source is gone, and aborts on a flattened-name collision
- [ ] #4 A Codex-target run of `scripts/sync-coding-tools.sh` syncs skills, commands, and agents into `~/.agents/`, and `make sync-codex` invokes it
- [ ] #5 Codex plugin or marketplace support is added parallel to `.cursor-plugin` and `.claude-plugin` when Codex offers an equivalent, and the absence is recorded in the repository when it does not
- [ ] #6 `AGENTS.md` and `README.md` describe the Codex mirror layout, its sync targets, and its plugin path or documented absence
- [ ] #7 One recorded observation shows Codex listing the synced skills, plus commands and agents where Codex exposes them, after `make mirrors && make sync-codex`
<!-- AC:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-09-08 01:50
---
TKT-019 landed project mirrors and home-dir sync for .agents/ and .codex/ (commands/skills/agents, gitattributes, make sync-agents / make sync-codex). Remaining on this ticket: live Codex observation (AC7), and any Codex-specific command/agent path that differs from the parity trees (deprecated ~/.codex/prompts; no marketplace).
---

created: 2026-09-08 01:58
---
Follow-up: tkt-021 dropped .codex/ and .agents/{commands,agents}. Supported layout is .agents/skills (repo) and $HOME/.agents/skills (user). make sync-codex is gone; use make sync-agents. Remaining: AC7 live Codex listing of .agents/skills.
---
<!-- COMMENTS:END -->
