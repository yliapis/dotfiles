---
id: TKT-038
title: >-
  Home-dir sync flattens plugin names without the collision check the project
  mirrors enforce
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - sync
  - 'estimate:S'
  - critique-kimi-2026-07-26
  - critique-gpt-2026-07-31
dependencies: []
references:
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:36-38
  - >-
    docs/reports/repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z.md:45-49
  - 'scripts/sync-coding-tools.sh:53-56'
  - scripts/sync-project-mirrors.sh
priority: medium
type: fix
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`sync-coding-tools.sh` flattens `*/commands/*.md`, `*/skills/*`, and `*/agents/*.md` from every plugin into one directory per tool with rsync last-write-wins. `sync-project-mirrors.sh` treats the same situation as fatal ("a name may be claimed by only one plugin"). Two plugins shipping one flattened name silently shadow each other in every home-dir install while the repo-root mirrors refuse to build.

### Evidence (main @ 225cbf2, 2026-09-08)

- Reproduced with a temporary duplicate `merge-commit-push.md` under a second plugin: `sync-coding-tools.sh --dry-run --targets cursor` exited 0; `sync-project-mirrors.sh --check` exited 2.
- `scripts/sync-coding-tools.sh:53-56` builds `SRC_COMMANDS`, `SRC_SKILLS`, `SRC_AGENTS` with no duplicate-basename preflight.
- `AGENTS.md` documents the abort rule for the project mirrors only.

### Provenance

Kimi 2026-07-26 (major), GPT 2026-07-31 (medium, remediation step 3).

### Scope

- `scripts/sync-coding-tools.sh` source enumeration; optionally a shared checker both scripts call.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A duplicate flattened command, skill, or agent name across two plugins makes sync-coding-tools.sh exit 2 naming both source paths, before any destination write, in copy, symlink, dry-run, and unlink modes
- [ ] #2 The rule matches sync-project-mirrors.sh (same definition of a collision)
- [ ] #3 make sync on the current tree still succeeds
<!-- AC:END -->
