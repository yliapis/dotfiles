# `model_mix` — model-assignment shape for a swarm

The model-assignment *shape* for the swarm: `broadcast` (one model to
all, default) | `per-agent` (list of length `{num_agents}`) |
`per-partition` (list of length `{num_partitions}`, broadcast across
contiguous slices). Resolves into worktree-task's `agent_model` at
dispatch time.

- **Used by:** agent-swarm
- **Full entry:** [concerns/models.md](../concerns/models.md#artifact-specific)
