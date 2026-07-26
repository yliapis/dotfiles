---
id: TKT-005
title: Two sync implementations disagree on the Cursor skills destination
status: Done
assignee: []
created_date: '2026-07-26 18:12'
updated_date: '2026-07-26 19:38'
labels:
  - ai-coding
  - 'estimate:S'
  - skill-auto-attach-2026-07-26
dependencies:
  - TKT-003
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:90-101'
priority: low
type: refactor
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two sync implementations disagree on the Cursor skills destination @ `ai-coding/scripts/sync`; two shipped scripts naming different Cursor skill destinations means the authoritative home layout cannot be settled by reading the repository.

### Context and Evidence

Skill auto-attach; Findings

- `ai-coding/scripts/sync` maps `cursor:skill` to `$HOME/.cursor/skills` while `scripts/sync-coding-tools.sh` maps the same concept to `$HOME/.cursor/skills-cursor`. (docs/reports/skill-auto-attach-2026-07-26.md:90-101)
- No `make` target, README section, or `AGENTS.md` line references `ai-coding/scripts/sync`, while the `Makefile` header calls `scripts/sync-coding-tools.sh` the single source of truth. (docs/reports/skill-auto-attach-2026-07-26.md:90-101)
- `docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md` already recorded this disagreement as unresolved. (docs/reports/skill-auto-attach-2026-07-26.md:90-101)

### Scope

#### In Scope

- ai-coding/scripts/sync
- scripts/sync-coding-tools.sh

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Exactly one sync implementation ships, or the unreferenced one is deleted
- [x] #2 No two files in the repository name different Cursor skill destinations
<!-- AC:END -->
