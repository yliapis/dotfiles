# Stage: `aggregate`

## Purpose
Reduce a list of `evaluations` (and the underlying `executions`) into a single summary: convergent vs. divergent findings, vote tallies, pass-rate, threshold checks (`min_successes`), and per-criterion aggregates. Distinct from `select` — `aggregate` summarizes, `select` chooses.

## Position
Runs after `evaluate`. Pure (no side effects). May run before OR be merged into the same stage as `select`, but the contracts are kept separate to allow "report convergence without picking a winner" pipelines.

## Input Contract

### Required
- `evaluations` (list<evaluation_result>) — from `evaluate`.
- `executions` (list<execution_result>) — from `execute` / `recover` (so `aggregate` can correlate findings with terminal status).

### Optional
- `aggregator` (enum: `vote-majority` | `vote-unanimous` | `union` | `intersection` | `mean-score` | `convergence-cluster` | `custom`, default: `convergence-cluster` for finding-based evaluations, `mean-score` for numeric scores) — aggregation method.
- `min_successes` (int, int_range: `>= 0`, default: `1`) — minimum count of `evaluations[i].pass == true` for the batch to be considered satisfied; sets `met_threshold` accordingly.
- `convergence_key` (list<string>, default: `[location, criterion_id]`) — fields that identify "the same finding across runs"; used by `convergence-cluster` and `intersection`.
- `min_agreement` (int, int_range: `>= 1`, default: `2`) — minimum number of runs that MUST raise the same finding for it to be "convergent."
- `compare_against` (artifact | execution_id, default: `null`) — when set, aggregation is computed relative to a baseline (e.g., "how often did candidates differ from baseline?").
- `weighting` (map<string, float>, default: `{}`) — per-criterion or per-severity weights applied before aggregation.

## Output Contract

- `aggregate_report` (map) — top-level summary:
  - `total` (int)
  - `success_count` (int) — number of `evaluations[i].pass == true`.
  - `fail_count` (int)
  - `met_threshold` (bool) — `success_count >= min_successes`.
  - `aggregate_score` (float | null) — mean / weighted-mean when `aggregator` is numeric.
- `convergent_findings` (list<finding>) — findings raised by `>= min_agreement` runs; each carries an `agreement_count` (int).
- `divergent_findings` (list<finding>) — findings raised by `< min_agreement` runs; each carries `agreement_count`.
- `per_criterion_counts` (map<criterion_id, { critical, major, minor, nit, total }>) — aggregated by severity.
- `aggregate_summary` (map) — `{ aggregator, min_successes, min_agreement, weighting_applied: bool }`.

## Depth-Aware Aliasing

- `aggregate[0]` summarizes outer-stage evaluations; `aggregate[1]` summarizes inner-stage evaluations within a single outer slot.
- `min_successes` does NOT cascade; outer threshold (e.g., "5 of 8 outer slots") is independent of inner threshold (e.g., "2 of 3 inner verifier sub-runs per slot").
- `convergence_key` cascades inward as a default; explicit inner override is common when inner findings live in a different namespace.
- An outer `aggregate` MAY consume inner `aggregate_report`s (via `evaluations: <map inner reports onto outer evaluation_result>`); this enables hierarchical voting.

## Composition Rules

- Predecessors: `evaluate`.
- Successors: `select`, `persist`, `report`.
- `aggregate` MUST emit `met_threshold` even when `min_successes == 0` (in which case it's trivially `true`).
- When `aggregate` is followed by `select`, the selector SHOULD respect `met_threshold`; e.g., refuse to pick a winner if the threshold is not met.

## Examples

### Example 1: critique — convergent vs. divergent findings across 5 runs

```yaml
stage: aggregate
evaluations: <from evaluate output, len=5>
executions: <from execute output, len=5>
aggregator: convergence-cluster
convergence_key: [location, criterion_id]
min_agreement: 3
min_successes: 0          # critique is "always passes" — we just want the analysis
outputs:
  aggregate_report:
    total: 5
    success_count: 5
    fail_count: 0
    met_threshold: true
    aggregate_score: null
  convergent_findings:
    - { id: cf1, location: "critique.md:14",  criterion_id: clarity,     severity: major,    agreement_count: 5 }
    - { id: cf2, location: "critique.md:25",  criterion_id: determinism, severity: critical, agreement_count: 4 }
    - { id: cf3, location: "critique.md:31",  criterion_id: completeness,severity: minor,    agreement_count: 3 }
  divergent_findings:
    - { id: df1, location: "critique.md:42",  criterion_id: robustness,  severity: nit,      agreement_count: 1 }
    - { id: df2, location: "critique.md:55",  criterion_id: correctness, severity: minor,    agreement_count: 2 }
  per_criterion_counts:
    clarity:     { critical: 0, major: 3, minor: 1, nit: 0, total: 4 }
    correctness: { critical: 0, major: 0, minor: 2, nit: 1, total: 3 }
    ...
  aggregate_summary: { aggregator: convergence-cluster, min_successes: 0, min_agreement: 3, weighting_applied: false }
```

### Example 2: worktree-task-agent — gate on min_successes

```yaml
stage: aggregate
evaluations: <from evaluate output, len=8>
executions: <from recover output, len=8>
aggregator: mean-score
min_successes: 5
outputs:
  aggregate_report:
    total: 8
    success_count: 6
    fail_count: 2
    met_threshold: true     # 6 >= 5
    aggregate_score: 0.125  # mean of exit codes (lower is better)
  convergent_findings: []
  divergent_findings: [{ id: df_t1, location: "auth.ts:88", criterion_id: tests-pass, severity: major, agreement_count: 1 }]
  per_criterion_counts: { tests-pass: { major: 1, total: 1 }, completed: { critical: 1, total: 1 } }
  aggregate_summary: { aggregator: mean-score, min_successes: 5, min_agreement: 2, weighting_applied: false }
```
