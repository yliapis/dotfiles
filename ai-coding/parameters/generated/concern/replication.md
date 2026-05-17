# Concern: Replication / Parallelism

> **Responsibility:** Declare *how many copies* of the same task run, and *how concurrently*. Replication answers questions of cardinality and concurrency; it does not answer "with which model" (see [models.md](./models.md)), "in what shape of tree" (see [subagent-tree.md](./subagent-tree.md)), or "how to pick the winner" (see [selection.md](./selection.md)).
>
> **Primary parameters:** `n_candidates`, `parallelism`, `num_partitions`

## Why this concern exists

A single command can want any of:

- **One result, run once** — the trivial case.
- **N results, run sequentially** — fan out for diversity but throttle concurrency (token-budget or rate-limit constraints).
- **N results, all concurrent** — maximum wall-clock speed.
- **K partitions of N results** — grouped fan-out where each partition has homogeneous internal characteristics (same model, same focus hint) and partitions differ from each other.

These four shapes are all expressible with `n_candidates` × `parallelism` × `num_partitions`. Grouping them in one concern lets the prompt author reason about cardinality once and only once, then layer model-diversity, selection, and isolation independently.

## Parameters

### `n_candidates`

**Aliases:** `k`, `num_experiments`, `n`
**Definition:** The number of independent candidate runs of the same task produced in one invocation.
**Type:** `int_range >= 1`. See [`constraints.md#int_range`](./constraints.md#int_range).
**Default:** `1`.

**Cross-refs:**

- [`parallelism` (this file)](#parallelism) — `parallelism <= n_candidates`; concurrency cap on candidates.
- [`selection.md`](./selection.md) — the whole selection concern only meaningfully applies when `n_candidates > 1`.
- [`focus_hints` (models.md)](./models.md#focus_hints) — if supplied as a list, length is constrained against `n_candidates`.
- [`min_successes` (selection.md)](./selection.md#min_successes) — typed `int_range [0, n_candidates]`.

**Example:** `/critique context=./auth.py num_experiments=4 parallel=2` — `n_candidates=4` (alias `num_experiments`); 4 independent analyses are produced, throttled to 2 concurrent.

---

### `parallelism`

**Aliases:** `parallel`, `concurrency`, `max_concurrent`
**Definition:** The maximum number of candidates that may run *concurrently*. Sequential when `1`.
**Type:** `int_range >= 1`. See [`constraints.md#int_range`](./constraints.md#int_range).
**Default:** `1`.

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | Concurrency cap on candidates of *this command's* fan-out. Validated before any worktree / subagent is created (`/worktree-task-agent` fails fast on `parallelism < 1`). |
| **subagent** | Concurrency cap on the children spawned by *this* subagent (children of a parent that itself is one of N siblings). Stacks multiplicatively across depth: a `depth=2`, `fan_out=4`, `parallelism=4` tree has up to 16 leaf agents alive at once. |
| **skill** | Skills do not own `parallelism`; they reference it when their workflow can opt into parallelism (e.g. a "lint everything" skill picks a worker count from `parallelism` if provided). |

**Cross-refs:**

- [`n_candidates` (this file)](#n_candidates) — what's being throttled.
- [`fan_out` (subagent-tree.md)](./subagent-tree.md#fan_out) — at the subagent layer, `parallelism` caps how many of `fan_out` children run at once.
- [`num_partitions` (this file)](#num_partitions) — partitions are scheduled within the `parallelism` budget.

**Example:** `/worktree-task-agent task="Refactor X" parallelism=4` — four sibling worktree agents run simultaneously; with `parallelism=1` they would run sequentially.

---

### `num_partitions`

**Aliases:** `partitions`, `slots`
**Definition:** The number of partitions the fan-out is divided into. Each partition contains one or more candidates that share characteristics (typically the same model or the same focus hint).
**Type:** `int_range >= 1`. See [`constraints.md#int_range`](./constraints.md#int_range).
**Default:** `1` (no partitioning; all candidates are siblings in one undifferentiated fan-out).

**Cross-refs:**

- [`agent_model` (models.md)](./models.md#agent_model) — when `agent_model` is iterable and `num_partitions > 1`, the iterable must be either a *full iteration across all candidates* or a *correctly-sized slice across partitions* (per `/worktree-task-agent`'s validation rule). Other shapes fail fast.
- [`focus_hints` (models.md)](./models.md#focus_hints) — same shape contract as `agent_model` when paired with `num_partitions`.
- [`subagent-tree.md`](./subagent-tree.md) — partitions are *not* the same as tree depth; a partition is a horizontal grouping at one depth, while depth adds vertical structure.

**Example:** `/worktree-task-agent task="Refactor X" parallelism=8 num_partitions=4 agent_model=[gpt-4o, sonnet-4.5, gemini-2.5, grok-3]` — 4 partitions × 2 candidates each; partition `i` uses `agent_model[i]`, broadcast to its two candidates.
