# Composition

How artifacts select and shape *other* skills and presets: trait registries
that resolve names to design skills, preset shortcuts that bundle defaults,
and style dimensions that bias drafting. This is the meta-programming concern
— parameters here change which guidance gets loaded, not what work is done.

## Cards

### `traits`
- **Aliases:** —
- **Applies to:** command, skill
- **Type:** non-empty ordered list of trait names; every name must be a key in
  the trait map
- **Default:** required
- **Meaning:** The design traits to apply to the target, in invocation order.
  All named traits are applied together — none is dropped, down-weighted, or
  silently merged; conflicts surface as labeled tensions.
- **Validation:** unknown traits abort before any design work, naming every
  unrecognized trait and listing the available ones. designer-controller
  requires exactly one trait in `mode=walkthrough`, one or more in
  `mode=propose`.
- **Used by:** designer (`{traits}`), designer-controller (`traits`)

### `trait_map`
- **Aliases:** —
- **Applies to:** command, skill
- **Type:** trait-name → skill-path registry; every path is repo-relative
  under `.cursor/skills/` (absolute paths, `~/`, `$HOME` rejected)
- **Default:** declared verbatim in the artifact body; seeded with
  `declarative` → `.cursor/skills/declarative-design/SKILL.md` and
  `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`
- **Meaning:** The registry that resolves trait names to
  `.cursor/skills/<trait>-design/SKILL.md` files, read at invocation time
  (never inlined). Extending it is one new row plus the matching `SKILL.md` —
  no caller changes.
- **Used by:** designer (`{trait_map}` parameter), designer-controller (`## Trait Map` section)

## Artifact-specific

- `{style}` / `{styles}` (meta-prompt) — synonyms; a single trait name or a
  comma-separated list. Design dimensions to prioritize when drafting or
  refining wording and criteria (accuracy, consistency, reliability,
  conciseness, simplicity, ...). Kin to `traits` but free-form: no registry,
  no skill files — the traits bias language and checkability directly.
  Parsed from `{input}` as `style=` / `styles=` and stripped; propagated
  verbatim to spawned variant agents.
- `{pattern}` (agent-swarm) — preset shortcut: `sanity` | `diversity` |
  `consensus` | `synthesize` | `tournament`. Supplies defaults for
  `{num_agents}`, `{model_mix}`, and `{selection_modes}` from the Pattern
  Catalog; user-set parameters always override preset defaults.
- `{design_skill}` (ralph-design) — repo-relative path to the design skill
  supplying the principles list and walkthrough the loop walks. Default:
  `.cursor/skills/declarative-design/SKILL.md`. Read at invocation time;
  round count, step names, and deliverable shape are sourced from it.
- `precedence` (designer-controller) — trait-conflict resolution: `none`
  (default) | ordered trait list | explicit rule string. Only meaningful in
  `mode=propose` with two or more traits; rejected otherwise.
- `deliverable_shape` (designer-controller) — output document shape: `union`
  (default — per-trait deliverables under one umbrella report) | `schema-doc`
  | `adr` | `prd` | `spec` | inline template string.
- `audience` (designer-controller) — advisory tone/detail target:
  `engineers` (default) | `managers` | `mixed` | free-form noun. No hard
  contract.
- `depth` (designer-controller) — advisory length/density: `sketch` |
  `standard` (default) | `deep`. No hard contract.
