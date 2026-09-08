---
id: TKT-021
title: Shrink new mirrors to .agents/skills only
status: In Progress
assignee:
  - '@cursor-agent'
created_date: '2026-09-08 01:55'
updated_date: '2026-09-08 01:55'
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
priority: medium
type: feat
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Drop the deprecated .codex/ mirror and stop emitting .agents/commands and .agents/agents. Official Codex and cross-platform discovery is .agents/skills (repo) and $HOME/.agents/skills (user). $CODEX_HOME/skills is a deprecated compatibility location.

### Scope

In Scope: scripts/sync-project-mirrors.sh, scripts/sync-coding-tools.sh, Makefile, .gitattributes, AGENTS.md, README.md, generated .agents/ and removal of .codex/.

Out of Scope: ~/.codex/prompts; inventing a Codex marketplace; live Codex client observation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 make mirrors writes only .agents/skills/ as a byte-identical non-symlink copy of plugin skills, and does not create .agents/commands, .agents/agents, or any .codex/ tree
- [ ] #2 make mirrors-check prunes leftover .agents/commands, .agents/agents, and .codex/{commands,skills,agents}
- [ ] #3 .gitattributes marks only .agents/skills/** linguist-generated among the new trees
- [ ] #4 scripts/sync-coding-tools.sh agents target syncs only ~/.agents/skills; the codex target and SYNC_CODING_TOOLS_CODEX_HOME are gone; Makefile has make sync-agents and no make sync-codex
- [ ] #5 AGENTS.md and README.md describe .agents/skills as the supported Codex and cross-platform skill root, and do not present .codex/ as a generated mirror
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Limit the agents tool to skills in both scripts; remove the codex tool and SYNC_CODING_TOOLS_CODEX_HOME.
2. Prune leftover .agents/{commands,agents} and .codex/{commands,skills,agents}.
3. Drop unused gitattributes, Makefile sync-codex, and .codex docs.
4. Keep the Codex marketplace absence recorded for TKT-020.
5. Verify with make mirrors, mirrors-check, shellcheck, zsh -n, and isolated home sync.
<!-- SECTION:PLAN:END -->
