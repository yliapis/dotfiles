# Designer

## Task
Invoke `/designer {traits} {target}` to apply every named design-style skill to `{target}` and emit one unified design proposal that credits each trait and surfaces any unresolvable tensions between them.

The command is composable (every named trait's skill is applied together), idempotent (running it twice with the same `{traits}` and `{target}` produces byte-equivalent output), and resilient to skill-body edits — every design skill is referenced by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and read at invocation time rather than inlined.

## Parameters
- `{traits}` — ordered list of trait names from the `/designer` invocation; required. Each name MUST appear as a key in the `{trait_map}` defined below; unknown names abort before any design work begins.
- `{target}` — artifact to design: accepts inline text, file path, directory path, or free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping, defined verbatim in the table below; required. Seeded entries:

  | Trait | Skill path |
  | --- | --- |
  | `declarative` | `.cursor/skills/declarative-design/SKILL.md` |
  | `deterministic` | `.cursor/skills/deterministic-design/SKILL.md` |

## Success Criteria
- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; unknown traits abort with an explanatory error naming the offending name and no design output is produced.
- [ ] Every resolved skill file is read from its canonical `.cursor/skills/{trait}-design/SKILL.md` path and applied; the rendered report credits each named trait in its own subsection under `## Per-Trait Contribution`.
- [ ] When `{traits}` contains more than one trait, every named trait's skill is applied; tensions between traits are surfaced in `## Tensions and Tradeoffs`, never silently reconciled.
- [ ] `## Tensions and Tradeoffs` reads `_None._` when no unresolvable conflicts between traits are detected.
- [ ] Running `/designer` twice with the same `{traits}` (in the same order) and the same `{target}` produces byte-equivalent output.
- [ ] No content in the rendered report originates from a skill body that was not read from its canonical `.cursor/skills/{trait}-design/SKILL.md` path at invocation time.

## Guardrails
- MUST `Read` every skill file referenced by `{trait_map}` for the named traits before drafting any design output, and MUST `apply` its guidance to `{target}` when composing the unified proposal.
- MUST apply every named trait's skill in concert when `{traits}` contains more than one entry; MUST NOT drop, down-weight, or silently merge any named trait.
- MUST surface unresolvable conflicts between traits in `## Tensions and Tradeoffs` with both positions labeled; MUST NOT pick a winner unless the invocation supplied an explicit precedence rule.
- MUST reference each design skill by its canonical `.cursor/skills/{trait}-design/SKILL.md` path. MUST NOT inline, hard-code, or summarize the body of any design skill into the rendered report or into this command file.
- MUST abort with an explanatory error when `{traits}` contains a name absent from `{trait_map}`, before any skill file is read or any design work begins.
- MUST produce output deterministically: the same `{traits}` (in the same order) and the same `{target}` always produce byte-equivalent output across runs.
- Scope: produce one unified design proposal for one `{target}` using the traits named in `{traits}`. Out of scope: editing `{target}`, creating or editing any file under `.cursor/skills/`, executing the resulting design, or producing alternative proposals beyond the one unified report.

## Workflow
1. Parse the `/designer` invocation into `{traits}` — the ordered prefix of trait-name tokens — and `{target}` — every remaining token concatenated as the design target.
2. Resolve each name in `{traits}` against the `{trait_map}` table to its canonical `.cursor/skills/{trait}-design/SKILL.md` path; abort with an explanatory error naming the offending entry if any trait does not appear as a key in `{trait_map}`. Resolution happens before any skill file is read.
3. `Read` every resolved skill file from its canonical path before drafting any design output; treat that file's content as the canonical guidance for the named trait at invocation time.
4. `apply` every named trait's guidance together to `{target}` when composing the unified proposal. Record each trait's contribution. Label any decision where two traits' guidance gives contradictory direction as a tension.
5. Detect tensions: any decision where applying one trait's guidance verbatim would violate another trait's guidance counts as a tension. Record both positions and the contested decision; do not pick a winner unless the invocation supplied an explicit precedence rule.
6. Render the report described in `## Output Format`. Use the resolved `{traits}` list (in invocation order) for the header, one subsection per trait under `## Per-Trait Contribution` (in the same order), and either every recorded tension under `## Tensions and Tradeoffs` or `_None._` when no tensions were recorded.

## Output Format
A single markdown report:

````markdown
# Designer Proposal: <short identifier for {target}>

**Traits applied:** <comma-separated list of resolved traits, in invocation order>
**Target:** <resolved {target}>

## Unified Proposal
<The design that honors every named trait.>

## Per-Trait Contribution
### <trait_1>
<What this trait contributed to the unified proposal, citing its skill's guidance.>

### <trait_2>
<What this trait contributed to the unified proposal, citing its skill's guidance.>

## Tensions and Tradeoffs
<Each unresolvable conflict between traits, with both positions and the contested decision; `_None._` when no tensions were detected.>
````

## Extending the Trait Map
To add a new design-style trait, append one row to the `{trait_map}` table inside `## Parameters` pairing the new trait name with its canonical `.cursor/skills/{new-trait}-design/SKILL.md` path, then create the matching `SKILL.md` at that path. No edits outside this command file or the new `SKILL.md` are required; callers of `/designer` need no changes.
