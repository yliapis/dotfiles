---
id: TKT-001
title: Project skill mirrors depend on symlink resolution
status: Done
assignee: []
created_date: '2026-07-26 18:12'
updated_date: '2026-07-26 19:38'
labels:
  - cursor
  - 'estimate:M'
  - skill-auto-attach-2026-07-26
dependencies:
  - TKT-002
references:
  - 'docs/reports/skill-auto-attach-2026-07-26.md:36-49'
priority: high
type: fix
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Project skill mirrors depend on symlink resolution @ `.cursor/skills/`; one shipped discovery implementation keeps a symlinked skill directory and another drops any link whose real path leaves the scanned directory, so whether a skill reaches the agent depends on which implementation the client runs.

### Context and Evidence

Skill auto-attach; Findings; the same layout covers commands and agents, so a discovery path that skips links skips all 75 mirror entries rather than skills alone.

- `git ls-files -s .cursor/skills` reports mode `120000` for all 15 entries, each pointing at `../../ai-coding/plugins/<plugin>/skills/<name>`. (docs/reports/skill-auto-attach-2026-07-26.md:36-49)
- `realpath .cursor/skills/stop-slop` resolves to `/workspace/ai-coding/plugins/writing/skills/stop-slop`, outside `/workspace/.cursor/skills`, so every mirror link leaves the directory a scanner would walk. (docs/reports/skill-auto-attach-2026-07-26.md:36-49)
- The cloud agent run on this layout was offered zero of the 15 skills while its context still carried `AGENTS.md`, so the transport that delivers repository instructions worked while skill delivery did not. (docs/reports/skill-auto-attach-2026-07-26.md:36-49)

### Scope

#### In Scope

- .cursor/skills/
- .claude/skills/
- .opencode/skills/
- .cursor/commands/
- .cursor/agents/

#### Out of Scope

Changes outside the listed scope and acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 No entry under any of the nine repo-root mirrors is a symlink, and `find .cursor .claude .opencode -maxdepth 2 -type l` prints nothing
- [x] #2 Each mirrored skill directory is byte-identical to its `ai-coding/plugins/*/skills/<name>` source
- [x] #3 `ai-coding/plugins/` remains the only location a maintainer edits
<!-- AC:END -->
