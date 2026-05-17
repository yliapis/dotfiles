# Stage: `select`

## Purpose
Choose zero, one, or many "winners" from the candidate executions, using the chosen `selection_mode` (interactive prompt, deterministic ranker, synthesizing aggregator, threshold gate). The selector decides what `persist` and `report` will treat as canonical.

## Position
Runs after `aggregate` (which provides `met_threshold` and `aggregate_score`). Pure (no side effects) unless `selection_mode == manual`, in which case it prompts the user and waits for input.

## Input Contract

### Required
- `executions` (list<execution_result>) — from `execute` / `recover`.
- `evaluations` (list<evaluation_result>) — from `evaluate`.
- `aggregate_report` (map) — from `aggregate`.

### Optional
- `selection_mode` (enum: `manual` | `auto-best` | `synthesize` | `none`, default: `manual` when running interactively, else `auto-best`) — selection strategy.
  - `manual`: ask the user to pick one (or none) of the candidates; mirrors `worktree-task-agent.md` `interactive` merge mode.
  - `auto-best`: pick the highest-ranked passing candidate per `ranker`.
  - `synthesize`: defer the choice to `aggregate`'s `aggregator` synthesis; `selected` is the synthesized artifact, not one of the inputs.
  - `none`: emit empty `selected[]`; downstream stages MUST NOT assume a winner.
- `ranker` (enum: `criteria-weighted` | `pairwise` | `llm-judge` | `test-exit-only` | `custom`, default: inherits from `evaluate.ranker`) — tie-breaker for `auto-best`.
- `max_selected` (int, int_range: `>= 0`, default: `1`, alias: `merge_count`) — maximum number of winners to choose. `0` means "do not pick anything." `1` matches `worktree-task-agent.md`'s "at most one merge."
- `respect_threshold` (bool, default: `true`) — when `true`, refuse to select if `aggregate_report.met_threshold == false`.
- `tie_breaker` (enum: `lowest-index` | `highest-score` | `manual`, default: `lowest-index`) — used when `auto-best` produces ties.
- `interactive_prompt_template` (string, default: built-in per-worktree prompt) — override the manual selection prompt; used by `worktree-task-agent.md`.

## Output Contract

- `selected` (list<execution_result | synthesized_artifact>) — winners. Length is `<= max_selected`. Each entry carries its original `index` (or `null` for synthesized).
- `rejected` (list<{ index, reason }>) — non-selected candidates with reasons (`below-threshold`, `failed-tests`, `lower-rank`, `user-skipped`, `excluded-by-max`).
- `selection_rationale` (string) — human-readable explanation of why the selection happened (used by `report`).
- `selection_summary` (map) — `{ selection_mode, max_selected, respect_threshold, met_threshold, ranker, ties_broken_by }`.

## Depth-Aware Aliasing

- `select[0]` picks among outer candidates; `select[1]` picks among inner candidates inside a slot (e.g., "best verifier verdict within slot 3").
- `selection_mode` does NOT cascade; each depth declares its own (interactive at the outer level + deterministic inner is the common pattern).
- `max_selected` does NOT cascade.
- Outer-stage `select` MAY consume the outputs of inner-stage `select` (treated as the slot's effective result), forming a hierarchical pick.

## Composition Rules

- Predecessors: `aggregate` (strongly recommended) or `evaluate` directly.
- Successors: `persist`, `report`.
- `select` MUST NOT mutate `executions`, `evaluations`, or `aggregate_report`.
- When `respect_threshold == true` and `met_threshold == false`, `select` MUST emit `selected: []` and `selection_rationale` MUST cite the threshold.
- `selected` ordering MUST be deterministic given the same inputs (tie-breaker applied).

## Examples

### Example 1: worktree-task-agent — interactive, at most one merge

```yaml
stage: select
executions: <from recover output, len=8>
evaluations: <from evaluate output, len=8>
aggregate_report: <from aggregate output>
selection_mode: manual
max_selected: 1
respect_threshold: true
outputs:
  selected: [<execution_result index=2: opus partition 1, exit 0, "..."> ]
  rejected:
    - { index: 1, reason: "user-skipped" }
    - { index: 3, reason: "below-threshold (incomplete)" }
    - { index: 4, reason: "failed-tests (exit 1)" }
    - { index: 5, reason: "aborted" }
    - { index: 6, reason: "user-skipped" }
    - { index: 7, reason: "user-skipped" }
    - { index: 8, reason: "user-skipped" }
  selection_rationale: "User chose worktree 2 (opus, partition 1) after reviewing 8 diffs."
  selection_summary: { selection_mode: manual, max_selected: 1, respect_threshold: true, met_threshold: true, ranker: test-exit-only, ties_broken_by: lowest-index }
```

### Example 2: critique — no selection (analysis pipeline emits findings, picks nothing)

```yaml
stage: select
executions: <from execute output, len=5>
evaluations: <from evaluate output, len=5>
aggregate_report: <from aggregate output>
selection_mode: none
max_selected: 0
outputs:
  selected: []
  rejected: []
  selection_rationale: "Critique pipeline is descriptive; no winner is chosen."
  selection_summary: { selection_mode: none, max_selected: 0, respect_threshold: false, met_threshold: true, ranker: null, ties_broken_by: null }
```
