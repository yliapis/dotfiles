# `cost_cap` — soft cap on projected swarm spend

Soft cap on projected token spend or wall-clock seconds across the swarm.
Optional. When set, cost is projected before dispatch; if the projection
exceeds the cap, the skill proposes a smaller `{num_agents}` and waits
for user approval — it never silently shrinks.

- **Used by:** agent-swarm
- **Full entry:** [concerns/robustness.md](../concerns/robustness.md#agent-swarm)
