---
id: TKT-027
title: install.sh argument parser turns any unknown token into the BREW_BUNDLE flag
status: Done
assignee:
  - '@cursor'
created_date: '2026-09-08 19:30'
updated_date: '2026-09-09 23:32'
labels:
  - install
  - 'estimate:S'
  - critique-kimi-2026-07-26
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:132-134
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:213
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:220
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:88-90
  - 'install.sh:71-83'
priority: high
type: fix
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The CLI loop breaks on the first token that is not `--refresh` and assigns whatever it was to `BREW_BUNDLE` with no validation. `./install.sh --help`, any typo of `--refresh`, or a stray positional therefore runs the full destructive bootstrap (`sudo apt-get install tilix`, the Homebrew installer, `cp -af home-config/. $HOME/`) with no usage text and no diagnostic.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:71-81` loop: `--refresh` sets MODE; `*) break`.
- `install.sh:83` `BREW_BUNDLE=${1:-$BREW_BUNDLE}`. Reproduced: with `--help` as the argument the parser leaves `BREW_BUNDLE=--help` and falls through to `do_bootstrap`.
- `./install.sh 1 --refresh` consumes `1` as the flag and never sees `--refresh`, so mode selection is order-dependent.
- `${1:-...}` falls back on empty as well as unset, so `./install.sh ""` cannot clear an inherited `BREW_BUNDLE=1`.
- `MODE` (`install.sh:53`, `:363`) is documented as an enum but never validated; `MODE=Refresh` or a typo silently selects the bootstrap branch.
- When the file is sourced, `$1` is the caller's positional parameter (Kimi, `install.sh:83`).

### Provenance

Opus bootstrap critique 2026-08-16 (critical, 5/5 runs; MODE validation 2/5), Kimi critique 2026-07-26 (nit: positional when sourced). The variable was renamed from GUI_INSTALL to BREW_BUNDLE in #90 without changing the parsing.

### Scope

- `install.sh` argument parsing block (`:71-83`) and header flag documentation (`:22-27`).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ./install.sh --help (and -h) prints usage and exits 0 with no side effects
- [x] #2 An unrecognized option or a positional value other than the documented ones exits non-zero with a message naming the bad token, before any step runs
- [x] #3 --refresh is recognized regardless of its position among the other arguments
- [x] #4 MODE outside install|refresh aborts before any step runs
- [x] #5 The header documents the resulting flag and positional contract
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced the break-on-first-unknown CLI loop and positional BREW_BUNDLE override with an allowlist parser (--refresh, -h, --help only), print_usage, and MODE install|refresh validation before do_bootstrap/do_refresh. Proved AC1-2: --help/-h exit 0 with usage and no bootstrap banner; unknown flags/positionals exit 1 naming the token. AC3: --refresh --help exits 0; 1 --refresh exits 1 on 1 (order-independent scan). AC4: MODE=Refresh/foo exit 1 before steps. AC5: header documents CLI-only flags and env-var BREW_BUNDLE.
<!-- SECTION:FINAL_SUMMARY:END -->
