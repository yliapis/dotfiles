---
id: TKT-019
title: Mirror canonical AI resources into .agents and .codex
status: In Progress
assignee:
  - '@cursor-agent'
created_date: '2026-09-08 01:47'
updated_date: '2026-09-08 01:47'
labels:
  - mirrors
  - agents
  - codex
  - ai-coding
dependencies: []
references:
  - scripts/sync-project-mirrors.sh
  - scripts/sync-coding-tools.sh
  - .gitattributes
  - 'https://developers.openai.com/codex/skills'
priority: medium
type: feat
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Copy canonical ai-coding plugin resources into .agents/ and .codex/ the same way .cursor/, .claude/, and .opencode/ already work.

### Context

.agents/ is the vendor-neutral Agent Skills tree. Codex reads repo skills from .agents/skills (CWD up to repo root) and user skills from $HOME/.agents/skills. Cursor skill-discovery also enumerates .agents/skills.

.codex/ is the OpenAI Codex home (CODEX_HOME, default ~/.codex). Official repo skills are .agents/skills; $CODEX_HOME/skills is a deprecated compatibility location. Some clients still scan .codex/skills. Codex has no repo-root commands/ or agents/ discovery equivalent to Cursor/Claude/OpenCode; custom prompts (deprecated) live in ~/.codex/prompts (user-only). Trees still emit commands/ and agents/ for parity with the other AI capability folders.

### Scope

In Scope: scripts/sync-project-mirrors.sh, scripts/sync-coding-tools.sh, Makefile, .gitattributes, AGENTS.md, README.md, generated .agents/ and .codex/ mirrors.

Out of Scope: live Codex client observation; inventing a Codex plugin marketplace; mapping commands to ~/.codex/prompts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Research records that .agents/ is the cross-platform Agent Skills tree (Codex official repo/user skill root) and .codex/ is the OpenAI Codex home/compat tree
- [ ] #2 make mirrors writes byte-identical non-symlink copies of every command, skill, and agent into .agents/{commands,skills,agents} and .codex/{commands,skills,agents}
- [ ] #3 make mirrors-check covers the new trees, prunes stale entries, and aborts on a flattened-name collision
- [ ] #4 .gitattributes marks .agents and .codex command/skill/agent mirrors linguist-generated like the other AI capability folders
- [ ] #5 scripts/sync-coding-tools.sh accepts agents and codex targets (defaults ~/.agents and ~/.codex) and Makefile exposes make sync-agents and make sync-codex
- [ ] #6 AGENTS.md and README.md describe the new trees, home-dir sync roots, and that Codex has no plugin marketplace equivalent
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add agents and codex to sync-project-mirrors.sh TOOLS and docs comments.
2. Add agents and codex home-dir targets to sync-coding-tools.sh and Makefile.
3. Mark new mirrors linguist-generated in .gitattributes.
4. Document researched paths in AGENTS.md and README.md.
5. Run make mirrors and verify with mirrors-check, shellcheck, zsh -n, and isolated home sync.
<!-- SECTION:PLAN:END -->
