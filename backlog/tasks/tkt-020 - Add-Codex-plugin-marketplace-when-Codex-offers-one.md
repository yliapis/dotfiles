---
id: TKT-020
title: Add Codex plugin marketplace when Codex offers one
status: Done
assignee: []
created_date: '2026-09-08 01:55'
updated_date: '2026-09-08 18:16'
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
- [x] #1 When Codex documents a plugin or marketplace layout equivalent to .cursor-plugin or .claude-plugin, add the matching manifest and wire dest_plugin_dir in scripts/sync-coding-tools.sh
- [x] #2 Until then, AGENTS.md and README.md keep recording that Codex has no plugin-marketplace equivalent
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC1: Codex packaging docs (https://developers.openai.com/plugins/build/plugins) specify `.codex-plugin/plugin.json` per plugin and `.agents/plugins/marketplace.json` for a repo marketplace. Added both, and wired dest_plugin_dir/plugin_meta_subdir for the agents target.

Evidence:
- 10 plugin manifests at ai-coding/plugins/*/.codex-plugin/plugin.json; python JSON parse and required-field checks passed (plugins=10)
- .agents/plugins/marketplace.json has 10 local entries whose source.path resolves to those plugin dirs
- Isolated SYNC_CODING_TOOLS_AGENTS_HOME=/tmp/sync-agents-codex.av4TzJ/agents-home ./scripts/sync-coding-tools.sh --targets agents wrote marketplace.json (cmp identical) and 10 .codex-plugin/plugin.json copies under plugins/marketplaces/yliapis-dotfiles
- OpenCode still skips plugin dest; --targets codex still exits 2
- make mirrors-check: in_sync=106, does not prune .agents/plugins
- Log: /opt/cursor/artifacts/codex-plugin-marketplace-tests.log
- HEAD e0eee157a28117c19057e0ce0eecc79dc7b8002d tree 24fb4866e0ed40ea1947f0fa4412d212542fe77d

AC2: After AC1, AGENTS.md and README.md describe `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json`. grep for "no plugin-marketplace equivalent" in those files is empty.

PR narrowed after review: dest_plugin_dir / home-dir marketplace sync was reverted. Codex already loads skills from .agents/skills and $HOME/.agents/skills. Remaining change is in-repo plugin packaging only: per-plugin .codex-plugin/plugin.json (cursor/claude shape plus skills) and .agents/plugins/marketplace.json. No root .codex-plugin/ folder. scripts/sync-coding-tools.sh and Makefile match main.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
In-repo Codex plugin packaging only: per-plugin `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json`. Skills still load from `.agents/skills`. No root `.codex-plugin/` folder and no home-dir dest_plugin_dir.
<!-- SECTION:FINAL_SUMMARY:END -->
