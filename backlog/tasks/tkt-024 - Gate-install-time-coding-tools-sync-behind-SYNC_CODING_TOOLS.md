---
id: TKT-024
title: Gate install-time coding-tools sync behind SYNC_CODING_TOOLS
status: Done
assignee: []
created_date: '2026-09-08 16:38'
updated_date: '2026-09-08 16:45'
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
- [x] #1 install.sh defaults SYNC_CODING_TOOLS to 0
- [x] #2 When SYNC_CODING_TOOLS is not 1, install and refresh skip sync-coding-tools.sh and print a skip line
- [x] #3 When SYNC_CODING_TOOLS=1, install and refresh run scripts/sync-coding-tools.sh
- [x] #4 Makefile defaults SYNC_CODING_TOOLS to 1 and passes it to make install and make refresh
- [x] #5 install.sh header and README document the env var and the makefile default
- [x] #6 zsh -n passes on install.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add SYNC_CODING_TOOLS=0 in install.sh and skip sync_coding_tools unless it is 1.
2. Call sync_coding_tools from do_bootstrap and keep the existing do_refresh call.
3. Makefile: SYNC_CODING_TOOLS ?= 1 and pass it from install and refresh.
4. Document in the install.sh header and README.
5. Verify skip vs run with a stubbed refresh, make -n, and zsh -n.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-09-08 on this Linux cloud VM. Full ./install.sh bootstrap was not run (it copies home-config into $HOME). Refresh was run with stub brew and REFRESH_BREWFILE=0 REFRESH_SCRIPTS=0 APT_UPGRADE=0.

- AC1: install.sh:65 is SYNC_CODING_TOOLS=${SYNC_CODING_TOOLS:-0}. Unexported zsh default is 0.
- AC2: unset and SYNC_CODING_TOOLS=0 refresh print "SYNC_CODING_TOOLS not set to 1; skipping sync-coding-tools.sh". Isolated dest dirs were not created. make refresh SYNC_CODING_TOOLS=0 also skips. SYNC_CODING_TOOLS=true does not enable.
- AC3: do_bootstrap and do_refresh both call sync_coding_tools. Function harness with SYNC_CODING_TOOLS=1 ran the stub. Live refresh with SYNC_CODING_TOOLS=1 wrote 17 skills each to isolated cursor/claude/opencode/agents homes.
- AC4: Makefile SYNC_CODING_TOOLS ?= 1. make -n install and make -n refresh pass SYNC_CODING_TOOLS="1". Override passes 0.
- AC5: install.sh header and README document the flag and the makefile default.
- AC6: zsh -n install.sh passed.

Logs: /opt/cursor/artifacts/sync_coding_tools_gate_verify.log, /opt/cursor/artifacts/sync_coding_tools_gate_evidence.log, /opt/cursor/artifacts/sync_coding_tools_env_verify.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
install.sh skips scripts/sync-coding-tools.sh unless SYNC_CODING_TOOLS=1 (default 0). make install and make refresh pass 1. All six acceptance criteria have runtime evidence.
<!-- SECTION:FINAL_SUMMARY:END -->
