---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-005"
fingerprint: "sha256:ba1fa2096dcdd4b9c0687bf7de21482d8aeb6d68f2fd6e960c1138cd8220ca5e"
title: "Two sync implementations disagree on the Cursor skills destination"
status: "done"
status_reason: null
owner: null
revision: 3
type: "refactor"
severity: "minor"
priority: "P2"
estimate: "S"
labels:
  - "ai-coding"
  - "skill-auto-attach-2026-07-26"
  - "two-sync-implementations-disagree-on-the-cursor-skills-destination"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:90-101"
dependencies:
  - "TKT-003"
extensions: {}
---

# TKT-005: Two sync implementations disagree on the Cursor skills destination

## Summary

Two sync implementations disagree on the Cursor skills destination @ `ai-coding/scripts/sync`; two shipped scripts naming different Cursor skill destinations means the authoritative home layout cannot be settled by reading the repository.

## Context and Evidence

Skill auto-attach; Findings

- `ai-coding/scripts/sync` maps `cursor:skill` to `$HOME/.cursor/skills` while `scripts/sync-coding-tools.sh` maps the same concept to `$HOME/.cursor/skills-cursor`. (docs/reports/skill-auto-attach-2026-07-26.md:90-101)
- No `make` target, README section, or `AGENTS.md` line references `ai-coding/scripts/sync`, while the `Makefile` header calls `scripts/sync-coding-tools.sh` the single source of truth. (docs/reports/skill-auto-attach-2026-07-26.md:90-101)
- `docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md` already recorded this disagreement as unresolved. (docs/reports/skill-auto-attach-2026-07-26.md:90-101)

## Scope

### In Scope

- ai-coding/scripts/sync
- scripts/sync-coding-tools.sh

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [x] Exactly one sync implementation ships, or the unreferenced one is deleted
- [x] No two files in the repository name different Cursor skill destinations

## Dependencies

- TKT-003

## Open Questions

_None._
