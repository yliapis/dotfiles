---
id: TKT-019
title: Mirror canonical AI resources into .agents and .codex
status: Done
assignee:
  - '@cursor-agent'
created_date: '2026-09-08 01:47'
updated_date: '2026-09-08 01:50'
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
- [x] #1 Research records that .agents/ is the cross-platform Agent Skills tree (Codex official repo/user skill root) and .codex/ is the OpenAI Codex home/compat tree
- [x] #2 make mirrors writes byte-identical non-symlink copies of every command, skill, and agent into .agents/{commands,skills,agents} and .codex/{commands,skills,agents}
- [x] #3 make mirrors-check covers the new trees, prunes stale entries, and aborts on a flattened-name collision
- [x] #4 .gitattributes marks .agents and .codex command/skill/agent mirrors linguist-generated like the other AI capability folders
- [x] #5 scripts/sync-coding-tools.sh accepts agents and codex targets (defaults ~/.agents and ~/.codex) and Makefile exposes make sync-agents and make sync-codex
- [x] #6 AGENTS.md and README.md describe the new trees, home-dir sync roots, and that Codex has no plugin marketplace equivalent
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add agents and codex to sync-project-mirrors.sh TOOLS and docs comments.
2. Add agents and codex home-dir targets to sync-coding-tools.sh and Makefile.
3. Mark new mirrors linguist-generated in .gitattributes.
4. Document researched paths in AGENTS.md and README.md.
5. Run make mirrors and verify with mirrors-check, shellcheck, zsh -n, and isolated home sync.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification (cloud VM, 2026-09-08):

- Official Codex docs: repo skills at .agents/skills (CWD up to repo root); user skills at $HOME/.agents/skills. $CODEX_HOME/skills (~/.codex/skills) is deprecated compatibility. Cursor skill-discovery also enumerates .agents/skills and .codex/skills. Codex has no repo-root commands/ or agents/ discovery; custom prompts (deprecated) are ~/.codex/prompts (user-only). Recorded in AGENTS.md and README.md.
- make mirrors: created=58 for .agents/.codex (11 commands + 17 skills + 1 agent each). find .agents .codex -type l prints nothing. cmp of every command/skill/agent vs ai-coding/plugins/ : fail=0.
- make mirrors-check: in_sync=147. Stale .agents/commands/stale-prune-test.md : check exits 1 and reports prune. Collision abort remains the existing flattened-name check (same source list for all tools).
- git check-attr linguist-generated: true on .agents and .codex command/skill/agent files; unspecified on .cursor/environment.json and .claude/settings.json.
- Isolated home sync: SYNC_CODING_TOOLS_AGENTS_HOME=/tmp/sync-agents-codex.Gn3V3a/agents-home SYNC_CODING_TOOLS_CODEX_HOME=.../codex-home ./scripts/sync-coding-tools.sh --targets agents,codex wrote 11/17/1 each; plugin dest skipped. make sync-agents and make sync-codex honor those env roots. Unknown target nope exits 2.
- shellcheck scripts/sync-project-mirrors.sh: 0. zsh -n scripts/sync-coding-tools.sh: 0. make skills-index-check: 17. make commands-index-check: 11.

Logs: /opt/cursor/artifacts/mirrors-lint-checks.log, /opt/cursor/artifacts/byte-identity-gitattributes.log, /opt/cursor/artifacts/home-sync-and-prune.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
.agents/ and .codex/ now receive the same flattened command/skill/agent copies as .cursor/, .claude/, and .opencode/. Home-dir sync gained agents (~/.agents) and codex (~/.codex) targets. Mirrors are linguist-generated. Codex still has no plugin marketplace; live Codex listing remains TKT-009.
<!-- SECTION:FINAL_SUMMARY:END -->
