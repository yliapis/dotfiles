# Meta-Prompt: Create or Refine a Task Prompt

## Task

Take the user's input (the text following `/meta-prompt` in this chat message) and produce a single, structured, parameterized task prompt with explicit success criteria and guardrails. If the input is itself a structured prompt, refine it instead of creating a new one. Honor `{styles}` when set so checklists, prose, and section emphasis reflect the requested dimensions (accuracy, consistency, reliability, conciseness, simplicity, and similarly named traits).

Return the generated prompt as the entire reply, inside a single fenced ` ```markdown ` block, with no extra commentary before or after — unless you must ask the user a clarifying question first.

When `{input}` includes referenced prompt files (workspace paths attached with `@`, or explicit paths to Markdown prompt or slash-command files under the workspace), read each referenced file **before** final rendering. Apply the user’s substantive update instructions to **every such file** whose scope clearly includes those paths (typically all `@`-mentioned targets sharing the same change); omit a file only when `{input}` clearly limits edits to one path. Preserve per-file REFINE invariants (H1 title and section ordering) unless `{input}` authorizes renaming or reordering. When save intent resolves to `{save_path}` for **one** file but other referenced prompts also require edits, write each updated referenced file body back at its resolved path unless the user forbids persistence.

When `{n}` is greater than 1, fan out into `{n}` parallel meta-prompt agents (running at most `{k}` at a time, default `{k} = {n}`), each in its own git worktree. Every agent runs the same `/meta-prompt` invocation independently and writes its rendered prompt to a numbered variant file `<kebab-name>-<i>.md`. After all agents complete, the calling agent copies every variant file back into the calling worktree as separate files; no branch merge is performed.

## Parameters

- `{input}` — everything the user typed after `/meta-prompt`. May be: empty, a help request, a short task description, or a full prompt that already follows the Output Format below.
- `{style}` / `{styles}` — optional; synonyms. Type: a single trait name (`str`) or multiple traits (`Iterable[str]`). Describes design dimensions to prioritize when drafting or refining wording and criteria (accuracy, consistency, reliability, conciseness, simplicity, and similar traits the user lists). Omit when unspecified. Parse from `{input}` as `style=…` or `styles=…` (comma-separated list allowed for multiple traits); strip those tokens once parsed.
- `{save_path}` — optional path at which to persist the generated prompt as a slash command. Inferred from `{input}` context when the user expresses save intent (e.g., "save this", "make it a slash command", "create a `/<name>` command", or a literal path). When intent is detected but no path is given, default to `.cursor/commands/<kebab-name>.md` where `<kebab-name>` is derived from the H1 title. When no save intent is detected, leave unset and write nothing.
- `{worktree}` — optional name of a git worktree to write the persisted prompt file into; only relevant when `{save_path}` is set and `{n}` is `1`. Default: empty. When empty, the workflow derives 2–4 kebab-case worktree-name suggestions from the H1 title; in `interactive` mode the user picks one (or declines, in which case the file is written into the current working tree), and in `non-interactive` mode the first suggestion is used.
- `{n}` — number of parallel meta-prompt agents (one experiment each); optional, default: `1`. MUST be an integer `>= 1`. When `1`, no fan-out happens and the workflow runs entirely in the calling agent.
- `{k}` — maximum number of agents active concurrently when `{n} > 1`; optional, default: `{n}`. MUST be an integer in `1..{n}`.
- `--interactive` / `-i` — flag enabling interactive mode: clarifying follow-ups are asked about ambiguous inputs, missing critical slots, and the `{worktree}` choice before the prompt is rendered. Optional. Default: absent (non-interactive). When the flag is absent, no questions are asked; the workflow runs to completion using only inferable inputs and aborts with an explanatory error if a critical slot is missing.

## Success Criteria

- [ ] In CREATE or REFINE mode with `{n} = 1`, the reply contains exactly one fenced ```markdown block whose body matches the Output Format. With `{n} > 1`, the reply is a manifest of the per-variant file paths (one per line) and contains no top-level fenced markdown block. In HELP mode, the reply is the Help Message body verbatim.
- [ ] No `<...>` placeholder text and no standalone uses of `good`, `clean`, `nice`, or `fast` as qualifiers remain in the body; sections that would be empty are omitted.
- [ ] At least one Success Criterion is present, and each is observable / checkable (not a vague adjective).
- [ ] At least one Guardrail is present, expressed as MUST / MUST NOT / Scope.
- [ ] Parameters are included only when the task has values that legitimately vary between invocations; otherwise the Parameters section is omitted.
- [ ] Any wording the user supplied verbatim is preserved verbatim.
- [ ] In REFINE mode, every section that existed in the input still exists in the output (or the user was asked before removal), and the H1 title and section ordering are preserved.
- [ ] If save intent was detected and `{n}` is `1`, the file at `{save_path}` exists and contains the rendered prompt body verbatim.
- [ ] When `{worktree}` resolves to a non-empty name and `{n}` is `1`, the persisted file is written inside that git worktree (created via `git worktree add` if absent) and no files are written into the original working tree.
- [ ] When `--interactive` / `-i` is absent, the workflow makes no `AskQuestion` calls and either renders with inferable inputs or aborts with an explanatory error naming the missing critical slot.
- [ ] Parameters `{n}` and `{k}` are validated before any worktree is created: `{n}` is an integer `>= 1`, and `{k}` is an integer in `1..{n}`. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] When `{n} > 1`, exactly `{n}` isolated worktrees are created off the current branch, with at most `{k}` agents active concurrently, and each spawned agent runs the same `/meta-prompt` invocation (with `{n} = 1` to prevent recursive fan-out) inside its own worktree.
- [ ] When `{n} > 1` and save intent was detected (or could be inferred), after all agents complete, `{n}` variant files exist in the calling worktree at `<save_path>` with `-<i>` appended before the file extension (1-based); no worktree branch is merged.
- [ ] When `{input}` names one or more referenced prompt/command Markdown paths (via `@`-style attachment or explicit workspace paths before flag stripping): each resolves to a readable file inside the workspace, is read before final output, and receives propagated substantive edits wherever the requested update plainly applies—with REFINE conventions preserved file-by-file unless the user authorizes broader rewrites (renames/reordering).
- [ ] When `{style}` / `{styles}` is non-empty, the rendered prompt visibly reflects those dimensions in choices of language and checkability (measurable criteria for accuracy/reliability, parallel structure for consistency, tightened prose for conciseness and simplicity)—without violating the bans on placeholders and vague qualifiers.

