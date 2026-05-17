# Designer

## Task

Invoke `/designer {traits} {target}` to apply each named design-style skill to `{target}` and emit a single unified design proposal. The command is composable (every listed trait is applied together, with tensions surfaced rather than silently resolved), idempotent (same `{traits}` and `{target}` always yield byte-equivalent output), and resilient to skill-body edits — each trait is referenced by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and read fresh at invocation time rather than inlined here.

## Parameters

- `{traits}` — ordered list of one or more trait names from the `/designer` invocation; required. Each name must resolve to an entry in `{trait_map}` or the invocation aborts.
- `{target}` — artifact to design: inline text, file path, directory path, or free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping used to resolve each name in `{traits}` to its canonical skill file. Seeded entries:
  - `declarative` → `.cursor/skills/declarative-design/SKILL.md`
  - `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

  To add a future trait, append one row to this mapping of the form `{new-trait}` → `.cursor/skills/{new-trait}-design/SKILL.md`, then create the matching `SKILL.md`. No edits to callers of `/designer` are required.

## Success Criteria

- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; unknown traits (names with no entry in `{trait_map}`) abort with an explanatory error listing every unrecognized name.
- [ ] Every resolved skill file is read and explicitly applied before any design output is drafted; the unified proposal credits each trait in its own subsection inside `## Per-Trait Contribution`.
- [ ] Running `/designer` twice with the same `{traits}` and `{target}` produces byte-equivalent output (idempotency).
- [ ] When more than one trait is supplied, every named trait's skill is applied and any tensions between traits are surfaced in `## Tensions and Tradeoffs`; conflicts are never silently reconciled.

## Guardrails

- MUST read every skill file referenced by `{trait_map}` for the named traits before drafting any design output.
- MUST apply every named trait's skill; MUST NOT drop, down-weight, or silently merge any trait's guidance.
- MUST NOT inline, hard-code, or summarize the body of any design skill into this command; reference each skill by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and read it at invocation time.
- MUST surface unresolvable conflicts between traits in `## Tensions and Tradeoffs`; MUST NOT silently pick a winner or blend conflicting guidance unless the user supplied an explicit precedence rule.
- MUST abort with an explanatory error before any design work begins if any name in `{traits}` has no entry in `{trait_map}`.
- Scope: produce one unified design proposal for `{target}` using the skills named in `{traits}`. Out of scope: editing `{target}`, editing or creating skill files, executing the resulting design.

## Workflow

1. Parse the invocation into `{traits}` (ordered list of trait names) and `{target}` (the artifact to design).
2. Resolve each trait via `{trait_map}` to its canonical skill path; if any name has no entry in `{trait_map}`, abort immediately with an explanatory error naming every unrecognized trait before any design work begins.
3. Read every resolved skill file (`.cursor/skills/{trait}-design/SKILL.md` for each trait in `{traits}`); if a skill file does not yet exist on disk, note the missing path in the proposal header and continue with all available skill files.
4. Apply all loaded skills together to `{target}`; for each trait record its contribution to the unified design and flag any point where its guidance conflicts with another trait's guidance.
5. Detect tensions: where two or more skills give contradictory direction for the same design decision, record each conflict as a labeled entry in `## Tensions and Tradeoffs`, identifying the traits in tension.
6. Emit the unified proposal using the report shape in `## Output Format`.

## Output Format

A single markdown report:

````markdown
# Designer Proposal: <short identifier for {target}>

**Traits applied:** <comma-separated list of resolved traits>
**Target:** <resolved {target}>

## Unified Proposal
<The design that honors every named trait, integrating their guidance into a single coherent proposal.>

## Per-Trait Contribution
### <trait_1>
<What this trait's skill contributed to the unified proposal.>

### <trait_2>
<What this trait's skill contributed to the unified proposal.>

## Tensions and Tradeoffs
<Each unresolvable conflict between traits, labeled by the pair of traits in tension and the specific decision point at issue, or `_None._` when there are none.>
````
