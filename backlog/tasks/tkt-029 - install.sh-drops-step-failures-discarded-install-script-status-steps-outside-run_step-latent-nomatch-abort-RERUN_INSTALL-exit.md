---
id: TKT-029
title: >-
  install.sh drops step failures: discarded install-script status, steps outside
  run_step, latent nomatch abort, RERUN_INSTALL exit
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - install
  - 'estimate:M'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-kimi-2026-07-26
  - critique-gpt-2026-07-31
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:142-148
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:166-168
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:212
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:218
  - >-
    docs/reports/repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z.md:56-59
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:44-46
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:61-66
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:46-49
  - 'install.sh:87-116'
  - 'install.sh:307-330'
priority: medium
type: fix
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`run_step` and `REFRESH_FAILURES` were added so failures are collected and the script exits non-zero (`install.sh:87-88`), but the bootstrap path applies them to three of thirteen steps and discards the one return value that carries install-script failures. Several other paths still swallow or misreport errors.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:322` calls `run_install_scripts` bare; the function returns `$failed` (`:115`) but nothing reads it, so a failing `scripts/install-*.sh` still ends in `dotfiles install complete` with exit 0. Refresh wraps the same call in `run_step` (`:350`).
- Only `upgrade_apt`, `run_brewfile_if_enabled`, and `run_brewfile_mas` go through `run_step` in `do_bootstrap` (`:313,318,319`); `ensure_curl`, `ensure_tilix`, `ensure_homebrew`, `disable_brew_analytics`, `copy_home_config`, `ensure_dotfiles_shell_extras_source` do not.
- `install.sh:103-104` `for script in .../install-*.sh; do [ -f "$script" ] || continue` is a bash idiom; under zsh's default `nomatch` an empty match aborts the whole script (reproduced: `no matches found`, rc 1, trailing statement never ran). Latent today because seven `install-*.sh` exist.
- `install.sh:335-336` `RERUN_INSTALL=1` runs `do_bootstrap`, whose `exit 1` (`:326`) on any failure skips `cleanup_brew_cache`, `upgrade_brew`, `upgrade_apt`, `sync_coding_tools`, and the install scripts, then reports "install finished with failures" from a refresh.
- `install.sh:285-287` skips `sync-coding-tools.sh` silently when it is present but not executable; `run_install_scripts` invokes via `bash "$script"` and needs no exec bit.
- All diagnostics, including `Error:` lines, go to stdout (`:93,111,121,133`), so `make install 2>err.log` captures nothing.

### Provenance

Raised by every critique (Fable, Composer, Kimi, GPT medium, Opus 5/5 and 3/5 runs). The `run_step` mechanism landed after the July reports; the Opus report (2026-08-16) lists the remaining gaps above.

### Scope

- `install.sh` `run_install_scripts`, `do_bootstrap`, `do_refresh`, `sync_coding_tools`, diagnostics.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A failing scripts/install-*.sh makes ./install.sh exit non-zero and name the script in the final summary, in both install and refresh modes
- [ ] #2 Every bootstrap step either runs through run_step or is documented as fatal-by-design in the header
- [ ] #3 An empty scripts/ directory or a glob with no install-*.sh match does not abort the script (nullglob qualifier or equivalent)
- [ ] #4 RERUN_INSTALL=1 ./install.sh --refresh with one failed bootstrap step still runs the remaining refresh steps and reports the failures under the refresh summary
- [ ] #5 A present but non-executable scripts/sync-coding-tools.sh is reported as a failure or invoked via zsh, not skipped silently
- [ ] #6 Error: diagnostics are written to stderr
<!-- AC:END -->