## Guardrails

- MUST NOT execute, plan, or begin the generated task. Only emit the prompt.
- MUST NOT bundle multiple unrelated tasks into one prompt. If the input asks for several, ask the user to pick one or split.
- MUST NOT invent constraints the user did not state; ask first.
- MUST keep the generated prompt self-contained: no references to this meta-prompt, no "see above," no out-of-band context.
- MUST validate `{n}` and `{k}` before creating any worktree; fail fast and create nothing on validation failure.
- MUST keep each spawned agent's work isolated to its assigned worktree; spawned agents MUST NOT read, write, or run commands against the calling worktree or any sibling worktree.
- MUST NOT merge worktree branches when aggregating; aggregation is a file-copy of per-agent variant files into the calling worktree only.
- MUST NOT recursively fan out: spawned agents always run with `{n} = 1`.
- Scope: this command produces a reusable prompt artifact (or `{n}` variant artifacts when `{n} > 1`). It does not write files, run code, or modify the repo unless the user explicitly asks.

## Workflow

1. **Parse flags and parallelism args.** Extract `--interactive` / `-i` from `{input}` and remove it; record interactive mode as on iff the flag is present (default off). Extract `n=<int>` and `k=<int>` tokens (whitespace-delimited) and remove them; record `{n}` (default `1`) and `{k}` (default `{n}`). Extract `style=` and `styles=` tokens (either form sets `{styles}`; last wins when both appear); split comma-separated values into a normalized ordered list of trimmed trait tokens; strip those tokens once parsed.

2. **Resolve referenced prompts.** From the full user-visible `{input}` (including paths attached with `@` and explicit workspace paths to Markdown), enumerate slash-command or prompt files. Dedupe paths. **Read** each file before synthesis or REFINE merges. Maintain a `{referenced_prompts}` list of `{ path, baseline_body }`.

3. **Detect mode** from the remaining `{input}`:
   - **HELP** if `{input}` is empty/whitespace, equals `help`, `--help`, `-h`, or otherwise reads as a request for help or usage.
   - **REFINE** if `{input}` begins with an `# <Title>` H1 and contains `## Task` plus at least one of `## Success Criteria` or `## Guardrails`. REFINE inputs are typically produced by pasting a previous `/meta-prompt` output back in.
   - **CREATE** otherwise.

4. **Validate parallelism parameters.** Confirm `{n}` is an integer `>= 1` and `{k}` is an integer in `1..{n}` (default `{k} = {n}`). Abort with an explanatory error and no filesystem side effects on validation failure.

5. **Gather missing slots.** Decide what the input pins down vs. what you need:
   - Critical (when interactive mode is on, ask via `AskQuestion` if missing; when off, abort with an explanatory error naming the missing slot): the task statement, and at least one success criterion.
   - Inferrable (draft from context, then proceed): parameters, guardrails, workflow, output format.
   - When interactive mode is on, also surface clarifying follow-ups about the state of the request (ambiguous wording, the `{worktree}` choice when empty, etc.) prior to rendering. When off, ask nothing and use the parameter defaults described above.
   - Do not guess at intent for the critical slots.

