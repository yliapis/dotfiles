# Command Parameters

Parameters in this file are **execution-oriented** and live exclusively on
the command side of the ontology. Skills do not consume them directly; when
a skill needs to influence one of these knobs, it must hand control back to
the parent agent which is the only side that can set them.

A command is an imperative artifact the user explicitly invokes (e.g.
`/critique`, `/meta-prompt`, `/worktree-task-agent`). The parameters below
control **how** that invocation runs: concurrency, isolation, fan-out,
model selection, selection/aggregation, robustness, and reporting.

> See also: [`shared-core.md`](./shared-core.md) for cross-namespace params
> (`task`, `context`, `criteria`, `save_path`, etc.),
> [`skill-params.md`](./skill-params.md) for skill-side equivalents,
> [`overrides.md`](./overrides.md) for how these params are re-bound at the
> subagent layer, [`bridging.md`](./bridging.md) for the skill-side notes
> ("n/a; consult parent agent" / "expressed as `mandate_level`" / etc.).

The values referenced as `int_range`, `file_type`, `enum`, `path`, `url`,
`glob`, `bool`, `list<T>`, `dict<K, V>` are defined in
[`shared-core.md`](./shared-core.md) §0.

---

## D. Replication / parallelism

### `parallelism`
- aliases: `parallel`, `concurrency`, `n_workers`
- definition: number of independent workers run concurrently within a single
  invocation.
- namespace: command
- type: `int_range >= 1`
- default: `1`
- bridging:
  - skill: no direct equivalent; a skill that wants concurrent enforcement
    must hand off to a command. See `bridging.md`.
- example: `{parallelism}` = `8` in `worktree-task-agent.md` runs eight
  sibling agents concurrently; `{parallel}` = `4` in `critique.md` caps the
  analysis worker pool.

### `n_candidates`
- aliases: `k`, `num_candidates`, `n`
- definition: number of distinct candidate outputs produced from a single
  task (each candidate is a complete result, not a worker).
- namespace: command
- type: `int_range >= 1`
- default: `1`
- bridging:
  - skill: a skill produces a single deterministic output per activation; no
    direct equivalent.
- example: `{n_candidates}` = `5` asks `meta-prompt.md` to emit five
  refined prompt variants side by side.

### `num_experiments`
- aliases: `runs`, `replications`
- definition: number of independent end-to-end runs of the same task, used
  for variance estimation or convergence analysis (distinct from
  `n_candidates`, which produces alternatives, not replicas).
- namespace: command
- type: `int_range >= 1`
- default: `1`
- bridging:
  - skill: no equivalent.
- example: `{num_experiments}` = `3` in `critique.md` runs three independent
  analyses and merges convergent findings.

### `num_partitions`
- aliases: `partition_count`, `groups`
- definition: number of partition groups across which workers / models are
  distributed.
- namespace: command
- type: `int_range >= 1`
- default: `1`
- bridging:
  - skill: no equivalent.
- example: `{num_partitions}` = `2` in `worktree-task-agent.md` splits
  `{parallelism}` agents into two model-or-task groups (semantics still
  under design — see `trajectory.md`).

---

## E. Subagent tree

A "subagent" is a child agent launched by a command to do a slice of work in
isolation. Subagent parameters re-bind shared-core and command parameters at
the child layer. The full re-binding catalogue lives in
[`overrides.md`](./overrides.md); this section defines the subagent-specific
knobs themselves.

### `subagent_type`
- aliases: `child_type`, `agent_kind`
- definition: the class of subagent to spawn (e.g. `code-agent`,
  `analysis-agent`, `tool-agent`).
- namespace: command
- type: `enum {code-agent | analysis-agent | tool-agent | custom}`
- default: `code-agent`
- bridging:
  - skill: a skill cannot spawn subagents; n/a.
- example: `{subagent_type}` = `analysis-agent` for a critique fan-out.

### `subagent_model`
- aliases: `agent_model`, `child_model`, `worker_model`
- definition: model identifier (or list) used for each subagent.
- namespace: command
- type: `string | list<string>[len = {parallelism}]`
- default: parent's `{model}`
- bridging:
  - skill: skills are model-agnostic by design (they describe what should
    happen, not who does it). See `bridging.md` → "model".
