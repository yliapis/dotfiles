# `max_iterations` — hard safety cap on loop rounds

Hard cap on total loop rounds, counting repeats via `refine` / `back`;
hitting it halts with a terminal state (e.g. `iteration-cap-hit`)
regardless of `stop_condition`. The two design skills accept it only in
`mode=walkthrough`.

- **Used by:** ralph-design, design-skill, designer-controller
- **Full entry:** [concerns/constraints.md](../concerns/constraints.md#max_iterations)
