# `worklist` — the work-item source for the commit loop

The source the loop draws work items from: a markdown path, chat
reference, MCP endpoint, or inline items. Required; each unaddressed item
becomes a unit of work that is implemented, verified, and committed.

- **Used by:** address-worklist-commit-loop
- **Full entry:** [concerns/intent.md](../concerns/intent.md#artifact-specific)