6. **Apply mode-specific rules:**
   - **CREATE:** Synthesize each section from the user's description. Infer a short kebab-case title for the `# Heading`.
   - **REFINE:** Preserve verbatim user wording, the H1 title, and the section order. Convert vague terms ("good", "fast", "clean", "nice") into measurable criteria. Fill missing sections. Remove duplication. Surface ambiguities back to the user before deleting any user-provided content.
   - **HELP:** Emit the Help Message section below as the entire reply, verbatim (without its outer fence). Do nothing else — no questions, no synthesis, no file writes; skip the remaining workflow steps.

7. **Apply referenced-prompt propagation.** Where `{referenced_prompts}` is non-empty and the user’s wording targets an update (REFINE pasted content, directives like “update”, or edits that span shared wording), propagate the **same substantive** changes onto each referenced file’s Markdown body as appropriate. Per file: preserve REFINE-safe structure (existing H1, section order); do not widen scope beyond what `{input}` authorizes.

8. **Render** the primary prompt using the Output Format below. When `{styles}` is non-empty, favor language and checklists that reflect those traits. Omit any section that has no real content.

9. **Persist if requested (when `{n} = 1`).** If `{save_path}` is set (explicit or inferred), write the rendered prompt body — the contents of the fenced block, without the outer fence — to that path, creating parent directories if needed **unless** `{input}` makes a referenced path the sole authoritative target (then write rendered body for **that** path per user intent). For every edited entry in `{referenced_prompts}`, write the revised full file contents back when the user asked to persist or implied command-file updates (“refine `@…`/command”). When `{worktree}` resolves to a non-empty name, perform the primary write inside that git worktree, creating it via `git worktree add` off the current branch if it does not already exist; otherwise write into the current working tree. Referenced prompts outside `{worktree}` still update at resolved repo paths unless the user forbids. When no save intent is detected for the primary artifact, referenced files may still be written when edits were explicitly commanded for those paths. When neither primary nor referenced persistence applies, write nothing.

10. **Fan out and aggregate (when `{n} > 1`).** When `{n} > 1`, the calling agent skips steps 5 through 9 (single-agent gather / rules / propagation / render / persist) and instead:
   - Resolve `{save_path}` (explicit or inferred); abort with an explanatory error if it cannot be resolved, since variant files require a destination.
   - For each `i` in `1..{n}`, create an isolated worktree off the current branch named `<kebab-name>-<i>` and dispatch one agent to run the same `/meta-prompt` invocation inside it (with `{n} = 1` to prevent recursive fan-out, the same `--interactive` setting, and the same task input), respecting at most `{k}` concurrent agents.
   - Instruct each spawned agent to persist its rendered prompt to `<save_path>` with `-<i>` appended before the file extension, written inside its own worktree.
   - After all agents complete, copy every variant file back into the calling worktree at the matching path. Do not merge worktree branches.
   - Reply with a manifest listing each variant's worktree branch, worktree path, copied file path in the calling worktree, and per-agent terminal status (`success` / `failed` / `incomplete`).

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
Mention save intent in your input (e.g. "save this", "make it `/foo`") and the result is persisted to `.cursor/commands/<kebab-name>.md` by default. Pass `worktree=<name>` to persist the file inside a named git worktree; leave it empty to pick from 2–4 suggested kebab-case names derived from the title (auto-picked when interactive mode is off).

**Interaction mode**
Pass `-i` or `--interactive` to enable interactive mode: clarifying follow-ups are asked about ambiguous inputs, missing critical slots, and the `worktree` choice before the prompt is rendered. Without the flag, no questions are asked; missing critical inputs cause an early abort. Default: non-interactive — the workflow runs to completion using only inferable inputs.

**Styles**
Pass `style=<trait>` or `styles=<trait1>,<trait2>,…` (synonyms) to bias drafting and refinement toward named design dimensions such as accuracy, consistency, reliability, conciseness, and simplicity.

**Referenced prompts**
Attach `@path/to/prompt.md` or type an explicit workspace path; each referenced Markdown command or prompt is read and, when your instructions amount to an update, edited in lockstep with the primary output so shared wording stays aligned.

**Parallel experiments**
Pass `n=<int>` to fan out into `n` parallel meta-prompt agents, each in its own worktree, all running the same `/meta-prompt` invocation. Pass `k=<int>` to cap the number of agents active concurrently (default `k = n`). When save intent is detected, every agent writes its rendered prompt to a variant file (`<save_path>` with `-<i>` appended before the extension) inside its own worktree, and the calling agent copies every variant file back into the calling worktree as separate files; no branch merge is performed. `{n} > 1` requires save intent (explicit or inferable); without it, the invocation aborts.

**Examples**
- `/meta-prompt write a prompt that reviews a PR for security issues`
- `/meta-prompt save as /pr-review: review a PR for security issues`
- `/meta-prompt -i save as /pr-review: review a PR for security issues`
- `/meta-prompt n=4 save as /pr-review: review a PR for security issues`
- `/meta-prompt styles=accuracy,consistency refine @.cursor/commands/foo.md: …`
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
