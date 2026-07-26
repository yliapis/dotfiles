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
| `task` | broadcast verbatim to every member; agent-swarm relays it unchanged into worktree-task, appending a delimited `## Upstream Context` block (prior summaries, branches, test results) for `staged` waves and `pipeline` stages after the first |
| `agent_model` | scalar → broadcast; list → zip (length = `candidate_count`) or partition (length = `partition_count`); agent-swarm resolves the assignment over its global slots, then hands each dispatch only its slice |
| `test_command` | broadcast; each member's exit code bubbles back and gates merge eligibility |
| `stop_condition` | broadcast; per-member satisfaction bubbles back |
| `base_branch` | broadcast; every member forks from it and diffs render against it. Exception: under agent-swarm's `pipeline` topology the swarm rewrites it per stage, so stage *i* forks from stage *i-1*'s branch |
| `worktree_name` | rewrite: member *i* gets the `-<i>` suffix. Under agent-swarm's `staged` / `pipeline` topologies each wave or stage is dispatched with its own name (`<slug>-w<j>`, `<slug>-s<i>`), so the child's suffix is local to that invocation |
| `topology` | invocation-level, never forwarded (worktree-task has no topology knob): it decides how many worktree-task invocations the swarm makes, what each one forks from, and whether upstream context is appended to the relayed `task` |
| `artifact_path` | rewrite (meta-prompt fan-out): variant *i* writes `<save_path>` with `-<i>` inserted before the extension |
| `candidate_count` | orthogonal, always reset to 1: meta-prompt spawns variants with `n=1` to prevent recursive fan-out; swarm members run as single agents and never spawn swarms; replacements never chain |
| `concurrency` | invocation-level pacing cap; maps across the agent-swarm → worktree-task dispatch edge (`parallel_agents` → `concurrency`) but members themselves have no inner concurrency knob |
| `interactive` | broadcast (meta-prompt passes the same flag setting to variant agents) |
| `styles` | broadcast (meta-prompt passes the same styles to variant agents) |
| status / diff / verification / change summary | bubble: collected per member and rendered in the invocation's report |

## Worked example: agent-swarm dispatching worktree-task

agent-swarm is the policy layer; worktree-task owns worktree mechanics.
At dispatch (agent-swarm Workflow step 7), swarm parameters resolve into
worktree-task parameters. The rows below describe the default `parallel`
topology, which dispatches the whole swarm in one invocation; `staged` and
`pipeline` dispatch one invocation per wave or stage and are covered in the
contract cases:

| agent-swarm | worktree-task | Note |
|---|---|---|
| `{task}` (relayed) | `{task}` | verbatim for every member, plus the upstream-context block under `staged` / `pipeline` |
| `{num_agents}` | `{parallelism}` | total member count; the child creates exactly this many worktrees |
| `{topology}` | — | not a child parameter; it selects the dispatch pattern (one invocation, or one per wave or stage) |
| `{parallel_agents}` | `{concurrency}` | simultaneous-execution cap; pacing only, never the total |
| resolved `{model_mix}` | `{agent_model}` | `broadcast` → scalar; `per-agent` → list of length `{num_agents}`; `per-partition` → list of length `{num_partitions}` plus `{num_partitions}` |
| `{num_partitions}` | `{num_partitions}` | only with `model_mix = per-partition`; the `partitioned` and `staged` topologies group the swarm's own slots, which the child never needs to know |
| `{test_command}` | `{test_command}` | when set |
| — | `{merge_mode}` | always set to `interactive`; the chosen branch is handed back through worktree-task's merge prompt |

Receiving-side contract check (worktree-task validates before any side
effect): a list-valued `{agent_model}` must have length `{parallelism}`
(per-agent) or, when `{num_partitions}` is set, be a correctly-sized
per-partition iteration; `{concurrency}` must be an integer in
`1..{parallelism}`.

The swarm keeps for itself (never forwarded): `{selection_modes}`,
`{aggregator}`, `{min_successes}`, `{relaunch_on_hang_after}`,
`{replacement_policy}`, `{cost_cap}`, `{pattern}`, `{topology}`,
`--preview-swarm-topology`. Member lifecycle results bubble up as events
(`member.started`, `member.completed`, ...) and feed the selection modes.

### Contract cases

Dispatch resolutions that must hold (and that the child's fail-fast
validation must accept), with `n = {num_agents}`, `p = {parallel_agents}`:

| Case | agent-swarm inputs | worktree-task receives | Must pass |
|---|---|---|---|
| `n = p` (full parallelism) | `num_agents=4, parallel_agents=4`, `model_mix=broadcast` | `parallelism=4, concurrency=4, agent_model=<scalar>` | 4 worktrees; all members launch together |
| `n > p` (throttled) | `num_agents=8, parallel_agents=4`, `model_mix=broadcast` | `parallelism=8, concurrency=4, agent_model=<scalar>` | 8 worktrees; at most 4 run at once; slot indexes stay stable |
| per-agent models | `num_agents=8, parallel_agents=4`, `model_mix=per-agent` (list of 8) | `parallelism=8, concurrency=4, agent_model=<list of 8>` | `len(agent_model) == parallelism`; member *i* gets element *i* |
| per-partition models | `num_agents=8, parallel_agents=4`, `model_mix=per-partition`, `num_partitions=2` (list of 2) | `parallelism=8, concurrency=4, num_partitions=2, agent_model=<list of 2>` | list length = `num_partitions`; `num_partitions` divides `parallelism`; each slice of 4 shares one model |
| `staged` waves | `num_agents=6, parallel_agents=6`, `topology=staged`, `num_partitions=3` | three invocations, each `parallelism=2, concurrency=2, base_branch=<swarm base>, worktree_name=<slug>-w<j>`, carrying that wave's 2-element model slice | wave *j+1* launches only after wave *j* terminates; every invocation satisfies `len(agent_model) == parallelism` |
| `pipeline` stages | `num_agents=3`, `topology=pipeline` (`parallel_agents` resolves to 1) | three invocations, each `parallelism=1, concurrency=1, worktree_name=<slug>-s<i>`, with `base_branch` = the previous stage's branch | stage 1 forks from the swarm base; a non-`success` stage stops the chain and the remaining stages are reported `incomplete` |

## Invariants

- **Isolation:** members never read, write, or run commands against the
  calling worktree or any sibling (worktree-task, agent-swarm, and meta-prompt
  all restate this).
- **Single merge:** at most one worktree branch is merged per invocation,
  regardless of how many members succeeded or how many selection modes
  converged.
- **No recursion:** fan-out never nests — spawned members always run with
  `candidate_count = 1`. agent-swarm's `staged` and `pipeline` topologies
  order members the swarm already owns; no member spawns another.
- **Validate before side effects:** every parameter check happens before the
  first worktree, branch, or file write; failure aborts with an explanatory
  error and no filesystem changes.
