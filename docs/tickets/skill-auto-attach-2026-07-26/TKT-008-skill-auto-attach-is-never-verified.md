---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-008"
fingerprint: "sha256:7ef701ac247748230544fbf9b5febfe0dd3aa5d6d80a65392ac3d68971e66e0c"
title: "Skill auto-attach is never verified against a real client"
status: "open"
status_reason: null
owner: null
revision: 1
type: "test"
severity: "minor"
priority: "P2"
estimate: "S"
labels:
  - "docs"
  - "skill-auto-attach-2026-07-26"
  - "skill-auto-attach-is-never-verified-against-a-real-client"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:126-136"
dependencies:
  - "TKT-001"
extensions: {}
---

# TKT-008: Skill auto-attach is never verified against a real client

## Summary

Skill auto-attach is never verified against a real client @ `docs/`; a layout change justified by client behaviour stays unproven until a client is observed listing the skills, and the repository has no recorded procedure for checking that.

## Context and Evidence

Skill auto-attach; Findings; the repository ships skills for three separate clients, and only one of them was examined at all.

- The only evidence gathered so far is filesystem shape plus inspection of the shipped bundle, and no client was observed listing the skills. (docs/reports/skill-auto-attach-2026-07-26.md:126-136)
- Every `cursor-agent` command that would enumerate discovery returned `Error: Authentication required. Run 'agent login', pass --api-key/--auth-token, or set CURSOR_API_KEY/CURSOR_AUTH_TOKEN.` on the cloud VM. (docs/reports/skill-auto-attach-2026-07-26.md:126-136)

## Scope

### In Scope

- docs/

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [ ] A committed procedure states how to confirm a client lists all 15 skills
- [ ] One recorded observation shows a client listing them, from the Cursor skills panel or from a fresh cloud agent run that reports its skill list

## Dependencies

- TKT-001

## Open Questions

_None._
