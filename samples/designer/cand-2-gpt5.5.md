# Designer

## Task
Invoke `/designer {traits} {target}` to apply every named design-style skill to `{target}` and emit one unified design proposal.

The command is composable across all resolved traits, idempotent for identical inputs, and resilient to skill-body edits by referencing canonical skill paths that are read at invocation time.

## Parameters
- `{traits}` — ordered list of trait names from the `/designer` invocation; required.
- `{target}` — artifact to design: inline text, file path, directory path, or free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping. Seeded entries:
  - `declarative` → `.cursor/skills/declarative-design/SKILL.md`
  - `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

## Success Criteria
- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; unknown traits abort with an explanatory error and no partial report.
- [ ] The design agent uses `Read` on each resolved skill file and applies its guidance before drafting any design output.
- [ ] When more than one trait is supplied, every named trait's skill is applied together and any tension between traits is surfaced in the final report, never silently resolved.
- [ ] The report credits each resolved trait in its own subsection under per-trait contribution.
- [ ] Running `/designer` twice with the same `{traits}` and `{target}` produces byte-equivalent output.

## Guardrails
- MUST read every skill file referenced by `{trait_map}` for the named traits before drafting any design output.
- MUST apply every named trait's skill; MUST NOT drop, down-weight, inline, hard-code, or summarize any skill body into this command.
- MUST surface unresolvable conflicts in `## Tensions and Tradeoffs`; MUST NOT silently resolve tensions or pick a winner unless the user supplied an explicit precedence rule.
- MUST keep every skill reference repo-relative under `.cursor/skills/`; MUST NOT use `~/`, `$HOME`, absolute paths outside the repo, or machine-specific home directories.
- MUST keep output deterministic: stable ordering, no timestamps, no random identifiers, and no environment-specific details unless present in `{target}`.
- Scope: produce one unified design proposal for one `{target}` using the traits named in `{traits}`. Out of scope: editing `{target}`, editing skill files, executing the resulting design, or creating trait entries beyond `{trait_map}`.

## Workflow
1. Parse the invocation into `{traits}` and `{target}`, preserving the user-supplied trait order.
2. Resolve each trait through `{trait_map}`; abort before any design work begins if any trait is unknown, naming the unresolved trait and the available trait names.
3. For each resolved trait, `Read` the mapped skill file at invocation time, then apply that skill's guidance to `{target}`. Do not inline skill contents into this command.
4. Apply all resolved skills together to `{target}`, recording how each trait shaped the proposal and where trait guidance conflicts.
5. Surface unresolved conflicts in `## Tensions and Tradeoffs`; render `_None._` when no tensions exist.
6. Emit exactly one markdown report using the shape in `## Output Format`, preserving deterministic section order and stable wording for identical `{traits}` and `{target}`.
7. To add a future trait, append one row to `{trait_map}` pairing the new trait name with its canonical `.cursor/skills/{new-trait}-design/SKILL.md` path, then create the matching `SKILL.md`. No edits outside this command file or the new `SKILL.md` are required.

## Output Format
A single markdown report with these sections, in this order:

- A top-level header named `Designer Proposal: {target_identifier}`.
- `Traits applied`: comma-separated resolved `{traits}`, preserving invocation order.
- `Target`: the resolved `{target}`.
- `Unified Proposal`: the design that honors every named trait.
- `Per-Trait Contribution`: one `### {trait}` subsection per resolved trait, in invocation order, explaining what that trait contributed.
- `Tensions and Tradeoffs`: each unresolvable conflict between traits, or `_None._` when there are none.
