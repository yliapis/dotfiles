# Designer

## Task
Invoke `/designer {traits} {target}` to run the `designer` skill in one-shot composition mode: apply every named trait to `{target}` and emit one unified design proposal that credits each trait and surfaces any unresolvable tensions between them.

This command is a preset, not a second implementation. It pins `mode=propose` and forwards everything else to the skill, which owns the trait map, the knob inventory, the validation rules, and the output format.

## Preset
- `mode=propose` — pinned; the command exists to select this motion. For the step-by-step motion, use `/ralph-design`.

Every other knob takes the skill's own default unless the invocation overrides it.

## Parameters
- `{traits}` — ordered list of trait names parsed from the leading tokens of the invocation, up to but not including the first token that begins `{target}`; required. Forwarded as the skill's `traits`.
- `{target}` — artifact to design: inline text, repo-relative file path, repo-relative directory path, or free-form description; required. Forwarded as the skill's `target`.
- Any additional `key=value` tokens are forwarded verbatim to the skill and validated there.

## Success Criteria
- [ ] The `designer` skill is read at its canonical `skills/designer/SKILL.md` path and invoked with `mode=propose`, the parsed `{traits}`, and the parsed `{target}`.
- [ ] Trait resolution, knob validation, tension detection, and report shape all come from the skill; this command contributes only the parsed arguments and the pinned `mode`.
- [ ] An invocation with an empty `{traits}` or an empty `{target}` aborts with an explanatory error before the skill is invoked, and emits no partial design output.
- [ ] Unknown trait names and inapplicable knobs surface as the skill's own validation errors; this command does not pre-empt them with a second set of checks.

## Guardrails
- MUST delegate to the `designer` skill; MUST NOT reimplement, inline, or paraphrase the skill's trait map, knob inventory, validation rules, workflow, or output format.
- MUST forward `{traits}` in invocation order and pass through any additional `key=value` tokens unmodified.
- MUST NOT pin any knob other than `mode=propose`; every other default belongs to the skill.
- MUST NOT claim byte-equivalent or otherwise deterministic output. The dispatch path is fixed by the knobs; the generated proposal is not bit-stable, and the skill's own guardrails say so.
- Scope: parse an invocation and dispatch it to the `designer` skill in `propose` mode. Out of scope: editing `{target}`, editing any trait card, registering new traits, and executing the resulting design.

## Workflow
1. Parse the invocation: leading tokens that name traits become `{traits}` (preserving order); the remainder forms `{target}`; any `key=value` tokens are collected for forwarding. Abort with an explanatory error if `{traits}` or `{target}` is empty.
2. Invoke the `designer` skill with `mode=propose traits=[{traits}] target={target}` plus the forwarded knobs.
3. Emit the skill's report unchanged.

## Adding a Trait
Trait registration lives in the skill's `## Trait Map`, next to the trait cards themselves under `skills/designer/traits/`. No change to this command is needed when a trait is added or removed.
