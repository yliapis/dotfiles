# Selection

How multiple candidates reduce to an outcome: pick one, merge many, or report
disagreement. Today only two artifacts declare selection parameters
(agent-swarm and wrap-up); worktree-task's pick-a-winner step is governed by
[`merge_mode`](lifecycle.md#merge_mode), and critique's cross-run aggregation
(convergent vs divergent findings) is built-in behavior, not a parameter.

No parameter in this concern spans two artifacts yet, so this file has no
cards — only the two artifact groups below.

## agent-swarm

- `{selection_modes}` — list (any subset) of `manual`, `auto-best`,
  `synthesize`, `vote`, `hybrid`, `tournament`, `consensus`. Every listed mode
  runs in parallel over the surviving members and produces its own outcome
  block. Default: `auto` — every mode whose prerequisites are met; skipped
  modes are reported with the missing prerequisite. Prerequisites:

  | Mode | Decision rule | Requires |
  |---|---|---|
  | `manual` | user picks zero or one branch from the per-member report | — |
  | `auto-best` | rank by `test_command` exit, then smaller diff, fewer files, lower index | `test_command` |
  | `synthesize` | run `aggregator` over survivors; emit one merged artifact | `aggregator` |
  | `vote` | group by output equivalence; largest group wins | `test_command` or comparable signature |
  | `hybrid` | filter by `test_command`, then `aggregator` over the filtered set | `test_command` and `aggregator` |
  | `tournament` | pairwise reduction to one | `test_command`; `candidate_count` must be a power of 2 |
  | `consensus` | emit only per-hunk agreement as a unified diff, plus contested hunks | comparable diffs |

- `{aggregator}` — prompt or shell command that produces a merged artifact from
  candidates. Required when `synthesize` or `hybrid` is selected.
- `{min_successes}` — minimum members reaching `success` before aggregation
  runs. Default: `ceil({num_agents} / 2)`. If unmet after replacements
  terminate, every selection mode reports `under-floor` and no winner is
  auto-selected.

Regardless of how many modes converge on the same winner, at most one worktree
branch is merged per invocation (see [merge_mode](lifecycle.md#merge_mode)).

## wrap-up

- `{rollup}` — rollup mode for substantive variant content when archiving
  worktrees: `interactive` | `auto` | `off`. Default: `interactive` when `-i`
  is set, else `off`.
- `{rollup_threshold}` — minimum distinct new lines a variant must add vs its
  canonical to qualify as substantive. Default: `30`.
