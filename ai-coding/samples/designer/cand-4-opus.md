# Designer

## Task
Apply every named design-style trait's skill to `{target}` and emit a single unified design proposal that credits each trait and surfaces unresolvable tensions between them.

Invoked as `/designer {trait_1} {trait_2} ... {target}`. The command is composable (every named trait's skill is applied together), idempotent (the same `{traits}` plus the same `{target}` produces byte-equivalent output), and decoupled from skill bodies — each design skill is referenced by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and read at invocation time, so skill-body edits and renames propagate without touching this file.

## Parameters
- `{traits}` — ordered list of trait names parsed from the leading tokens of the `/designer` invocation, up to but not including the first token that begins `{target}`; required. Every entry MUST be a key in `{trait_map}`.
- `{target}` — the artifact to design: inline text, a repo-relative file path, a repo-relative directory path, or a free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping. Seeded entries (extend by adding rows in place; see `## Extending the Trait Map`):
  - `declarative` → `.cursor/skills/declarative-design/SKILL.md`
  - `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

## Success Criteria
- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; unknown traits abort with an explanatory error naming the unrecognized trait and listing the available trait names, and no partial design output is emitted.
- [ ] Every resolved skill file is read at its canonical `.cursor/skills/{trait}-design/SKILL.md` path and its guidance is applied to `{target}`; the report credits each named trait in its own `###` subsection under `## Per-Trait Contribution`, one subsection per trait in invocation order.
- [ ] Composability: when `{traits}` contains more than one entry, every named trait's skill is applied together; no trait is dropped, down-weighted, reordered out of invocation order, or silently merged with another.
- [ ] Tensions between traits are surfaced in `## Tensions and Tradeoffs` with both positions labeled by trait; conflicting guidance is never silently reconciled, and `_None._` is rendered if and only if no conflict was detected.
- [ ] Running `/designer` twice with the same `{traits}` (same names in the same order) and the same `{target}` produces byte-equivalent output.
- [ ] The emitted report uses the exact section structure in `## Output Format`: a header naming the resolved traits and `{target}`, a `## Unified Proposal`, a `## Per-Trait Contribution` containing one `###` subsection per trait, and a `## Tensions and Tradeoffs` section.
- [ ] Every skill reference resolves to a repo-relative path under `.cursor/skills/`; no machine-specific, home-directory, or absolute path outside the repo is used.

## Guardrails
- MUST `Read` every skill file referenced by `{trait_map}` for the names in `{traits}` before drafting any portion of the design output.
- MUST apply every named trait's skill to `{target}`; MUST NOT drop, down-weight, or silently merge any trait, regardless of how many traits are supplied.
- MUST surface unresolvable conflicts between traits in `## Tensions and Tradeoffs`; MUST NOT pick a winner unless the user supplied an explicit precedence rule in the invocation.
- MUST reference each design skill by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and load that file at invocation time; MUST NOT inline, hard-code, or summarize the body of any skill into this command or into the emitted report.
- MUST abort with an explanatory error before any design work begins if any name in `{traits}` is not a key in `{trait_map}`; no partial report may be emitted on failure.
- Scope: produce one unified design proposal for one `{target}` using the traits named in `{traits}`. Out of scope: editing `{target}`, editing skill files, registering or executing the proposed design, and seeding traits beyond those already listed in `{trait_map}`.

## Workflow
1. Parse the `/designer` invocation: take the leading tokens that match keys in `{trait_map}` as `{traits}` (preserving invocation order); the remaining tokens form `{target}` (inline text, file path, directory path, or free-form description). If `{traits}` is empty or `{target}` is empty, abort with an explanatory error.
2. Validate `{traits}` against `{trait_map}`: every name MUST be a key in the mapping. On any unknown trait, abort with an explanatory error that names the unrecognized trait and lists the available trait names; emit no design output.
3. Resolve each trait to its canonical skill path via `{trait_map}` and `Read` every resolved `.cursor/skills/{trait}-design/SKILL.md` file before drafting any design output. Do not inline or summarize the skill bodies into the report.
4. Apply every named trait's guidance to `{target}` together, recording for each trait the specific contributions it made to the unified proposal.
5. Detect tensions: whenever two or more traits' skills give contradictory direction for the same decision, capture both positions and label the conflict by the traits involved. Do not silently pick a winner.
6. Emit a single markdown report in the shape required by `## Output Format`, rendering `_None._` in `## Tensions and Tradeoffs` if and only if no conflict was detected.

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
<What this trait contributed to the unified proposal.>

### <trait_2>
<What this trait contributed to the unified proposal.>

## Tensions and Tradeoffs
<Each unresolvable conflict between traits as a labeled bullet (e.g., `**declarative vs. deterministic:** <one-line summary of both positions>`), or `_None._` when no conflicts exist.>
````

## Extending the Trait Map
To add a new design-style trait, append one row to `{trait_map}` in `## Parameters` above pairing the new trait name with its canonical `.cursor/skills/{new-trait}-design/SKILL.md` path, then create the matching `SKILL.md` at that path. No edits to callers of `/designer`, to the design skills already in `{trait_map}`, or to any file outside this command file and the new `SKILL.md` are required.
