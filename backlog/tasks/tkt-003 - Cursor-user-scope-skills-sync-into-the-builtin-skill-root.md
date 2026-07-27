---
id: TKT-003
title: Cursor user-scope skills sync into the builtin skill root
status: Done
assignee: []
created_date: '2026-07-26 18:12'
updated_date: '2026-07-26 19:38'
labels:
  - 'estimate:XS'
  - scripts
  - skill-auto-attach-2026-07-26
dependencies: []
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:67-76'
priority: medium
type: fix
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Cursor user-scope skills sync into the builtin skill root @ `scripts/sync-coding-tools.sh`; a global sync writes this repository's skills into a root the client treats as its own builtin content instead of registering them as user skills.

### Context and Evidence

Skill auto-attach; Findings; this target is what makes the skills available outside this repository, so the destination decides whether they appear in every other project.

- `dest_skills_dir` returns `$HOME/.cursor/skills-cursor` for the cursor target. (docs/reports/skill-auto-attach-2026-07-26.md:67-76)
- The shipped bundle registers `~/.cursor/skills-cursor` with `scope: "builtin"` and `source: "builtin"`, and registers `~/.cursor/skills` with `scope: "user"`. (docs/reports/skill-auto-attach-2026-07-26.md:67-76)

### Scope

#### In Scope

- scripts/sync-coding-tools.sh

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A cursor-target sync writes each skill to `~/.cursor/skills/<name>/SKILL.md`
- [x] #2 The script records why `~/.cursor/skills-cursor` is not a destination so the value is not reverted later
<!-- AC:END -->
