---
id: TKT-025
title: install.sh is written to be executed but README tells users to source it
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
updated_date: '2026-09-08 21:40'
labels:
  - install
  - readme
  - 'estimate:M'
  - critique-composer-2026-07-12
  - critique-kimi-2026-07-26
  - critique-opus-2026-08-16
  - critique-visual-2026-07-24
dependencies: []
references:
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:39-42
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:28-30
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:170-176
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:199
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:214
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:220-221
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:223-224
  - 'README.md:6'
  - 'install.sh:51'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:481-545'
priority: high
type: fix
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`README.md:6` and the `install.sh:5` header name `source install.sh` as the primary entry point, while the script body is written for a subprocess: it resolves paths from `$0`, calls `exit`, exports variables, and changes directory. Every one of those is wrong when the file is sourced.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:51` sets `DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"`. Under bash, `$0` inside a sourced file is `bash`, so `dirname` yields `.` and the root becomes the caller's cwd (reproduced: `dirname "$0"` printed `.`). Every `$DOTFILES_ROOT/...` path then mis-resolves, including the Brewfile paths fed to `brew bundle cleanup --force`.
- Nine `exit 1` sites (`install.sh:122,134,154,158,172,217,326,333,357`) terminate the sourcing login shell instead of returning an error.
- `install.sh:69` exports `HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1` into the caller's session; `install.sh:333` leaves the caller chdir'd into the repo; `install.sh:103` loop variable `script` is not `local`; `install.sh:83` `BREW_BUNDLE=${1:-$BREW_BUNDLE}` reads the caller's positional parameters.
- `make install` (`Makefile:40-41`) executes the script, so the two documented entry points have different failure semantics.

### Provenance

Composer swarm critique 2026-07-12 (critical), Kimi critique 2026-07-26 (major), Opus bootstrap critique 2026-08-16 (major, 4/5 and 1/5 runs; listed as the top open question). Unchanged at those lines since the first report.

### Scope

- `README.md`, `install.sh` header and the sourced-path sites listed above. Pick one contract: either document `./install.sh` / `make install` only and refuse to run when sourced, or make the sourced path correct (`return`, `${(%):-%x}` / `BASH_SOURCE` root resolution, no exports or `cd` leaks). Header prerequisite wording belongs to the header-hygiene ticket.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 README.md and the install.sh header name exactly one supported invocation, and any other documented form either behaves identically or fails fast with a message
- [ ] #2 Sourcing install.sh from bash and from zsh in a foreign cwd (e.g. /tmp) does not terminate the caller's shell, does not resolve DOTFILES_ROOT to the cwd, and leaves no exported variable, cwd change, or loop variable behind
- [ ] #3 ./install.sh executed from a foreign cwd resolves DOTFILES_ROOT to the repository root
- [ ] #4 zsh -n install.sh passes
<!-- AC:END -->
