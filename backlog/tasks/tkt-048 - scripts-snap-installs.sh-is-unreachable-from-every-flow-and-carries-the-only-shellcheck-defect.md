---
id: TKT-048
title: >-
  scripts/snap-installs.sh is unreachable from every flow and carries the only
  shellcheck defect
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - scripts
  - linux
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-kimi-2026-07-26
  - critique-gpt-2026-07-31
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:167-173
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:62-64
  - >-
    docs/reports/repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z.md:51-54
  - scripts/snap-installs.sh
  - 'install.sh:103'
  - 'install.sh:353'
priority: low
type: fix
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`run_install_scripts` discovers `scripts/install-*.sh`; the Snap installer is named `snap-installs.sh`, so nothing runs it. `install.sh --refresh` still carries `# TODO: add snap refresh script`. The script installs `code` and `docker` snaps (desktop tooling, also provided as macOS casks in the Brewfile) with no platform or headless guard, and its `[ -z $SNAP_PATH ]` is the repo's only shellcheck finding.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:103` glob `install-*.sh`; `scripts/snap-installs.sh` does not match.
- `install.sh:353` `# TODO: add snap refresh script`.
- `shellcheck scripts/snap-installs.sh` -> SC2086 at line 5 (reproduced).

### Provenance

Fable 2026-07-12 (minor), Kimi 2026-07-26 (minor), GPT 2026-07-31 (medium).

### Scope

- `scripts/snap-installs.sh`, `install.sh` TODO, `manage-packages` references if the snap manifest is kept.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The script is either renamed to match install-*.sh with a Linux+snap guard and an opt-in flag documented in the install.sh header, or deleted with the snap entries documented as manual
- [ ] #2 The snap refresh TODO is resolved or removed
- [ ] #3 shellcheck passes on every script under scripts/
<!-- AC:END -->
