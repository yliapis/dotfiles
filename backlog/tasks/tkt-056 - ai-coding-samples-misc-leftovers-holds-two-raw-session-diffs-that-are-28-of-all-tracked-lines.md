---
id: TKT-056
title: >-
  ai-coding/samples/misc-leftovers holds two raw session diffs that are 28% of
  all tracked lines
status: To Do
assignee: []
created_date: '2026-09-08 21:40'
labels:
  - ai-coding
  - samples
  - 'estimate:XS'
  - critique-visual-2026-07-24
dependencies: []
references:
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:338-369'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:562'
  - ai-coding/samples/misc-leftovers/README.md
priority: medium
type: chore
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`ai-coding/samples/misc-leftovers/` archives two raw `.diff` dumps from a worktree-cleanup pass: `dotfiles-pre-symlink-3c99292.diff` (23,880 lines, 1.35 MB) and `dual-licensing/full.diff` (4,000 lines). Together they are 27,880 of 99,033 tracked lines (28%; 47.6% when the critique ran). Git history preserves them if deleted, and the directory's own README already records what they were.

### Evidence (main @ 225cbf2, 2026-09-08)

- `git ls-files | xargs wc -l`: the two diffs are the largest tracked files by a factor of 20 over the largest hand-written file.
- `ai-coding/samples/misc-leftovers/README.md` describes both as historical artifacts whose source branches were deleted.
- No file under `ai-coding/samples/` states what belongs there; the other seven sample directories hold curated excerpts.

### Provenance

Visual critique 2026-07-24 (finding 02 "ballast", recommendation 2: "Delete the leftovers ... Add a samples policy: excerpts in, raw session dumps out").

### Scope

- `ai-coding/samples/misc-leftovers/`; a short samples policy note (in `ai-coding/samples/README.md` or `AGENTS.md`).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The two raw .diff files are removed from the tree; the misc-leftovers README (or the commit message) names the last commit that contains them
- [ ] #2 A samples policy states what may be committed under ai-coding/samples/ (curated excerpts) and what may not (raw session dumps, full diffs)
<!-- AC:END -->
