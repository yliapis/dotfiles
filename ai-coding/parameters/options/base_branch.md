# `base_branch` — branch worktrees fork from and merge back into

The branch worktrees are forked from and merged back into. Fan-out
artifacts default to the current branch; session-hygiene commands
(wrap-up, soft-shutdown) reconcile against `main`. Broadcast: every member
forks from the same branch, and per-member diffs render against it.

- **Used by:** worktree-task, address-worklist-commit-loop, ralph-design, wrap-up, soft-shutdown
- **Full entry:** [concerns/isolation.md](../concerns/isolation.md#base_branch)
