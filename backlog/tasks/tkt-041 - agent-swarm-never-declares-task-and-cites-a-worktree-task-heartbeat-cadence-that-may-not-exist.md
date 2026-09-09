---
id: TKT-041
title: >-
  agent-swarm never declares {task} and cites a worktree-task heartbeat cadence
  that may not exist
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - ai-coding
  - orchestration
  - 'estimate:XS'
  - critique-composer-2026-07-12
dependencies: []
references:
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:114-117
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:159
  - 'ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md:15-32'
  - 'ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md:214'
  - 'ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md:387'
  - 'ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md:404'
priority: medium
type: docs
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The `agent-swarm` Parameters section lists fifteen knobs but not `{task}`, the primary work payload, while the Topology Catalog and Workflow pass "the verbatim `{task}`" to every member. The Events table describes `member.progress` as a heartbeat "per `worktree-task`'s reporting cadence"; verify that `worktree-task` defines such a cadence, and drop or define the reference if it does not.

### Evidence (main @ 225cbf2, 2026-09-08)

- `agent-swarm/SKILL.md:15-32` Parameters: no `{task}` entry.
- `agent-swarm/SKILL.md:214` and `:404` pass "verbatim `{task}`" to members.
- `agent-swarm/SKILL.md:387` `member.progress` row cites `worktree-task`'s reporting cadence.
- The related per-partition `{agent_model}` mismatch from the same report is fixed: `worktree-task/SKILL.md:20-27` now accepts a partition-sized slice.

### Provenance

Composer swarm 2026-07-12 (major, 2/10; nit 1/10).

### Scope

- `ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md`, possibly `worktree-task/SKILL.md`; regenerate mirrors and indexes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 {task} is declared in agent-swarm Parameters with required/optional status, accepted forms, and how it is forwarded per topology
- [ ] #2 The member.progress heartbeat either references a cadence defined in worktree-task/SKILL.md or the reference is removed
- [ ] #3 make mirrors-check and make skills-index-check pass after the edit
<!-- AC:END -->
