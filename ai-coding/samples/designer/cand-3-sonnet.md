# Designer

## Task

Invoke `/designer {traits} {target}` to apply each named design-style skill to `{target}` and emit a single unified design proposal that credits every trait and surfaces any unresolvable tensions between them. The command is composable — every named trait's skill is applied together; idempotent — running it twice with the same `{traits}` and `{target}` produces byte-equivalent output; extensible — adding a future trait requires one row in the `{trait_map}` table plus a new `SKILL.md`; and path-based — each skill is referenced by its canonical `.cursor/skills/{trait}-design/SKILL.md` path and read at invocation time, keeping skill-body edits fully decoupled from this command.

## Parameters

- `{traits}` — ordered list of trait names from the `/designer` invocation; required.
- `{target}` — artifact to design: inline text, file path, directory path, or free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping used to resolve each name in `{traits}`. Seeded entries:
  - `declarative` → `.cursor/skills/declarative-design/SKILL.md`
  - `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

## Success Criteria

- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; unknown trait names abort with an explanatory error that lists each unrecognized name.
- [ ] Every resolved skill file is `Read` at invocation time and its guidance is `apply`-ed; the unified proposal credits each trait in its own subsection.
- [ ] When more than one trait is supplied, every named trait's skill MUST be applied; no trait is dropped, down-weighted, or silently merged with another.
- [ ] Tensions between traits are surfaced explicitly in `## Tensions and Tradeoffs` and are never silently reconciled.
- [ ] Running `/designer` twice with the same `{traits}` and `{target}` produces byte-equivalent output (idempotency).

## Guardrails

- MUST read every skill file referenced by `{trait_map}` for the named traits before drafting any design output.
- MUST apply every named trait's skill; MUST NOT drop, down-weight, or silently merge any trait.
- MUST surface unresolvable conflicts in `## Tensions and Tradeoffs`; MUST NOT pick a winner or silently prefer one trait over another unless the user supplied an explicit precedence rule.
- MUST NOT inline, hard-code, or summarize the body of any design skill into the proposal; all trait guidance is loaded from the canonical skill path at invocation time.
- MUST NOT modify `{target}`, any skill file under `.cursor/skills/`, or any other file; this command is read-then-produce only.
- Scope: produce one unified design proposal for one `{target}` using the traits named in `{traits}`. Out of scope: editing `{target}`, editing skill files, executing the resulting design, adding trait entries beyond those already listed in `{trait_map}`.

## Workflow

1. Parse the `/designer` invocation into `{traits}` (ordered list of trait names) and `{target}` (the remaining argument describing the artifact to design).
2. Resolve each name in `{traits}` against `{trait_map}`. If any name has no entry, abort immediately with an explanatory error that lists every unrecognized trait; perform no design work.
3. Read every resolved skill file in order (e.g., `Read .cursor/skills/declarative-design/SKILL.md`, `Read .cursor/skills/deterministic-design/SKILL.md`) and internalize each skill's guidance.
4. Apply all named traits' skills together to `{target}`; record each trait's distinct contribution to the unified proposal.
5. Detect tensions: when two traits give contradictory direction for the same design decision, record both positions alongside their source trait; do not pick a winner.
6. Emit the unified proposal using the report shape in `## Output Format`.

## Output Format

A single markdown report:

````markdown
# Designer Proposal: <short identifier for {target}>

**Traits applied:** <comma-separated list of resolved traits>
**Target:** <resolved {target}>

## Unified Proposal
<The design that honors every named trait.>

## Per-Trait Contribution
### <trait_1>
<What this trait contributed to the unified proposal.>

### <trait_2>
<What this trait contributed to the unified proposal.>

## Tensions and Tradeoffs
<Each unresolvable conflict between traits, labeled by the two source traits and the decision point where they diverge. Render `_None._` when no tensions exist.>
````

## Extending the Trait Map

To add a new trait, append one row to the `{trait_map}` table in `## Parameters` above, pairing the new trait name with its canonical `.cursor/skills/{new-trait}-design/SKILL.md` path, then create the matching `SKILL.md`. No edits to callers of `/designer` are required.
