---
id: TKT-018
title: Add manage-packages skill under dotfiles-dev
status: Done
assignee: []
created_date: '2026-09-07 00:31'
updated_date: '2026-09-07 00:32'
labels: []
dependencies: []
priority: medium
type: feat
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a dotfiles-dev plugin for this repo with a manage-packages skill that applies add, delete, or update operations to Brewfile, Brewfile.mas, snap installs, and other package manifests.

Default mode opens a GitHub PR, merges it into main, and stops. The skill encodes the existing Brewfile PR loop: resolve formula vs cask vs mas, OS-gate GUI packages, verify via formulae.brew.sh (or the manager API) plus a Brewfile OS-gate eval, then commit as chore(brew)/equivalent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Plugin dotfiles-dev exists under ai-coding/plugins/dotfiles-dev with .cursor-plugin/plugin.json and .claude-plugin/plugin.json
- [x] #2 Skill manage-packages implements add, delete, and update for Brewfile, Brewfile.mas, snap installs, and other package manifests in this repo
- [x] #3 Default mode is PR: open a GitHub PR and merge it into main
- [x] #4 Plugin is registered in .cursor-plugin/marketplace.json and .claude-plugin/marketplace.json
- [x] #5 make mirrors-check and make skills-index-check pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add ai-coding/plugins/dotfiles-dev plugin metadata.
2. Author skills/manage-packages from the historical Brewfile PR pattern.
3. Register the plugin in both marketplace files.
4. Regenerate project mirrors and the skills index.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified on feat/dotfiles-dev-manage-packages.

- AC1: ai-coding/plugins/dotfiles-dev/.cursor-plugin/plugin.json and .claude-plugin/plugin.json both exist (269 bytes each).
- AC2: SKILL.md description and Parameters declare action add|delete|update across Brewfile, Brewfile.mas, snap, uv, vscode.
- AC3: {mode} defaults to pr; workflow step 8 runs gh pr merge --squash --delete-branch and treats a successful squash into main as Done.
- AC4: both marketplace.json files register name=dotfiles-dev source=./ai-coding/plugins/dotfiles-dev (cursor line 19, claude line 21).
- AC5: make mirrors-check: 89 in_sync, mirrors match; make skills-index-check: 17 skills, index matches.

eval-brewfile-os.py Linux casks: claude-code@latest, codex, cursor, devin-cli, gcloud-cli, font-jetbrains-mono-nerd-font.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added the dotfiles-dev plugin and manage-packages skill. Default PR mode opens a GitHub PR and squash-merges it into main. Marketplaces, mirrors, and the skills index are current.
<!-- SECTION:FINAL_SUMMARY:END -->
