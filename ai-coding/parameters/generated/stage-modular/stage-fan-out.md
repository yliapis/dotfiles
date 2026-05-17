# Stage: `fan-out`

## Purpose
Materialize `k` *diversified* job specs from a single template, varying along one or more axes (model, seed, temperature, focus hints, partition slot). Used when the goal is exploration / best-of-N — distinct from `replicate`, which preserves identity across slots.

## Position
Runs after `validate` (and `isolate`, when isolation is in play) and before `execute`. Pure (in-memory) except when consuming `isolations` as per-slot workspace assignments.

## Input Contract

### Required
- `template` (job_spec) — the base job spec; per-slot variation overrides individual fields.
- `k` (int, int_range: `>= 1`, aliases: `fan_out`, `n_candidates`, `parallelism`) — number of diversified slots to produce.

### Optional
- `agent_model` (model_id | list<model_id>, default: `template.model`) — model assignment.
  - **Scalar**: broadcasts to every slot.
  - **List of length `k`**: one model per slot, mapped positionally by index (list-by-agent).
  - **List of length `num_partitions`**: one model per partition, each partition's `k / num_partitions` slots share the model (list-by-partition).
- `num_partitions` (int, int_range: `>= 1`, default: `1`) — partition count. `validate` MUST ensure `k % num_partitions == 0` and that `agent_model` shape matches one of the three forms above.
- `focus_hints` (list<string>, default: `[]`) — one refinement angle per slot (e.g., `tighten guardrails`, `clarify parameters`). When non-empty, `len(focus_hints) MUST in {1, k, num_partitions}`.
- `seed` (int | list<int>, default: per-slot auto-derived `template.seed + index`) — explicit seeds per slot for reproducibility.
- `temperature` (float | list<float>, default: `template.temperature`) — per-slot temperature override.
- `parallel` (int, int_range: `>= 1`, default: `k`) — concurrency hint forwarded to `execute`.
- `isolations` (list<isolation_record>, default: `[]`) — `len(isolations) MUST == k` when provided; slot `i` binds to `isolations[i]`.
- `index_base` (int, default: `1`) — first slot index.

## Output Contract

- `jobs` (list<job_spec>) — `k` entries, each carrying:
  - `index` (int)
  - `partition_id` (int, 1-based) — populated when `num_partitions > 1`
  - `model` (model_id) — resolved per-slot model
  - `focus_hint` (string | null)
  - `seed` (int)
  - `temperature` (float | null)
  - `isolation_id` (string | null)
  - all other fields from `template`
- `partition_map` (map<int, list<int>>) — `partition_id -> list of slot indices`. Empty when `num_partitions == 1`.
- `fan_out_summary` (map) — `{ k, num_partitions, model_shape: scalar|by-agent|by-partition, parallel, isolation_bound: bool }`.

## Depth-Aware Aliasing

- `fan-out[0].k` is the outer fan width; `fan-out[1].k` is the inner fan width.
- Total workload at depth `d` is `∏ fan-out[i].k for i in 0..d`. `validate` SHOULD enforce a configured product ceiling.
- Inner `agent_model` defaults are *not* inherited from outer slots; each inner `fan-out` declares its own (intentional — outer diversification rarely makes sense as inner default).
- Inner `parallel` defaults to `floor(outer.parallel / outer.k)` so total concurrency is bounded.
- `focus_hints` are NEVER auto-cascaded inward; they belong to the depth at which they were declared.

## Composition Rules

- Predecessors: `validate`, optionally `isolate`.
- Successors: `execute` (consumes `jobs`); typically followed by `evaluate` → `aggregate` → `select`.
- `fan-out` MUST produce slots that differ in at least one diversification axis; if every axis is uniform, the pipeline SHOULD use `replicate` instead. `validate` MAY warn but does not enforce.
- `fan-out` and `replicate` are composable: `fan-out` then `replicate` produces "N variants × M independent retries each."

## Examples

### Example 1: worktree-task-agent — 8 slots, 4 partitions, list-by-partition model

```yaml
stage: fan-out
template:
  task: "Refactor auth.ts to remove legacy session code"
  test_command: "pnpm test"
k: 8                              # alias: parallelism = 8
num_partitions: 4
agent_model: ["opus", "sonnet", "haiku", "gpt-5"]   # by-partition
isolations: [<from isolate output, len=8>]
outputs:
  jobs:
    - { index: 1, partition_id: 1, model: opus,   seed: 1001, isolation_id: refactor-auth-1-... }
    - { index: 2, partition_id: 1, model: opus,   seed: 1002, isolation_id: refactor-auth-2-... }
    - { index: 3, partition_id: 2, model: sonnet, seed: 1003, isolation_id: refactor-auth-3-... }
    - { index: 4, partition_id: 2, model: sonnet, seed: 1004, isolation_id: refactor-auth-4-... }
    - { index: 5, partition_id: 3, model: haiku,  seed: 1005, isolation_id: refactor-auth-5-... }
    - { index: 6, partition_id: 3, model: haiku,  seed: 1006, isolation_id: refactor-auth-6-... }
    - { index: 7, partition_id: 4, model: gpt-5,  seed: 1007, isolation_id: refactor-auth-7-... }
    - { index: 8, partition_id: 4, model: gpt-5,  seed: 1008, isolation_id: refactor-auth-8-... }
  partition_map: { 1: [1,2], 2: [3,4], 3: [5,6], 4: [7,8] }
  fan_out_summary: { k: 8, num_partitions: 4, model_shape: by-partition, parallel: 8, isolation_bound: true }
```

### Example 2: meta-prompt with N=3 focus-hint-driven candidates

```yaml
stage: fan-out
template:
  task: "Refine the /pr-review prompt"
  model: claude-opus
k: 3
focus_hints:
  - "tighten guardrails"
  - "clarify parameters"
  - "improve workflow steps"
seed: [11, 22, 33]
outputs:
  jobs:
    - { index: 1, model: opus, focus_hint: "tighten guardrails", seed: 11 }
    - { index: 2, model: opus, focus_hint: "clarify parameters", seed: 22 }
    - { index: 3, model: opus, focus_hint: "improve workflow steps", seed: 33 }
  partition_map: {}
  fan_out_summary: { k: 3, num_partitions: 1, model_shape: scalar, parallel: 3, isolation_bound: false }
```
