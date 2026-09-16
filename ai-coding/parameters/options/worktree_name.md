# `worktree_name` — base name for the worktree directory and branch

Filesystem-safe kebab-case base name for the worktree directory and its
branch; defaults to a slug derived from the intent parameter (`task`,
`worklist`, `domain`). When fanning out, a 1-based index suffix (`-1`,
`-2`, ...) is appended per member. Aliased as `worktree` (meta-prompt).

- **Used by:** worktree-task, address-worklist-commit-loop, ralph-design, meta-prompt
- **Full entry:** [concerns/isolation.md](../concerns/isolation.md#worktree_name)
