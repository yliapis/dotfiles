# Designer

## Task
Invoke `/designer {traits} {target}` to apply every named design-style trait's skill to `{target}` and emit one unified design proposal that credits each trait and surfaces any unresolvable tensions between them.

The command is composable (every named trait's skill is applied together), stable (the same `{traits}` and `{target}` always resolve to the same skill set and the same report structure, with no run-specific metadata; the LLM-rendered prose itself is not bit-stable across runs), extensible (adding a future trait requires one row in `{trait_map}` plus a new `SKILL.md`), and decoupled from skill bodies — each design skill is referenced by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and read at invocation time rather than inlined into this file.

## Parameters
- `{traits}` — ordered list of trait names parsed from the leading tokens of the `/designer` invocation, up to but not including the first token that begins `{target}`; required. Every entry MUST be a key in `{trait_map}`.
- `{target}` — artifact to design: inline text, repo-relative file path, repo-relative directory path, or free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping declared verbatim below (fixed in this file, not invocation-supplied). Extend in place per `## Extending the Trait Map`. Seeded entries:
  - `declarative` → `.cursor/skills/declarative-design/SKILL.md`
  - `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

## Success Criteria
- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; unknown traits abort with an explanatory error that names every unrecognized trait and lists the available trait names, and no partial design output is emitted.
- [ ] Every resolved skill file is `Read` at its canonical `.cursor/skills/{trait}-design/SKILL.md` path and its guidance is `apply`-ed; the rendered report credits each named trait in its own `### {trait}` subsection under `## Per-Trait Contribution`, one subsection per trait in invocation order.
- [ ] When `{traits}` contains more than one entry, every named trait's skill is applied together; no trait is dropped, down-weighted, reordered out of invocation order, or silently merged with another.
- [ ] Tensions between traits are surfaced in `## Tensions and Tradeoffs` with both positions labeled by the traits involved; conflicting guidance is never silently reconciled, and `_None._` is rendered if and only if no tension was detected.
- [ ] Running `/designer` twice with the same `{traits}` (same names, same order) and the same `{target}` resolves the same skill set and produces a report with the same section structure and no run-specific metadata (no timestamps or random identifiers).
- [ ] Every skill reference resolved at runtime is a repo-relative path under `.cursor/skills/`; absolute paths, `~/`, `$HOME`, and machine-specific home directories are rejected before any design work begins.

## Guardrails
- MUST `Read` every skill file referenced by `{trait_map}` for the names in `{traits}` before drafting any portion of the design output, and MUST `apply` its guidance to `{target}` when composing the unified proposal.
- MUST apply every named trait's skill to `{target}` when `{traits}` contains more than one entry; MUST NOT drop, down-weight, or silently merge any trait, regardless of how many traits are supplied.
- MUST surface unresolvable conflicts between traits in `## Tensions and Tradeoffs`, labeled by the traits involved with both positions stated; MUST NOT pick a winner or silently prefer one trait unless the invocation supplied an explicit precedence rule.
- MUST reference each design skill by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and load that file at invocation time; MUST NOT inline, hard-code, summarize, or paraphrase the body of any design skill into this command or the emitted report.
- MUST abort with an explanatory error before any design work begins if any name in `{traits}` has no entry in `{trait_map}` or if any resolved skill file cannot be read; emit no partial report on failure.
- MUST keep output free of run-specific metadata: no timestamps or random identifiers; identical `{traits}` and `{target}` always resolve the same skills and render the same report structure. MUST NOT promise byte-equivalent output — the LLM-rendered prose is not bit-stable across runs.
- MUST keep every skill reference repo-relative under `.cursor/skills/`; MUST NOT use `~/`, `$HOME`, absolute paths outside the repo, or machine-specific home directories.
- Scope: produce one unified design proposal for one `{target}` using the traits named in `{traits}`. Out of scope: editing `{target}`, creating or editing any file under `.cursor/skills/`, executing the resulting design, seeding traits beyond those listed in `{trait_map}`, or invoking `/designer` recursively.

## Workflow
1. Parse the `/designer` invocation: take the leading tokens that match keys in `{trait_map}` as `{traits}` (preserving invocation order); the remaining tokens form `{target}` (inline text, file path, directory path, or free-form description). If `{traits}` is empty or `{target}` is empty, abort with an explanatory error.
2. Validate `{traits}` against `{trait_map}`: every name MUST be a key. On any unknown trait, abort with an explanatory error that names every unrecognized trait and lists the available trait names; emit no design output.
3. Validate that every resolved skill path is a repo-relative path under `.cursor/skills/`; reject `~/`, `$HOME`, absolute paths outside the repo, and machine-specific home directories, aborting with an explanatory error before any skill file is read.
4. `Read` every resolved skill file in full before drafting any design output; treat the file's contents as the canonical guidance for the named trait at invocation time. If any resolved skill file cannot be read, abort with an explanatory error naming the trait and the missing path. Do not inline or summarize skill bodies into the report.
5. `apply` every named trait's guidance together to `{target}`. Record for each trait the specific contributions it made to the unified proposal, and flag any decision where two traits' guidance gives contradictory direction.
6. Detect tensions: whenever two or more traits' skills give contradictory direction for the same decision, capture both positions and label the conflict by the traits involved. Do not pick a winner unless the invocation supplied an explicit precedence rule.
7. Emit a single markdown report in the shape required by `## Output Format`, rendering `_None._` in `## Tensions and Tradeoffs` if and only if no conflict was captured in step 6.

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
<What this trait contributed to the unified proposal.>

### <trait_2>
<What this trait contributed to the unified proposal.>

## Tensions and Tradeoffs
<Each unresolvable conflict between traits as a labeled bullet (e.g., `**declarative vs. deterministic:** <one-line summary of both positions>`), or `_None._` when no conflicts exist.>
````

## Extending the Trait Map
To add a new design-style trait, append one row to the `{trait_map}` list in `## Parameters` above pairing the new trait name with its canonical `.cursor/skills/{new-trait}-design/SKILL.md` path, then create the matching `SKILL.md` at that path. No edits to callers of `/designer`, to design skills already in `{trait_map}`, or to any file outside this command file and the new `SKILL.md` are required. (The `designer-controller` skill keeps its own `## Trait Map`; add a matching row there when the trait should also be reachable through the controller.)
