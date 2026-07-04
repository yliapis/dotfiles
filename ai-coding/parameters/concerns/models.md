# Models

Which model runs where. Two distinct concepts share this concern and must not
be conflated: **`model`** is the model the current (orchestrating) agent runs
analysis on, while **`agent_model`** assigns models to *spawned* workers. Every
artifact defaults both to "the parent agent's model", so the distinction only
bites when a fan-out mixes models.

## Cards

### `agent_model`
- **Aliases:** —
- **Applies to:** command, skill → spawned agent
- **Type:** a single model identifier, or a list of identifiers (worktree-task,
  address-worklist-commit-loop only)
- **Default:** the parent agent's model
- **Meaning:** Model(s) assigned to spawned worker agents. A scalar broadcasts
  to every member; a list maps positionally.
- **Validation:** list length must equal `candidate_count` (per agent, by
  index) or `partition_count` (per partition, broadcast within) — see
  [replication.md](replication.md). ralph-design and designer-controller
  accept a scalar only; designer-controller accepts it only when
  `fan_out >= 2`.
- **Propagation:** scalar → broadcast; list → positional zip or per-partition
  broadcast. See [propagation.md](../propagation.md).
- **Used by:** worktree-task, address-worklist-commit-loop, ralph-design, designer-controller

## Artifact-specific

- `{model}` (critique) — the model used for each analysis run. Default: the
  parent agent's model. Critique restates the resolved value in its report
  header. This is the only live declaration of the "which model does the
  current work" concept; other artifacts inherit the parent model implicitly.
- `{model_mix}` (agent-swarm) — the model-assignment *shape* for the swarm:
  `broadcast` (one model to all, default) | `per-agent` (list of length
  `{num_agents}`) | `per-partition` (list of length `{num_partitions}`,
  broadcast across contiguous slices). Resolves into worktree-task's
  `agent_model` at dispatch time — see [propagation.md](../propagation.md).
