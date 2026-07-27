# Replication

How many independent runs happen, how many run at once, and how they group.
This is the highest-collision concern in the repo: six artifacts spell the
same three concepts more than a dozen different ways. The three cards below
are the canonical split — **total count**, **concurrency cap**, and
**partition grouping** are distinct knobs even where an artifact conflates
them.

## Cards

### `candidate_count`
- **Aliases:** `n` (meta-prompt), `num_experiments` (critique), `parallelism`
  (worktree-task), `num_agents` / `n` / `num` (agent-swarm), `fan_out`
  (designer)
- **Applies to:** command, skill
- **Type:** integer `>= 1` (agent-swarm requires `>= 2` and refuses a "swarm of 1"; designer accepts `>= 2` only in `mode=walkthrough`)
- **Default:** `1` (meta-prompt, critique, worktree-task, designer);
  required (agent-swarm)
- **Meaning:** Total number of independent runs / agents / variants launched
  for one invocation. `1` means no fan-out: the workflow runs entirely in the
  calling agent. In designer's `mode=walkthrough` the fan-out is per round: a
  round that forks spawns this many variants, and `1` means the round prompts
  for a count instead.
- **Validation:** a list-valued `agent_model` must have length
  `candidate_count` (per-agent) or `partition_count` (per-partition);
  `partition_count` must divide `candidate_count` evenly.
- **Propagation:** never inherited — spawned agents always run with
  `candidate_count = 1` (meta-prompt spawns variants with `n=1`; swarm members
  never recurse; replacements never chain). See
  [propagation.md](../propagation.md).
- **Used by:** meta-prompt, critique, worktree-task, agent-swarm, designer

### `concurrency`
- **Aliases:** `k` (meta-prompt), `parallel` (critique), `parallel_agents` / `p` (agent-swarm); worktree-task spells it canonically (`concurrency`)
- **Applies to:** command, skill
- **Type:** integer in `1..candidate_count`
- **Default:** `= candidate_count` (meta-prompt, agent-swarm, worktree-task — full parallelism); `1` (critique)
- **Meaning:** Cap on how many members are active simultaneously. Changes
  pacing, never the total.
- **Validation:** must not exceed `candidate_count`.
- **Propagation:** maps across the agent-swarm → worktree-task dispatch edge
  (`{parallel_agents}` → `{concurrency}`, alongside
  `{num_agents}` → `{parallelism}`); members themselves have no inner
  concurrency knob. See [propagation.md](../propagation.md).
- **Used by:** meta-prompt, critique, agent-swarm, worktree-task

### `partition_count`
- **Aliases:** `num_partitions` (worktree-task, agent-swarm)
- **Applies to:** command, skill
- **Type:** integer `>= 1`; must divide `candidate_count` evenly
- **Default:** `= candidate_count` (one partition per member)
- **Meaning:** Groups members into contiguous slices, primarily for
  per-partition model assignment ("k samples per model" comparisons).
- **Validation:** when set together with a list-valued `agent_model`, the list
  must be a full per-agent iteration (length `candidate_count`) or a
  per-partition iteration (length `partition_count`).
- **Used by:** worktree-task, agent-swarm

## Artifact-specific

- `{topology}` (agent-swarm) — the arrangement of the `candidate_count`
  members: `parallel` (default — one wave of independent members) |
  `partitioned` (`partition_count` groups that share a model slice, each
  selected within before the global pass) | `staged` (`partition_count`
  sequential waves, each
  wave after the first receiving the previous wave's summaries as text) |
  `pipeline` (a chain of single-member stages, stage *i* forking from stage
  *i-1*'s branch). Orthogonal to `candidate_count` (how many) and
  `concurrency` (how many at once): topology sets what members fork from and
  what flows between them. `partitioned` and `staged` require an explicit
  `partition_count`; `pipeline` forces `concurrency = 1` and rejects an
  explicit higher value. Dispatch consequences — one worktree-task invocation
  per wave or stage, and the per-stage `base_branch` rewrite — are in
  [propagation.md](../propagation.md).
