# `partition_count` — grouping of members into contiguous slices

Groups fan-out members into contiguous slices, primarily for per-partition
model assignment ("k samples per model" comparisons) and, in
address-worklist-commit-loop, for distributing work items. Aliased as
`num_partitions` everywhere it appears.

- **Used by:** worktree-task, agent-swarm, address-worklist-commit-loop
- **Full entry:** [concerns/replication.md](../concerns/replication.md#partition_count)
