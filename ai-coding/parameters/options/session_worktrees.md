# `session_worktrees` — worktrees created this thread that gate shutdown

Worktree absolute paths created during this thread that soft-shutdown
must reconcile before shutting down. Default: every worktree from
`git worktree list --porcelain` other than the main and calling
worktrees.

- **Used by:** soft-shutdown
- **Full entry:** [concerns/isolation.md](../concerns/isolation.md#artifact-specific)
