---
id: TKT-052
title: >-
  Skill metadata inconsistencies: five skills lack license frontmatter; shared
  timestamp token has two names
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - ai-coding
  - skills
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:230-246
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:160
  - 'ai-coding/plugins/session-state/skills/file-dump/SKILL.md:17-19'
  - 'ai-coding/plugins/session-state/skills/trajectory-snapshot/SKILL.md:14'
priority: low
type: chore
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
### Evidence (main @ 225cbf2, 2026-09-08)

- No `license:` field in: `excalidraw/skills/excalidraw-diagrams`, `flint-chart/skills/flint-chart-author`, `orchestration/skills/worktree-task`, `session-state/skills/trajectory-snapshot`, `writing/skills/stop-slop`. The other twelve skills carry `license: MIT`.
- `file-dump/SKILL.md:17-19` names the UTC timestamp token `{date}` and states it owns the naming convention; `trajectory-snapshot/SKILL.md:14` names the identically defined value `{datetime_timestamp}`.

### Provenance

Fable 2026-07-12 (nits), Composer 2026-07-12 (nit 1/10). The stale marketplace description from the same reports is already fixed.

### Scope

- The five SKILL.md frontmatters and the two session-state skills; regenerate mirrors and the skills index.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every ai-coding/plugins/*/skills/*/SKILL.md frontmatter carries the same license field, or the field is removed from all
- [ ] #2 file-dump and trajectory-snapshot use one token name for the timestamp, with the other documented as an alias or removed
- [ ] #3 make mirrors-check and make skills-index-check pass
<!-- AC:END -->
