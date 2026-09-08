---
id: TKT-032
title: Refresh runs the Brewfile ungated while bootstrap gates it on BREW_BUNDLE
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - install
  - brewfile
  - 'estimate:S'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:162-164
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:130-137
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:66-73
  - 'install.sh:276-282'
  - 'install.sh:337-341'
priority: medium
type: fix
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bootstrap runs the Brewfile only on macOS or when `BREW_BUNDLE=1` (`run_brewfile_if_enabled`), and the header documents that contract. Refresh calls the ungated `run_brewfile` whenever `REFRESH_BREWFILE=1` (the default), so a Linux machine deliberately bootstrapped without the Brewfile receives the entire manifest, and `brew upgrade`, on its first `make refresh`. A Linux host without Homebrew at all records two brew failures per refresh instead of skipping.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:318` `run_step "brew bundle" run_brewfile_if_enabled` (bootstrap) vs `install.sh:339` `run_step "brew bundle" run_brewfile` (refresh).
- `install.sh:30-33` header documents the gate for install only; `:48` `REFRESH_BREWFILE=1` says nothing about the platform gate.
- `install.sh:290-297` `upgrade_brew` and `:254-257` `disable_brew_analytics` have no `command -v brew` guard.

### Provenance

Fable 2026-07-12 (major, then `refresh.sh`), Composer 2026-07-12 (major, 1/10), Opus 2026-08-16 (major, 3/5; call-site asymmetry confirmed by the orchestrator). `refresh.sh` has since been folded into `install.sh --refresh`, and the asymmetry moved with it.

### Scope

- `install.sh` `do_refresh`, `run_brewfile*`, `upgrade_brew`, header lines for `BREW_BUNDLE` and `REFRESH_BREWFILE`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Refresh honors the same macOS-or-BREW_BUNDLE=1 gate as bootstrap before running brew bundle
- [ ] #2 On a host without brew on PATH, refresh skips the brew steps with a message and does not record them as failures
- [ ] #3 The header documents the refresh-mode gate
<!-- AC:END -->
