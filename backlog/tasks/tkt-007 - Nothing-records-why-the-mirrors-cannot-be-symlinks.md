---
id: TKT-007
title: Nothing records why the mirrors cannot be symlinks
status: Done
assignee: []
created_date: '2026-07-26 18:12'
updated_date: '2026-07-26 21:54'
labels:
  - 'estimate:S'
  - readme-md
  - skill-auto-attach-2026-07-26
dependencies:
  - TKT-001
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:114-124'
priority: low
type: docs
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing records why the mirrors cannot be symlinks @ `README.md`; without the constraint written down, the next maintainer who prefers live edits reverts the layout and silently turns skill discovery off again.

### Context and Evidence

Skill auto-attach; Findings

- `AGENTS.md` describes the mirrors as flattened per-item symlink mirrors and gives no indication that a discovery path may skip them. (docs/reports/skill-auto-attach-2026-07-26.md:114-124)
- `README.md` documents `make help` and the cloud bootstrap but never mentions the project mirrors, so a reader cannot learn the layout from it. (docs/reports/skill-auto-attach-2026-07-26.md:114-124)

### Scope

#### In Scope

- README.md
- AGENTS.md

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Both files state the mirror layout, the regeneration command, and the drift-check command
- [x] #2 Both files state that a symlinked mirror entry is skipped by at least one discovery implementation, and name the escape hatch for a maintainer who wants live edits
<!-- AC:END -->
