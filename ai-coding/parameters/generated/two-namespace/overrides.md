# Subagent Re-Binding Overrides

When a command spawns subagents (see [`command-params.md`](./command-params.md)
§E. Subagent tree), several shared-core and command parameters take on a
**different meaning at the child layer** than they do at the parent layer.
This file catalogues every such re-binding, the shape of the re-binding
(scalar broadcast, list-by-position, dict-by-key, forbidden), and the
source artifact that demonstrates it.

It does **not** introduce new parameters; it documents how existing
parameters are re-interpreted when the call graph deepens.

> See also: [`shared-core.md`](./shared-core.md) for the canonical
> definitions, [`command-params.md`](./command-params.md) for the parent's
> view, [`bridging.md`](./bridging.md) for skill-side reinterpretations
> (skills cannot themselves spawn subagents, so they are absent from this
> file).

---

## Re-binding shapes (vocabulary)

The right-hand column of the catalogue below uses these shape labels:

| shape | meaning |
|---|---|
| **scalar broadcast** | Parent supplies one value; every child receives the same value. |
| **list-by-position** | Parent supplies a `list<T>` whose length MUST equal `{parallelism}`; child `i` receives index `i`. |
| **dict-by-slot** | Parent supplies a `dict<int, T>` keyed by slot index; missing keys fall back to a default. |
| **derived-from-parent** | Child's value is computed from the parent's value (e.g. branch name + index suffix). |
| **inherited** | Child inherits parent's value verbatim, no re-binding. |
| **forbidden** | Re-binding is prohibited; child MUST use the parent's value. |
| **fresh-per-child** | Child draws a fresh value (e.g. unique branch name) at spawn time. |

---

## Catalogue

Each row: parent-layer parameter → child-layer parameter, re-binding shape,
source artifact.

### Shared-core re-bindings

