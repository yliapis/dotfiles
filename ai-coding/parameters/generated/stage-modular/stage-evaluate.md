# Stage: `evaluate`

## Purpose
Score / judge each execution's output against `criteria` (and optionally a `compare_against` baseline), producing per-execution `findings[]` and / or numeric `scores` that `aggregate` and `select` can act on.

## Position
Runs after `execute` (or its `recover` wrapper). Pure with respect to source code; may write evaluation artifacts (e.g., scorecards) to a temp area.

## Input Contract

### Required
- `executions` (list<execution_result>) — output of `execute` / `recover`.
- `criteria` (list<criterion> | null) — usually `input-resolve.resolved_criteria`. When `null`, `evaluate` is skipped or short-circuits to a pass-through.

### Optional
- `ranker` (enum: `criteria-weighted` | `pairwise` | `llm-judge` | `test-exit-only` | `custom`, default: `criteria-weighted` when `criteria` is non-empty, else `test-exit-only`) — scoring strategy.
- `judge_model` (model_id, default: same as parent agent) — when `ranker == llm-judge`.
- `compare_against` (artifact | execution_id | null, default: `null`) — baseline for relative scoring. Required for `pairwise`.
- `severity_scale` (enum: `critical-major-minor-nit` | `numeric-1-5` | `pass-fail`, default: `critical-major-minor-nit`) — how findings/scores are labeled.
- `pass_threshold` (float | int | null, default: `null`) — numeric or label threshold above which a job is "passing"; consumed by `aggregate`.
- `parallel` (int, int_range: `>= 1`, default: `min(len(executions), 4)`) — how many evaluations to run concurrently.
- `judge_prompt` (string | path, default: derived from `criteria`) — explicit judge prompt override.
- `evaluate_artifacts` (bool, default: `true`) — when `false`, only the `summary` field of each execution is read (cheaper).

## Output Contract

- `evaluations` (list<evaluation_result>) — one per input execution. Each `evaluation_result`:
  - `index` (int) — mirrors `execution.index`
  - `score` (float | int | null) — single numeric score when applicable.
  - `findings` (list<finding>) — each `finding`: `{ id, location, criterion_id, severity, evidence, rationale }`.
  - `pass` (bool | null) — `true` iff `score >= pass_threshold` (or `findings` contains no `critical`).
  - `judge_log` (string) — abbreviated rationale.
- `criterion_coverage` (map<criterion_id, int>) — how many findings cite each criterion (used by `report` to flag under-evaluated criteria).
- `evaluate_summary` (map) — `{ total: int, passed: int, failed: int, ranker, severity_scale, pass_threshold }`.

## Depth-Aware Aliasing

- `evaluate[0]` is the outer evaluation (over outer-stage executions); `evaluate[1]` runs inside a slot to grade nested executions.
- `criteria` does NOT cascade; each depth declares its own. Inheritance is opt-in via `criteria_ref: evaluate[0].criteria`.
- `ranker` cascades inward as a default; `judge_model` cascades inward as a default.
- `compare_against` is depth-local; an outer baseline cannot be referenced implicitly by an inner evaluation (must use the explicit `ref` form).

## Composition Rules

- Predecessors: `execute` (or `recover`-wrapped `execute`).
- Successors: `aggregate` (consumes `evaluations`), then `select`.
- `evaluate` MUST NOT mutate the executions it grades.
- `evaluate` MUST produce a row for every execution (even failed ones, with `findings: []` and `pass: false`).

## Examples

### Example 1: critique — per-run findings against quality + determinism criteria

```yaml
stage: evaluate
executions: <from execute output, len=5>
criteria: <from input-resolve.resolved_criteria>
ranker: criteria-weighted
severity_scale: critical-major-minor-nit
outputs:
  evaluations:
    - { index: 1, score: null, pass: false, findings: [
          { id: f1, location: "critique.md:14",  criterion_id: clarity,       severity: major,    evidence: "...", rationale: "..." },
          { id: f2, location: "critique.md:25",  criterion_id: determinism,   severity: critical, evidence: "...", rationale: "..." }
        ] }
    - { index: 2, score: null, pass: false, findings: [ ... ] }
    - { index: 3, ... }
    - { index: 4, ... }
    - { index: 5, ... }
  criterion_coverage: { clarity: 18, correctness: 12, completeness: 9, robustness: 7, determinism: 6 }
  evaluate_summary: { total: 5, passed: 0, failed: 5, ranker: criteria-weighted, severity_scale: critical-major-minor-nit }
```

### Example 2: worktree-task-agent — pass/fail from `test_command` exit only

```yaml
stage: evaluate
executions: <from recover output, len=8>
criteria: null
ranker: test-exit-only
pass_threshold: 0
outputs:
  evaluations:
    - { index: 1, score: 0, pass: true,  findings: [] }
    - { index: 2, score: 0, pass: true,  findings: [] }
    - { index: 3, score: 0, pass: true,  findings: [] }
    - { index: 4, score: 1, pass: false, findings: [{ id: t1, criterion_id: tests-pass, severity: major, evidence: "1 test failed" }] }
    - { index: 5, score: null, pass: false, findings: [{ id: r1, criterion_id: completed, severity: critical, evidence: "aborted" }] }
    - { index: 6, score: 0, pass: true,  findings: [] }
    - { index: 7, score: 0, pass: true,  findings: [] }
    - { index: 8, score: 0, pass: true,  findings: [] }
  evaluate_summary: { total: 8, passed: 6, failed: 2, ranker: test-exit-only, severity_scale: pass-fail, pass_threshold: 0 }
```
