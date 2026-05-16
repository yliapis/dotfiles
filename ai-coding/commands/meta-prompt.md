# Meta-Prompt: Create or Refine a Task Prompt

## Task

Take the user's input (the text following `/meta-prompt` in this chat message) and produce a single, structured, parameterized task prompt with explicit success criteria and guardrails. If the input is itself a structured prompt, refine it instead of creating a new one.

Return the generated prompt as the entire reply, inside a single fenced ` ```markdown ` block, with no extra commentary before or after — unless you must ask the user a clarifying question first.

## Parameters

- `{input}` — everything the user typed after `/meta-prompt`. May be: empty, a short task description, or a full prompt that already follows the Output Format below.
- `{save_path}` — optional. If the user asks to save the result, default to `.cursor/commands/<kebab-name>.md`. Do not write any file unless asked.

## Success Criteria

- [ ] The reply contains exactly one fenced ```markdown block whose body matches the Output Format.
- [ ] Every section in the body is non-empty and concrete; empty sections are omitted, not left as placeholders.
- [ ] At least one Success Criterion is present, and each is observable / checkable (not a vague adjective).
- [ ] At least one Guardrail is present, expressed as MUST / MUST NOT / Scope.
- [ ] Parameters are included only when the task has values that legitimately vary between invocations; otherwise the Parameters section is omitted.
- [ ] Any wording the user supplied verbatim is preserved verbatim.
- [ ] In REFINE mode, every section that existed in the input still exists in the output (or the user was asked before removal).

## Guardrails

- MUST NOT execute, plan, or begin the generated task. Only emit the prompt.
- MUST NOT bundle multiple unrelated tasks into one prompt. If the input asks for several, ask the user to pick one or split.
- MUST NOT invent constraints the user did not state; ask first.
- MUST NOT add a YAML frontmatter block to the generated prompt.
- MUST omit sections that would otherwise be empty or placeholder-only.
- MUST keep the generated prompt self-contained: no references to this meta-prompt, no "see above," no out-of-band context.
- Scope: this command produces a reusable prompt artifact. It does not write files, run code, or modify the repo unless the user explicitly asks.

## Workflow

1. **Detect mode** from `{input}`:
   - **REFINE** if `{input}` contains at least two of the canonical headings `## Task`, `## Success Criteria`, `## Guardrails`.
   - **INTERACTIVE** if `{input}` is empty or under ~20 characters with no clear task.
   - **CREATE** otherwise.

2. **Gather missing slots.** For each of {task, parameters, success criteria, guardrails, workflow, output format}, decide whether the input already pins it down. If anything critical is missing or ambiguous, ask the user 1–2 questions via `AskQuestion` (or conversationally if unavailable) before writing. Do not guess at intent.

3. **Apply mode-specific rules:**
   - **CREATE:** Synthesize each section from the user's description. Infer a short kebab-case title for the `# Heading`.
   - **REFINE:** Preserve verbatim user wording. Convert vague terms ("good", "fast", "clean", "nice") into measurable criteria. Fill missing sections. Remove duplication. Surface ambiguities back to the user before deleting any user-provided content.
   - **INTERACTIVE:** Ask first for the task in one sentence, then for the single most important guardrail or success criterion. Proceed once you have enough to draft.

4. **Render** the prompt using the Output Format below. Omit any section that has no real content.

5. **Offer next steps** in a single short sentence after the fenced block: mention that the user can paste the output back into `/meta-prompt` to refine, and that saving to `.cursor/commands/<name>.md` makes it its own slash command.

## Output Format

The generated prompt MUST follow this exact skeleton (omit any section whose body would be empty):

````markdown
# <Imperative Title in Title Case>

## Task
<One sentence stating what the prompt accomplishes. Optionally a short paragraph of context after.>

## Parameters
- `{param_name}` — what it is; required.
- `{param_name}` — what it is; optional, default: `<value>`.

## Success Criteria
- [ ] <Observable, checkable outcome.>
- [ ] <Observable, checkable outcome.>

## Guardrails
- MUST <constraint>.
- MUST NOT <prohibition>.
- Scope: <what is in / out of scope>.

## Workflow
1. <Step.>
2. <Step.>

## Output Format
<Exact structure of what the executing agent should produce. Include a short example when it helps.>
````

## Refinement

To refine the prompt you just produced (or any prompt that follows the Output Format above), paste it as the input to `/meta-prompt`. This file itself follows the same structure and is a valid input for refinement.