| parent param | child param | shape | source |
|---|---|---|---|
| `task` | `task` (per child) | inherited (default) OR list-by-position (when fan-out wants distinct sub-tasks) | `worktree-task-agent.md` inherits the single `{task}` for all children. A hypothetical `/divide-and-conquer` would slice `{task}` per child. |
| `context` | `context` (per child) | inherited OR list-by-position (when each child gets a slice) | `critique.md` with `{num_experiments} > 1` runs each child against the same `{context}` (inherited). Multi-file partitioning would use list-by-position. |
| `criteria` | `criteria` (per child) | inherited | `critique.md`. |
| `guardrails` | `guardrails` + augmentation | inherited + augmented (parent's guardrails + isolation clauses) | `worktree-task-agent.md`: child inherits parent's guardrails AND must also obey "stay in your worktree" — see `subagent_constraints`. |
| `stop_condition` | `stop_condition` (per child) | inherited | `worktree-task-agent.md`. |
| `test_command` | `test_command` (per child) | inherited (default) OR list-by-position via `test_command_per_worker` | `worktree-task-agent.md` inherits; `test_command_per_worker` is the list-by-position variant. |
| `save_path` | `save_path` (per child) | derived-from-parent (e.g. parent `out/result.md` → child `out/result-1.md`, `out/result-2.md`) | conventional for any fan-out that writes per-child artifacts. |
| `output_format` | `output_format` (per child) | inherited | `critique.md`. |
| `verbosity` | `verbosity` (per child) | inherited | universal default. |

### Command re-bindings

| parent param | child param | shape | source |
|---|---|---|---|
| `model` | `subagent_model` | scalar broadcast OR list-by-position | `worktree-task-agent.md`: `{agent_model}` is the canonical example — scalar broadcasts to every child, list-by-position requires `len = {parallelism}`. |
| `parallelism` | `parallelism` (grand-child layer) | forbidden by default — children do not themselves spawn unless `{depth} > 1` | `worktree-task-agent.md` does not nest fan-out. |
| `n_candidates` | `n_candidates` (per child) | forbidden by default — each child produces 1 candidate | conventional. A nested best-of-N would explicitly set this. |
| `num_partitions` | `num_partitions` (per child) | forbidden | `worktree-task-agent.md`. |
| `selection_mode` | n/a | forbidden — children do not select; the parent selects across children | `worktree-task-agent.md`. |
| `min_successes` | n/a | forbidden — children do not enforce minima on themselves | conventional. |
| `ranker` | n/a | forbidden — the parent runs the ranker | conventional. |
| `aggregator` | n/a | forbidden — the parent runs the aggregator | conventional. |
| `focus_hints` | (per-child slot value) | list-by-position (each child gets one hint) | `meta-prompt.md` (proposed in `trajectory.md`): `{focus_hints}[i]` = child `i`'s refinement angle. |
| `seed` | seed (per child) | scalar broadcast (all children share) OR derived-from-parent (`seed + i` for diversification) | conventional. |
| `temperature` | temperature (per child) | scalar broadcast OR list-by-position | conventional. |
| `isolation` | inherited | inherited | `worktree-task-agent.md`. |
| `base_branch` | `base_branch` (per child) | scalar broadcast — all children fork from the same base | `worktree-task-agent.md`. |
| `worktree_name` | per-child branch name | derived-from-parent: `<worktree_name>-<i>` for child `i` | `worktree-task-agent.md` Workflow step 4. |
| `worktree_root` | per-child dir | derived-from-parent: `<worktree_root>/<repo_key>` then suffixed | `/worktree` command. |
| `cleanup_policy` | inherited | inherited | `worktree-task-agent.md`. |
| `auto_save_winner` | n/a | forbidden — parent decides | conventional. |
| `merge_mode` | n/a | forbidden — parent decides | `worktree-task-agent.md`. |
| `merge_count` | n/a | forbidden — capped at parent layer | `worktree-task-agent.md`'s guardrail "MUST NOT merge more than one worktree branch per invocation". |
| `delete_worktree` | per-child decision | inherited as default; user override interactively | `worktree-task-agent.md`. |
| `timeout` | per-child timeout | scalar broadcast OR list-by-position | conventional. |
| `relaunch_on_hang_after` | per-child threshold | scalar broadcast | conventional. |
| `retry_policy` | inherited | inherited | conventional. |
| `hang_policy` | inherited | inherited | conventional. |
| `require_diff` | per-child decision | inherited | `worktree-task-agent.md`. |
| `include_terminal_log` | per-child cap | inherited | conventional. |
| `depth` | depth - 1 | derived-from-parent (decrement by 1; child sees `{depth} - 1` as their remaining budget) | structural invariant. |
| `fan_out` | inherited (default) OR independently set | inherited | structural invariant. |
| `subagent_type` | inherited (default) OR independently set per slot | scalar broadcast OR list-by-position | conventional. |
| `subagent_prompt` | the child's incoming prompt | derived-from-parent (templated from `{task}` + `{focus_hints}[i]`) | `worktree-task-agent.md` Workflow step 5. |
| `subagent_constraints` | child's effective guardrails | inherited + augmentation | `worktree-task-agent.md`. |

---

## Validation rules (cross-cutting)

These rules MUST hold at parent invocation time, before any child is
spawned. They are derived from `worktree-task-agent.md`'s
`## Success Criteria` step 1 and generalized.

1. Every parameter whose shape is `list-by-position` MUST be either:
   - a scalar (which is broadcast), OR
   - a `list<T>` whose `len == {parallelism}` (mapped positionally).
   Any other length is a validation error and aborts before any child is
   spawned.
2. Every parameter whose shape is `forbidden` MUST be absent from the
   parameter set used to construct each child's invocation. If the parent
   carries a non-default value, it MUST drop or sentinel it at spawn time.
3. `{num_partitions}` interacts with `list-by-position` parameters: when
   `{num_partitions} > 1` is set together with a list-shaped parameter, the
   list MUST be either a full iteration across all children OR a
   correctly-sized slice for the partitions (currently under design — see
   `trajectory.md` open question).
4. `{depth}` decrements by 1 at each layer; spawning a child requires
   `{depth} >= 1` at the parent. A child receiving `{depth} == 0` MUST NOT
   spawn its own children.
5. `derived-from-parent` parameters (`save_path`, `worktree_name`,
   `worktree_root`, `subagent_prompt`) MUST produce values that are unique
   across siblings within the same invocation; collisions are a validation
   error.

---

## Worked example: `worktree-task-agent.md` with `{parallelism} = 4`

Parent invocation:

```text
/worktree-task-agent
  task              = "Add OAuth2 support"
  base_branch       = main
  worktree_name     = oauth-support
  parallelism       = 4
  agent_model       = [claude-opus-4.5, gpt-5, claude-opus-4.5, gpt-5]
  test_command      = "pnpm test --filter @app/auth"
  merge_mode        = interactive
  delete_worktree   = true
```

Child re-bindings (per the catalogue above):

| param | child 1 | child 2 | child 3 | child 4 | shape |
|---|---|---|---|---|---|
| `task` | "Add OAuth2 support" | (same) | (same) | (same) | inherited |
| `subagent_model` | `claude-opus-4.5` | `gpt-5` | `claude-opus-4.5` | `gpt-5` | list-by-position |
| `worktree_name` | `oauth-support-1` | `oauth-support-2` | `oauth-support-3` | `oauth-support-4` | derived-from-parent |
| `worktree_root` | `~/.cursor/worktrees/<id>/<repo>/oauth-support-1` | … | … | … | derived-from-parent |
| `base_branch` | `main` | `main` | `main` | `main` | scalar broadcast |
| `test_command` | `pnpm test --filter @app/auth` | (same) | (same) | (same) | inherited |
| `parallelism` | `1` (forbidden to nest) | `1` | `1` | `1` | forbidden |
| `selection_mode` | n/a | n/a | n/a | n/a | parent-only |
| `merge_mode` | n/a | n/a | n/a | n/a | parent-only |
| `delete_worktree` | `true` | `true` | `true` | `true` | inherited |

After the children finish, the parent collects per-child status, diff,
test result, and runs its own `{selection_mode}` to pick at most one
branch (per `{merge_count} = one`) to merge.
