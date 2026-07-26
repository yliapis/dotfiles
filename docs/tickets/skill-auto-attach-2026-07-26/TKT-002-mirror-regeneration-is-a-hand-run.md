---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-002"
fingerprint: "sha256:9a4df599cfa3ac5832b7b266cd2915c541609cae6166b03d63473ecbd8772db8"
title: "Mirror regeneration is a hand-run loop with no prune or drift check"
status: "open"
status_reason: null
owner: null
revision: 1
type: "feat"
severity: "major"
priority: "P1"
estimate: "M"
labels:
  - "agents-md"
  - "mirror-regeneration-is-a-hand-run-loop-with-no-prune-or-drift-check"
  - "skill-auto-attach-2026-07-26"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:51-65"
dependencies: []
extensions: {}
---

# TKT-002: Mirror regeneration is a hand-run loop with no prune or drift check

## Summary

Mirror regeneration is a hand-run loop with no prune or drift check @ `AGENTS.md`; a mirror layout that only a pasted loop can reproduce cannot be verified in review, and that layout is what skill discovery depends on.

## Context and Evidence

Skill auto-attach; Findings; flattening means one name may be claimed by only one plugin, and nothing currently detects a collision between two plugins.

- `AGENTS.md` asks the maintainer to paste a three-tool `for` loop over `ai-coding/plugins/*/{commands,skills,agents}` to rebuild all nine mirrors. (docs/reports/skill-auto-attach-2026-07-26.md:51-65)
- The same section says to remove leftover symlinks for deleted artifacts by hand, so a renamed or deleted skill leaves a stale mirror entry until someone notices. (docs/reports/skill-auto-attach-2026-07-26.md:51-65)
- No target, script, or check reports whether the mirrors currently match `ai-coding/plugins/`, so drift stays invisible until an agent silently misses a skill. (docs/reports/skill-auto-attach-2026-07-26.md:51-65)

## Scope

### In Scope

- AGENTS.md
- Makefile
- scripts/

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [ ] One committed script regenerates all nine mirrors from `ai-coding/plugins/` and is reachable from a `make` target
- [ ] The script prunes mirror entries whose source no longer exists
- [ ] The script exits non-zero with an explanatory message when two plugins claim the same flattened name
- [ ] A no-write check mode exits non-zero when any mirror has drifted from its source and is reachable from a `make` target
- [ ] The script runs on a VM that has neither zsh nor rsync installed

## Dependencies

None.

## Open Questions

_None._
