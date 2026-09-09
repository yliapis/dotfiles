---
id: TKT-057
title: >-
  ai-coding/parameters/generated keeps twelve taxonomies, eight byte-identical
  file pairs, and two competing entry docs
status: To Do
assignee: []
created_date: '2026-09-08 21:40'
labels:
  - ai-coding
  - parameters
  - 'estimate:S'
  - critique-visual-2026-07-24
dependencies: []
references:
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:370-403'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:563'
  - ai-coding/parameters/generated/INDEX.md
  - ai-coding/parameters/generated/README.md
  - 'ai-coding/parameters/TASKS.md:168-191'
  - 'ai-coding/parameters/README.md:17-20'
priority: low
type: docs
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`ai-coding/parameters/generated/` organizes one parameter ontology twelve ways. Four of the twelve scheme directories are byte-for-byte copies of files in the other eight (verified with an MD5 scan: eight identical pairs), and two entry documents each describe a different subset of the archive. `TASKS.md` task 8 ("Generated-archive hygiene") already lists the fixes; the trials ended without a declared winner.

### Evidence (main @ 225cbf2, 2026-09-08)

- Identical pairs: `param-ontology/layered-2.md` = `layered/README.md`; `param-ontology/flat-1.md` = `flat/README.md`; `params/twonamespace-2.md` = `two-namespace/README.md`; `params/concern-1.md` = `concern/README.md`; `params/type-first-3.md` = `type-first/README.md`; `parameters/tree-2.md` = `tree/0-root.md`; `parameters/lifecycle-1.md` = `lifecycle/1-input.md`; `param-stages/stages-1.md` = `stage-modular/README.md`.
- `generated/INDEX.md` covers the eight ontology directories; `generated/README.md` covers only the four older sample directories; neither mentions the other.
- `ai-coding/parameters/README.md:17-18` says the archive "holds eight candidate ontologies"; `generated/` has twelve subdirectories.
- `generated/INDEX.md:3` attributes the archive to `/best-of-n (n=8)`, a command that exists nowhere in the repo.

### Provenance

Visual critique 2026-07-24 (finding 03 "duplication", recommendation 3 "Declare a wiki winner"), `ai-coding/parameters/TASKS.md` task 8 (flagged by three of four wiki critiques).

### Scope

- `ai-coding/parameters/generated/` and the two sentences in `ai-coding/parameters/README.md`. Whether the archive stays at all is decided by TKT-040; the duplicate copies can go regardless.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An MD5 scan of ai-coding/parameters/generated finds no byte-identical file pairs
- [ ] #2 One entry document owns the whole archive and carries a frozen-provenance banner (snapshot revision and date, a note that internal links predate the layout, a link back to the normative wiki); the other entry doc is removed or reduced to a pointer
- [ ] #3 ai-coding/parameters/README.md states the correct count of archived taxonomies and INDEX.md names a provenance that exists in the repo
<!-- AC:END -->
