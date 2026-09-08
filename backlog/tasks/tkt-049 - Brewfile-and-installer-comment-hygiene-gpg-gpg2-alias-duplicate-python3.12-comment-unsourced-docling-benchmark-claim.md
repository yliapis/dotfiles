---
id: TKT-049
title: >-
  Brewfile and installer comment hygiene: gpg/gpg2 alias duplicate, python@3.12
  comment, unsourced docling benchmark claim
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - brewfile
  - scripts
  - 'estimate:XS'
  - critique-fable-2026-07-12
  - critique-kimi-2026-07-26
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:191-195
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:84-86
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:92-94
  - 'Brewfile:30-31'
  - 'Brewfile:116-117'
  - 'scripts/install-doc-tools.sh:25'
priority: low
type: chore
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three comment-level and manifest-level inaccuracies.

### Evidence (main @ 225cbf2, 2026-09-08)

- `Brewfile:30-31` list both `gpg` and `gpg2`; the Fable report verified against the Homebrew formulae API that both are aliases of `gnupg`, so the same package appears twice and complicates `brew bundle cleanup` reasoning.
- `Brewfile:116` `# set system python3 as 3.12` above `brew "python@3.12"`; the formula is keg-only and does not change the system python3.
- `scripts/install-doc-tools.sh:25` `# Docling ... best 2026 benchmark.` is an unsourced, time-relative claim.

### Provenance

Fable 2026-07-12 (minor), Kimi 2026-07-26 (nits). Brewfile edits go through the `manage-packages` skill.

### Scope

- `Brewfile`, `scripts/install-doc-tools.sh`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One gnupg entry remains (verified via formulae.brew.sh that the removed token is an alias)
- [ ] #2 The python@3.12 comment states what the formula does (keg-only; brew link or PATH note if intended)
- [ ] #3 The docling comment cites a source or drops the benchmark claim
<!-- AC:END -->
