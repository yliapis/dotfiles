# Concern: Subagent Tree

> **Responsibility:** Declare the *shape and identity* of the agent tree spawned underneath this invocation: what kind of children, how many levels deep, with what per-child prompt and constraints. Where [replication.md](./replication.md) answers "how many siblings", this concern answers "what about grandchildren? what about per-child specialization?".
>
> **Primary parameters:** `subagent_type`, `subagent_model`, `subagent_prompt`, `subagent_constraints`, `depth`, `fan_out`

## Why this concern exists

Replication parameters (`n_candidates`, `parallelism`, `num_partitions`) are sufficient for flat fan-out: one parent spawns N siblings. As soon as a workflow needs **recursive structure** — a parent that spawns children, each of which spawns grandchildren — the description becomes a tree, and a tree needs its own vocabulary: per-level branching factor (`fan_out`), tree height (`depth`), per-child identity and instructions (`subagent_type`, `subagent_model`, `subagent_prompt`), and per-child prohibitions (`subagent_constraints`).

Keeping this concern separate from replication is what lets a future `/refine-best-of-n` command (per [`trajectory.md`](../plugins/ai-coding/commands/trajectory.md)) compose `/meta-prompt` (which produces candidates) with `/worktree-task-agent` (which runs them) without confusing "how many candidates" with "what kind of children each candidate spawns".

## Parameters

### `subagent_type`

**Aliases:** `child_type`, `agent_kind`
**Definition:** The role / archetype of the spawned child agent (informs prompt selection, default model, default constraints).
**Type:** Enum: `worker | analyst | critic | synthesizer | router`. Extensible per command.
**Default:** `worker`.

**Cross-refs:**

- [`subagent_prompt` (this file)](#subagent_prompt) — `subagent_type` selects a default `subagent_prompt` template.
- [`subagent_model` (this file)](#subagent_model) — different types may default to different models (e.g. `critic` defaults to a stronger model).

**Example:** `subagent_type=critic` — children inherit the *critic* archetype (read-only, evidence-grounded) and use the `/critique`-style prompt.

---

### `subagent_model`

**Aliases:** `child_model`
**Definition:** Model identifier(s) used by spawned children.
**Type:** `string | string[]` — single identifier (broadcast) or list of identifiers (positionally mapped per child, length must equal `fan_out`).
**Default:** Inherits from parent's `model` (or `agent_model` at the worktree layer).

**Cross-refs:**

- [`model` (models.md)](./models.md#model) — primary home for model identity.
- [`agent_model` (models.md)](./models.md#agent_model) — at the worktree layer, `subagent_model` and `agent_model` are the same concept; `agent_model` is the established name in `/worktree-task-agent`.
- [`fan_out` (this file)](#fan_out) — list-form length must equal `fan_out`.

**Example:** `subagent_model=[gpt-4o, sonnet-4.5]` with `fan_out=2` — child 1 uses `gpt-4o`, child 2 uses `sonnet-4.5`.

---

### `subagent_prompt`

**Aliases:** `child_prompt`, `agent_prompt`
**Definition:** The literal prompt (or prompt template) supplied to each spawned child.
**Type:** `string` (template; may interpolate parent context).
**Default:** Selected by `subagent_type`; otherwise inherits the parent's `task` verbatim.

**Cross-refs:**

- [`task` (task.md)](./task.md#task) — `subagent_prompt` is usually derived from (or equal to) the parent's `task`.
- [`focus_hints` (models.md)](./models.md#focus_hints) — when `focus_hints` is a list, each child's `subagent_prompt` is augmented with its corresponding hint.

**Example:** `subagent_prompt="${task}\n\nFocus angle: ${focus_hints[i]}"` — template interpolates per-child focus hint into a shared task.

---

### `subagent_constraints`

**Aliases:** `child_guardrails`, `child_constraints`
**Definition:** Additional `MUST` / `MUST NOT` / `Scope` rules applied to children on top of the parent's `guardrails`.
**Type:** `inline` list of natural-language constraints.
**Default:** Empty (children inherit parent's `guardrails` only).

**Cross-refs:**

- [`guardrails` (constraints.md)](./constraints.md#guardrails) — parent-level prohibitions; children inherit them.
- [`isolation` (isolation.md)](./isolation.md#isolation) — children spawned into isolated workspaces inherit isolation-related guardrails automatically.

**Example:** `subagent_constraints=["MUST run only inside its assigned worktree", "MUST NOT push or open PRs"]` — strengthens isolation guarantees per child.

---

### `depth`

**Aliases:** `tree_depth`, `levels`
**Definition:** The maximum height of the spawned subagent tree (the root agent is at depth 0; its direct children are depth 1; their children depth 2, and so on).
**Type:** `int_range >= 0`. See [`constraints.md#int_range`](./constraints.md#int_range).
**Default:** `1` (one level of children).

**Cross-refs:**

- [`fan_out` (this file)](#fan_out) — branching factor at each level.
- [`parallelism` (replication.md)](./replication.md#parallelism) — across-depth concurrency is bounded by `parallelism` at each layer.

**Example:** `depth=2 fan_out=3` — root spawns 3 children, each of which spawns 3 grandchildren (9 leaves total).

---

### `fan_out`

**Aliases:** `branching_factor`, `children_per_node`
**Definition:** The number of children each parent node in the subagent tree spawns. Constant across depth unless the command specifies a per-depth schedule.
**Type:** `int_range >= 1`. See [`constraints.md#int_range`](./constraints.md#int_range).
**Default:** Equal to the calling command's `n_candidates` if defined; otherwise `1`.

**Cross-refs:**

- [`n_candidates` (replication.md)](./replication.md#n_candidates) — at depth 1, `fan_out == n_candidates` is the common case (flat fan-out).
- [`parallelism` (replication.md)](./replication.md#parallelism) — `parallelism` caps how many of `fan_out` children at a given parent run concurrently.
- [`depth` (this file)](#depth) — tree size is `fan_out^depth` for constant `fan_out`.

**Example:** `fan_out=4 depth=1` is the standard "flat best-of-4" pattern, equivalent to `n_candidates=4` at the parent.
