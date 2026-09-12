# `write_gate` (family) — whether the run writes files or only previews

Family of spellings for one concept: whether the run mutates the
filesystem or only shows what it would do. Each member gates its primary
deliverable write behind a no-write mode. Spellings: `update_mode`
(meta-prompt), `persistence` (ralph-design, design-skill,
designer-controller), `dry_run` (address-worklist-commit-loop), `mode`
(save-session-state).

- **Used by:** meta-prompt, ralph-design, design-skill, designer-controller, address-worklist-commit-loop, save-session-state
- **Full entry:** [concerns/lifecycle.md](../concerns/lifecycle.md#write_gate-family)
