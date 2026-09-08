---
id: TKT-047
title: 'home-config nits: unpinned uvx MCP servers and xterm-256color inside tmux'
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - home-config
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
dependencies: []
references:
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:138-141
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:155
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:247-250
  - 'home-config/.cursor/mcp.json:3-13'
  - 'home-config/.tmux.conf:2'
priority: low
type: chore
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two small determinism and correctness items in `home-config/`.

### Evidence (main @ 225cbf2, 2026-09-08)

- `home-config/.cursor/mcp.json:3-6` and `:10-13` launch `docling-mcp` and `markitdown-mcp` through `uvx` with no version, so the MCP tool surface changes at runtime without any repo change.
- `home-config/.tmux.conf:2` `set -g default-terminal "xterm-256color"`; tmux documentation expects `tmux-256color` or `screen-256color` inside tmux, and `xterm-*` can degrade key handling and italics.

### Provenance

Composer 2026-07-12 (major 1/10 for mcp.json; nit for tmux), Fable 2026-07-12 (nit).

### Scope

- `home-config/.cursor/mcp.json`, `home-config/.tmux.conf`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each uvx server in mcp.json pins a version (pkg==X.Y.Z) or a comment-equivalent field records that floating is intentional
- [ ] #2 default-terminal is tmux-256color (with screen-256color fallback if the terminfo entry is absent on target hosts) and tmux starts without a terminfo warning on macOS and Ubuntu
<!-- AC:END -->
