---
id: TKT-020
title: Add Codex plugin marketplace when Codex offers one
status: To Do
assignee: []
created_date: '2026-09-08 01:55'
labels:
  - codex
  - marketplace
  - ai-coding
dependencies: []
references:
  - .cursor-plugin/marketplace.json
  - .claude-plugin/marketplace.json
  - 'https://developers.openai.com/codex/skills'
priority: low
type: feat
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a Codex plugin marketplace parallel to .cursor-plugin and .claude-plugin when Codex offers an equivalent.

### Context

Codex has no documented plugin-marketplace directory like .cursor-plugin or .claude-plugin. Official skill discovery is .agents/skills (repo) and $HOME/.agents/skills (user). Do not invent a marketplace.

### Scope

In Scope: marketplace manifests and sync-coding-tools.sh dest_plugin_dir when Codex documents an equivalent.

Out of Scope: inventing a Codex marketplace; mapping commands to ~/.codex/prompts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 When Codex documents a plugin or marketplace layout equivalent to .cursor-plugin or .claude-plugin, add the matching manifest and wire dest_plugin_dir in scripts/sync-coding-tools.sh
- [ ] #2 Until then, AGENTS.md and README.md keep recording that Codex has no plugin-marketplace equivalent
<!-- AC:END -->
