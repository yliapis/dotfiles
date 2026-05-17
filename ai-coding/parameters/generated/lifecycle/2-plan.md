# Stage 2 — Plan

**Position in lifecycle:** runs after **input** has resolved every value; runs before any execution.

**Purpose:** decide the **topology** of the run — how many agents, in what shape, with what diversity, under what guardrails. Plan turns a resolved parameter bag into an execution graph. Nothing observable happens to the world here; only the orchestration plan is built.

**Flows in:** the resolved parameter bag from input.
**Flows out:** an execution graph — a set of slots, each with a model, a prompt (`subagent_prompt`), a slice of work, a stopping rule, and a timeout. Plus the partition / fan-out structure.

**Skipped when:** never (even a 1-agent, 1-slot run runs a trivial plan stage). Often degenerate, but always present.

**Key invariant:** plan is **side-effect-free**. If plan succeeds, execute can start; if plan fails (e.g. invalid `parallel` value), the run aborts with zero filesystem changes. `worktree-task-agent.md` codifies this: validation failure "aborts with an explanatory error and no filesystem side effects."

---

## Replication / fan-out

### `parallel`

**Aliases:** `parallelism`, `concurrency`, `max_workers`
**Definition:** Maximum number of agents running at the same wall-clock time.
**Stages:** plan (decision) → execute (orchestration).
**Depth:** **both.** Outer = how many subagents the command fans out. Inner = how many sub-subagents each subagent may itself launch.
**Type:** `int_range[>= 1]`.
**Default:** `1`.

**Examples:**

```
{parallel} = 4        # outer: run 4 critique agents at once
inner_{parallel} = 1  # each critique agent itself runs single-threaded
```

`critique.md` uses `{parallel}` as a worker cap that may be lower than `{num_experiments}`:

> "schedule `{num_experiments}` independent analysis runs, dispatching up to `{parallel}` at a time"

### `n_candidates`

**Aliases:** `k`, `num_candidates`, `num_experiments`
**Definition:** Total number of independent attempts at the same task / analysis.
**Stages:** plan (decision) → execute (instantiation).
**Depth:** both. Outer = total candidate count for the command; inner = per-subagent fan-out into its own children.
**Type:** `int_range[>= 1]`.
**Default:** `1`.

**Examples:**

```
{n_candidates}    = 8   # generate 8 prompt refinements
{num_experiments} = 5   # run critique 5 times
```

Relationship to `parallel`: `n_candidates` is the *total* count, `parallel` is the *batch width*. When `n_candidates > parallel`, slots run in waves.

### `num_partitions`

**Aliases:** `partitions`, `num_groups`
**Definition:** Number of groups the agents (or their inputs) are split into; each partition shares a config slice.
**Stages:** plan (decision) → execute (per-partition setup).
**Depth:** both.
**Type:** `int_range[>= 1]`.
**Default:** `1` (no partitioning — all agents in one logical group).

**Open semantics** (per `trajectory.md`): when `num_partitions > 1` and `agent_model` is iterable, `agent_model` MUST be either a full iteration across all agents *or* a correctly-sized slice across partitions. Plan validates this; execute relies on it.

**Example:**

```
{n_candidates}    = 8
{num_partitions}  = 2
{agent_model}     = ["claude-opus", "gpt-5"]   # one model per partition
                   # ⇒ 4 agents on claude-opus, 4 on gpt-5
```

### `depth`

**Aliases:** `recursion_depth`, `max_depth`
**Definition:** Maximum nesting level — how many times a subagent may itself spawn subagents.
**Stages:** plan (limit) → execute (enforced).
**Depth:** both. Outer = the command's max depth; inner counts inherit, decremented at each level.
**Type:** `int_range[>= 0]`. `0` = no nesting (flat fan-out only).
**Default:** `0`.

**Example:**

```
{depth} = 2   # outer can spawn inner can spawn inner-inner, but no deeper
```

### `fan_out`

**Aliases:** `branching_factor`
**Definition:** Per-node fan-out in the subagent tree (independent of `parallel`, which is a wall-clock cap).
**Stages:** plan (topology) → execute (instantiation).
**Depth:** both.
**Type:** `int_range[>= 1]`.
**Default:** `1` (each node has one child — i.e. no fan-out at this level).

**Example:**

```
{depth}   = 1
{fan_out} = 3
# tree shape: 1 outer → 3 inner → each does its work
```

---

## Subagent-tree parameters

These are the per-slot definitions plan emits for execute. All are **inner-depth** by definition (they describe what the children are).

### `subagent_type`

