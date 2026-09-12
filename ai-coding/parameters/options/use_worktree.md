# `use_worktree` — whether codebase writes happen in a dedicated worktree

Boolean controlling whether disk writes for a codebase-persisted
deliverable happen inside a dedicated worktree forked from the current
branch; when `true`, the calling working tree is never touched. Must be
`false` when `persistence=chat`.

- **Used by:** ralph-design, design-skill, designer-controller
- **Full entry:** [concerns/isolation.md](../concerns/isolation.md#use_worktree)
