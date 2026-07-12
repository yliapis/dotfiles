# `session_branches` — branches created this thread that gate shutdown

Branches created during this thread that soft-shutdown must reconcile
before shutting down. Default: each branch associated with a path in the
resolved `{session_worktrees}` set, plus the current branch when it
differs from `{base_branch}`.

- **Used by:** soft-shutdown
- **Full entry:** [concerns/isolation.md](../concerns/isolation.md#artifact-specific)
