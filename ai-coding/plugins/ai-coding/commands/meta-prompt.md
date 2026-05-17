# Meta-Prompt: Create or Refine a Task Prompt

## Task

Take the user's input (the text following `/meta-prompt` in this chat message) and produce a single, structured, parameterized task prompt with explicit success criteria and guardrails. If the input is itself a structured prompt, refine it instead of creating a new one.

Return the generated prompt as the entire reply, inside a single fenced ` ```markdown ` block, with no extra commentary before or after — unless you must ask the user a clarifying question first.

## Parameters

- `{input}` — everything the user typed after `/meta-prompt`. May be: empty, a help request, a short task description, or a full prompt that already follows the Output Format below.
- `{save_path}` — optional path at which to persist the generated prompt as a slash command. Inferred from `{input}` context when the user expresses save intent (e.g., "save this", "make it a slash command", "create a `/<name>` command", or a literal path). When intent is detected but no path is given, default to `.cursor/commands/<kebab-name>.md` where `<kebab-name>` is derived from the H1 title. When no save intent is detected, leave unset and write nothing.

## Success Criteria

- [ ] In CREATE or REFINE mode, the reply contains exactly one fenced ```markdown block whose body matches the Output Format. In HELP mode, the reply is the Help Message body verbatim.
- [ ] No `<...>` placeholder text and no standalone uses of `good`, `clean`, `nice`, or `fast` as qualifiers remain in the body; sections that would be empty are omitted.
- [ ] At least one Success Criterion is present, and each is observable / checkable (not a vague adjective).
- [ ] At least one Guardrail is present, expressed as MUST / MUST NOT / Scope.
- [ ] Parameters are included only when the task has values that legitimately vary between invocations; otherwise the Parameters section is omitted.
- [ ] Any wording the user supplied verbatim is preserved verbatim.
- [ ] In REFINE mode, every section that existed in the input still exists in the output (or the user was asked before removal), and the H1 title and section ordering are preserved.
- [ ] If save intent was detected, the file at `{save_path}` exists and contains the rendered prompt body verbatim.

## Guardrails

- MUST NOT execute, plan, or begin the generated task. Only emit the prompt.
- MUST NOT bundle multiple unrelated tasks into one prompt. If the input asks for several, ask the user to pick one or split.
- MUST NOT invent constraints the user did not state; ask first.
- MUST keep the generated prompt self-contained: no references to this meta-prompt, no "see above," no out-of-band context.
- Scope: this command produces a reusable prompt artifact. It does not write files, run code, or modify the repo unless the user explicitly asks.

## Workflow

1. **Detect mode** from `{input}`:
   - **HELP** if `{input}` is empty/whitespace, equals `help`, `--help`, `-h`, or otherwise reads as a request for help or usage.
   - **REFINE** if `{input}` begins with an `# <Title>` H1 and contains `## Task` plus at least one of `## Success Criteria` or `## Guardrails`. REFINE inputs are typically produced by pasting a previous `/meta-prompt` output back in.
   - **CREATE** otherwise.

2. **Gather missing slots.** Decide what the input pins down vs. what you need:
   - Critical (ask via `AskQuestion` if missing): the task statement, and at least one success criterion.
   - Inferrable (draft from context, then proceed): parameters, guardrails, workflow, output format.
   - Do not guess at intent for the critical slots.

3. **Apply mode-specific rules:**
   - **CREATE:** Synthesize each section from the user's description. Infer a short kebab-case title for the `# Heading`.
   - **REFINE:** Preserve verbatim user wording, the H1 title, and the section order. Convert vague terms ("good", "fast", "clean", "nice") into measurable criteria. Fill missing sections. Remove duplication. Surface ambiguities back to the user before deleting any user-provided content.
   - **HELP:** Emit the Help Message section below as the entire reply, verbatim (without its outer fence). Do nothing else — no questions, no synthesis, no file writes; skip the remaining workflow steps.

4. **Render** the prompt using the Output Format below. Omit any section that has no real content.

5. **Persist if requested.** If `{save_path}` is set (explicit or inferred), write the rendered prompt body — the contents of the fenced block, without the outer fence — to that path, creating parent directories if needed. Otherwise write nothing.

## Help Message

In HELP mode, emit the body inside the fenced block below as the entire reply, verbatim — without the outer fence markers themselves:

````markdown
# /meta-prompt

Create or refine a structured task prompt for an AI coding agent.

**Usage**
- `/meta-prompt create <task description>` — synthesize a new prompt (CREATE mode).
- `/meta-prompt refine <existing structured prompt>.md` — refine an existing prompt (REFINE mode).
- `/meta-prompt help` — show this message.

**Modes**
- **CREATE** — input is a free-form task description; a new prompt is synthesized.
- **REFINE** — input is itself a structured prompt (H1 + `## Task` + `## Success Criteria` or `## Guardrails`); existing wording, H1 title, and section order are preserved.
- **HELP** - show structured help message to user

**Save as a slash command**
Mention save intent in your input (e.g. "save this", "make it `/foo`") and the result is persisted to `.cursor/commands/<kebab-name>.md` by default.

**Examples**
- `/meta-prompt write a prompt that reviews a PR for security issues`
- `/meta-prompt save as /pr-review: review a PR for security issues`
````

## Output Format

The generated prompt MUST follow this exact skeleton (omit any section whose body would be empty):

````markdown
# <Title in Title Case>

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

If the rendered body contains triple-backtick fences, escalate the outer fence to four backticks (and so on, in increments of one) so the outer fence never collides with content.
