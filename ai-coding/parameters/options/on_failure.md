# `on_failure` — per-item failure policy in the commit loop

Policy when an item's implementation, `{verify_command}`, or commit
creation fails: `abort` | `skip` | `retry-once-then-skip` |
`mark-blocked`. Default depends on `{mode}`: `abort` for `interactive`,
`retry-once-then-skip` for `non-interactive` and `force-approve-all`.

- **Used by:** address-worklist-commit-loop
- **Full entry:** [concerns/robustness.md](../concerns/robustness.md#address-worklist-commit-loop)
