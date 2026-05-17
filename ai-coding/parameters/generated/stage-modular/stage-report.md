# Stage: `report`

## Purpose
Render a single, user-facing report drawing from every prior stage's outputs: header context (`input-resolve`, `validate`), per-candidate sections (`execute`, `recover`), evaluation summaries (`evaluate`, `aggregate`), the chosen winner (`select`), and the persistence manifest (`persist`). The terminal stage of every pipeline.

## Position
Last stage. No durable side effects (the report is the response to the user). MAY include a "next-action prompt" when `merge_mode == interactive` and the user still owes a choice.

## Input Contract

### Required
- `pipeline_state` (map) — accumulated outputs of every prior stage, keyed by stage name and depth (e.g., `execute[0].executions`, `aggregate[0].aggregate_report`).

### Optional
- `verbosity` (enum: `terse` | `normal` | `verbose` | `debug`, default: `normal`) — how much detail to render.
  - `terse`: one-paragraph summary + winner identifier (if any).
  - `normal`: per-candidate one-line summary + findings counts.
  - `verbose`: full per-candidate block (mirrors `worktree-task-agent.md` Output Format).
  - `debug`: everything in `verbose` plus `validation_report`, `attempt_log`, `manifest`.
- `require_diff` (bool, default: `true` when `execute` was wrapped around code-changing tasks, else `false`) — include `git diff` blocks per candidate; truncated above ~400 lines with a count-of-omitted footer.
- `include_terminal_log` (bool | int, default: `false`) — `true` includes full `terminal_log`; an `int` includes that many trailing characters per execution.
- `output_format` (enum: `md` | `json` | `html`, default: `md`) — wire format of the report itself.
- `sections` (list<enum>, default: `[header, summary, candidates, evaluation, aggregate, selection, persistence, next-actions]`) — explicit section ordering and inclusion list.
- `redact` (list<string>, default: `[]`) — paths / patterns to redact from any embedded log / diff (e.g., secrets, env files).
- `interactive_prompts` (bool, default: `true` when `select.selection_mode == manual` and no selection was made) — emit follow-up prompts.

## Output Contract

- `report` (string) — the rendered text (markdown / JSON / HTML).
- `report_sections` (map<section_name, string>) — the same content broken out by section.
- `next_actions` (list<{ kind, prompt }>) — pending user decisions (e.g., merge-which-branch).
- `report_summary` (map) — `{ verbosity, total_length_chars, sections_emitted, redactions_applied: int }`.

## Depth-Aware Aliasing

- `report` typically runs only at depth 0 (the user only sees the outermost report).
- An inner `report[1]` is legal but unusual — used to render intermediate per-slot reports embedded into the outer report's candidate sections.
- `verbosity` cascades inward as a default (`verbose` outer → `verbose` inner) but explicit inner override is honored.
- `sections` does NOT cascade; each depth declares its own ordering.

## Composition Rules

- Predecessors: any subset of `validate`, `isolate`, `execute`, `recover`, `evaluate`, `aggregate`, `select`, `persist`. `report` is robust to missing predecessors (it omits the corresponding sections).
- Successors: none.
- `report` MUST surface every fatal error from earlier stages (`validate.errors`, `aggregate.met_threshold == false`, `persist.merge_failures`).
- `report` MUST honor `redact` for any embedded log / diff before emission.

## Examples

### Example 1: worktree-task-agent — verbose, per-worktree diff, interactive next-action

```yaml
stage: report
pipeline_state:
  validate[0]: { ... }
  isolate[0]: { isolations: <len=8> }
  fan-out[0]: { ... }
  execute[0]: { executions: <len=8> }
  recover[0]: { recover_summary: { ... } }
  evaluate[0]: { evaluations: <len=8> }
  aggregate[0]: { aggregate_report: { ... } }
  select[0]: { selected: [<index=2>], selection_rationale: "..." }
  persist[0]: { merged_branches: [...] }
verbosity: verbose
require_diff: true
include_terminal_log: 2000
sections: [header, summary, candidates, evaluation, aggregate, selection, persistence, next-actions]
outputs:
  report: |
    ### Run Summary
    Base branch: main
    Parallelism: 8
    Merge mode: interactive
    Counts: 6 succeeded / 1 failed / 1 incomplete

    ### Worktree Results
    [8 per-worktree blocks, each with Index/Path/Branch/Model/Status/Summary/Verification/Diff/Merge recommendation]

    ### Merge Recommendation
    Worktree 2 (opus, partition 1) is recommended; passes tests and matches all guardrails.

    ### Merge Prompt
    1. Merge refactor-auth-2 into main? (y/n)
    2. Delete worktree at ~/.cursor/worktrees/.../refactor-auth-2? (y/n)
  next_actions:
    - { kind: merge-confirmation, prompt: "Merge refactor-auth-2 into main? (y/n)" }
    - { kind: cleanup-confirmation, prompt: "Delete worktree at .../refactor-auth-2? (y/n)" }
  report_summary: { verbosity: verbose, total_length_chars: 18_402, sections_emitted: 8, redactions_applied: 0 }
```

### Example 2: critique — terse summary + findings (no diff, no merge)

```yaml
stage: report
pipeline_state:
  input-resolve[0]: { ... }
  execute[0]: { executions: <len=5> }
  evaluate[0]: { evaluations: <len=5> }
  aggregate[0]: { convergent_findings: [...], divergent_findings: [...] }
verbosity: normal
require_diff: false
include_terminal_log: false
sections: [header, summary, findings, divergent, open-questions]
outputs:
  report: |
    # Critique: critique.md
    Criteria applied: clarity, correctness, completeness, robustness, determinism
    Runs: 5 (parallel up to 3, model: claude-opus)

    ## Summary
    Overall: solid command; 1 critical (determinism), 3 major, 5 minor, 3 nit findings.

    ## Findings
    ### Critical
    - **determinism** @ `critique.md:25` (4/5 runs): ...

    ### Major
    - ...

    ## Divergent Findings
    - **correctness** @ `critique.md:55` (2/5 runs): ...

    ## Open Questions
    - `{criteria}` was unspecified for severity weighting; defaulted to equal weights.
  report_summary: { verbosity: normal, total_length_chars: 4_812, sections_emitted: 5, redactions_applied: 0 }
```
