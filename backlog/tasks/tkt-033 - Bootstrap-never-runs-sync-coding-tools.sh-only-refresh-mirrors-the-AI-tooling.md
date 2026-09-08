---
id: TKT-033
title: Bootstrap never runs sync-coding-tools.sh; only refresh mirrors the AI tooling
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - install
  - sync
  - 'estimate:XS'
  - critique-composer-2026-07-12
dependencies: []
references:
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:62-65
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:146
  - 'install.sh:284-287'
  - 'install.sh:307-330'
  - 'AGENTS.md:5-7'
priority: medium
type: feat
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`AGENTS.md` describes the deliverable as shell scripts that install dotfiles and mirror `ai-coding/` commands, skills, and agents into the Cursor, Claude, OpenCode, and `.agents` home locations. `do_bootstrap` never calls `sync_coding_tools`; only `do_refresh` does. A fresh `./install.sh` or `make install` therefore leaves every home-dir mirror empty until the user discovers `make sync` or `make refresh`.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:284-287` defines `sync_coding_tools`; the only call is `install.sh:347` inside `do_refresh`.
- `install.sh:307-330` `do_bootstrap` step list has no sync step; the header mode summary (`:16-18`) does not mention one.
- `Makefile:40-41` `install` target runs `./install.sh` only.

### Provenance

Composer swarm 2026-07-12 (major, 2/10: "documented setup contract is incomplete for a fresh install"; minor: "make install does not chain sync").

### Scope

- `install.sh` `do_bootstrap` and header; optionally `Makefile` `install` help text.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A fresh ./install.sh (install mode) runs scripts/sync-coding-tools.sh after copy_home_config, through run_step
- [ ] #2 The header mode summary lists the sync step
- [ ] #3 make help text for install reflects that the home-dir mirrors are populated
<!-- AC:END -->
