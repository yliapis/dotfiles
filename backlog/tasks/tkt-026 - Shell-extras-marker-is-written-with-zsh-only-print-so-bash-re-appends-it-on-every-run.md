---
id: TKT-026
title: >-
  Shell-extras marker is written with zsh-only print, so bash re-appends it on
  every run
status: Done
assignee:
  - '@cursor'
created_date: '2026-09-08 19:30'
updated_date: '2026-09-09 23:32'
labels:
  - install
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:47-58
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:35-38
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:138-140
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:230-244
  - 'install.sh:136-141'
priority: high
type: fix
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`ensure_dotfiles_shell_extras_source` guards re-runs by grepping for a marker comment, but writes that marker with `print`, a zsh builtin. Under bash the marker is never written while the `printf` source line is, so the guard never matches and `~/.bashrc` grows one duplicate source line per run.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:136` greps for `# dotfiles: shell extras (managed by dotfiles/install.sh)`.
- `install.sh:139-140` write the blank line and the marker with `print`; `install.sh:141` writes the source line with `printf`.
- `bash -c 'print hello'` returns `print: command not found`, rc 127 (reproduced on this VM).
- `install.sh:167-168` explicitly accepts bash as a supported login shell, and `README.md:6` documents `source install.sh`, which runs the file under whatever shell the user has open.

### Provenance

Fable critique 2026-07-12 (critical, reproduced live: three runs appended three duplicate lines), Composer swarm 2026-07-12 (critical), Opus bootstrap critique 2026-08-16 (major, 5/5 runs; still present at commit 9bbdad8). Independent of the entry-point decision: the fix is `printf` either way.

### Scope

- `install.sh` `ensure_dotfiles_shell_extras_source`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The marker and blank line are written with a POSIX-portable command (printf or echo), not print
- [x] #2 Running the function twice against a fresh profile file under bash appends exactly one marker block; the same holds under zsh
- [x] #3 zsh -n install.sh passes
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced zsh-only print with POSIX printf for the blank line and marker in ensure_dotfiles_shell_extras_source. Proved AC1 with sed/grep (printf only, no standalone print). Proved AC2 with isolated bash and zsh harnesses using temp HOME and a dummy .shell_extras.sh: running the function twice left exactly one marker comment and one source line in each shell. Proved AC3 with zsh -n install.sh (exit 0).
<!-- SECTION:FINAL_SUMMARY:END -->