- example: `{subagent_model}` = `[gpt-5, claude-opus-4.5, gpt-5,
  claude-opus-4.5]` distributes four worktree agents across two models.

### `subagent_prompt`
- aliases: `child_prompt`, `worker_prompt`
- definition: prompt template the parent emits to each subagent; usually a
  parameterized version of the parent's `{task}`.
- namespace: command
- type: string (template)
- default: derived from the parent's `{task}` and per-slot `{focus_hints}`
- bridging:
  - skill: a skill's prose body is its prompt; there is no separate child
    prompt. See `skill-params.md` → `description`.
- example: see `worktree-task-agent.md` Workflow step 5: each subagent gets
  the same `{task}` plus its slot-specific `{agent_model}`.

### `subagent_constraints`
- aliases: `child_guardrails`, `worker_guardrails`
- definition: guardrails layered ONTO the parent's guardrails when spawning
  each subagent (commonly "stay in your worktree", "do not push", etc.).
- namespace: command
- type: string (prose)
- default: inherited from parent; commonly augmented with isolation clauses
- bridging:
  - skill: a skill's `## Guardrails` body, when consumed by an agent the
    skill governs, plays a similar role. See `skill-params.md` →
    `mandate_level`.
- example: `worktree-task-agent.md`'s "MUST keep each agent's task
  execution isolated to its assigned worktree" is a `subagent_constraint`.

### `depth`
- aliases: `recursion_depth`, `tree_depth`
- definition: maximum depth of subagent recursion (parent at depth 0, its
  subagents at depth 1, their subagents at depth 2, etc.).
- namespace: command
- type: `int_range [0, 8]`
- default: `1`
- bridging:
  - skill: no equivalent.
- example: `{depth}` = `0` forbids subagent spawning; `{depth}` = `2` allows
  the parent → child → grandchild pattern.

### `fan_out`
- aliases: `branching_factor`, `children_per_node`
- definition: number of subagents spawned per node when the tree branches.
- namespace: command
- type: `int_range >= 1`
- default: `{parallelism}`
- bridging:
  - skill: no equivalent.
- example: `{fan_out}` = `3` and `{depth}` = `2` produces up to 1 + 3 + 9 =
  13 nodes.

### Subagent overrides (cross-reference)

When a parent command spawns a subagent, several shared-core and command
parameters are **re-bound** at the child layer with different semantics
(parent's `{task}` vs. child's `{task}`, parent's `{model}` vs. child's
`{subagent_model}`, etc.). The full catalogue — including which parameters
are re-bound, which broadcast scalar-to-list, and which are forbidden from
re-binding — lives in [`overrides.md`](./overrides.md).

---

## F. Models / diversity

### `model`
- aliases: `llm`, `agent_model_top`
- definition: model identifier used for the top-level (parent) agent of the
  invocation.
- namespace: command
- type: string
- default: parent agent's currently active model
- bridging:
  - skill: skills are model-agnostic. The active model is whatever model the
    parent agent is already running on. See `bridging.md`.
- example: `{model}` = `claude-opus-4.5` in `critique.md`.

### `focus_hints`
- aliases: `refinement_angles`, `slot_hints`
- definition: list of distinct refinement angles, one per candidate /
  subagent, used to deliberately diversify outputs.
- namespace: command
- type: `list<string>[len = {n_candidates}]` (or `len = {parallelism}` when
  fan-out is per worker rather than per candidate)
- default: `[]` (no hints → maximally homogeneous run)
- bridging:
  - skill: a skill's `description` and `decision_framework` already encode
    its specific angle; no per-invocation hint mechanism exists.
- example: `{focus_hints}` = `[tighten guardrails, clarify parameters,
  improve workflow steps]` in `meta-prompt.md`.

### `seed`
- aliases: `random_seed`, `rng_seed`
- definition: integer seed for reproducibility of stochastic generation.
- namespace: command
- type: integer (no specific `int_range`; implementations may restrict)
- default: unset (non-deterministic)
- bridging:
  - skill: skills do not consume seeds directly.
- example: `{seed}` = `1729` pins a `critique.md` run for re-runnable
  comparison.

