# Designer

## Task
Invoke `/designer {traits} {target}` to apply every named design-style skill from `{trait_map}` to the resolved `{target}` and emit a single unified design proposal that credits each trait and surfaces unresolvable tensions between traits.

The command is composable (every named trait's skill is applied together), idempotent (running it twice with the same `{traits}` and `{target}` produces byte-equivalent output), and decoupled from skill bodies — every design skill is referenced by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and read at invocation time rather than inlined into this file.

## Parameters
- `{traits}` — ordered list of trait names taken verbatim from the `/designer` invocation (e.g., `declarative deterministic`); required. Order is preserved in the per-trait contribution section of the report.
- `{target}` — artifact to design: inline text, file path, directory path, or free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping declared inline below; required. Seeded entries:
  - `declarative` → `.cursor/skills/declarative-design/SKILL.md`
  - `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

## Success Criteria
- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; an unknown trait aborts with an explanatory error that names the unresolved trait and lists the available trait names, and no partial proposal is emitted.
- [ ] Every resolved skill file is read in full and applied; the report contains one `### {trait}` subsection under `## Per-Trait Contribution` for each name in `{traits}`, in invocation order.
- [ ] When `{traits}` contains more than one entry, every named trait's skill is applied together; no trait is dropped, down-weighted, or silently merged into another.
- [ ] Conflicts between traits are surfaced verbatim in `## Tensions and Tradeoffs`, labeled with the traits involved and both positions; the section reads `_None._` when no conflicts were detected and never silently picks a winner.
- [ ] Running `/designer` twice with the same `{traits}` and `{target}` produces byte-equivalent output.
- [ ] Every skill reference resolved at runtime is a repo-relative path under `.cursor/skills/`; absolute paths, `~/`, `$HOME`, and machine-specific home directories are rejected before any design work begins.

## Guardrails
- MUST read every skill file referenced by `{trait_map}` for the names in `{traits}` before drafting any design output; the agent loads each skill body at invocation time and MUST NOT rely on inlined or cached summaries.
- MUST apply every named trait's skill together when `{traits}` contains more than one entry; MUST NOT drop, down-weight, or silently merge any trait.
- MUST surface unresolvable conflicts between traits in `## Tensions and Tradeoffs`, labeling each conflict with the traits involved and both positions; MUST NOT pick a winner unless the user supplied an explicit precedence rule in the invocation.
- MUST abort with an explanatory error when any name in `{traits}` has no entry in `{trait_map}`; create no partial proposal and do no design work.
- MUST keep skill references decoupled from skill bodies: every reference is the canonical `.cursor/skills/{trait}-design/SKILL.md` path; MUST NOT inline, hard-code, or summarize the body of any design skill.
- MUST keep output deterministic: the same `{traits}` and `{target}` produce byte-equivalent output across runs.
- Scope: produce one unified design proposal for one `{target}` using the traits named in `{traits}`. Out of scope: editing `{target}`, editing or creating skill files under `.cursor/skills/`, executing the resulting design, registering the command anywhere, or invoking `/designer` recursively.

## Workflow
1. Parse the `/designer` invocation into `{traits}` (the ordered prefix of trait-name tokens) and `{target}` (the remaining argument as inline text, file path, directory path, or free-form description).
2. For each name in `{traits}`, look up its skill path in `{trait_map}`. If any name is missing from `{trait_map}`, abort with an explanatory error that names every unresolved trait and lists the available trait names; do not draft any design output.
3. Validate that every resolved skill path is a repo-relative path under `.cursor/skills/`; reject absolute paths, `~/`, `$HOME`, and machine-specific home directories and abort with an explanatory error.
4. Read every resolved skill file in full and apply its guidance to `{target}`. When two traits' skills give contradictory direction for the same decision, capture both positions verbatim with the traits involved; do not silently reconcile.
5. Draft the unified proposal that honors every named trait simultaneously, attributing each trait's contribution to its `### {trait}` subsection in invocation order.
6. Render the report in the shape required by `## Output Format`. Write `_None._` in `## Tensions and Tradeoffs` when no conflicts were captured in step 4.

## Output Format
A single markdown report:

````markdown
# Designer Proposal: <short identifier for {target}>

**Traits applied:** <comma-separated list of resolved traits, in invocation order>
**Target:** <resolved {target}>

## Unified Proposal
<The design that honors every named trait simultaneously.>

## Per-Trait Contribution
### <trait_1>
<What this trait contributed to the unified proposal, sourced verbatim or by reference from its skill file.>

### <trait_2>
<What this trait contributed to the unified proposal, sourced verbatim or by reference from its skill file.>

## Tensions and Tradeoffs
<Each unresolvable conflict between traits, labeled with the traits involved and both positions; reads `_None._` when there are none.>
````

## Extending the Trait Map
To add a new design-style trait, append one row to the `{trait_map}` list under `## Parameters` of the form `{new-trait}` → `.cursor/skills/{new-trait}-design/SKILL.md` and create the matching `SKILL.md` at that path. No edits outside this command file or the new `SKILL.md` are required; callers of `/designer` need no changes.
