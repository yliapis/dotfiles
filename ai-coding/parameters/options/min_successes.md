# `min_successes` — success floor before aggregation runs

Minimum number of members reaching `success` before aggregation runs.
Default: `ceil({num_agents} / 2)`. If unmet after replacements terminate,
every selection mode reports `under-floor` and no winner is
auto-selected.

- **Used by:** agent-swarm
- **Full entry:** [concerns/selection.md](../concerns/selection.md#agent-swarm)
