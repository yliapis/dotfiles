---
id: TKT-002
title: Mirror regeneration is a hand-run loop with no prune or drift check
status: Done
assignee: []
created_date: '2026-07-26 18:12'
updated_date: '2026-07-26 19:38'
labels:
  - agents-md
  - 'estimate:M'
  - skill-auto-attach-2026-07-26
dependencies: []
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:51-65'
priority: medium
type: feat
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mirror regeneration is a hand-run loop with no prune or drift check @ `AGENTS.md`; a mirror layout that only a pasted loop can reproduce cannot be verified in review, and that layout is what skill discovery depends on.

### Context and Evidence

Skill auto-attach; Findings; flattening means one name may be claimed by only one plugin, and nothing currently detects a collision between two plugins.

- `AGENTS.md` asks the maintainer to paste a three-tool `for` loop over `ai-coding/plugins/*/{commands,skills,agents}` to rebuild all nine mirrors. (docs/reports/skill-auto-attach-2026-07-26.md:51-65)
- The same section says to remove leftover symlinks for deleted artifacts by hand, so a renamed or deleted skill leaves a stale mirror entry until someone notices. (docs/reports/skill-auto-attach-2026-07-26.md:51-65)
- No target, script, or check reports whether the mirrors currently match `ai-coding/plugins/`, so drift stays invisible until an agent silently misses a skill. (docs/reports/skill-auto-attach-2026-07-26.md:51-65)

### Scope

#### In Scope

- AGENTS.md
- Makefile
- scripts/

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 One committed script regenerates all nine mirrors from `ai-coding/plugins/` and is reachable from a `make` target
- [x] #2 The script prunes mirror entries whose source no longer exists
- [x] #3 The script exits non-zero with an explanatory message when two plugins claim the same flattened name
- [x] #4 A no-write check mode exits non-zero when any mirror has drifted from its source and is reachable from a `make` target
- [x] #5 The script runs on a VM that has neither zsh nor rsync installed
<!-- AC:END -->
