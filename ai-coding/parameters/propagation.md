# Parameter Propagation

How parameter values flow between an invocation and the agents it spawns.
Scope model: the **invocation** (a command or skill read by the orchestrating
agent) resolves parameters, then launches **members** (spawned agents — one
per worktree, swarm slot, or variant). Skills that compose skills
(agent-swarm → worktree-task) resolve parameters at dispatch time.

Everything below is grounded in today's artifacts. The full design space
(inherit / shadow / reset / bubble trees, layered namespaces) lives in the
[generated/](generated/INDEX.md) archive.

## Resolution modes (vocabulary)

- **broadcast** — one value copied to every member.
- **zip** — list value; member *i* gets element *i*. List length must equal
  `candidate_count`.
- **partition** — list value; contiguous slices of members share element *j*.
  List length must equal `partition_count`, which must divide
  `candidate_count` evenly.
- **rewrite** — the member's value is computed from the invocation's value
  (e.g. an index suffix).
- **orthogonal** — same name exists at both scopes but the values are
  independent; never inherited.
- **bubble** — produced by members, read upward by the invocation (statuses,
  diffs, exit codes).

## Live rules

| Parameter | Rule |
|---|---|
| `task` | broadcast verbatim to every member; agent-swarm relays it unchanged into worktree-task |
| `agent_model` | scalar → broadcast; list → zip (length = `candidate_count`) or partition (length = `partition_count`) |
| `test_command` | broadcast; each member's exit code bubbles back and gates merge eligibility |
| `stop_condition` | broadcast; per-member satisfaction bubbles back |
| `base_branch` | broadcast; every member forks from it and diffs render against it |
| `worktree_name` | rewrite: member *i* gets the `-<i>` suffix |
| `artifact_path` | rewrite (meta-prompt fan-out): variant *i* writes `<save_path>` with `-<i>` inserted before the extension |
| `candidate_count` | orthogonal, always reset to 1: meta-prompt spawns variants with `n=1` to prevent recursive fan-out; swarm members run as single agents and never spawn swarms; replacements never chain |
| `concurrency` | invocation-only; members have no inner concurrency knob |
| `interactive` | broadcast (meta-prompt passes the same flag setting to variant agents) |
| `styles` | broadcast (meta-prompt passes the same styles to variant agents) |
| status / diff / verification / change summary | bubble: collected per member and rendered in the invocation's report |

## Worked example: agent-swarm dispatching worktree-task

agent-swarm is the policy layer; worktree-task owns worktree mechanics.
At dispatch (agent-swarm Workflow step 6), swarm parameters resolve into
worktree-task parameters:

| agent-swarm | worktree-task | Note |
|---|---|---|
| `{task}` (relayed) | `{task}` | verbatim for every member |
| `{parallel_agents}` | `{parallelism}` | worktree-task's `parallelism` is both count and concurrency, so the swarm feeds its concurrency cap here and owns the total via `{num_agents}` |
| resolved `{model_mix}` | `{agent_model}` | `broadcast` → scalar; `per-agent` → list of length `{num_agents}`; `per-partition` → list of length `{num_partitions}` plus `{num_partitions}` |
| `{num_partitions}` | `{num_partitions}` | only with `model_mix = per-partition` |
| `{test_command}` | `{test_command}` | when set |
| — | `{merge_mode}` | always set to `interactive`; the chosen branch is handed back through worktree-task's merge prompt |

The swarm keeps for itself (never forwarded): `{selection_modes}`,
`{aggregator}`, `{min_successes}`, `{relaunch_on_hang_after}`,
`{replacement_policy}`, `{cost_cap}`, `{pattern}`. Member lifecycle results
bubble up as events (`member.started`, `member.completed`, ...) and feed the
selection modes.

## Invariants

- **Isolation:** members never read, write, or run commands against the
  calling worktree or any sibling (worktree-task, agent-swarm, meta-prompt,
  address-worklist-commit-loop all restate this).
- **Single merge:** at most one worktree branch is merged per invocation,
  regardless of how many members succeeded or how many selection modes
  converged.
- **No recursion:** fan-out never nests — spawned members always run with
  `candidate_count = 1`.
- **Validate before side effects:** every parameter check happens before the
  first worktree, branch, or file write; failure aborts with an explanatory
  error and no filesystem changes.
