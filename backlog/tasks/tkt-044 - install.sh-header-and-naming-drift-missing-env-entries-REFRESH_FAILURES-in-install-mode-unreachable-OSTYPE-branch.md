---
id: TKT-044
title: >-
  install.sh header and naming drift: missing env entries, REFRESH_FAILURES in
  install mode, unreachable OSTYPE branch
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
updated_date: '2026-09-08 21:40'
labels:
  - install
  - 'estimate:XS'
  - critique-opus-2026-08-16
dependencies:
  - TKT-025
references:
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:198-199
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:204-205
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:216-217
  - 'install.sh:1-60'
  - 'install.sh:85'
  - 'install.sh:152-155'
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:225
priority: low
type: chore
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 50-line header is the only user-facing documentation of the script's knobs, and it has drifted from the body in several small ways. Bundle these after the entry-point decision lands so the header is rewritten once.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:69` exports `HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1` with an eight-line justification, but the header env block (`:28-49`) does not list it.
- `BREW_BUNDLE_MAS` is the only documented variable missing from the `${VAR:-...}` normalization block (`:53-60`); it is read unset at `:265` and `:367`, fatal under `nounset`.
- `REFRESH_FAILURES` (`:85`) accumulates failures for both modes; `:325` prints "install finished with failures" from it.
- `:152-155` the `OSTYPE` empty branch is unreachable (zsh and bash always set it) and its remedy says "try sourcing this script".
- The mode summary (`:15-20`) omits `upgrade_apt`, `ensure_curl`, `ensure_tilix`, and `disable_brew_analytics`, which mutates a global brew setting on every run; nothing states that zsh must already exist for the script to run.

### Provenance

Opus bootstrap critique 2026-08-16 (minor 3/5, nit 5/5 and 4/5, divergent 1/5).

### Scope

- `install.sh` header comment, variable names, `detect_platform`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The header env block lists every variable the script reads or exports, and every read variable has a normalized default
- [ ] #2 The failure accumulator has a mode-neutral name and the summaries print the right mode
- [ ] #3 The unreachable OSTYPE branch is removed or its message no longer recommends sourcing
- [ ] #4 The mode summary lists every side effect of each mode and states the zsh prerequisite
- [ ] #5 The header (or README) states the supported platform and shell matrix
<!-- AC:END -->
