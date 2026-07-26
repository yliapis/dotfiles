---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-001"
fingerprint: "sha256:b8484de418d21a7644e23a3d6cf477a877c2cba131d5a290275300be44f19c23"
title: "Project skill mirrors depend on symlink resolution"
status: "done"
status_reason: null
owner: null
revision: 3
type: "fix"
severity: "critical"
priority: "P0"
estimate: "M"
labels:
  - "cursor"
  - "project-skill-mirrors-depend-on-symlink-resolution"
  - "skill-auto-attach-2026-07-26"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:36-49"
dependencies:
  - "TKT-002"
extensions: {}
---

# TKT-001: Project skill mirrors depend on symlink resolution

## Summary

Project skill mirrors depend on symlink resolution @ `.cursor/skills/`; one shipped discovery implementation keeps a symlinked skill directory and another drops any link whose real path leaves the scanned directory, so whether a skill reaches the agent depends on which implementation the client runs.

## Context and Evidence

Skill auto-attach; Findings; the same layout covers commands and agents, so a discovery path that skips links skips all 75 mirror entries rather than skills alone.

- `git ls-files -s .cursor/skills` reports mode `120000` for all 15 entries, each pointing at `../../ai-coding/plugins/<plugin>/skills/<name>`. (docs/reports/skill-auto-attach-2026-07-26.md:36-49)
- `realpath .cursor/skills/stop-slop` resolves to `/workspace/ai-coding/plugins/writing/skills/stop-slop`, outside `/workspace/.cursor/skills`, so every mirror link leaves the directory a scanner would walk. (docs/reports/skill-auto-attach-2026-07-26.md:36-49)
- The cloud agent run on this layout was offered zero of the 15 skills while its context still carried `AGENTS.md`, so the transport that delivers repository instructions worked while skill delivery did not. (docs/reports/skill-auto-attach-2026-07-26.md:36-49)

## Scope

### In Scope

- .cursor/skills/
- .claude/skills/
- .opencode/skills/
- .cursor/commands/
- .cursor/agents/

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [x] No entry under any of the nine repo-root mirrors is a symlink, and `find .cursor .claude .opencode -maxdepth 2 -type l` prints nothing
- [x] Each mirrored skill directory is byte-identical to its `ai-coding/plugins/*/skills/<name>` source
- [x] `ai-coding/plugins/` remains the only location a maintainer edits

## Dependencies

- TKT-002

## Open Questions

_None._
