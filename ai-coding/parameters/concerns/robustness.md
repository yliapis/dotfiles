# Robustness

What happens when work hangs, fails, or is interrupted. Agent-swarm owns member
replacement and cost control; ticket execution owns per-ticket rollback;
ticket execution and update share journal recovery semantics.

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

- `{on_failure}` — after guarded rollback, `abort` (default) stops or
  `continue` revalidates the set and considers only independent runnable
  tickets. The compatibility command relays this parameter.
- `{recovery}` — `abort` (default) reports an interrupted execution journal,
  `resume` continues only a recognized transaction state, and `rollback`
  restores exact journaled preimages while `HEAD` permits.

## crud-tickets

- `{recovery}` — the same `abort` | `resume` | `rollback` surface, scoped to a
  valid update journal. Resume never consumes another revision or
  approval; rollback never rewrites a committed transaction.
