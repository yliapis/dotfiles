---
id: TKT-051
title: Command contracts contradict themselves on interactivity and accepted inputs
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - ai-coding
  - commands
  - 'estimate:S'
  - critique-composer-2026-07-12
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:126-133
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:150-151
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:170
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:226-227
  - 'ai-coding/plugins/writing/commands/meta-prompt.md:7'
  - 'ai-coding/plugins/session-state/commands/wrap-up.md:13'
  - 'ai-coding/plugins/writing/commands/critique.md:7'
  - 'ai-coding/plugins/session-state/commands/save-session-state.md:15'
  - 'ai-coding/plugins/git-operations/commands/merge-commit-push.md:31'
priority: low
type: docs
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Five command files carry internal contradictions or unspecified paths that a non-interactive agent cannot resolve. Each is a text-only fix in `ai-coding/plugins/`.

### Evidence (main @ 225cbf2, 2026-09-08)

- `meta-prompt.md:7` "A clarifying question may always precede the reply" vs `:22`, `:43`, `:58` (no questions when `-i` is absent).
- `wrap-up.md:13` allows `{rollup}=interactive` explicitly; `:30` then requires per-proposal prompts, while `:22` says no questions are asked without `-i`. Behavior for an explicit `rollup=interactive` without `-i` is unspecified.
- `critique.md:7` accepts a URL `{context}`; the workflow at `:33` handles file, directory, and inline content only. A required `{context}` with no value has no defined non-interactive behavior (Opus report: the orchestrator had to ask).
- `save-session-state.md:15` says omitted `{include_sections}` MUST NOT appear; the gather steps after `:45` collect every section regardless and rely on rendering to omit.
- `merge-commit-push.md:7,31` default `{source_branch}` to `git rev-parse --abbrev-ref HEAD`, which prints `HEAD` on a detached checkout; no handling is specified.

### Provenance

Composer swarm 2026-07-12 (major 1/10 each; divergent 1/10), Opus 2026-08-16 (open question). The soft-shutdown `-i` and address-worklist-commit-loop findings from the same report are already fixed.

### Scope

- The five command files; regenerate mirrors and the commands index.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each listed contradiction is resolved in the source file so that the non-interactive path is fully specified
- [ ] #2 make mirrors-check and make commands-index-check pass
<!-- AC:END -->
