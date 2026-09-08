---
id: TKT-021
title: Shrink new mirrors to .agents/skills only
status: Done
assignee:
  - '@cursor-agent'
created_date: '2026-09-08 01:55'
updated_date: '2026-09-08 01:58'
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
- [x] #1 make mirrors writes only .agents/skills/ as a byte-identical non-symlink copy of plugin skills, and does not create .agents/commands, .agents/agents, or any .codex/ tree
- [x] #2 make mirrors-check prunes leftover .agents/commands, .agents/agents, and .codex/{commands,skills,agents}
- [x] #3 .gitattributes marks only .agents/skills/** linguist-generated among the new trees
- [x] #4 scripts/sync-coding-tools.sh agents target syncs only ~/.agents/skills; the codex target and SYNC_CODING_TOOLS_CODEX_HOME are gone; Makefile has make sync-agents and no make sync-codex
- [x] #5 AGENTS.md and README.md describe .agents/skills as the supported Codex and cross-platform skill root, and do not present .codex/ as a generated mirror
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Limit the agents tool to skills in both scripts; remove the codex tool and SYNC_CODING_TOOLS_CODEX_HOME.
2. Prune leftover .agents/{commands,agents} and .codex/{commands,skills,agents}.
3. Drop unused gitattributes, Makefile sync-codex, and .codex docs.
4. Keep the Codex marketplace absence recorded for TKT-020.
5. Verify with make mirrors, mirrors-check, shellcheck, zsh -n, and isolated home sync.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification (cloud VM, 2026-09-08):

- .agents contains only skills/ (17 entries). .codex is absent. find .agents -type l: empty. cmp of every skill vs ai-coding/plugins/: fail=0.
- Leftover .agents/commands and .codex/skills: --check exits 1 and reports prune; write mode removes them; follow-up mirrors-check matches.
- git check-attr linguist-generated: true on .agents/skills; unspecified on stale .agents/commands and .codex paths.
- Isolated home sync --targets agents writes only ~/.agents/skills (17); no commands/agents/plugins. --targets codex exits 2. make help has sync-agents, no sync-codex.
- shellcheck 0; zsh -n 0; skills-index-check 17; commands-index-check 11; in_sync=106.

Logs: /opt/cursor/artifacts/shrink-lint-checks.log, /opt/cursor/artifacts/shrink-home-and-prune.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Generated mirrors for the new trees are .agents/skills only. .codex/ is not generated. Home-dir sync for agents writes ~/.agents/skills. Codex marketplace remains tkt-020.
<!-- SECTION:FINAL_SUMMARY:END -->
