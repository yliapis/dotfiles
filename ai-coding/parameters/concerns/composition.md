# Composition

How artifacts select and shape *other* guidance and presets: trait registries
that resolve names to design trait cards, preset shortcuts that bundle defaults,
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
  unrecognized trait and listing the available ones. designer requires exactly
  one trait in `mode=walkthrough`, one or more in `mode=propose`.
- **Used by:** designer (`traits`), and the `/designer` and `/ralph-design`
  presets, which forward it

### `trait_map`
- **Aliases:** —
- **Applies to:** skill
- **Type:** trait-name → card-path registry; every path is relative to the
  owning skill's own directory and must resolve under `./traits/` (`..`
  segments, absolute paths, `~/`, `$HOME` rejected)
- **Default:** declared verbatim in the artifact body; seeded with
  `declarative` → `./traits/declarative.md` and
  `deterministic` → `./traits/deterministic.md`
- **Meaning:** The registry that resolves trait names to `./traits/<trait>.md`
  cards, read at invocation time (never inlined). Extending it is one new row
  plus the matching card — no caller changes. Sibling-relative paths are what
  let the skill directory work unchanged as plugin source, as a generated
  project mirror, and as a home-scope install.
- **Used by:** designer (`## Trait Map` section)

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
- `{ticket_template}` (ticket-create) — path to the parameterized ticket
  template rendered once per ticket. Default: the skill's own
  `TICKET_TEMPLATE.md`. Read at invocation time (never inlined), like a
  `trait_map` card; a custom template may use any subset of the skill's
  token vocabulary, and unknown tokens abort before any write.
- `precedence` (designer) — trait-conflict resolution: `none`
  (default) | ordered trait list | explicit rule string. Only meaningful in
  `mode=propose` with two or more traits; rejected otherwise.
- `deliverable_shape` (designer) — output document shape: `union`
  (default — per-trait deliverables under one umbrella report) | `schema-doc`
  | `adr` | `prd` | `spec` | inline template string.
- `audience` (designer) — advisory tone/detail target:
  `engineers` (default) | `managers` | `mixed` | free-form noun. No hard
  contract.
- `depth` (designer) — advisory length/density: `sketch` |
  `standard` (default) | `deep`. No hard contract.

`{design_skill}` (ralph-design) is retired. The loop's trait is now selected by
the `designer` skill's `traits` knob, not by a path to a skill file.
