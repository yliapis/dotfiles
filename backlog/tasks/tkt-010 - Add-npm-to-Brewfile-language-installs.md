---
id: TKT-010
title: Add npm to Brewfile language installs
status: Done
assignee:
  - '@cursor-agent'
created_date: '2026-08-07 18:04'
updated_date: '2026-08-07 18:04'
labels:
  - brew
  - npm
dependencies: []
references:
  - Brewfile
  - ai-coding/hooks/cloud-agent-bootstrap.sh
  - install.sh
  - scripts/snap-installs.sh
modified_files:
  - Brewfile
priority: medium
type: chore
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Brewfile should install npm via Homebrew. Confirm npm is not provisioned by another path in this repo (install.sh, cloud-agent-bootstrap apt list, scripts/install-*.sh, snap-installs), then add the Brewfile entry under languages next to node.

Context: Homebrew currently aliases npm to the node formula; Brewfile already has brew \"node\". Still make npm an explicit Brewfile line so the intent is searchable and brew bundle installs it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brewfile lists brew "npm" under the languages section
- [x] #2 Repo install paths do not separately apt/snap/script-install npm or nodejs (only Brewfile / node alias)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Grep install paths for npm/nodejs installs outside Brewfile.
2. Add brew \"npm\" under languages beside brew \"node\".
3. Confirm Homebrew API: npm is alias of node (no separate formula).
4. Verify Brewfile contains the entry; check ACs; mark Done.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added brew \"npm\" beside brew \"node\" in Brewfile languages.
Verified: no apt/snap/script path installs npm/nodejs; cloud-agent-bootstrap only consumes npm if already on PATH.
Homebrew has no separate npm formula (API 404); npm is an alias of node.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Brewfile now lists brew \"npm\" under languages. npm is not installed elsewhere in repo provisioning paths; Homebrew resolves npm as an alias of node.
<!-- SECTION:FINAL_SUMMARY:END -->
