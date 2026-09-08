---
id: TKT-053
title: prompts/editorial-standards.md is unreachable from every documented flow
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - docs
  - prompts
  - 'estimate:XS'
  - critique-fable-2026-07-12
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:251-255
  - prompts/editorial-standards.md
priority: low
type: docs
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A 138-line style guide sits at `prompts/editorial-standards.md`, and no command, skill, script, README, or AGENTS.md references it. The only mentions of a `prompts/` path are example values inside generated parameter docs and archived samples, none of which name this file.

### Evidence (main @ 225cbf2, 2026-09-08)

- `rg 'editorial-standards|prompts/'` outside `prompts/`, `docs/reports/`, `ai-coding/samples/`, and `ai-coding/trajectories/` returns only `ai-coding/parameters/generated/**` example paths for other files.

### Provenance

Fable 2026-07-12 (nit).

### Scope

- `prompts/editorial-standards.md` and whichever consumer adopts it (the `writing` plugin is the natural home).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The file is referenced from a command, skill, or README that explains when to apply it, or it is deleted
<!-- AC:END -->
