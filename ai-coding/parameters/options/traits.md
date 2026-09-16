# `traits` — the design traits to apply to the target

Non-empty ordered list of trait names to apply to the target, in
invocation order; every name must be a key in the trait map. All named
traits are applied together — none is dropped, down-weighted, or silently
merged; conflicts surface as labeled tensions.

- **Used by:** designer, designer-controller
- **Full entry:** [concerns/composition.md](../concerns/composition.md#traits)
