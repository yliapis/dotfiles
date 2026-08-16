# Research Artifact

## Task
Invoke `/research-artifact` to run the `artifact-researcher` skill. This command is a thin wrapper. It forwards `$ARGUMENTS` to the skill, which owns the type map, knob inventory, validation, and output format.

## Parameters
- `$ARGUMENTS` — forwarded verbatim. Typical knobs: `type=architecture artifacts=submodules/oss/pi` and optional `out=...`. See the skill for the full inventory.

## Success Criteria
- [ ] The `artifact-researcher` skill is read at `skills/artifact-researcher/SKILL.md` and invoked with the forwarded arguments.
- [ ] Type resolution, knob validation, analysis, and file shape all come from the skill; this command contributes only the dispatch.
- [ ] An invocation with no arguments aborts with an explanatory error before the skill runs.

## Guardrails
- MUST delegate to the `artifact-researcher` skill. MUST NOT reimplement the type map, knob inventory, or write procedures.
- MUST forward `$ARGUMENTS` unmodified.
- Scope: parse an invocation and dispatch it. Out of scope: writing analysis files except through the skill.

## Workflow
1. If `$ARGUMENTS` is empty, abort and name the required knobs `type` and `artifacts`.
2. Read `skills/artifact-researcher/SKILL.md` and invoke it with `$ARGUMENTS`.
3. Emit the skill's report unchanged.
