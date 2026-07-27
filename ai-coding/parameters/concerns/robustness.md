# Robustness

What happens when work hangs, fails, or is interrupted. Agent-swarm owns member
replacement and cost control; ticket execution owns per-task rollback.

## agent-swarm

- `{relaunch_on_hang_after}` — wall-clock duration after which a silent member
  is force-aborted (a hard kill, not a polite request). Default: `5m`.
  Whether the killed member is respawned is decided by
  `{replacement_policy}`.
- `{replacement_policy}` — hang-recovery policy: `off` (default — killed
  members end as `incomplete`) | `replace-up-to-n` (each slot may respawn at
  most once) | `replace-up-to-budget` (replacements continue while the
  `{cost_cap}` projection allows; requires `{cost_cap}`). Replacements never
  recurse: a replacement that itself hangs ends as `incomplete`. A
  replacement counts toward `{min_successes}` only if it reports `success`.
- `{cost_cap}` — soft cap on projected token spend or wall-clock seconds
  across the swarm. Optional. When set, cost is projected before dispatch; if
  the projection exceeds the cap, the skill proposes a smaller
  `{num_agents}` and waits for user approval — it never silently shrinks.

## ticket-execute

- `{on_failure}` — after the failed task is rolled back to its starting status
  and its working-tree changes are restored, `abort` (default) stops or
  `continue` re-reads the board and considers only independent runnable tasks.
