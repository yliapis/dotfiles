# `max_consecutive_failures` — per-agent circuit breaker

When an agent records this many consecutive non-`committed` items, it
halts its slice regardless of `{on_failure}` and the slice is reported as
`circuit-broken`. The counter resets on each successful commit. Default:
unbounded.

- **Used by:** address-worklist-commit-loop
- **Full entry:** [concerns/robustness.md](../concerns/robustness.md#address-worklist-commit-loop)