### `temperature`
- aliases: `sampling_temperature`
- definition: model sampling temperature governing output randomness.
- namespace: command
- type: float `[0.0, 2.0]` (formalism not defined here; implementation-bound)
- default: model-default
- bridging:
  - skill: not applicable.
- example: `{temperature}` = `0.7` for diverse `n_candidates` generation;
  `0.0` for deterministic re-runs.

---

## G. Selection / aggregation

### `selection_mode`
- aliases: `selector`, `pick_mode`
- definition: how a final result is chosen (or synthesized) from multiple
  candidates / runs.
- namespace: command
- type: `enum {manual | auto-best | synthesize | none}`
- default: `manual`
- bridging:
  - skill: skills produce a single output deterministically; no equivalent.
- example: `{selection_mode}` = `auto-best` in a `worktree-task-agent.md`
  fan-out asks the parent to auto-pick the winner using `{ranker}`.

### `min_successes`
- aliases: `min_passing`, `min_complete`
- definition: minimum number of subagents/runs that must report `success`
  before selection or synthesis is attempted.
- namespace: command
- type: `int_range >= 1`
- default: `1`
- bridging:
  - skill: not applicable.
- example: `{min_successes}` = `3` of `{parallelism}` = `8` in
  `worktree-task-agent.md` to be robust to hangs/failures.

### `ranker`
- aliases: `scorer`, `judge`
- definition: a function, command, or prompt that scores candidates so the
  highest-ranked one can be picked.
- namespace: command
- type: string (command, prompt name, or callable reference)
- default: unset; `auto-best` selection mode falls back to `{test_command}`
  exit + diff-size heuristics.
- bridging:
  - skill: skills can be invoked AS rankers but they are not parameterized
    as rankers themselves.
- example: `{ranker}` = `/critique criteria=./rubrics/security.md` ranks
  each candidate against a security rubric.

### `aggregator`
- aliases: `candidate_aggregator`, `synthesizer`, `merger`
- definition: a function, command, or prompt that **synthesizes** multiple
  candidates into a single artifact (vs. picking one).
- namespace: command
- type: string (command, prompt name, or callable reference)
- default: unset; required when `{selection_mode}` = `synthesize`.
- bridging:
  - skill: skills can be invoked AS aggregators (e.g. a "merge minimal-diff"
    skill) but are not parameterized as aggregators themselves.
- example: `{aggregator}` = `/meta-prompt synthesize` synthesizes N
  candidate prompts into one merged prompt.

### `compare_against`
- aliases: `baseline`, `reference`
- definition: a baseline artifact against which candidates are compared
  (e.g. the original prompt being refined).
- namespace: command
- type: `file | inline | url`
- default: implied by REFINE mode (the input itself is the baseline)
- bridging:
  - skill: a skill's `references` list can act as comparison material; not a
    parameter.
- example: `{compare_against}` = `ai-coding/plugins/ai-coding/commands/critique.md`
  in a REFINE run.

---

## H. Isolation / workspace

### `isolation`
- aliases: `isolation_mode`, `sandbox`
- definition: how strongly the run is isolated from the parent working tree
  and other concurrent runs.
- namespace: command
- type: `enum {none | process | worktree | container}`
- default: `none` for read-only commands (e.g. `critique.md`); `worktree`
  for commands that write code (e.g. `worktree-task-agent.md`).
- bridging:
  - skill: a skill cannot demand isolation; it can only declare in its body
    that it MUST be invoked under appropriate isolation. See
    `mandate_level`.
- example: `{isolation}` = `worktree` selects the per-worktree pattern.

### `base_branch`
- aliases: `parent_branch`, `fork_point`
- definition: branch from which isolated worktrees / branches are forked.
- namespace: command
- type: string (git ref; branch name, tag, SHA, `origin/main`, etc.)
- default: current branch (`git rev-parse --abbrev-ref HEAD`)
- bridging:
  - skill: not applicable.
- example: `{base_branch}` = `main` in `worktree-task-agent.md`.

### `worktree_name`
- aliases: `branch_basename`, `worktree_slug`
- definition: base name used for both the worktree directory and the
  resulting branch; index suffixes are appended when fan-out > 1.
