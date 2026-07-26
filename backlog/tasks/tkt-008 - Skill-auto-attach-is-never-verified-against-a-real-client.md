---
id: TKT-008
title: Skill auto-attach is never verified against a real client
status: To Do
assignee: []
created_date: '2026-07-26 18:12'
labels:
  - docs
  - 'estimate:S'
  - skill-auto-attach-2026-07-26
dependencies:
  - TKT-001
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:126-136'
priority: low
type: test
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Skill auto-attach is never verified against a real client @ `docs/`; a layout change justified by client behaviour stays unproven until a client is observed listing the skills, and the repository has no recorded procedure for checking that.

### Context and Evidence

Skill auto-attach; Findings; the repository ships skills for three separate clients, and only one of them was examined at all.

- The only evidence gathered so far is filesystem shape plus inspection of the shipped bundle, and no client was observed listing the skills. (docs/reports/skill-auto-attach-2026-07-26.md:126-136)
- Every `cursor-agent` command that would enumerate discovery returned `Error: Authentication required. Run 'agent login', pass --api-key/--auth-token, or set CURSOR_API_KEY/CURSOR_AUTH_TOKEN.` on the cloud VM. (docs/reports/skill-auto-attach-2026-07-26.md:126-136)

### Scope

#### In Scope

- docs/

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A committed procedure states how to confirm a client lists all 15 skills
- [ ] #2 One recorded observation shows a client listing them, from the Cursor skills panel or from a fresh cloud agent run that reports its skill list
<!-- AC:END -->
