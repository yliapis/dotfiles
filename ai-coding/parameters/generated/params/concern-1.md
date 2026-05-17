# Parameter Ontology — Concern-First

> **Angle:** Parameters are grouped by **responsibility / concern**: what the parameter is *for*, not what type it has, not when in the lifecycle it fires, and not where in the agent tree it lives.

## Motivation

Every parameter in our prompt library answers one of a small number of recurring questions: *What am I doing?* (task), *Where does data come in / go out?* (io), *What's not allowed and when am I done?* (constraints), *How many copies?* (replication), *Who runs the work and at what depth?* (subagent tree), *Which model and with what diversity?* (models), *Which result wins?* (selection), *Where does work happen in isolation?* (isolation), *How does the result get promoted or cleaned up?* (lifecycle), *What happens when things hang or fail?* (robustness), *How is the result reported?* (reporting).

Grouping by concern matches the **mental model of what a parameter does**. When a prompt author wonders "do I need a knob for X?", they ask "what concern is X?" and look in one file — not "what type is X?" (which can be the same `int` for parallelism, depth, and timeout, three very different concerns) and not "when does X fire?" (a parameter like `criteria` shapes both planning and reporting, so lifecycle stages cut across it).

The cost of this angle: parameters that genuinely belong to two concerns (e.g. `agent_model` is a *model identity* but also a *subagent-tree* attribute; `save_path` is an *I/O destination* but is consumed by *lifecycle*'s `auto_save_winner`) are handled with **explicit cross-references**. Each parameter has exactly one primary home; every other concern that touches it links to that home.

## Multi-depth scheme (in-place)

Names are **not renamed and not prefixed** by depth. A single parameter can mean slightly different things at the **command** layer (invoked by the user via `/foo`), the **subagent** layer (passed by a parent agent when spawning a child), and the **skill** layer (referenced from a skill's prose / guardrails). Multi-depth lives inside each parameter's entry as a small table:

| Layer | Semantics at this layer |
|---|---|
| **command** | How the user supplies it via slash command (CLI-style). |
| **subagent** | How a parent agent forwards / overrides it when spawning a child. Often inherited unless explicit. |
| **skill** | How the skill references it in prose / guardrails. Usually a name match against the calling command's params; sometimes fixed by the skill. |

If a parameter has no meaningful per-depth variation, the table is omitted. The base inventory items required to have a multi-depth table are: `task`, `model`, `parallel` (a.k.a. `parallelism`), `criteria`, `save_path`, `selection_mode`. Others use it whenever the semantics shift across layers.

## Concern map

| File | Concern | Primary parameters |
|---|---|---|
| [`task.md`](./task.md) | What the agent is supposed to accomplish | `task`, `input`, `context` |
| [`io.md`](./io.md) | Where data comes in and goes out | `file`, `directory`, `glob`, `url`, `inline`, `format`, `save_path`, `output_format` |
| [`constraints.md`](./constraints.md) | What's not allowed, what counts as done, what counts as valid | `criteria`, `guardrails`, `stop_condition`, `test_command`, `file_type`, `int_range` |
| [`replication.md`](./replication.md) | How many parallel/serial copies to run | `n_candidates`, `parallelism`, `num_partitions` |
| [`subagent-tree.md`](./subagent-tree.md) | Shape of the agent tree spawned underneath | `subagent_type`, `subagent_model`, `subagent_prompt`, `subagent_constraints`, `depth`, `fan_out` |
| [`models.md`](./models.md) | Which model runs, with what sampling and diversity | `model`, `agent_model`, `focus_hints`, `seed`, `temperature` |
| [`selection.md`](./selection.md) | Which candidate(s) win and how they're combined | `selection_mode`, `min_successes`, `ranker`, `aggregator`, `compare_against` |
| [`isolation.md`](./isolation.md) | Where work runs without touching the parent checkout | `isolation`, `base_branch`, `worktree_name`, `worktree_root`, `cleanup_policy` |
| [`lifecycle.md`](./lifecycle.md) | Promotion, persistence, and end-of-run handling of results | `auto_save_winner`, `merge_mode`, `merge_count` |
| [`robustness.md`](./robustness.md) | What happens when things hang, time out, or fail | `timeout`, `retry_policy`, `hang_policy` |
| [`reporting.md`](./reporting.md) | What the final response shows and how loud it is | `verbosity`, `require_diff`, `include_terminal_log` |

Total: **50 parameters** across 11 concerns.

## Type formalisms

Two type formalisms are referenced across many concerns. Both are defined in [`constraints.md`](./constraints.md):

- **`int_range`** (a.k.a. `integer_interval`) — a domain spec for integer parameters, written like `>= 1`, `[1, 8]`, `(0, ∞)`. See [`constraints.md#int_range`](./constraints.md#int_range).
- **`file_type`** (a.k.a. `extension`) — a domain spec for file-extension restrictions, written like `{.md, .json}` or referencing a `format` category. See [`constraints.md#file_type`](./constraints.md#file_type).

## Worked example 1 — `/critique` consumes the ontology

The existing [`critique.md`](../plugins/ai-coding/commands/critique.md) declares five parameters. Mapped onto this ontology:

| `/critique` param | Concern file | Canonical name | Notes |
|---|---|---|---|
| `{context}` | [`task.md`](./task.md) | `context` | The artifact under analysis; sourced via `io.md` resolvers (`file` / `directory` / `url` / `inline`) — but the *role* is task input, not an I/O destination. |
| `{criteria}` | [`constraints.md`](./constraints.md) | `criteria` | Judgment criteria; can be `file` / `directory` / inline (`io.md` resolvers). |
| `{model}` | [`models.md`](./models.md) | `model` | The model identity at the command depth. |
| `{parallel}` | [`replication.md`](./replication.md) | `parallelism` | `int_range >= 1`; `parallel` is a legal alias. |
| `{num_experiments}` | [`replication.md`](./replication.md) | `n_candidates` | `int_range >= 1`; `num_experiments` is a legal alias. |

Concerns *implicitly* present in `/critique` but not surfaced as parameters:

- **selection.md** — the command does its own merge / convergence aggregation (per [Output Format](../plugins/ai-coding/commands/critique.md)). If ranking became configurable, `ranker` and `aggregator` would slot in.
- **reporting.md** — `verbosity` is fixed by the command's Output Format; `require_diff` is N/A because the command is read-only.
- **isolation.md** — N/A; the command is read-only and runs in-tree.

## Worked example 2 — `/worktree-task-agent` consumes the ontology

The existing [`worktree-task-agent.md`](../plugins/ai-coding/commands/worktree-task-agent.md) declares ten parameters. Mapped onto this ontology:

| `/worktree-task-agent` param | Concern file | Canonical name | Notes |
|---|---|---|---|
| `{task}` | [`task.md`](./task.md) | `task` | Required task statement passed to each agent. |
| `{base_branch}` | [`isolation.md`](./isolation.md) | `base_branch` | Defaults to current branch. |
| `{worktree_name}` | [`isolation.md`](./isolation.md) | `worktree_name` | With `-{i}` suffix when `parallelism > 1`. |
| `{delete_worktree}` | [`isolation.md`](./isolation.md) | `cleanup_policy` | Boolean is the simple form; richer policy values discussed in `isolation.md`. |
| `{merge_mode}` | [`lifecycle.md`](./lifecycle.md) | `merge_mode` | `interactive` / `auto`. |
| `{test_command}` | [`constraints.md`](./constraints.md) | `test_command` | Gates merge; exit code 0 = pass. |
| `{agent_model}` | [`models.md`](./models.md) | `agent_model` | Scalar or list of length `parallelism`. Cross-ref from [`subagent-tree.md#subagent_model`](./subagent-tree.md#subagent_model). |
| `{parallelism}` | [`replication.md`](./replication.md) | `parallelism` | `int_range >= 1`. Cross-ref from [`subagent-tree.md#fan_out`](./subagent-tree.md#fan_out). |
| `{num_partitions}` | [`replication.md`](./replication.md) | `num_partitions` | `int_range >= 1`; coupling rules with `agent_model` shape. |
| `{stop_condition}` | [`constraints.md`](./constraints.md) | `stop_condition` | Explicit "done" beyond default verification. |

Concerns *implicitly* present in `/worktree-task-agent` but not yet surfaced as parameters (open work, per [`trajectory.md`](../plugins/ai-coding/commands/trajectory.md)):

- **selection.md** — `selection_mode`, `min_successes`, `aggregator` are in flight.
- **robustness.md** — `timeout` / `relaunch_on_hang_after`, `hang_policy` are in flight.
- **lifecycle.md** — `merge_count` is currently implicit (capped at one).
- **reporting.md** — `require_diff` is implicitly true (the Output Format mandates per-worktree diffs); `verbosity` is fixed.

## Worked example 3 (mini) — `/meta-prompt` consumes the ontology

[`meta-prompt.md`](../plugins/ai-coding/commands/meta-prompt.md) declares two parameters:

| `/meta-prompt` param | Concern file | Canonical name |
|---|---|---|
| `{input}` | [`task.md`](./task.md) | `input` |
| `{save_path}` | [`io.md`](./io.md) | `save_path` |

The proposed extensions in [`trajectory.md`](../plugins/ai-coding/commands/trajectory.md) (`{n_candidates}`, `{focus_hints}`, `{compare_against}`, `{require_diff}`, `{auto_save_winner}`) land cleanly across the ontology: `n_candidates` → [`replication.md`](./replication.md), `focus_hints` → [`models.md`](./models.md), `compare_against` → [`selection.md`](./selection.md), `require_diff` → [`reporting.md`](./reporting.md), `auto_save_winner` → [`lifecycle.md`](./lifecycle.md).

## Reading order

If you're new to the ontology:

1. [`task.md`](./task.md) — the verb of every invocation.
2. [`io.md`](./io.md) — how `context` / `input` / `save_path` actually resolve.
3. [`constraints.md`](./constraints.md) — also defines `int_range` and `file_type`, used elsewhere.
4. [`replication.md`](./replication.md) → [`models.md`](./models.md) → [`selection.md`](./selection.md) — the fan-out / pick triangle.
5. [`subagent-tree.md`](./subagent-tree.md) — recursive shape on top of replication.
6. [`isolation.md`](./isolation.md) → [`lifecycle.md`](./lifecycle.md) — where work happens, how it's promoted.
7. [`robustness.md`](./robustness.md), [`reporting.md`](./reporting.md) — operational quality of the run.
