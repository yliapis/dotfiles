# `trait_map` — registry resolving trait names to design skills

Trait-name → skill-path registry that resolves trait names to
`.cursor/skills/<trait>-design/SKILL.md` files, read at invocation time
(never inlined). Extending it is one new row plus the matching `SKILL.md`
— no caller changes.

- **Used by:** designer, designer-controller
- **Full entry:** [concerns/composition.md](../concerns/composition.md#trait_map)
