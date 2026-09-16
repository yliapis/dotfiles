# `delete_worktree` — remove a worktree after its branch merges

Boolean controlling whether a worktree (and its branch) is removed after a
successful merge. Unmerged worktrees are always left in place; deletion
never happens before the user has seen the diff (interactive) or the merge
succeeded (auto). Aliased as `delete_after_merge` (wrap-up).

- **Used by:** worktree-task, wrap-up
- **Full entry:** [concerns/isolation.md](../concerns/isolation.md#delete_worktree)
