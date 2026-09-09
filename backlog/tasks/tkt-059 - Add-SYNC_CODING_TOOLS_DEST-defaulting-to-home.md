---
id: TKT-059
title: Add SYNC_CODING_TOOLS_DEST defaulting to home
status: Done
assignee: []
created_date: '2026-09-09 00:01'
updated_date: '2026-09-09 00:02'
labels: []
dependencies: []
references:
  - scripts/sync-coding-tools.sh
  - install.sh
  - Makefile
  - README.md
priority: medium
type: feat
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add SYNC_CODING_TOOLS_DEST as the parent sync destination. It defaults to $HOME. Per-tool homes stay overridable and default to DEST/.cursor, DEST/.claude, DEST/.config/opencode, and DEST/.agents. install.sh and the Makefile pass the variable. make install and make sync write under $HOME unless DEST is set.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 sync-coding-tools.sh defaults SYNC_CODING_TOOLS_DEST to HOME
- [x] #2 Unset DEST writes under HOME/.cursor HOME/.claude HOME/.config/opencode HOME/.agents
- [x] #3 SYNC_CODING_TOOLS_DEST=/path writes under /path/.cursor /path/.claude /path/.config/opencode /path/.agents
- [x] #4 An explicit SYNC_CODING_TOOLS_CURSOR_HOME still wins over DEST
- [x] #5 install.sh defaults SYNC_CODING_TOOLS_DEST to HOME and passes it to the sync script
- [x] #6 Makefile defaults SYNC_CODING_TOOLS_DEST to HOME and passes it on install, refresh, and sync targets
- [x] #7 Header, --help, and README document DEST and the home default
- [x] #8 zsh -n passes on install.sh and sync-coding-tools.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add SYNC_CODING_TOOLS_DEST:=HOME in sync-coding-tools.sh and derive per-tool homes from it.
2. Default and pass DEST in install.sh.
3. Makefile: DEST ?= HOME and pass it from install, refresh, and sync recipes.
4. Document in headers, --help, and README.
5. Verify default vs override vs per-tool win, make -n, and zsh -n.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-09-09 on this Linux cloud VM.

- AC1: scripts/sync-coding-tools.sh:65 is : "${SYNC_CODING_TOOLS_DEST:=$HOME}"
- AC2: HOME=/tmp/dest-default-home.p4wudv with DEST unset wrote .cursor .claude .config/opencode .agents
- AC3: DEST=/tmp/dest-override.LYKTaP wrote under that root
- AC4: CURSOR_HOME=/tmp/dest-cursor-win.bFRFeF won; DEST/.cursor was absent; claude used DEST/.claude
- AC5: install.sh:72 defaults DEST to HOME; SYNC_CODING_TOOLS=1 refresh wrote /tmp/dest-install.FSqZUv/.cursor/skills
- AC6: Makefile ?= $(HOME); make -n install/refresh/sync pass DEST=$HOME; make sync-cursor DEST=/tmp/dest-make.Y7FwhZ wrote there
- AC7: --help, README, install.sh header, AGENTS.md document DEST
- AC8: zsh -n passed on install.sh and sync-coding-tools.sh

Logs: /opt/cursor/artifacts/sync_coding_tools_dest_evidence.log, /opt/cursor/artifacts/sync_coding_tools_dest_verify.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
SYNC_CODING_TOOLS_DEST defaults to HOME. Per-tool homes derive from that dest unless a *_HOME override is set. make install, make refresh, and make sync pass HOME unless you override it.
<!-- SECTION:FINAL_SUMMARY:END -->
