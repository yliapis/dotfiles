# `authoring_mode` — one-shot draft vs stepwise walkthrough

Enum (`walkthrough` | `propose`) selecting the authoring motion:
`walkthrough` runs an interactive section-by-section loop (one round per
section); `propose` generates the full draft in one shot from the spec.
Gates other knobs — `max_iterations` and `fan_out >= 2` are
walkthrough-only. Spelled `mode` in both declaring artifacts.

- **Used by:** design-skill, designer-controller
- **Full entry:** [concerns/interaction.md](../concerns/interaction.md#authoring_mode)
