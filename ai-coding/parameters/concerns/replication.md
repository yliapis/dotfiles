# Replication

How many independent runs happen, how many run at once, and how they group.
This is the highest-collision concern in the repo: seven artifacts spell the
same three concepts eleven different ways. The three cards below are the
canonical split — **total count**, **concurrency cap**, and **partition
grouping** are distinct knobs even where an artifact conflates them.

## Cards

### `candidate_count`
- **Aliases:** `n` (meta-prompt), `num_experiments` (critique), `parallelism` (worktree-task, address-worklist-commit-loop), `num_agents` / `n` / `num` (agent-swarm), `fan_out` (designer-controller), `fanout_default_n` (ralph-design)
- **Applies to:** command, skill
- **Type:** integer `>= 1` (agent-swarm requires `>= 2` and refuses a "swarm of 1"; ralph-design's fan-out default requires `>= 2`; designer-controller accepts `>= 2` only in `mode=walkthrough`)
- **Default:** `1` (meta-prompt, critique, worktree-task, address-worklist-commit-loop, designer-controller); required (agent-swarm); `4` (ralph-design)
- **Meaning:** Total number of independent runs / agents / variants launched
  for one invocation. `1` means no fan-out: the workflow runs entirely in the
  calling agent.
- **Validation:** a list-valued `agent_model` must have length
  `candidate_count` (per-agent) or `partition_count` (per-partition);
  `partition_count` must divide `candidate_count` evenly.
- **Propagation:** never inherited — spawned agents always run with
  `candidate_count = 1` (meta-prompt spawns variants with `n=1`; swarm members
  never recurse; replacements never chain). See
  [propagation.md](../propagation.md).
- **Used by:** meta-prompt, critique, worktree-task, address-worklist-commit-loop, agent-swarm, designer-controller, ralph-design

### `concurrency`
- **Aliases:** `k` (meta-prompt), `parallel` (critique), `parallel_agents` / `p` (agent-swarm)
- **Applies to:** command, skill
- **Type:** integer in `1..candidate_count`
- **Default:** `= candidate_count` (meta-prompt, agent-swarm — full parallelism); `1` (critique)
- **Meaning:** Cap on how many members are active simultaneously. Changes
  pacing, never the total.
- **Validation:** must not exceed `candidate_count`.
- **Propagation:** invocation-level only; members have no inner concurrency
  knob. Note: worktree-task has no separate concurrency parameter — its
  `parallelism` is both count and concurrency (all members launch together),
  which is why agent-swarm dispatches it with
  `{parallelism} = {parallel_agents}` and owns the total via `{num_agents}`.
  See [propagation.md](../propagation.md).
- **Used by:** meta-prompt, critique, agent-swarm

### `partition_count`
- **Aliases:** `num_partitions` (worktree-task, agent-swarm, address-worklist-commit-loop)
- **Applies to:** command, skill
- **Type:** integer `>= 1`; must divide `candidate_count` evenly (agent-swarm, address-worklist-commit-loop)
- **Default:** `= candidate_count` (one partition per member)
- **Meaning:** Groups members into contiguous slices, primarily for
  per-partition model assignment ("k samples per model" comparisons) and, in
  address-worklist-commit-loop, for distributing work items.
- **Validation:** when set together with a list-valued `agent_model`, the list
  must be a full per-agent iteration (length `candidate_count`) or a
  per-partition iteration (length `partition_count`).
- **Used by:** worktree-task, agent-swarm, address-worklist-commit-loop

## Artifact-specific

- `{partition_strategy}` (address-worklist-commit-loop) — how unaddressed work
  items distribute across the `{parallelism}` slices: `round-robin` (default) |
  `contiguous` | `severity-balanced`. Distinct from `partition_count`, which
  groups *agents* for model assignment; this groups *work items*.
