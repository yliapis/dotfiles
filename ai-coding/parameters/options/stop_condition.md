# `stop_condition` — explicit completion condition

An explicit completion condition beyond the implicit "done": per-member in
worktree-task (free-text predicate that gates merge eligibility), loop-exit
in ralph-design (closed enum: `user-signals-done` | `all-steps-complete` |
`validation-pass` | `max-rounds:<n>`).

- **Used by:** worktree-task, ralph-design
- **Full entry:** [concerns/constraints.md](../concerns/constraints.md#stop_condition)
