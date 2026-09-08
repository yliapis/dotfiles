---
id: TKT-024
title: Gate install-time coding-tools sync behind SYNC_CODING_TOOLS
status: In Progress
assignee:
  - cursor-agent
created_date: '2026-09-08 16:38'
updated_date: '2026-09-08 16:38'
labels: []
dependencies: []
references:
  - install.sh
  - Makefile
  - README.md
priority: medium
type: feat
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Refresh mode always runs scripts/sync-coding-tools.sh. Direct ./install.sh and source install.sh should skip that sync unless SYNC_CODING_TOOLS=1. make install and make refresh must pass SYNC_CODING_TOOLS=1 by default, matching BREW_BUNDLE. Install mode must honor the same flag so make install can sync.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 install.sh defaults SYNC_CODING_TOOLS to 0
- [ ] #2 When SYNC_CODING_TOOLS is not 1, install and refresh skip sync-coding-tools.sh and print a skip line
- [ ] #3 When SYNC_CODING_TOOLS=1, install and refresh run scripts/sync-coding-tools.sh
- [ ] #4 Makefile defaults SYNC_CODING_TOOLS to 1 and passes it to make install and make refresh
- [ ] #5 install.sh header and README document the env var and the makefile default
- [ ] #6 zsh -n passes on install.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add SYNC_CODING_TOOLS=0 in install.sh and skip sync_coding_tools unless it is 1.
2. Call sync_coding_tools from do_bootstrap and keep the existing do_refresh call.
3. Makefile: SYNC_CODING_TOOLS ?= 1 and pass it from install and refresh.
4. Document in the install.sh header and README.
5. Verify skip vs run with a stubbed refresh, make -n, and zsh -n.
<!-- SECTION:PLAN:END -->
