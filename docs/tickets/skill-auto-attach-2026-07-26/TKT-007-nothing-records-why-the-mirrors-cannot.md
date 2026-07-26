---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-007"
fingerprint: "sha256:028d8176f79686c8929ef346c30daff5180a9311c2f1dd45f06f9135b421b33f"
title: "Nothing records why the mirrors cannot be symlinks"
status: "done"
status_reason: null
owner: null
revision: 3
type: "docs"
severity: "minor"
priority: "P2"
estimate: "S"
labels:
  - "nothing-records-why-the-mirrors-cannot-be-symlinks"
  - "readme-md"
  - "skill-auto-attach-2026-07-26"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:114-124"
dependencies:
  - "TKT-001"
extensions: {}
---

# TKT-007: Nothing records why the mirrors cannot be symlinks

## Summary

Nothing records why the mirrors cannot be symlinks @ `README.md`; without the constraint written down, the next maintainer who prefers live edits reverts the layout and silently turns skill discovery off again.

## Context and Evidence

Skill auto-attach; Findings

- `AGENTS.md` describes the mirrors as flattened per-item symlink mirrors and gives no indication that a discovery path may skip them. (docs/reports/skill-auto-attach-2026-07-26.md:114-124)
- `README.md` documents `make help` and the cloud bootstrap but never mentions the project mirrors, so a reader cannot learn the layout from it. (docs/reports/skill-auto-attach-2026-07-26.md:114-124)

## Scope

### In Scope

- README.md
- AGENTS.md

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [x] Both files state the mirror layout, the regeneration command, and the drift-check command
- [x] Both files state that a symlinked mirror entry is skipped by at least one discovery implementation, and name the escape hatch for a maintainer who wants live edits

## Dependencies

- TKT-001

## Open Questions

_None._
