# `cross-layer.md` — Inheritance, Overrides, Shadowing

This file is the contract between layers. It exists because the same root name (`task`, `model`, `parallel`, `criteria`, …) appears in two or more `*.md` layer files with deliberately different semantics, and somebody has to define *how a value flows between them*.

**Read this whenever you encounter a layer parameter whose Definition says "Sibling root: …" or "Derived from `<other layer>.X`".**

---

## Resolution order (general)

When a subagent reads `subagent.X` and the orchestrator did not explicitly set it, the value is computed in this order:

1. **Skill contributions** that activated in this slot (unioned for set-shaped parameters; ignored for scalar-shaped parameters unless the skill explicitly overrides — see `skill.guardrails` and `skill.criteria`).
2. **Per-slot override** the orchestrator computed for this `subagent.slot_index` (e.g., `command.focus_hints[slot_index - 1]`).
3. **Broadcast from `command.X`** when the root name has a sibling at the command layer.
4. **Layer default** documented in `subagent.md`.
5. **Validation failure** if the parameter is required and nothing above produced a value.

Earlier wins. The orchestrator MUST record the resolved chain (which step produced the value) for any post-mortem.

For a `command.X` whose value is itself derived from skill activation, the order is: explicit user input → command default → skill contribution → validation failure.

---

## Cross-layer roots — at-a-glance

| Root | `command.*` | `subagent.*` | `skill.*` | Mode |
| --- | --- | --- | --- | --- |
| `task` | ✓ | ✓ | ✓ | rewrite (cmd→sub); categorical (skill) |
| `input` | ✓ | — | ✓ | distinct: raw vs categorical |
| `context` | ✓ | ✓ | — | broadcast or partition |
| `model` | ✓ (orchestrator) | ✓ | — | distinct roles; `command.agent_model` is the setter |
| `agent_model` | ✓ | — | — | resolver for `subagent.model` |
| `parallel` | ✓ (outer) | ✓ (inner) | — | orthogonal — NOT inherited |
| `num_partitions` | ✓ | — | — | orchestrator-only |
| `criteria` | ✓ | ✓ | ✓ | broadcast / partition / union |
| `guardrails` | ✓ | ✓ | ✓ | union (strictest-wins on conflict) |
| `stop_condition` | ✓ | ✓ | — | broadcast |
| `test_command` | ✓ | ✓ | — | broadcast |
| `save_path` | ✓ | ✓ | — | distinct: final vs intermediate |
| `output_format` | ✓ | ✓ | ✓ | downcast (cmd→sub); skill contributes invariant |
| `timeout` | ✓ | ✓ | — | orthogonal — NOT inherited |
| `seed` | ✓ | ✓ | — | broadcast with index offset |
| `temperature` | ✓ | ✓ | — | broadcast (commonly varied) |
| `base_branch` | ✓ | ✓ | — | broadcast |
| `verbosity` | ✓ | ✓ | — | broadcast with orchestrator downcast |
| `retry_policy` | ✓ | ✓ | — | orthogonal — different scopes |

Modes are defined under "Resolution modes" below; each per-root section below specifies which mode applies.

---

## Resolution modes (vocabulary)

- **broadcast**: the orchestrator copies one `command.X` value into every `subagent[i].X`.
- **zip**: the orchestrator copies `command.X[i-1]` into `subagent[i].X`. Length MUST equal `command.parallel` (or `command.num_partitions` in partition mode).
- **partition**: the orchestrator splits `command.X` into N disjoint pieces and assigns one piece per slot.
- **rewrite**: the orchestrator computes `subagent[i].X` as a *function* of `command.X` and per-slot context (e.g., focus hints, partition id). The subagent NEVER sees the raw `command.X`.
- **union**: the effective value is the set-theoretic union of every layer's contribution.
- **downcast**: the orchestrator translates a higher-level value into a stricter or more structured form for subagents, then translates back when rendering.
- **orthogonal**: the layers share a root name but the values are independent; no automatic flow.
- **distinct**: the layers share a root name but represent different *concepts*; no automatic flow.
- **categorical**: a skill-layer interpretation: the parameter describes a class of moments, not a single value.

---

## Per-root rules

### `task`

