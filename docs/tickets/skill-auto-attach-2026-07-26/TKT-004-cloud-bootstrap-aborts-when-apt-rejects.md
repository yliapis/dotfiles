---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:8de3aaef2b9550a73e1c703c3e2e63d9ef162acaa040ecd60d55338481daff40"
id: "TKT-004"
fingerprint: "sha256:20b0f11e1bca4b7a9596744db521b0b34859ae47470b299258a1704727a282ec"
title: "Cloud bootstrap aborts when apt rejects the VM clock"
status: "open"
status_reason: null
owner: null
revision: 1
type: "fix"
severity: "major"
priority: "P1"
estimate: "XS"
labels:
  - "cloud-bootstrap-aborts-when-apt-rejects-the-vm-clock"
  - "cursor"
  - "skill-auto-attach-2026-07-26"
source:
  kind: "file"
  identifier: "docs/reports/skill-auto-attach-2026-07-26.md"
  fingerprint: "sha256:8efd2908d9537a8ef027b161df354daffee352339a2c197b9579aad0943e9afc"
  refs:
    - "docs/reports/skill-auto-attach-2026-07-26.md:78-88"
dependencies: []
extensions: {}
---

# TKT-004: Cloud bootstrap aborts when apt rejects the VM clock

## Summary

Cloud bootstrap aborts when apt rejects the VM clock @ `.cursor/scripts/cloud-agent-bootstrap.sh`; a cloud VM whose clock sits behind the release-file validity window starts without any of the interpreters the repository's own scripts need.

## Context and Evidence

Skill auto-attach; Findings; every repo script except the mirror workflow runs under zsh, and the linter for a shell-script repository is one of the missing packages.

- The cloud install log records `E: Release file for http://archive.ubuntu.com/ubuntu/dists/noble-updates/InRelease is not valid yet (invalid for another 22h 55min 22s)` for five repositories. (docs/reports/skill-auto-attach-2026-07-26.md:78-88)
- `/tmp/cursor/async-install/install-user.status` contained `100`, the apt exit code, so `set -e` ended the script at `apt-get update` before the install step ran. (docs/reports/skill-auto-attach-2026-07-26.md:78-88)
- `command -v` found none of `zsh`, `rsync`, or `shellcheck` on the resulting VM, and `docs/reports/ticket-operations-engineering-loop-2026-07-26.md` records the same failure on an earlier run. (docs/reports/skill-auto-attach-2026-07-26.md:78-88)

## Scope

### In Scope

- .cursor/scripts/cloud-agent-bootstrap.sh

### Out of Scope

Changes outside the listed scope and acceptance criteria.

## Acceptance Criteria

- [ ] The bootstrap installs all three packages on a VM whose clock is a day behind real time
- [ ] Signature verification stays enabled and only the date window is relaxed

## Dependencies

None.

## Open Questions

_None._
