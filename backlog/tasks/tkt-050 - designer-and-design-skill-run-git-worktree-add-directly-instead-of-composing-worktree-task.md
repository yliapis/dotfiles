---
id: TKT-050
title: >-
  designer and design-skill run git worktree add directly instead of composing
  worktree-task
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - ai-coding
  - design-suite
  - 'estimate:XS'
  - critique-composer-2026-07-12
dependencies: []
references:
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:122-125
  - 'ai-coding/plugins/design-suite/skills/designer/SKILL.md:136'
  - 'ai-coding/plugins/design-suite/skills/design-skill/SKILL.md:67'
priority: low
type: docs
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`agent-swarm` forbids re-implementing worktree mechanics and `artifact-researcher` routes worktree creation through `worktree-task` / `worktree-runner`, but the two design-suite skills issue `git worktree add` themselves. Two orchestration surfaces use opposite strategies for the same side effect.

### Evidence (main @ 225cbf2, 2026-09-08)

- `designer/SKILL.md:136` and `design-skill/SKILL.md:67` "run `git worktree add`".
- `agent-swarm/SKILL.md:54` "MUST NOT re-specify or re-implement worktree mechanics"; `artifact-researcher/SKILL.md` Workflow step 4 delegates.

### Provenance

Composer swarm 2026-07-12 (major, 1/10; then named `designer-controller`).

### Scope

- The two design-suite SKILL.md files; regenerate mirrors.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both skills either delegate worktree creation to worktree-task or document why they own it
- [ ] #2 make mirrors-check passes after the edit
<!-- AC:END -->
