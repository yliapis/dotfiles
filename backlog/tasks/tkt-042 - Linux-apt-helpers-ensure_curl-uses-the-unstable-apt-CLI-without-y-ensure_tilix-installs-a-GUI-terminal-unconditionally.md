---
id: TKT-042
title: >-
  Linux apt helpers: ensure_curl uses the unstable apt CLI without -y;
  ensure_tilix installs a GUI terminal unconditionally
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - install
  - linux
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-kimi-2026-07-26
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:141-152
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:54-57
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:168
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:24-26
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:70-72
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:192-193
  - 'install.sh:207-229'
priority: low
type: fix
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`ensure_curl` runs `sudo apt install --update curl`: `apt` warns that it has no stable CLI, `--update` is not listed under `apt install --help` on apt 2.8.3, and there is no `-y`, so an unattended run blocks or fails. `ensure_tilix` runs `sudo apt-get install tilix` on every Linux bootstrap with no `command -v` guard, no `-y`, no `apt-get update`, and no gate, although tilix is a GUI app and the Brewfile GUI entries are gated. `upgrade_apt` and `cloud-agent-bootstrap.sh` already show the correct `apt-get ... -y` pattern.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:213` `sudo apt install --update curl`.
- `install.sh:222-229` `ensure_tilix`.
- `install.sh:201-204` and `ai-coding/hooks/cloud-agent-bootstrap.sh:53-54` use `apt-get update` then `apt-get install -y`.

### Provenance

Fable, Composer, Kimi (major), Opus (minor, 5/5 both).

### Scope

- `install.sh` `ensure_curl`, `ensure_tilix`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ensure_curl uses apt-get update and apt-get install -y curl (non-interactive), consistent with upgrade_apt
- [ ] #2 ensure_tilix is skipped when tilix is installed, runs non-interactively, and is gated behind the same flag as other GUI installs or removed
- [ ] #3 zsh -n install.sh passes
<!-- AC:END -->
