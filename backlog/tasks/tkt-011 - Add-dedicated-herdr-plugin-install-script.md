---
id: TKT-011
title: Add dedicated herdr plugin install script
status: In Progress
assignee:
  - '@yliapis'
created_date: '2026-08-14 22:40'
updated_date: '2026-08-14 22:40'
labels: []
dependencies: []
references:
  - 'https://github.com/smarzban/herdr-file-viewer'
  - 'https://github.com/persiyanov/herdr-reviewr'
  - 'https://github.com/dcolinmorgan/herdr-remote'
  - 'https://github.com/nicosuave/memex'
priority: medium
type: feat
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create scripts/install-herdr-plugins.sh (picked up by install.sh via scripts/install-*.sh) to install the herdr plugins:

- https://github.com/smarzban/herdr-file-viewer
- https://github.com/persiyanov/herdr-reviewr
- https://github.com/dcolinmorgan/herdr-remote
- https://github.com/nicosuave/memex

Add associated tool installs to the Brewfile, or leave a comment on where to relocate items that are not Homebrew formulas (Herdi.app, herdr-push, memex setup, optional glab, rust fallback).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 scripts/install-herdr-plugins.sh exists and matches the scripts/install-*.sh glob used by install.sh
- [ ] #2 The script installs smarzban/herdr-file-viewer, persiyanov/herdr-reviewr, dcolinmorgan/herdr-remote, and nicosuave/memex via herdr plugin install --yes
- [ ] #3 The script skips with exit 0 when herdr is not on PATH
- [ ] #4 Associated tools are in the Brewfile (memex, cloudflared) or commented with a relocate note (Herdi.app, herdr-push, memex setup, optional glab, rust source-build fallback)
- [ ] #5 shellcheck and bash -n pass on the new script
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add scripts/install-herdr-plugins.sh that calls herdr plugin install --yes for the four GitHub specs and skips when herdr is missing.
2. Add nicosuave/tap + memex and cloudflared to the Brewfile; comment Herdi.app, herdr-push, memex setup, glab, and rust fallback.
3. Verify with shellcheck, bash -n, a missing-herdr skip, and a mocked herdr install path.
<!-- SECTION:PLAN:END -->