- Layers: `command.task`, `subagent.task`, `skill.task`.
- Mode: **rewrite** (command → subagent) and **categorical** (skill).
- Rule:
  - `subagent[i].task = rewrite(command.task, focus_hints[i-1], partition_i, criterion_i)`.
  - When `command.n_candidates = 1` AND no `command.focus_hints` AND no partitioning, the rewrite is the identity (`subagent[i].task = command.task`); the orchestrator MUST still log it as a rewrite to keep the contract explicit.
  - `skill.task` does NOT flow into `subagent.task`; it tells the runtime *when the skill activates*, after which the skill's contributions go through `guardrails`, `criteria`, and `output_format`.
- Worked example:
  ```text
  command.task: "Refine /pr-review prompt."
  command.n_candidates: 3
  command.focus_hints: ["tighten guardrails", "clarify parameters", "improve workflow"]

  subagent[1].task: "Refine /pr-review prompt with a focus on tighter guardrails."
  subagent[2].task: "Refine /pr-review prompt with a focus on clearer parameters."
  subagent[3].task: "Refine /pr-review prompt with a focus on better workflow steps."
  ```

---

### `input`

- Layers: `command.input`, `skill.input`.
- Mode: **distinct**.
- Rule: `command.input` is the literal text the user typed after the slash command; `skill.input` is a categorical description of the *kind* of payload the skill expects. They do not flow into each other and SHOULD NOT be confused at validation time. There is intentionally no `subagent.input`: subagents receive `subagent.task` and `subagent.context`, not the raw user message.

---

### `context`

- Layers: `command.context`, `subagent.context`.
- Mode: **broadcast** or **partition** (command-policy choice).
- Rule:
  - Default: broadcast. Every `subagent[i].context = command.context`.
  - When the command opts into partitioning (e.g., a critique with N criteria split across N slots), the orchestrator splits `command.context` into per-slot views and `subagent[i].context` is the i-th view.
  - The variant within `shared.addressable` MAY change: a `command.context: shared.directory` may broadcast as N `subagent.context: shared.file` entries (one file per slot) when the command partitions.

---

### `model`

