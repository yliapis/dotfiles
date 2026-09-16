# `concurrency` — cap on simultaneously active members

Caps how many fan-out members are active at once; changes pacing, never
the total. Must not exceed `candidate_count`. Aliased as `k` (meta-prompt),
`parallel` (critique), `parallel_agents` / `p` (agent-swarm);
worktree-task spells it canonically.

- **Used by:** meta-prompt, critique, agent-swarm, worktree-task
- **Full entry:** [concerns/replication.md](../concerns/replication.md#concurrency)
