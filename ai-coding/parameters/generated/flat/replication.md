# Replication / Parallelism (Category D)

Covers *how many* independent slots run, *how concurrently* they run, *how slots group into partitions*, and *how many must succeed* for the run to be considered acceptable.

Under the flat angle, every "count" parameter that could mean "outer" or "inner" gets its layer prefix. The base-inventory shorthand `k`, `n_candidates`, `num_experiments`, `parallel`, `parallelism` is **not** valid here — pick the layer-specific variant.

---

## `outer_k`

**Aliases (deprecated under this angle):** `k`, `n_candidates`, `num_experiments`, `replications`.
**Definition:** Number of independent top-level slots the command launches; i.e., the fan-out factor at the orchestrator layer.
**Type:** integer.
**Allowed values:** `int_range: ">= 1"`.
**Default:** `1` (single slot, no fan-out).
**Rename rationale (multi-depth):** every command and trajectory note picks a slightly different shorthand for the same concept (`{num_experiments}` in `critique`, `{parallelism}` in `worktree-task-agent` *also* sets it, `{n_candidates}` in trajectory notes for `meta-prompt`). Collapsing them to one canonical name with explicit "outer" layer removes the cross-command vocabulary drift.
**Consumed by:** `critique` (renamed from `{num_experiments}`), `worktree-task-agent` (renamed from `{parallelism}` as a sibling-count *separate* from its parallel-execution count), future `refine-best-of-n` (renamed from `{n_candidates}`).
**Example:**

```
outer_k: 4         # launch 4 independent slots
outer_k: 1         # no fan-out (single run)
```

---

## `inner_k`

**Aliases (deprecated under this angle):** `k` (when nested), `sub_k`, `child_k`.
**Definition:** Number of independent slots launched *inside* one outer slot; i.e., the fan-out factor at the subagent layer when subagents themselves fan out.
**Type:** integer.
**Allowed values:** `int_range: ">= 1"`.
**Default:** `1`.
**Rename rationale (multi-depth):** nested fan-out (best-of-N at level 1, then best-of-M at level 2) is an open design question in `trajectory.md`. Without distinct names, the total work `outer_k * inner_k` cannot be expressed without parenthesizing.
**Consumed by:** future nested fan-out commands; not yet exercised by any command in this repo, but reserved.
**Example:**

```
outer_k: 3
inner_k: 2          # 3 outer slots, each spawning 2 inner replicates = 6 total
```

---

## `command_parallel`

**Aliases (deprecated under this angle):** `parallel`, `parallelism`, `concurrency` (at the orchestrator layer).
**Definition:** Maximum number of outer slots running concurrently at any moment; an execution cap, independent from `outer_k` (the *total* count).
**Type:** integer.
**Allowed values:** `int_range: ">= 1"`. MUST satisfy `command_parallel <= outer_k`.
**Default:** `1` (strictly sequential).
**Rename rationale (multi-depth):** `critique.md` uses `{parallel}`; `worktree-task-agent.md` uses `{parallelism}` and conflates it with `outer_k` (i.e., it always launches `parallelism` slots and runs them all concurrently). The flat angle splits "how many total" (`outer_k`) from "how many at once" (`command_parallel`) and prefixes by layer.
**Consumed by:** `critique` (`{parallel}`), `worktree-task-agent` (the concurrent-execution slice of `{parallelism}`).
**Example:**

```
outer_k: 8
command_parallel: 4    # 8 slots total, at most 4 running at once
```

---

## `subagent_parallel`

**Aliases (deprecated under this angle):** `parallel` (when describing concurrency inside one slot).
**Definition:** Maximum number of inner slots a single outer subagent runs concurrently when it itself fans out.
**Type:** integer.
**Allowed values:** `int_range: ">= 1"`. MUST satisfy `subagent_parallel <= inner_k`.
**Default:** `1`.
**Rename rationale (multi-depth):** see `inner_k`. Required to disambiguate execution cap at the subagent layer.
**Consumed by:** future nested fan-out.
**Example:**

```
inner_k: 4
subagent_parallel: 2
```

---

## `outer_partitions`

**Aliases (deprecated under this angle):** `num_partitions`, `partitions`.
**Definition:** Number of partitions the outer slots group into; each partition typically shares a `subagent_context` slice, a `subagent_model`, or a `focus_hints` value.
**Type:** integer.
**Allowed values:** `int_range: ">= 1"`. MUST divide `outer_k` evenly when slot-broadcast is in use, or MUST satisfy `subagent_*` iterable length checks (see `worktree-task-agent.md` parameter validation rules for the iterable-shape contract).
**Default:** `1` (no partitioning; all outer slots are interchangeable replicates).
**Rename rationale (multi-depth):** `num_partitions` exists only at the outer layer in current usage; renaming makes the layer explicit and reserves room for a future `inner_partitions` without retroactive renaming.
**Consumed by:** `worktree-task-agent` (`{num_partitions}`); open semantics noted in `trajectory.md`.
**Example:**

```
outer_k: 6
outer_partitions: 3        # 3 partitions × 2 replicates per partition
subagent_model: ["gpt-5", "gpt-5", "claude-4.7", "claude-4.7", "gemini-2.5", "gemini-2.5"]
```

---

## `min_successes`

**Aliases:** `min_passing`, `success_threshold`.
**Definition:** Minimum number of outer slots that must report `success` before selection or aggregation may proceed; if fewer succeed, the run is reported as failed and no aggregation is attempted.
**Type:** integer.
**Allowed values:** `int_range: "[0, outer_k]"`.
**Default:** `1`.
**Rename rationale (multi-depth):** described in `trajectory.md` as an open need ("Hung subagents (2 of 8 in one batch) returned no diff..."). Single-layer concept at the orchestrator; no rename needed beyond not having an `outer_` prefix (kept short by convention since there is no inner counterpart).
**Consumed by:** future `refine-best-of-n`; any fan-out with a success gate.
**Example:**

```
outer_k: 8
min_successes: 5      # need at least 5 of 8 slots to pass
```