**Aliases:** `agent_kind`, `role`
**Definition:** A label naming the kind of work a subagent performs (e.g. `critic`, `coder`, `summarizer`).
**Stages:** plan (assigned) → execute (drives prompt selection and tool restrictions).
**Depth:** inner.
**Type:** string id, often constrained to a command-specific enum.
**Default:** `"default"` (inherit the outer agent's role).

**Example:**

```
{subagent_type} = "critic"
{subagent_type} = "coder"
```

### `subagent_prompt`

**Aliases:** `child_prompt`, `inner_prompt`, `slot_prompt`
**Definition:** The full prompt body handed to a single subagent slot.
**Stages:** plan (written) → execute (consumed by that subagent).
**Depth:** inner.
**Type:** text, typically derived by templating `{task}` + `{focus_hints}[i]` + slot context.
**Default:** derived from outer `{task}` and slot index.

**Example:**

```
{subagent_prompt}[i=2] = "Refine this prompt. Focus angle: tighten guardrails. Original:\n<task>"
```

### `subagent_model`

**Aliases:** `child_model`
**Definition:** Model identifier each subagent runs on.
**Stages:** plan (assigned) → execute (used).
**Depth:** inner.
**Type:** model id string, or list of length `n_candidates` (positional mapping).
**Default:** inherit outer `{model}`.

**Example:**

```
{subagent_model} = "claude-opus-4"
{subagent_model} = ["claude-opus-4", "gpt-5", "gemini-2-pro", "claude-opus-4"]
```

This is the canonical name; commands often alias to `{agent_model}` when there's only one nesting level (see `worktree-task-agent.md`).

### `subagent_constraints`

**Aliases:** `child_guardrails`, `inner_guardrails`
**Definition:** Per-subagent guardrails layered on top of inherited outer guardrails.
**Stages:** plan (written) → execute (enforced) → evaluate (verified).
**Depth:** inner.
**Type:** text or `source_ref`.
**Default:** inherit outer `{guardrails}` verbatim.

**Example:**

```
{subagent_constraints} = "MUST NOT touch files outside ./src/auth/"
```

---

## Diversity / non-determinism

These exist to make N candidates *different from each other* on purpose. Without them, N=8 may collapse into 8 near-identical outputs.

### `focus_hints`

**Aliases:** `angles`, `slot_hints`, `diversification_hints`
**Definition:** A list of distinct framings — one per candidate — to bias each subagent toward a different angle.
**Stages:** plan (assigned per-slot) → execute (templated into the prompt).
**Depth:** both. Outer = the list. Inner = the per-slot scalar (`focus_hints[i]`).
**Type:** list of text. Length SHOULD equal `n_candidates`; shorter lists cycle, longer lists truncate (per `trajectory.md`'s noted convention).
**Default:** none (all subagents see the same prompt).

**Example (from `trajectory.md`):**

```
{focus_hints} = [
  "tighten guardrails",
  "clarify parameters",
  "improve workflow steps",
  "add edge-case handling"
]
```

### `seed`

**Aliases:** `rng_seed`
**Definition:** A deterministic seed forwarded to each subagent (when its model supports it).
**Stages:** plan (assigned per-slot) → execute (forwarded).
**Depth:** both.
**Type:** int.
**Default:** unset (model picks its own).

**Example:**

```
{seed}    = 42           # broadcast
{seed}[i] = 42 + i       # per-slot derivation, reproducible across re-runs
```

### `temperature`

**Aliases:** `temp`
**Definition:** Sampling temperature forwarded to each subagent.
**Stages:** plan (assigned per-slot) → execute (forwarded).
**Depth:** both.
**Type:** float in `[0, 2]`, or list of same length as `n_candidates`.
**Default:** model default.

**Example:**

```
{temperature} = 0.7
{temperature} = [0.2, 0.5, 0.8, 1.0]   # explore diversity at high end
```

---

## Robustness / recovery (configured at plan, enforced at execute)

### `timeout`

**Aliases:** `time_limit`, `wall_clock_limit`
**Definition:** Per-agent wall-clock deadline.
**Stages:** plan (configured) → execute (enforced).
**Depth:** both.
**Type:** duration string (`30m`, `2h`, `90s`) or seconds as int.
**Default:** unset (no deadline).

**Example:**

```
{timeout} = 20m
```

### `relaunch_on_hang_after`

**Aliases:** `hang_timeout`
**Definition:** Duration of no-progress after which a subagent is auto-aborted and replaced.
**Stages:** plan (configured) → execute (monitored + acted on).
**Depth:** both.
**Type:** duration; usually shorter than `timeout` (hang ≠ slow).
**Default:** unset.

**Example (from `trajectory.md`'s open ideas):**

```
{relaunch_on_hang_after} = 5m
```

Notional behavior: if a slot produces no tool calls or stdout for 5 minutes, abort it; replacement is governed by `hang_policy`.

### `retry_policy`

**Aliases:** `retries`, `retry_spec`
**Definition:** How many retries each slot gets on transient failure, and the backoff between attempts.
**Stages:** plan (configured) → execute (applied).
**Depth:** both.
**Type:** object — `{ max_retries: int_range[>= 0], backoff: linear|exponential|none, base_delay: duration }`.
**Default:** `{ max_retries: 0 }` (no retries).

**Example:**

```
{retry_policy} = { max_retries: 2, backoff: exponential, base_delay: 30s }
```

### `hang_policy`

**Aliases:** `on_hang`
**Definition:** What to do when `relaunch_on_hang_after` fires.
**Stages:** plan (configured) → execute (applied).
**Depth:** both.
**Type:** enum `ignore | abort | relaunch | replace`.
   - `ignore`: log and continue waiting (legacy behavior).
   - `abort`: kill the slot, record `incomplete`.
   - `relaunch`: kill and restart with same prompt + seed.
   - `replace`: kill and restart with a fresh slot id (new `seed`).
**Default:** `ignore` (current behavior; `trajectory.md` flags this as a gap).

**Example:**

```
{hang_policy} = relaunch
```

### `min_successes`

**Aliases:** `success_threshold`
**Definition:** Minimum number of slots that must complete successfully for the select stage to proceed.
**Stages:** plan (threshold set) → evaluate (counted) → select (gating predicate).
**Depth:** outer (a tree-wide threshold).
**Type:** `int_range[0, n_candidates]`.
**Default:** `1`.

**Example:**

```
{n_candidates}    = 8
{min_successes}   = 5
# fail the entire invocation unless at least 5 of 8 slots succeeded
```

---

## Isolation / workspace (planned topology that execute realizes, persist cleans up)

### `isolation`

**Aliases:** `sandbox`, `isolation_mode`
**Definition:** The boundary inside which each subagent runs.
**Stages:** plan (decision) → execute (sandbox setup) → persist (cleanup honors the same boundary).
**Depth:** outer (typically — siblings share an isolation kind).
**Type:** enum `none | worktree | container | vm`.
**Default:** `worktree` for code-modifying commands; `none` for read-only commands.

**Example:**

```
{isolation} = worktree   # worktree-task-agent's default
{isolation} = none       # critique reads but doesn't write
```

### `worktree_name`

**Aliases:** `branch_name`, `wt_name`
**Definition:** Base name for the worktree directory and its branch.
**Stages:** plan (derived per-slot) → execute (worktree creation) → persist (referenced for cleanup).
**Depth:** outer (the base name); slot index is the inner discriminator (`-1`, `-2`, …).
**Type:** filesystem-safe kebab-case string.
**Default:** derived from `{task}`.

**Example:**

```
{worktree_name} = "keyboard-nav"
# with parallel=3 → branches: keyboard-nav-1, keyboard-nav-2, keyboard-nav-3
```

### `worktree_root`

**Aliases:** `wt_root`, `worktrees_dir`
**Definition:** Directory under which all sibling worktrees are created.
**Stages:** plan (chosen) → execute (used) → persist (cleanup target).
**Depth:** outer.
**Type:** directory path (must exist or be creatable).
**Default:** `~/.cursor/worktrees/<WORKTREE_ID>/` per the `/worktree` command convention.

**Example:**

```
{worktree_root} = "~/scratch/wt"
```

### `base_branch`

**Aliases:** `start_ref`, `start_branch`
**Definition:** Git ref each worktree is forked from.
**Stages:** plan (resolved if not user-specified) → execute (worktree start point) → persist (merge target).
**Depth:** outer.
**Type:** any git commit-ish — branch name, tag, full SHA, `origin/main`.
**Default:** current branch (`git rev-parse --abbrev-ref HEAD`).

**Example:**

```
{base_branch} = main
{base_branch} = origin/release/2.1
```

---

## Cross-stage notes

- **Plan is the natural home of `int_range` checks for topology params.** `parallel`, `n_candidates`, `num_partitions`, `depth`, `fan_out`, `min_successes` all interact (e.g. `min_successes <= n_candidates`); plan enforces the joint constraint, not input alone.
- **Diversity params (`focus_hints`, `seed`, `temperature`) are the primary lever against "N near-identical candidates."** `trajectory.md` flags this as an open question ("How should non-determinism be controlled across parallel agents — distinct `{agent_model}` per slot, varied temperature, or distinct `{focus_hints}`?"). Plan is where the answer is committed.
- **What plan does NOT do:** any I/O, any model call, any worktree creation. If plan fails, the world is unchanged.
