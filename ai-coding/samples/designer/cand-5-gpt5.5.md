# Designer

## Task
Invoke `/designer {traits} {target}` to apply every named design-style skill to `{target}` and emit one unified design proposal.

The command is composable across multiple traits, idempotent for the same `{traits}` and `{target}`, and resilient to skill-body edits because design skills are referenced by canonical repo-relative paths and read at invocation time.

## Parameters
- `{traits}` — ordered list of trait names from the `/designer` invocation; required.
- `{target}` — artifact to design: inline text, file path, directory path, or free-form description; required.
- `{trait_map}` — trait-name → skill-path mapping. Seeded entries:
  - `declarative` → `.cursor/skills/declarative-design/SKILL.md`
  - `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

## Success Criteria
- [ ] Every name in `{traits}` resolves to a skill path via `{trait_map}` before any design work begins; unknown traits abort with an explanatory error.
- [ ] The agent must `Read` each resolved skill file and `apply` its guidance before drafting any design output.
- [ ] Every resolved trait is credited in the final report with its own per-trait contribution subsection.
- [ ] When more than one trait is supplied, every named trait's skill MUST be applied together and tensions between traits MUST be surfaced in the final report, never silently resolved.
- [ ] Running `/designer` twice with the same `{traits}` and `{target}` produces byte-equivalent output.
- [ ] Adding a future trait requires only one new row in `{trait_map}` mapping `{new-trait}` to `.cursor/skills/{new-trait}-design/SKILL.md`, plus the corresponding `SKILL.md`; no edits outside this command file or the new skill file are required.

## Guardrails
- MUST read every skill file resolved from `{trait_map}` for the named traits before drafting any design output.
- MUST apply every named trait's skill; when more than one trait is supplied, every named trait's skill MUST be applied and tensions between traits MUST be surfaced in the final report, never silently resolved.
- MUST surface unresolvable conflicts in the Tensions and Tradeoffs section; MUST NOT pick a winner unless the user supplied an explicit precedence rule.
- MUST preserve the order of `{traits}` from the invocation when crediting contributions, listing tensions, and naming the applied traits.
- MUST produce deterministic wording and ordering from the resolved `{traits}` and `{target}` only; do not include timestamps, random identifiers, or run-specific metadata.
- MUST keep skill references as repo-relative paths under `.cursor/skills/`; MUST NOT use `~/`, `$HOME`, absolute paths, or machine-specific home directories.
- MUST NOT inline, hard-code, summarize, or paraphrase the body of any design skill into this command.
- Scope: produce one unified design proposal for one `{target}` using the traits named in `{traits}`. Out of scope: editing `{target}`, editing skill files, executing the resulting design, or registering traits outside `{trait_map}`.

## Workflow
1. Parse the invocation into `{traits}` and `{target}`. Preserve the user-supplied trait order and resolve `{target}` as inline text, file path, directory path, or free-form description.
2. Resolve each trait via `{trait_map}` to its skill path. Abort before any design work begins if any trait is unknown, and report the unknown name plus the available trait names.
3. For every resolved trait, `Read` the canonical skill file from `.cursor/skills/` and `apply` its guidance to `{target}`. If a resolved skill file cannot be read, abort with the trait name and path.
4. Apply all resolved skills together to `{target}`. Record what each trait contributes to the unified proposal and any point where trait guidance conflicts.
5. Surface unresolvable conflicts instead of silently reconciling them. If the user supplied an explicit precedence rule, name it before using it.
6. Emit exactly one markdown report using the report shape in `## Output Format`, with stable ordering based on `{traits}` and no run-specific metadata.
7. To extend `{trait_map}`, add one row mapping `{new-trait}` to `.cursor/skills/{new-trait}-design/SKILL.md`, then create that matching `SKILL.md`. No edits to callers of `/designer`, other command files, or existing skill files are required.

## Output Format
Return a single markdown report with this shape:

- Header: `# Designer Proposal: {short_identifier_for_target} with {traits}`.
- Metadata lines: `**Traits applied:** {traits}` and `**Target:** {resolved_target}`.
- `Unified Proposal` section: the design that honors every named trait.
- `Per-Trait Contribution` section: one subsection per trait, in `{traits}` order, naming what that trait contributed to the unified proposal.
- `Tensions and Tradeoffs` section: each unresolvable conflict between traits, or `_None._` when there are no tensions.

The report must credit every resolved trait, use one unified proposal rather than separate proposals, and render no extra sections unless needed to explain an explicit user-supplied precedence rule.
