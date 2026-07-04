# Robustness

What happens when things hang, fail repeatedly, or overspend. Only the two
loop-shaped artifacts declare robustness parameters today — agent-swarm
(member-level hang recovery and cost control) and address-worklist-commit-loop
(per-item failure policy and a circuit breaker). No parameter spans two
artifacts yet, so this file has no cards.

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

## address-worklist-commit-loop

- `{on_failure}` — policy when an item's implementation, `{verify_command}`,
  or commit creation fails: `abort` | `skip` | `retry-once-then-skip` |
  `mark-blocked`. Default depends on `{mode}`: `abort` for `interactive`,
  `retry-once-then-skip` for `non-interactive` and `force-approve-all`.
- `{max_consecutive_failures}` — per-agent circuit breaker. When an agent
  records this many consecutive non-`committed` items, it halts its slice
  regardless of `{on_failure}` and the slice is reported as `circuit-broken`.
  The counter resets on each successful commit. Default: unbounded.
