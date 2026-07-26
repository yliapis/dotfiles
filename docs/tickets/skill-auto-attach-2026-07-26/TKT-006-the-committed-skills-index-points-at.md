---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-006"
fingerprint: "sha256:ee22bc343a7060f4079f4109b498573b5e1a6a914fb80238bd5f4fb4d499f4d4"
title: "The committed skills index points at a path that no longer exists"
status: "done"
status_reason: null
owner: null
revision: 3
type: "docs"
severity: "minor"
priority: "P2"
estimate: "S"
labels:
  - "ai-coding"
  - "skill-auto-attach-2026-07-26"
  - "the-committed-skills-index-points-at-a-path-that-no-longer-exists"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:103-112"
dependencies: []
extensions: {}
---

# TKT-006: The committed skills index points at a path that no longer exists

## Summary

The committed skills index points at a path that no longer exists @ `ai-coding/indexes/skills-2026-07-12.md`; a hand-dated census rots whenever a skill is added or a plugin is split, and this one has already missed three skills and one directory move.

## Context and Evidence

Skill auto-attach; Findings; the index describes itself as the parameter surface that de-slop commands enumerate, so the stale paths are consumed by tooling rather than read only by people.

- The index names `ai-coding/skills/` as its source root and lists 12 skills, while skills live under `ai-coding/plugins/*/skills/` and number 15. (docs/reports/skill-auto-attach-2026-07-26.md:103-112)
- Every row of its path list, such as `ai-coding/skills/stop-slop/SKILL.md`, resolves to no file. (docs/reports/skill-auto-attach-2026-07-26.md:103-112)

## Scope

### In Scope

- ai-coding/indexes/skills-2026-07-12.md

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [x] An index lists all 15 skills at their current `ai-coding/plugins/*/skills/<name>/SKILL.md` paths
- [x] The index is produced by a committed target, or is deleted in favour of a command that enumerates the skills directly

## Dependencies

None.

## Open Questions

_None._
