---
id: TKT-040
title: >-
  ai-coding/parameters wiki has drifted from the plugin tree: broken links,
  missing artifacts, stale layout
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
updated_date: '2026-09-08 21:40'
labels:
  - ai-coding
  - parameters
  - 'estimate:M'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-visual-2026-07-24
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:203-213
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:106-113
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:149
  - 'ai-coding/parameters/coverage.md:1-12'
  - 'ai-coding/parameters/README.md:88'
  - 'ai-coding/parameters/TASKS.md:31'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:437-480'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:565'
  - 'ai-coding/parameters/TASKS.md:24-250'
priority: medium
type: docs
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`coverage.md` calls itself "intended to cover every declared parameter", and `TASKS.md:31` already records that a hand-maintained index drifts. It has kept drifting: nine relative links point at pre-plugin paths, the header describes `.cursor/{commands,skills}` as symlink directories, at least two skills with declared parameters have no entry, and the README quick map lists a knob the skill does not declare.

### Evidence (main @ 225cbf2, 2026-09-08)

- Broken links from `coverage.md`: `../commands/{critique,meta-prompt,save-session-state,soft-shutdown,wrap-up}.md`, `../skills/{agent-swarm,prompt-template-library,trajectory-snapshot,worktree-task}/SKILL.md` (sources now live under `ai-coding/plugins/<plugin>/`).
- `coverage.md:7-9` says the plugin sources are flattened into symlink directories; mirrors are real files since TKT-001.
- `coverage.md` indexes 16 artifacts; the tree has 17 skills and 11 commands. `file-dump` (six declared parameters) and `artifact-researcher` (six knobs) have no entry; `rg file-dump ai-coding/parameters` returns nothing.
- `ai-coding/parameters/README.md:88` lists `trait_map` for `designer`; `ai-coding/plugins/design-suite/skills/designer/SKILL.md` declares no `trait_map`.
- Composer also flagged stale `trajectory-snapshot` token defaults in `coverage.md:210-218`.

### Provenance

Fable 2026-07-12 (minor, "wiki drift, recurred"), Composer 2026-07-12 (major 2/10; correctness 1/10; minor 1/10).

### Scope

- `ai-coding/parameters/` (about 95 files, many generated or archival). Decide between (a) regenerating the live cards from `ai-coding/plugins/` with a `make`-reachable drift check like `gen-artifact-index.sh`, or (b) marking the tree archival and removing the coverage claim. Either outcome closes this ticket.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every relative link in ai-coding/parameters/coverage.md and README.md resolves to an existing file
- [ ] #2 Either every skill and command that declares parameters has a coverage.md entry and a no-write drift check exists and passes, or the tree is explicitly labeled archival and coverage.md no longer claims completeness
- [ ] #3 README.md:88 (trait_map) and the .cursor/{commands,skills} layout sentence match the current tree
- [ ] #4 Open items in ai-coding/parameters/TASKS.md (tasks 3-11) are migrated to backlog tickets or closed by the archival decision, and TASKS.md is removed or marked frozen
<!-- AC:END -->
