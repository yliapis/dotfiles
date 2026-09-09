---
id: TKT-059
title: Add SYNC_CODING_TOOLS_DEST defaulting to home
status: In Progress
assignee:
  - cursor-agent
created_date: '2026-09-09 00:01'
updated_date: '2026-09-09 00:01'
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
- [ ] #1 sync-coding-tools.sh defaults SYNC_CODING_TOOLS_DEST to HOME
- [ ] #2 Unset DEST writes under HOME/.cursor HOME/.claude HOME/.config/opencode HOME/.agents
- [ ] #3 SYNC_CODING_TOOLS_DEST=/path writes under /path/.cursor /path/.claude /path/.config/opencode /path/.agents
- [ ] #4 An explicit SYNC_CODING_TOOLS_CURSOR_HOME still wins over DEST
- [ ] #5 install.sh defaults SYNC_CODING_TOOLS_DEST to HOME and passes it to the sync script
- [ ] #6 Makefile defaults SYNC_CODING_TOOLS_DEST to HOME and passes it on install, refresh, and sync targets
- [ ] #7 Header, --help, and README document DEST and the home default
- [ ] #8 zsh -n passes on install.sh and sync-coding-tools.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add SYNC_CODING_TOOLS_DEST:=HOME in sync-coding-tools.sh and derive per-tool homes from it.
2. Default and pass DEST in install.sh.
3. Makefile: DEST ?= HOME and pass it from install, refresh, and sync recipes.
4. Document in headers, --help, and README.
5. Verify default vs override vs per-tool win, make -n, and zsh -n.
<!-- SECTION:PLAN:END -->
