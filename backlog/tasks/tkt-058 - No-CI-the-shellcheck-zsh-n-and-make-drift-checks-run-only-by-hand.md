---
id: TKT-058
title: 'No CI: the shellcheck, zsh -n, and make drift checks run only by hand'
status: To Do
assignee: []
created_date: '2026-09-08 21:40'
labels:
  - ci
  - scripts
  - 'estimate:S'
  - critique-visual-2026-07-24
dependencies: []
references:
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:566'
  - 'AGENTS.md:24-40'
  - 'Brewfile:37-38'
priority: medium
type: chore
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`AGENTS.md` defines the repo's lint/test loop: `shellcheck` on the bash scripts, `zsh -n` on `install.sh` and `scripts/sync-coding-tools.sh`, and `make mirrors-check`, `make skills-index-check`, `make commands-index-check`. Nothing runs it automatically: there is no `.github/` directory, so a stale mirror or a shellcheck regression lands on `main` unnoticed until an agent runs the loop by hand. `shellcheck` and `shfmt` are already in the Brewfile, and the whole loop needs only apt packages on `ubuntu-latest`.

### Evidence (main @ 225cbf2, 2026-09-08)

- `ls .github` -> no such directory.
- `AGENTS.md:24-40` names the exact commands; `ai-coding/hooks/cloud-agent-bootstrap.sh:38-42` already installs `zsh`, `rsync`, `shellcheck` on a bare VM, which doubles as the CI dependency list.
- `scripts/snap-installs.sh` currently fails shellcheck (SC2086), which a workflow would have surfaced (TKT-048).

### Provenance

Visual critique 2026-07-24 (recommendation 6: "Adopt shfmt + shellcheck in CI ... A 10-line workflow linting the six shell scripts would have caught most of finding 06").

### Scope

- A GitHub Actions workflow under `.github/workflows/`; a one-line pointer in `AGENTS.md`. `shfmt -d` is optional and may start as a warning-only step.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A workflow runs on push and pull_request: shellcheck on the bash scripts named in AGENTS.md, zsh -n on install.sh and scripts/sync-coding-tools.sh, and the three make *-check targets
- [ ] #2 The workflow passes on the branch that adds it (run URL recorded in the ticket notes), and a deliberately stale mirror in a scratch branch makes it fail
- [ ] #3 AGENTS.md mentions that CI runs the same loop
<!-- AC:END -->
