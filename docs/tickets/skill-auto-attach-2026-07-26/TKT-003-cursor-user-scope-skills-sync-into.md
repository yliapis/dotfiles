---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-003"
fingerprint: "sha256:ea32bbb8ee7eb15c2457ca03c11289b3520eb9f92a5ca0a16f93d5c7190504c9"
title: "Cursor user-scope skills sync into the builtin skill root"
status: "open"
status_reason: null
owner: null
revision: 1
type: "fix"
severity: "major"
priority: "P1"
estimate: "XS"
labels:
  - "cursor-user-scope-skills-sync-into-the-builtin-skill-root"
  - "scripts"
  - "skill-auto-attach-2026-07-26"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:67-76"
dependencies: []
extensions: {}
---

# TKT-003: Cursor user-scope skills sync into the builtin skill root

## Summary

Cursor user-scope skills sync into the builtin skill root @ `scripts/sync-coding-tools.sh`; a global sync writes this repository's skills into a root the client treats as its own builtin content instead of registering them as user skills.

## Context and Evidence

Skill auto-attach; Findings; this target is what makes the skills available outside this repository, so the destination decides whether they appear in every other project.

- `dest_skills_dir` returns `$HOME/.cursor/skills-cursor` for the cursor target. (docs/reports/skill-auto-attach-2026-07-26.md:67-76)
- The shipped bundle registers `~/.cursor/skills-cursor` with `scope: "builtin"` and `source: "builtin"`, and registers `~/.cursor/skills` with `scope: "user"`. (docs/reports/skill-auto-attach-2026-07-26.md:67-76)

## Scope

### In Scope

- scripts/sync-coding-tools.sh

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [ ] A cursor-target sync writes each skill to `~/.cursor/skills/<name>/SKILL.md`
- [ ] The script records why `~/.cursor/skills-cursor` is not a destination so the value is not reverted later

## Dependencies

None.

## Open Questions

_None._
