---
id: TKT-030
title: >-
  detect_shell rejects zsh and bash at standard paths, including the zsh the
  Brewfile installs
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
updated_date: '2026-09-08 21:40'
labels:
  - install
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-opus-2026-08-16
  - critique-visual-2026-07-24
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:67-74
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:50-53
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:150-152
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:197
  - 'install.sh:163-180'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:481-545'
priority: medium
type: fix
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`detect_shell` is an exact-match allowlist of four absolute paths. It omits `/usr/bin/zsh` (Ubuntu's package), `/usr/local/bin/zsh` and `/usr/local/bin/bash` (Intel-Mac Homebrew), and `/home/linuxbrew/.linuxbrew/bin/zsh`, which is exactly what this repo's own `brew "zsh"` line produces. Making the repo's zsh your login shell yields `unsupported shell detected` and `exit 1`.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:164` accepts only `/bin/zsh` and `/opt/homebrew/bin/zsh`; `:167` only `/bin/bash` and `/opt/homebrew/bin/bash`.
- On this VM `command -v zsh` is `/usr/bin/zsh`.
- `Brewfile:20` installs `zsh`, which on Linux lands at `/home/linuxbrew/.linuxbrew/bin/zsh`.
- The test reads `$SHELL` (the login shell), not the running shell, so a bash user who launches zsh to run the script still gets `.bashrc` wired.
- `install.sh:128-129` comment claims the entrypoint "dispatches to the per-shell extras file"; `detect_shell` sets one `DEFAULT_PROFILE_FILE` and there is a single `~/.shell_extras.sh`.

### Provenance

Fable 2026-07-12 (major), Composer 2026-07-12 (major, 2/10), Opus 2026-08-16 (major, 5/5; comment finding 3/5).

### Scope

- `install.sh` `detect_shell` and the comment at `:128-129`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Shell detection accepts any $SHELL whose basename is zsh or bash (or detects the running shell), and still rejects other shells with a message
- [ ] #2 SHELL=/usr/bin/zsh, SHELL=/home/linuxbrew/.linuxbrew/bin/zsh, SHELL=/usr/local/bin/zsh, and SHELL=/usr/local/bin/bash each select the matching profile file
- [ ] #3 The comment above ensure_dotfiles_shell_extras_source describes the single-entrypoint behavior accurately
<!-- AC:END -->
