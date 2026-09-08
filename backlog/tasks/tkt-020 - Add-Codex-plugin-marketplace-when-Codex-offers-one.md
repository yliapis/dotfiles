---
id: TKT-020
title: Add Codex plugin marketplace when Codex offers one
status: In Progress
assignee:
  - '@yliapis'
created_date: '2026-09-08 01:55'
updated_date: '2026-09-08 17:27'
labels:
  - codex
  - marketplace
  - ai-coding
dependencies: []
references:
  - .cursor-plugin/marketplace.json
  - .claude-plugin/marketplace.json
  - 'https://developers.openai.com/codex/skills'
  - 'https://developers.openai.com/plugins/build/plugins'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Official Codex plugin packaging (https://developers.openai.com/plugins/build/plugins) now documents:

- Per plugin: `.codex-plugin/plugin.json` with skills path and interface metadata
- Repo marketplace: `.agents/plugins/marketplace.json` with local `source.path` entries

Implementation:

1. Add `.codex-plugin/plugin.json` next to each existing `.cursor-plugin` / `.claude-plugin` manifest
2. Add `.agents/plugins/marketplace.json` pointing at `./ai-coding/plugins/<name>`
3. Wire `dest_plugin_dir` / `plugin_meta_subdir` for the `agents` target in `scripts/sync-coding-tools.sh`
4. Update AGENTS.md and README.md so they describe the Codex marketplace instead of its absence
<!-- SECTION:PLAN:END -->
