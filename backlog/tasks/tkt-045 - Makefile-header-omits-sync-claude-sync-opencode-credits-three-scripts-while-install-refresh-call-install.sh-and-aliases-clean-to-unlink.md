---
id: TKT-045
title: >-
  Makefile header omits sync-claude/sync-opencode, credits three scripts while
  install/refresh call install.sh, and aliases clean to unlink
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - makefile
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:220-224
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:194-195
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:215
  - 'Makefile:1-23'
  - 'Makefile:98'
priority: low
type: docs
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The header enumerates the target set but leaves out two real `.PHONY` targets, says "Three scripts do the work" while the first two targets it lists run a fourth script (`./install.sh`, the only one that writes to `$HOME` and invokes `sudo`), and `clean: unlink` inverts the universal meaning of `clean` (it deletes synced files from `$HOME`, not build artifacts from the repo).

### Evidence (main @ 225cbf2, 2026-09-08)

- `Makefile:1-7` lists targets; `sync-claude` (`:62`) and `sync-opencode` (`:65`) are absent.
- `Makefile:9-23` "Three scripts do the work" vs `:40-44` `install` / `refresh` recipes.
- `Makefile:98` `clean: unlink   ## Alias for make unlink`.

### Provenance

Fable 2026-07-12 (nit), Opus 2026-08-16 (minor 5/5 and 4/5; divergent 2/5).

### Scope

- `Makefile` header comment and the `clean` target.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The header either lists every target or defers to make help instead of enumerating
- [ ] #2 The header names install.sh among the scripts the targets invoke
- [ ] #3 clean is removed, renamed, or its help string states that it removes synced files from $HOME
<!-- AC:END -->
