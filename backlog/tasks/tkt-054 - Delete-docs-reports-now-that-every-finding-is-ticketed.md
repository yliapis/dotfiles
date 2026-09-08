---
id: TKT-054
title: Delete docs/reports now that every finding is ticketed
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - docs
  - reports
  - 'estimate:XS'
dependencies: []
references:
  - 'docs/README.md:10'
  - docs/reports
priority: low
type: docs
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`docs/reports/` holds seven Markdown critique/design reports and one HTML visualization. Every actionable finding in them was re-verified against `main` at 225cbf2 on 2026-09-08 and either carried into a Backlog.md ticket, closed by an existing ticket, or recorded below as intentionally not actioned. The reports are duplicate provenance and can go.

### Files

- `skill-auto-attach-2026-07-26.md` (TKT-001..008)
- `ticket-operations-engineering-loop-2026-07-26.md` (design record, no open items; its bootstrap note is TKT-004)
- `repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md`
- `repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md`
- `repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md`
- `repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z.md`
- `bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md`
- `repo-critique-visualizations-2026-07-24.html` (dashboard over the critiques; no separate findings)

Tickets keep `docs/reports/...:line` references as provenance; after deletion they resolve through git history only (`git log --all -- docs/reports`).

### Findings already fixed before ticketing (no ticket)

`make help` requiring `/bin/zsh`; duplicate `ai-coding/scripts/sync` (TKT-005); copy-mode `(N)` nullglob on the commands glob; marketplace copy without the `plugins/` tree; `begining` typo; stale marketplace description; Brewfile OS gating (TKT-013); ollama piped to `$SHELL` (TKT-023); per-partition `{agent_model}` length mismatch; `soft-shutdown` `-i` unused; `address-worklist-commit-loop` blocked-marker text; plugin `rules/` sync (no plugin has one); cloud bootstrap clock (TKT-004); skills index path (TKT-006); symlink mirrors (TKT-001, TKT-002, TKT-007); Cursor skills destination (TKT-003).

### Findings recorded as not actioned

- Unpinned Brewfile / uv versions with `Brewfile.lock.json` gitignored: accepted trade-off stated in `.gitignore:1`.
- Unordered `install-*.sh` glob: zsh sorts glob expansions lexically by default.
- Clock and hostname in the tmux status bar: intended display.
- `.vimrc` `silent! colorscheme`: standard optional-colorscheme idiom.
- `.claude-plugin/marketplace.json` `0.1.0` versions with no bump policy: one plugin is already at 0.4.0; a bump policy is a process choice.
- Two marketplace manifests no longer byte-identical: `.cursor-plugin` and `.claude-plugin` use distinct client schemas.
- `sync-coding-tools.sh` is zsh-only: zsh is a declared prerequisite installed by the cloud bootstrap and the Brewfile; the header-hygiene ticket makes it explicit.
- "Cross-skill structural schemas" (orchestration vs prose skills): no concrete location or defect.
- `ralph-design` refine-round snapshot gap: the command now delegates round structure and snapshots to the designer skill; not reproducible from the command text.

### Scope

- `docs/reports/` and the `reports/` row in `docs/README.md`. Out of scope: `docs/pr-template.md`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 docs/reports/ no longer exists in the tree and docs/README.md no longer lists it
- [ ] #2 rg 'docs/reports' --glob '!backlog/**' returns no live references outside git history
- [ ] #3 make mirrors-check still passes
<!-- AC:END -->
