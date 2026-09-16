# `selection_modes` — how swarm candidates reduce to an outcome

List (any subset) of `manual`, `auto-best`, `synthesize`, `vote`,
`hybrid`, `tournament`, `consensus`. Every listed mode runs in parallel
over the surviving members and produces its own outcome block. Default:
`auto` — every mode whose prerequisites are met; skipped modes are
reported with the missing prerequisite.

- **Used by:** agent-swarm
- **Full entry:** [concerns/selection.md](../concerns/selection.md#agent-swarm)
