# `candidate_count` — total independent runs launched per invocation

Sets how many independent runs / agents / variants one invocation fans out
into; `1` means no fan-out: the workflow runs entirely in the calling
agent. Aliased as `n`, `num_experiments`, `parallelism`, `num_agents`,
`num`, `fan_out`, `fanout_default_n` across artifacts. Never inherited —
spawned agents always run with `candidate_count = 1`.

- **Used by:** meta-prompt, critique, worktree-task, address-worklist-commit-loop, agent-swarm, designer-controller, ralph-design
- **Full entry:** [concerns/replication.md](../concerns/replication.md#candidate_count)
