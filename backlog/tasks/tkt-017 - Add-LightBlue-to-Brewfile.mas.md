---
id: TKT-017
title: Add LightBlue to Brewfile.mas
status: Done
assignee: []
created_date: '2026-09-04 22:15'
updated_date: '2026-09-04 22:15'
labels: []
dependencies: []
references:
  - 'https://apps.apple.com/us/app/lightblue/id557428110'
  - 'https://punchthrough.com'
modified_files:
  - Brewfile.mas
priority: medium
type: chore
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Punch Through LightBlue to Brewfile.mas so brew bundle installs the Mac App Store BLE browser when BREW_BUNDLE_MAS=1.

App Store only; no Homebrew cask or formula (brew search returns lighthouse/lightburn, not lightblue). Listing: https://apps.apple.com/us/app/lightblue/id557428110 (trackId 557428110, seller Punch Through Design LLC). Includes MacDesktop in supportedDevices, so mas can install it unlike the commented Bandcamp iOS-only entry.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brewfile.mas contains mas "LightBlue", id: 557428110
- [x] #2 Brewfile is unchanged and adds no lightblue cask, formula, or tap
- [x] #3 iTunes lookup for 557428110 is Punch Through LightBlue and lists MacDesktop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add mas "LightBlue", id: 557428110 to Brewfile.mas next to Boom3D.
2. Do not change Brewfile or add a tap.
3. Verify the App Store listing and a brew search with no lightblue cask.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-09-04 on this worktree.

- AC1: Brewfile.mas:14 is mas "LightBlue", id: 557428110. HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --file=Brewfile.mas --mas prints Boom3D then LightBlue.
- AC2: git diff -- Brewfile is empty; rg -i lightblue|557428110 Brewfile has no match; brew search lightblue returns lighthouse and lightburn only.
- AC3: iTunes lookup id=557428110: trackName=LightBlue®, artistName=Punch Through, sellerName=Punch Through Design LLC, bundleId=com.PunchThrough.LightBlue, supportedDevices includes MacDesktop-MacDesktop.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added mas "LightBlue", id: 557428110 to Brewfile.mas. Punch Through LightBlue is App Store only (no Homebrew cask) and lists MacDesktop, so mas can install it. All three acceptance criteria have runtime evidence.
<!-- SECTION:FINAL_SUMMARY:END -->
