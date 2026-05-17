# Stage: `replicate`

## Purpose
Materialize `k` byte-identical job specs from a single template, for reliability-oriented replication (e.g., independent reruns of the same critique to detect non-determinism). No diversification — every replica receives the same model, prompt, seed semantics, and constraints.

## Position
Runs after `validate` (and `isolate`, when isolation is in play) and before `execute`. Pure (in-memory) except when consuming `isolations` as per-replica workspace assignments.

## Input Contract

### Required
- `template` (job_spec) — a complete job spec (the fields `execute` will consume: `task`, `model`, `subagent_*`, `test_command`, `stop_condition`, `guardrails`, `seed`, `temperature`). Produced by composing `resolved_task`, `resolved_context`, and any explicit overrides.
- `k` (int, int_range: `>= 1`, aliases: `n_candidates`, `num_experiments`) — number of replicas to produce.

### Optional
- `parallel` (int, int_range: `>= 1`, default: `min(k, 1)`) — maximum concurrent executions hint passed forward to `execute` / scheduler.
- `isolations` (list<isolation_record>, default: `[]`) — assignments produced by `isolate`. When non-empty, `len(isolations) MUST == k`; replica `i` is bound to `isolations[i]`.
- `index_base` (int, default: `1`) — first replica index (1-based by default to match human-facing reports).
- `seed_strategy` (enum: `shared` | `per-replica-from-base`, default: `shared`) — when `shared`, every replica reuses `template.seed`; when `per-replica-from-base`, replica `i` uses `template.seed + i` (still deterministic but distinguishable in logs).

## Output Contract

- `jobs` (list<job_spec>) — `k` entries, each carrying:
  - `index` (int)
  - all fields from `template`, byte-identical except `index`, optional `seed_offset`, and optional `isolation_id`
  - `isolation_id` (string | null) — bound when `isolations` was supplied
- `replication_summary` (map) — `{ k, parallel, seed_strategy, isolation_bound: bool }`.

## Depth-Aware Aliasing

- `replicate[0].k` is the outer replication count; `replicate[1].k` is the inner replication count (e.g., each outer replica is itself replicated for inner cross-checks).
- Effective workload = product of nested `k`s: `replicate[0].k * replicate[1].k * …`. `validate` SHOULD warn if the product exceeds a configured budget.
- `parallel` cascades inward: inner `parallel` defaults to `outer.parallel / outer.k`, rounded down (so total concurrency does not exceed outer budget). An explicit inner `parallel` overrides.

## Composition Rules

- Predecessors: `validate`, optionally `isolate`.
- Successors: `execute` (consumes `jobs`); typically followed by `evaluate` → `aggregate`.
- `replicate` MUST NOT diversify; if you need different models / seeds / hints per slot, use `fan-out` instead. Mixing the two (e.g., replicate-then-fan-out per replica) is legal and depth-aliased.
- Contrast with `fan-out`: `replicate` produces *interchangeable* outputs; `aggregate` typically uses voting / convergence semantics on them.

## Examples

### Example 1: critique — 5 independent runs of the same critique

```yaml
stage: replicate
template:
  task: "Critique critique.md against clarity + determinism"
  model: claude-opus
  context_ref: input-resolve[0].resolved_context
  criteria_ref: input-resolve[0].resolved_criteria
k: 5
parallel: 3
seed_strategy: per-replica-from-base
outputs:
  jobs:
    - { index: 1, model: claude-opus, seed_offset: 1, isolation_id: null, ... }
    - { index: 2, model: claude-opus, seed_offset: 2, isolation_id: null, ... }
    - { index: 3, ... }
    - { index: 4, ... }
    - { index: 5, ... }
  replication_summary: { k: 5, parallel: 3, seed_strategy: per-replica-from-base, isolation_bound: false }
```

### Example 2: replicate bound to isolations (rare; isolation but no diversification)

```yaml
stage: replicate
template:
  task: "Run the test suite and report flakiness"
  model: claude-opus
  test_command: "pnpm test"
k: 3
isolations: [<from isolate output, len=3>]
outputs:
  jobs:
    - { index: 1, isolation_id: flake-1-..., test_command: "pnpm test", ... }
    - { index: 2, isolation_id: flake-2-..., test_command: "pnpm test", ... }
    - { index: 3, isolation_id: flake-3-..., test_command: "pnpm test", ... }
```
