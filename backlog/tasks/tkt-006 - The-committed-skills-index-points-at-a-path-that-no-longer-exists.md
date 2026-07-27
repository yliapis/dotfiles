---
id: TKT-006
title: The committed skills index points at a path that no longer exists
status: Done
assignee: []
created_date: '2026-07-26 18:12'
updated_date: '2026-07-26 21:54'
labels:
  - ai-coding
  - 'estimate:S'
  - skill-auto-attach-2026-07-26
dependencies: []
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:103-112'
priority: low
type: docs
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The committed skills index points at a path that no longer exists @ `ai-coding/indexes/skills-2026-07-12.md`; a hand-dated census rots whenever a skill is added or a plugin is split, and this one has already missed three skills and one directory move.

### Context and Evidence

Skill auto-attach; Findings; the index describes itself as the parameter surface that de-slop commands enumerate, so the stale paths are consumed by tooling rather than read only by people.

- The index names `ai-coding/skills/` as its source root and lists 12 skills, while skills live under `ai-coding/plugins/*/skills/` and number 15. (docs/reports/skill-auto-attach-2026-07-26.md:103-112)
- Every row of its path list, such as `ai-coding/skills/stop-slop/SKILL.md`, resolves to no file. (docs/reports/skill-auto-attach-2026-07-26.md:103-112)

### Scope

#### In Scope

- ai-coding/indexes/skills-2026-07-12.md

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 An index lists all 15 skills at their current `ai-coding/plugins/*/skills/<name>/SKILL.md` paths
- [x] #2 The index is produced by a committed target, or is deleted in favour of a command that enumerates the skills directly
<!-- AC:END -->
