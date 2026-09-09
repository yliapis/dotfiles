---
id: TKT-028
title: >-
  cleanup_brew_cache mass-uninstalls from an unchecked process substitution
  under a cache-cleanup name
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - install
  - brewfile
  - 'estimate:S'
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:128-130
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:186-188
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:200
  - 'install.sh:45'
  - 'install.sh:299-305'
priority: high
type: fix
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`CLEAR_CACHE=1 ./install.sh --refresh` runs `brew bundle cleanup --force`, which per `brew bundle cleanup --help` uninstalls every formula and cask absent from the Brewfile, and `--force` suppresses the prompt. The manifest is fed through `<(cat Brewfile Brewfile.mas)` with no existence check, and the exit status of that `cat` is structurally unobservable, so a wrong `DOTFILES_ROOT` or a partial checkout hands brew an empty manifest with outer rc 0. The variable, function, and header wording all describe reclaiming a download cache.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:299-305` `cleanup_brew_cache` with `--file=<(cat "$DOTFILES_ROOT/Brewfile" "$DOTFILES_ROOT/Brewfile.mas")`.
- `install.sh:45` header: `CLEAR_CACHE=0  Refresh only: brew bundle cleanup --force when 1.`
- `install.sh:268-270` skips `Brewfile.mas` off macOS, but `:303` concatenates it unconditionally, so a Linux cleanup run receives `mas` lines.
- Opus report: two runs independently verified a missing Brewfile yields a 0-byte manifest with outer `rc=0`.

### Provenance

Opus bootstrap critique 2026-08-16: critical (3/5 runs), naming finding promoted to major after orchestrator verification, Brewfile.mas concatenation 2/5.

### Scope

- `install.sh` `cleanup_brew_cache`, the `CLEAR_CACHE` variable and its header line. Renaming the env var is acceptable if the header documents the old name as deprecated, matching the GUI_INSTALL -> BREW_BUNDLE precedent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both manifest files are checked for existence and readability before brew bundle cleanup runs; a missing or unreadable file aborts the step with a message and no uninstall
- [ ] #2 The manifest passed to brew is a real file whose creation status is checked (no process substitution), or the concatenation exit status is otherwise verified
- [ ] #3 Brewfile.mas is included only on macOS, matching run_brewfile_mas
- [ ] #4 The variable name, function name, and header text state that the step uninstalls packages absent from the Brewfiles
<!-- AC:END -->
