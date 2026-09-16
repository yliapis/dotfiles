# `replacement_policy` — whether killed members are respawned

Hang-recovery policy: `off` (default — killed members end as
`incomplete`) | `replace-up-to-n` (each slot may respawn at most once) |
`replace-up-to-budget` (replacements continue while the `{cost_cap}`
projection allows). Replacements never recurse: a replacement that itself
hangs ends as `incomplete`.

- **Used by:** agent-swarm
- **Full entry:** [concerns/robustness.md](../concerns/robustness.md#agent-swarm)