- namespace: command
- type: string (kebab-case slug; filesystem-safe)
- default: derived from `{task}` as a kebab-case slug
- bridging:
  - skill: not applicable.
- example: `{worktree_name}` = `oauth-refactor` → branches
  `oauth-refactor-1`, `oauth-refactor-2`, …

### `worktree_root`
- aliases: `worktrees_dir`
- definition: directory under which all worktrees for the run are created.
- namespace: command
- type: `path`
- default: `~/.cursor/worktrees/<worktree_id>/` per the `/worktree` command
- bridging:
  - skill: not applicable.
- example: `{worktree_root}` = `~/.cursor/worktrees/oauth-refactor-c6ab6bc8/`.

### `cleanup_policy`
- aliases: `worktree_cleanup`, `post_run_cleanup`
- definition: rule for what to delete after the run completes.
- namespace: command
- type: `enum {keep | remove-on-success | remove-always | interactive}`
- default: `interactive` (asks the user)
- bridging:
  - skill: not applicable.
- example: `{cleanup_policy}` = `remove-on-success` deletes only the
  worktree whose branch was merged successfully.

---

## I. Lifecycle / persistence (command-specific)

> Cross-cutting persistence params (`save_path`, `output_format`) live in
> [`shared-core.md`](./shared-core.md). Below are the lifecycle knobs that
> exist only in command contexts.

### `auto_save_winner`
- aliases: `persist_winner`, `auto_persist`
- definition: when `{n_candidates}` > 1 and a clear winner is selected,
  automatically write it to `{save_path}` instead of asking the user.
- namespace: command
- type: `bool`
- default: `false`
- bridging:
  - skill: not applicable.
- example: `{auto_save_winner}` = `true` for `meta-prompt.md` in CI.

### `merge_mode`
- aliases: `merge_strategy`, `merge_behavior`
- definition: behavior after diffs are presented — interactive prompts vs.
  automatic merging.
- namespace: command
- type: `enum {interactive | auto}`
- default: `interactive`
- bridging:
  - skill: not applicable.
- example: `{merge_mode}` = `auto` in `worktree-task-agent.md` merges the
  single eligible branch without prompting.

### `merge_count`
- aliases: `max_merges`, `merges_per_invocation`
- definition: cap on how many candidate branches may be merged per
  invocation.
- namespace: command
- type: `enum {one | all-passing | user-pick-multi}` (or `int_range >= 0`
  for a literal cap)
- default: `one`
- bridging:
  - skill: not applicable.
