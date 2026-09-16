# `partition_strategy` — how work items distribute across agent slices

How unaddressed work items distribute across the `{parallelism}` slices:
`round-robin` (default) | `contiguous` | `severity-balanced`. Distinct
from `partition_count`, which groups *agents* for model assignment; this
groups *work items*.

- **Used by:** address-worklist-commit-loop
- **Full entry:** [concerns/replication.md](../concerns/replication.md#artifact-specific)
