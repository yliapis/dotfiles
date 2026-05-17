# Concern: Models / Diversity

> **Responsibility:** Declare *which model* runs the work, with *what sampling parameters*, and with *what diversity dials* applied across candidates. This concern owns model identity and generation behavior; it does not own *how many* candidates (see [replication.md](./replication.md)) or *which* candidate wins (see [selection.md](./selection.md)).
>
> **Primary parameters:** `model`, `agent_model`, `focus_hints`, `seed`, `temperature`

## Why this concern exists

"Which model" is the loudest knob for cost and quality. "How to make candidates differ from each other" is the second loudest — three random samples from one model differ less than three runs across three models, and three runs with three different focus hints differ more usefully still. Putting model identity (`model`, `agent_model`), sampling controls (`seed`, `temperature`), and diversity dials (`focus_hints`) in one file lets the prompt author tune all three together, since they trade off against each other (more `temperature` ≈ less need for varied `focus_hints`, etc.).

`agent_model` and `subagent_model` (the latter in [subagent-tree.md](./subagent-tree.md)) are the same concept at different layers. We document `agent_model` as the primary because that's the name `/worktree-task-agent` uses, and the subagent-tree file cross-references back here.

## Parameters

### `model`

**Aliases:** `llm`, `model_id`
**Definition:** The model identifier used for the work this invocation does *directly* (i.e. the model the command itself runs on, before any subagent spawn).
**Type:** `string` — provider-qualified model identifier (e.g. `anthropic/claude-sonnet-4.5`, `openai/gpt-4o`).
**Default:** The parent agent's current model (inherited).

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | The model used for the command's own response (which may then spawn subagents on other models). `/critique` uses `model` for each analysis run. |
| **subagent** | The model the child runs on; passed explicitly via `subagent_model` / `agent_model`. If unset, inherits from the parent. Different subagents in the same fan-out may use different models. |
| **skill** | Skills do not own `model`; they reference the calling command's `model` when their behavior should adapt (e.g. a "use longer chain-of-thought for weaker models" skill). |

**Cross-refs:**

- [`agent_model` (this file)](#agent_model) — same concept, used at the worktree layer.
- [`subagent_model` (subagent-tree.md)](./subagent-tree.md#subagent_model) — same concept, used at the subagent-tree layer.
- [`temperature` (this file)](#temperature) / [`seed` (this file)](#seed) — sampling controls that compose with `model`.

**Example:** `/critique context=./auth.py model=anthropic/claude-opus-4.7` — analysis runs on Opus.

---

### `agent_model`

**Aliases:** `worktree_model`, `worker_model`
**Definition:** The model identifier(s) used by sibling worktree agents in a parallel fan-out. The worktree-layer name for the same concept `model` represents at the command layer.
**Type:** `string | string[]` — single identifier (broadcast to every sibling) or a list whose length MUST equal `parallelism` (positionally mapped per sibling).
**Default:** The parent agent's model (inherited).

**Cross-refs:**

- [`model` (this file)](#model) — same concept; `model` is the canonical name at the command depth.
- [`parallelism` (replication.md)](./replication.md#parallelism) — list-form length must equal `parallelism`.
- [`num_partitions` (replication.md)](./replication.md#num_partitions) — when `num_partitions > 1` and `agent_model` is iterable, the iterable must be either a full iteration or a correctly-sized slice across partitions.
- [`subagent_model` (subagent-tree.md)](./subagent-tree.md#subagent_model) — the recursive layer's name; identical semantics.

**Example:** `/worktree-task-agent task=X parallelism=3 agent_model=[gpt-4o, sonnet-4.5, gemini-2.5]` — three sibling agents, one per model.

---

### `focus_hints`

**Aliases:** `refinement_angles`, `diversity_hints`
**Definition:** Per-candidate angles or refinement directions that diversify what each candidate *focuses on* (without changing the underlying `task`).
**Type:** `string[]` — list of natural-language hints. Length must equal `n_candidates` (or a divisor compatible with `num_partitions`).
**Default:** Empty (no per-candidate angle; diversity comes only from `temperature`/`seed`/`agent_model`).

**Cross-refs:**

- [`n_candidates` (replication.md)](./replication.md#n_candidates) — length constraint.
- [`num_partitions` (replication.md)](./replication.md#num_partitions) — when partitioned, `focus_hints` per partition.
- [`subagent_prompt` (subagent-tree.md)](./subagent-tree.md#subagent_prompt) — children's prompts interpolate their assigned hint.
- [`task` (task.md)](./task.md#task) — `focus_hints` *narrow* a shared `task`; they do not replace it.

**Example:** `/meta-prompt n_candidates=3 focus_hints=["tighten guardrails", "clarify parameters", "improve workflow steps"]` — three refined prompts, each emphasizing a different angle.

---

### `seed`

**Aliases:** `random_seed`, `sampling_seed`
**Definition:** Integer seed passed to the model's sampling RNG for reproducibility.
**Type:** `int_range >= 0` (or `null` for non-deterministic). See [`constraints.md#int_range`](./constraints.md#int_range).
**Default:** `null` (no seed; sampling is non-deterministic).

**Cross-refs:**

- [`temperature` (this file)](#temperature) — at `temperature=0`, `seed` is mostly redundant.
- [`n_candidates` (replication.md)](./replication.md#n_candidates) — with `n_candidates > 1` and a fixed `seed`, candidates collapse to the same output (defeating the purpose of replication unless `focus_hints` or `agent_model` differ).

**Example:** `/critique context=./x.py model=sonnet-4.5 seed=42 num_experiments=3` — three runs that, modulo provider non-determinism, agree exactly.

---

### `temperature`

**Aliases:** `temp`, `sampling_temperature`
**Definition:** Sampling temperature controlling output entropy; higher = more diverse, lower = more deterministic.
**Type:** `float` in `[0.0, 2.0]` typically (provider-dependent).
**Default:** Provider-specific (often `1.0`); commands inherit parent's setting.

**Cross-refs:**

- [`seed` (this file)](#seed) — `seed` + `temperature=0` ≈ determinism.
- [`focus_hints` (this file)](#focus_hints) — `temperature` and `focus_hints` are complementary diversity dials.

**Example:** `/meta-prompt n_candidates=5 temperature=1.2` — five refined prompts with high sampling diversity but no explicit angle hints.