- example: `{merge_count}` = `all-passing` would merge every branch whose
  `{test_command}` exited 0 (currently disallowed by
  `worktree-task-agent.md`'s scope guardrail).

### `delete_worktree`
- aliases: `cleanup_worktree`
- definition: whether to delete a worktree after its branch is merged
  successfully.
- namespace: command
- type: `bool`
- default: `true`
- bridging:
  - skill: not applicable.
- example: `{delete_worktree}` = `false` keeps merged worktrees around for
  forensic inspection.

---

## J. Robustness / recovery

### `timeout`
- aliases: `deadline`, `max_duration`
- definition: maximum wall-clock duration for the whole invocation (or per
  subagent, depending on convention).
- namespace: command
- type: string (duration, e.g. `30s`, `15m`, `2h`)
- default: unset (no timeout)
- bridging:
  - skill: not applicable.
- example: `{timeout}` = `15m` aborts a critique run after 15 minutes.

### `relaunch_on_hang_after`
- aliases: `hang_threshold`, `liveness_timeout`
- definition: duration of inactivity after which a hung subagent is aborted
  and (optionally) replaced.
- namespace: command
- type: string (duration)
- default: unset (no liveness checking)
- bridging:
  - skill: not applicable.
- example: `{relaunch_on_hang_after}` = `5m` in `worktree-task-agent.md`
  catches the "2 of 8 silently hung" pattern from `trajectory.md`.

### `retry_policy`
- aliases: `retry`, `backoff`
- definition: rule for retrying failed work (count, delay, backoff).
- namespace: command
- type: `enum {none | once | exponential | dict<...>}` (dict form takes
  `{count, base_delay, max_delay}`)
- default: `none`
- bridging:
  - skill: not applicable.
- example: `{retry_policy}` = `{count: 3, base_delay: 30s, backoff:
  exponential}`.

### `hang_policy`
- aliases: `liveness_policy`
- definition: action taken when a subagent hangs past
  `{relaunch_on_hang_after}`.
- namespace: command
- type: `enum {abort | replace | continue}`
- default: `abort`
- bridging:
  - skill: not applicable.
- example: `{hang_policy}` = `replace` re-spawns a fresh subagent in the
  same slot.

---

## K. Reporting (command-specific)

> Cross-cutting reporting params (`verbosity`, `output_format`) live in
> [`shared-core.md`](./shared-core.md). Below are reporting knobs that
> exist only in command contexts.

### `require_diff`
- aliases: `emit_diff`, `show_diff`
- definition: whether to include a git diff (or a diff against
  `{compare_against}`) in the final report for each candidate.
- namespace: command
- type: `bool`
- default: `true` for code-producing commands (`worktree-task-agent.md`);
  `false` for read-only commands (`critique.md`).
- bridging:
  - skill: not applicable.
- example: `{require_diff}` = `true` in `meta-prompt.md` REFINE mode emits
  a diff against the input.

### `include_terminal_log`
- aliases: `attach_logs`, `verbatim_logs`
- definition: whether to attach raw terminal output (stdout/stderr tails)
  from subagents in the final report.
- namespace: command
- type: `bool` | `int_range >= 0` (line cap)
- default: `false` (or `400` line cap when `true`)
- bridging:
  - skill: not applicable.
- example: `{include_terminal_log}` = `200` keeps the last 200 lines of
  each subagent's output.

### `test_command_per_worker`
- aliases: `per_worker_test`, `slot_test`
- definition: variant of `{test_command}` (shared-core) that may be defined
  per subagent slot, overriding the parent's value.
- namespace: command (re-binding of shared-core `test_command`)
- type: `list<string>[len = {parallelism}]`
- default: each slot inherits the parent `{test_command}`
- bridging:
  - skill: not applicable.
- example: `{test_command_per_worker}` = `[pytest -k auth, pytest -k api,
  pytest -k ui]` runs different test filters per worker.

---

## Index of command-only parameters

| # | parameter | section |
|--:|---|---|
|  1 | `parallelism` | D. Replication |
|  2 | `n_candidates` | D. Replication |
|  3 | `num_experiments` | D. Replication |
|  4 | `num_partitions` | D. Replication |
|  5 | `subagent_type` | E. Subagent tree |
|  6 | `subagent_model` | E. Subagent tree |
|  7 | `subagent_prompt` | E. Subagent tree |
|  8 | `subagent_constraints` | E. Subagent tree |
|  9 | `depth` | E. Subagent tree |
| 10 | `fan_out` | E. Subagent tree |
| 11 | `model` | F. Models / diversity |
| 12 | `focus_hints` | F. Models / diversity |
| 13 | `seed` | F. Models / diversity |
| 14 | `temperature` | F. Models / diversity |
| 15 | `selection_mode` | G. Selection |
| 16 | `min_successes` | G. Selection |
| 17 | `ranker` | G. Selection |
| 18 | `aggregator` | G. Selection |
| 19 | `compare_against` | G. Selection |
| 20 | `isolation` | H. Isolation |
| 21 | `base_branch` | H. Isolation |
| 22 | `worktree_name` | H. Isolation |
| 23 | `worktree_root` | H. Isolation |
| 24 | `cleanup_policy` | H. Isolation |
| 25 | `auto_save_winner` | I. Lifecycle |
| 26 | `merge_mode` | I. Lifecycle |
| 27 | `merge_count` | I. Lifecycle |
| 28 | `delete_worktree` | I. Lifecycle |
| 29 | `timeout` | J. Robustness |
| 30 | `relaunch_on_hang_after` | J. Robustness |
| 31 | `retry_policy` | J. Robustness |
| 32 | `hang_policy` | J. Robustness |
| 33 | `require_diff` | K. Reporting |
| 34 | `include_terminal_log` | K. Reporting |
| 35 | `test_command_per_worker` | K. Reporting |
