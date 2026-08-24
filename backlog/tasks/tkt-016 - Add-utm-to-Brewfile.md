---
id: TKT-016
title: Add utm to Brewfile
status: Done
assignee: []
created_date: '2026-08-24 19:24'
updated_date: '2026-08-24 19:25'
labels: []
dependencies: []
references:
  - 'https://formulae.brew.sh/cask/utm'
  - 'https://mac.getutm.app/'
priority: medium
type: chore
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add the official Homebrew cask for UTM so brew bundle installs the free QEMU and Apple Virtualization GUI on macOS.

Cask is homebrew/cask; no extra tap. Official cask: https://formulae.brew.sh/cask/utm
macOS-only GUI, so gate the line with if OS.mac?
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brewfile contains cask "utm" if OS.mac?
- [x] #2 No extra Homebrew tap is added for utm
- [x] #3 A Linux Brewfile evaluation does not request utm
- [x] #4 The official formulae.brew.sh cask utm exists and is not disabled
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add cask "utm" if OS.mac? next to docker-desktop in the Brewfile development tools section.
2. Do not add a tap; the cask is homebrew/cask.
3. Verify the official formulae.brew.sh cask API and a Brewfile OS-gate evaluation.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-08-24 on this worktree. Cloud VM has no Homebrew, so evidence is a Brewfile parse plus the live formulae.brew.sh API.

- AC1: Brewfile:170 is cask "utm" if OS.mac?
- AC2: grep finds no utm tap; only the homebrew/cask line
- AC3: mock postfix if OS.mac? eval: Linux casks do not include utm; macOS casks do. Linux unguarded casks stay claude-code, codex, cursor, devin-cli, gcloud-cli, font-jetbrains-mono-nerd-font
- AC4: formulae.brew.sh name=utm tap=homebrew/cask disabled=false deprecated=false version=4.7.5 macos>=11

Log: /opt/cursor/artifacts/utm_brewfile_verify.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added cask "utm" if OS.mac? next to docker-desktop. The cask is official homebrew/cask and is gated so Linux brew bundle never requests it. All four acceptance criteria have runtime evidence in utm_brewfile_verify.log.
<!-- SECTION:FINAL_SUMMARY:END -->
