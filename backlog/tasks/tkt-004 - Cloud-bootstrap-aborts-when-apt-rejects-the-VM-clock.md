---
id: TKT-004
title: Cloud bootstrap aborts when apt rejects the VM clock
status: Done
assignee: []
created_date: '2026-07-26 18:12'
updated_date: '2026-07-27 02:58'
labels:
  - cursor
  - 'estimate:XS'
  - skill-auto-attach-2026-07-26
dependencies: []
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:78-88'
priority: medium
type: fix
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Cloud bootstrap aborts when apt rejects the VM clock @ `ai-coding/hooks/cloud-agent-bootstrap.sh` (was `.cursor/scripts/cloud-agent-bootstrap.sh`); a cloud VM whose clock sits behind the release-file validity window starts without any of the interpreters the repository's own scripts need.

### Context and Evidence

Skill auto-attach; Findings; every repo script except the mirror workflow runs under zsh, and the linter for a shell-script repository is one of the missing packages.

- The cloud install log records `E: Release file for http://archive.ubuntu.com/ubuntu/dists/noble-updates/InRelease is not valid yet (invalid for another 22h 55min 22s)` for five repositories. (docs/reports/skill-auto-attach-2026-07-26.md:78-88)
- `/tmp/cursor/async-install/install-user.status` contained `100`, the apt exit code, so `set -e` ended the script at `apt-get update` before the install step ran. (docs/reports/skill-auto-attach-2026-07-26.md:78-88)
- `command -v` found none of `zsh`, `rsync`, or `shellcheck` on the resulting VM, and `docs/reports/ticket-operations-engineering-loop-2026-07-26.md` records the same failure on an earlier run. (docs/reports/skill-auto-attach-2026-07-26.md:78-88)

### Scope

#### In Scope

- ai-coding/hooks/cloud-agent-bootstrap.sh

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The bootstrap installs all three packages on a VM whose clock is a day behind real time
- [x] #2 Signature verification stays enabled and only the date window is relaxed
<!-- AC:END -->

## Resolution
<!-- SECTION:RESOLUTION:BEGIN -->
`apt-get update` now runs with `-o Acquire::Check-Date=false`. The option is
scoped to the `update` invocation; `apt-get install` is unchanged.

Verified against a local repository whose `Release` file is dated one day ahead
of system time, which is the same condition as a VM clock one day behind:

- #1 Without the option, apt reports `Release file ... is not valid yet (invalid
  for another 23h 59min 24s)` and exits 100, reproducing the reported failure;
  `set -e` ends the script there. With the option, the same command exits 0 with
  no date error, so the install step runs and `zsh`, `rsync`, and `shellcheck`
  are installed. Confirmed end to end on a fresh VM through the Claude Code
  SessionStart hook.
- #2 `Acquire::Check-Date` governs only the `Date`/`Valid-Until` window.
  Signature verification is a separate check and stays on: `apt-config dump`
  after the run still reports `Acquire::AllowInsecureRepositories "0"` and
  `Acquire::AllowDowngradeToInsecureRepositories "0"`, and no
  `--allow-unauthenticated` or `[trusted=yes]` was introduced.
<!-- SECTION:RESOLUTION:END -->
