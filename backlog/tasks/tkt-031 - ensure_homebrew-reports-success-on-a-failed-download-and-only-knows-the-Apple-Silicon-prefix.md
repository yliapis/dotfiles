---
id: TKT-031
title: >-
  ensure_homebrew reports success on a failed download and only knows the Apple
  Silicon prefix
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - install
  - 'estimate:S'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-kimi-2026-07-26
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:154-160
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:75-82
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:181-190
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:58-61
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:52-54
  - 'install.sh:240-257'
priority: medium
type: fix
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A failed `curl` makes the command substitution empty and `bash -c ""` exits 0, so `ensure_homebrew` returns success with no Homebrew installed; the unguarded `disable_brew_analytics` on the next line then fails for an unrelated-looking reason. On macOS the post-install activation hardcodes `/opt/homebrew`, although Intel Macs install to `/usr/local` and `home-config/.shell_extras.sh` already probes both.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:245` `bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`. Reproduced: `bash -c "$(false)"` exits 0.
- `install.sh:246-249` `darwin*) BREW_ROOT="/opt/homebrew"`; `home-config/.shell_extras.sh:14-19` probes `/opt/homebrew`, `/usr/local`, and linuxbrew in turn.
- `install.sh:254-257` `disable_brew_analytics` runs `brew analytics off` with no `command -v brew` guard.
- The installer is fetched from `HEAD` with no pin or checksum, so identical invocations run different installer code over time (reproducibility; security criteria were out of scope for the critiques).

### Provenance

Opus 2026-08-16 (major, 4/5 and 5/5 runs), Fable 2026-07-12 (major), Composer 2026-07-12 (major), Kimi 2026-07-26 (major: unpinned execute-from-URL).

### Scope

- `install.sh` `ensure_homebrew`, `disable_brew_analytics`. Pinning the installer to a tag or checksum is optional; failure detection is required.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A failed download aborts ensure_homebrew with a message before any installer code runs (download to a file or check the substitution is non-empty)
- [ ] #2 After the installer runs, command -v brew succeeds or the step fails; disable_brew_analytics is not reached without brew on PATH
- [ ] #3 On macOS BREW_ROOT resolves to whichever of /opt/homebrew and /usr/local holds bin/brew, in the same order as home-config/.shell_extras.sh
<!-- AC:END -->
