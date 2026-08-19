---
id: TKT-015
title: Add pv to Brewfile
status: Done
assignee: []
created_date: '2026-08-19 22:33'
updated_date: '2026-08-19 22:34'
labels: []
dependencies: []
references:
  - 'https://formulae.brew.sh/formula/pv'
  - 'https://www.ivarch.com/programs/pv.shtml'
priority: medium
type: chore
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add the official Homebrew package for pv (Pipe Viewer) so brew bundle installs it on Mac and Linux.

Formula is homebrew/core; no extra tap. Official formula: https://formulae.brew.sh/formula/pv
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brewfile contains brew "pv"
- [x] #2 No extra Homebrew tap is added for pv
- [x] #3 The pv formula line is not OS-gated, matching upstream Mac and Linux Homebrew support
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add brew "pv" to the Brewfile general tools section.
2. Do not add a tap; the formula is homebrew/core.
3. Leave the line unguarded so Mac and Linux brew bundle both request it.
4. Verify against formulae.brew.sh and a Brewfile parse.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-08-19 on this worktree. Cloud VM has no Homebrew, so evidence is Brewfile parse plus the live formulae.brew.sh API.

- AC1: Brewfile:34 is brew "pv"
- AC2: grep finds no pv tap; only the core formula line
- AC3: that line has no if OS.mac? / if OS.linux?
- formulae.brew.sh: name=pv tap=homebrew/core disabled=false; bottles include sonoma, arm64_sonoma, x86_64_linux, arm64_linux; stable=1.11.0

Log: /opt/cursor/artifacts/pv_brewfile_verify.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added brew "pv" to the Brewfile general tools section. The formula is homebrew/core (Mac and Linux). All three acceptance criteria have runtime evidence in pv_brewfile_verify.log.
<!-- SECTION:FINAL_SUMMARY:END -->
