# `approval_mode` — how often a loop pauses for user sign-off

Enum (`interactive` | `non-interactive` | `force-approve-all`) setting the
approval cadence for a loop: `interactive` approves the plan and each
step/commit; `non-interactive` approves the plan once, then runs silently;
`force-approve-all` accepts every default with no approvals. Spelled
`mode` in both declaring artifacts.

- **Used by:** address-worklist-commit-loop, ralph-design
- **Full entry:** [concerns/interaction.md](../concerns/interaction.md#approval_mode)
