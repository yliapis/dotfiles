---
id: TKT-035
title: >-
  sync-coding-tools.sh --dry-run creates destination directories and appends the
  audit log
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - sync
  - 'estimate:S'
  - critique-kimi-2026-07-26
  - critique-gpt-2026-07-31
dependencies: []
references:
  - >-
    docs/reports/repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z.md:24-29
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:40-42
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:103
  - 'scripts/sync-coding-tools.sh:89'
  - 'scripts/sync-coding-tools.sh:119-121'
  - 'scripts/sync-coding-tools.sh:230-238'
  - 'scripts/sync-coding-tools.sh:271-299'
  - 'scripts/sync-coding-tools.sh:343'
  - 'Makefile:89'
priority: medium
type: fix
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The usage text promises `--dry-run` shows actions without writing and `make dry-run` advertises "(no filesystem writes)", yet copy mode runs `mkdir -p` for every destination unconditionally, symlink mode's `link_one` does the same for parent directories, and the EXIT trap appends a line to `~/.cache/dotfiles/sync.log` on every run including dry runs. The usage text contradicts itself about the log.

### Evidence (main @ 225cbf2, 2026-09-08)

- Reproduced with an empty `HOME`: `--dry-run --targets cursor` created `.cursor/{agents,commands,skills,plugins/local/ai-coding}` and `.cache/dotfiles/` with one log line.
- `scripts/sync-coding-tools.sh:271,277,284,299` `mkdir -p` in `copy_sync_tool`; `:343` in `link_one`; `:238` `trap 'append_log $?' EXIT`.
- `scripts/sync-coding-tools.sh:89` "Show actions without writing" vs `:119-121` "Every run appends one line"; `Makefile:89` "(no filesystem writes)".

### Provenance

GPT critique 2026-07-31 (high, remediation step 1), Kimi critique 2026-07-26 (major; open question whether the dry-run log append is intentional).

### Scope

- `scripts/sync-coding-tools.sh` copy, symlink, and audit-log paths; `Makefile` dry-run/status help text.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 --dry-run against an empty HOME (all four SYNC_CODING_TOOLS_*_HOME roots unset) leaves the tree empty: find "$HOME" -mindepth 1 prints nothing
- [ ] #2 Either the audit log is not written under --dry-run, or the usage text and Makefile name the log append as the one documented exception; the two texts agree
- [ ] #3 make dry-run and make status help strings match the implemented behavior
<!-- AC:END -->