- Layers: `command.model` (orchestrator's own), `subagent.model` (per-slot), with `command.agent_model` as the per-slot setter.
- Mode: **distinct** between `command.model` and `subagent.model`; **broadcast or zip** between `command.agent_model` and `subagent.model`.
- Rule (precedence, highest first):
  1. If `command.agent_model` is a list → `subagent[i].model = command.agent_model[i-1]` (zip). Length MUST equal `command.parallel`.
  2. If `command.agent_model` is a scalar → `subagent[i].model = command.agent_model` (broadcast).
  3. If `command.agent_model` is unset → `subagent[i].model = command.model`.
- Validation:
  - `command.agent_model` list length MUST equal `command.parallel` (or `command.num_partitions` in partition mode).
  - When `command.num_partitions > 1` and `command.agent_model` is iterable, the list MUST be either a full iteration over all slots OR a correctly-sized slice over partitions (see `partitions` below).

---

### `agent_model`

- Layers: `command.agent_model`.
- Mode: **resolver** — `command.agent_model` exists solely to populate `subagent.model`. It has no value of its own at runtime once subagents are launched.
- Rule: see `model` above.

---

### `parallel`

- Layers: `command.parallel` (outer fan-out across subagents), `subagent.parallel` (inner concurrency inside one subagent's tool loop).
- Mode: **orthogonal**.
- Rule: `subagent.parallel` is NEVER derived from `command.parallel`. They describe different concurrency axes. A subagent's inner parallelism (`subagent.parallel`) defaults to `1` and is only raised by an explicit `command.subagent_constraints` or per-slot override.
- Anti-pattern to watch: don't write `subagent.parallel: {command.parallel}`. That would compound concurrency (`command.parallel * subagent.parallel` total inflight tool calls), almost never desired.

---

### `num_partitions`

- Layers: `command.num_partitions`.
- Mode: **orchestrator-only**.
- Rule: when `command.num_partitions > 1`, the orchestrator groups slots into `num_partitions` disjoint subsets of size `command.parallel / command.num_partitions` (which MUST divide evenly; otherwise validation fails). The shape contract for `command.agent_model` in partition mode is:
  - Full iteration: `len(command.agent_model) = command.parallel` (one model per slot).
  - Partition slice: `len(command.agent_model) = command.num_partitions` (one model per partition; broadcast inside each).
  - Any other length is a validation error.

---

### `criteria`

- Layers: `command.criteria`, `subagent.criteria`, `skill.criteria`.
- Mode: **broadcast** OR **partition** (command-policy choice); **union** with `skill.criteria`.
- Rule:
  - Default: broadcast. `subagent[i].criteria = command.criteria`.
  - Tournament-style commands MAY partition `command.criteria` (one criterion per slot) so `subagent[i].criteria` is the i-th criterion.
  - Whenever a skill with `skill.criteria` activates in a slot, the effective criteria are `subagent.criteria ∪ skill.criteria`.

---

### `guardrails`

- Layers: `command.guardrails`, `subagent.guardrails`, `skill.guardrails`.
- Mode: **union** with strictest-wins on conflict.
- Rule:
  - `subagent[i].guardrails = command.guardrails ∪ command.subagent_constraints ∪ ⋃ { skill.guardrails : skill activated for slot i }`.
  - When two constraints conflict on the same axis (e.g., one says "MAY read tests/", another says "MUST NOT read tests/"), the strictest interpretation wins (here: MUST NOT).
  - The orchestrator's own guardrails are exactly `command.guardrails`; `subagent.guardrails` and `command.subagent_constraints` do not flow back to the orchestrator.

---

### `stop_condition`

- Layers: `command.stop_condition`, `subagent.stop_condition`.
- Mode: **broadcast**.
- Rule: `subagent[i].stop_condition = command.stop_condition`. Per-slot rewrites are unusual and SHOULD be expressed as additions to `subagent.guardrails` instead.

---

### `test_command`

- Layers: `command.test_command`, `subagent.test_command`.
- Mode: **broadcast**.
- Rule: `subagent[i].test_command = command.test_command`. The per-slot exit code is reported back as `subagent.verification.exit_code` and feeds `command.ranker`, `command.min_successes`, and `command.auto_save_winner`.

---

### `save_path`

- Layers: `command.save_path`, `subagent.save_path`.
- Mode: **distinct**.
- Rule:
  - `command.save_path` is where the *chosen / merged / synthesized final* lands (and only on success).
  - `subagent[i].save_path` is where slot `i`'s *candidate* lands; the orchestrator owns this path and derives it as `<command.worktree_root>/<command.worktree_name>-<i>/.candidate.<ext>` unless explicitly overridden.
  - The orchestrator MUST NOT promote `subagent.save_path` into `command.save_path` without an explicit selection step (manual pick, ranker winner, aggregator merge, etc.).

---

### `output_format`

- Layers: `command.output_format`, `subagent.output_format`, `skill.output_format`; also `shared.output_format` as the value type.
- Mode: **downcast** (command → subagent), **union/invariant** (skill into both).
- Rule:
  - `subagent.output_format` is usually a STRUCTURED form (JSON Schema, table) so the orchestrator can parse and aggregate, even when `command.output_format` is markdown for the user.
  - A skill with `skill.output_format` imposes an invariant on every output produced inside its activation scope; the orchestrator MUST keep `command.output_format` compatible (e.g., when a `conventional-commits` skill activates inside `worktree-task-agent`, the agent's commit messages MUST satisfy `skill.output_format` even though `command.output_format` describes the user-facing report).

---

### `timeout`

- Layers: `command.timeout`, `subagent.timeout`.
- Mode: **orthogonal**.
- Rule: per-slot budgets are NOT derived from the whole-command budget. The two are independent caps and a slot fails when EITHER is exceeded.

---

### `seed`

- Layers: `command.seed`, `subagent.seed`.
- Mode: **broadcast with index offset**.
- Rule: `subagent[i].seed = command.seed + (i - 1)` when `command.seed` is set; otherwise unset. The offset prevents identical sibling outputs from identical seeds.

---

### `temperature`

- Layers: `command.temperature`, `subagent.temperature`.
- Mode: **broadcast** (commonly **varied** for diversity).
- Rule: default is broadcast. A command that wants diversity MAY override per slot (e.g., temperature ramp `[0.2, 0.5, 0.8]`).

---

### `base_branch`

- Layers: `command.base_branch`, `subagent.base_branch`.
- Mode: **broadcast**.
- Rule: `subagent[i].base_branch = command.base_branch`. The orchestrator uses this for `git diff {base_branch}..HEAD` rendering and for the merge target.

---

### `verbosity`

- Layers: `command.verbosity`, `subagent.verbosity`.
- Mode: **broadcast with orchestrator downcast**.
- Rule: subagents emit at `subagent.verbosity` (default = `command.verbosity`); the orchestrator MAY trim per-slot output further in the final report. The orchestrator MUST NOT upcast a slot's output above what the slot itself emitted.

---

### `retry_policy`

- Layers: `command.retry_policy`, `subagent.retry_policy`.
- Mode: **orthogonal**.
- Rule: `command.retry_policy` controls "what to do if a whole subagent fails" (relaunch the slot). `subagent.retry_policy` controls "what to do if a tool call inside this subagent fails" (retry the tool). They never flow into each other.

---

## Whole-ontology validation rules

These rules bind the layers and MUST be checked before any worktree is created or any subagent is launched.

1. **Cardinality of list parameters.** Any `command.X` typed `shared.list_or_scalar<T>` that is supplied as a list MUST have length equal to `command.parallel` (or `command.num_partitions` in partition mode).
2. **Integer ranges.** Every `int` parameter MUST be validated against its `shared.int_range` cell. Validation failure aborts the command before filesystem side effects.
3. **Path existence.** Every `shared.file` / `shared.directory` parameter MUST resolve at validation time (or, for output paths, its parent directory MUST exist or be creatable).
4. **Required-when rules.** `command.aggregator` is required when `command.selection_mode = "synthesize"`. `command.ranker` is required when `command.selection_mode ∈ {auto-best, tournament}`.
5. **Mutual exclusion.** `command.k` and `command.n_candidates` MUST NOT both be set with conflicting values.
6. **Skill activation.** When a skill's `skill.requires` is unsatisfied or its `skill.conflicts_with` collides with a higher-priority skill, the orchestrator MUST NOT activate that skill in the current slot.
7. **Strictest-wins guardrails.** When merging `command.guardrails`, `command.subagent_constraints`, and `⋃ skill.guardrails`, conflicting constraints resolve to the strictest interpretation; the orchestrator MUST surface conflicts in the final report.
8. **Min successes feasibility.** `command.min_successes` MUST be `<= command.parallel`. When `command.hang_policy = abort`, `command.min_successes` MUST be `<= (command.parallel - max_expected_failures)`; the orchestrator MAY warn when this is implausibly tight.
9. **No silent fallback.** When `subagent.X` is unset AND the cross-layer rule above cannot resolve it AND the parameter is required, the orchestrator MUST fail with a message that names the missing root name AND the layers it consulted — NOT a generic "missing parameter".

---

## Worked end-to-end resolution

Suppose a user invokes:

```text
/critique
  context = "./src/parser/"
  criteria = "./rubrics/security.md"
  parallel = 3
  num_experiments = 3
  model = "claude-sonnet-4"
```

The layer resolution is:

```text
command.task                = "critique src/parser/ for security."   # from /critique invocation
command.context             = "./src/parser/"                         # user-supplied
command.criteria            = "./rubrics/security.md"                 # user-supplied
command.parallel            = 3                                       # user-supplied
command.num_experiments     = 3                                       # user-supplied
command.model               = "claude-sonnet-4"                       # user-supplied (orchestrator)
command.agent_model         = "claude-sonnet-4"                       # defaulted from command.model
command.seed                = unset
command.temperature         = unset

# For each slot i in 1..3:
subagent[i].slot_index      = i
subagent[i].task            = rewrite(command.task, experiment_i)
                            = "critique src/parser/ for security (independent run i)"
subagent[i].context         = "./src/parser/"                         # broadcast
subagent[i].criteria        = "./rubrics/security.md"                 # broadcast
subagent[i].model           = "claude-sonnet-4"                       # from command.agent_model
subagent[i].guardrails      = command.guardrails ∪ {}                 # no skill activated here
subagent[i].parallel        = 1                                       # default (NOT inherited)
subagent[i].timeout         = 15m                                     # default
subagent[i].output_format   = "json-schema:./schemas/finding.json"    # downcast from
                                                                       # command.output_format = "markdown:critique-report"
```

If a `minimal-diffs` skill activated for any subagent (it would not here, since the command is read-only), `subagent[i].guardrails` would gain that skill's MUST / MUST NOT lines via the **union** rule.

---

## When this file is the source of truth

`cross-layer.md` is authoritative for:

- Whether a `subagent.X` is broadcast, zipped, partitioned, rewritten, or independent.
- What the precedence is when multiple sources could populate a value.
- What the validation contract is at the layer boundary.

It is NOT authoritative for:

- The definition of `command.X` or `subagent.X` itself — that lives in the per-layer file.
- The primitive type of a value — that lives in `shared.md`.

When the rules here contradict a per-layer file, the per-layer file is in error and SHOULD be corrected; this file describes the wiring, not the wires.
