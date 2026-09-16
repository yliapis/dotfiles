# `relaunch_on_hang_after` — hang timeout before a member is killed

Wall-clock duration after which a silent swarm member is force-aborted (a
hard kill, not a polite request). Default: `5m`. Whether the killed
member is respawned is decided by `{replacement_policy}`.

- **Used by:** agent-swarm
- **Full entry:** [concerns/robustness.md](../concerns/robustness.md#agent-swarm)
