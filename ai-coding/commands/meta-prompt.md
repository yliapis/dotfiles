# Meta-Prompt: Create or Refine a Task Prompt

## Task

Take the user's input (the text following `/meta-prompt` in this chat message) and produce a single, structured, parameterized task prompt with explicit success criteria and guardrails. If the input is itself a structured prompt, refine it instead of creating a new one. Honor `{styles}` when set so checklists, prose, and section emphasis reflect the requested dimensions (accuracy, consistency, reliability, conciseness, simplicity, and similarly named traits).

The reply shape depends on `{update_mode}`: `auto` (default) writes the rendered prompt (and any propagated referenced-prompt updates) to disk when a write target is resolvable and replies with exactly one line — `Wrote N file(s).` — otherwise falls back to returning the rendered prompt as the entire reply inside a single fenced ` ```markdown ` block; `plan` always returns the rendered prompt as the entire reply, inside a single fenced ` ```markdown ` block, with no extra commentary before or after; `agent` always writes to disk and aborts when no write target is resolvable; `dry-run` returns a single fenced ` ```markdown ` block previewing the intended writes (manifest, diffs, full bodies of new files) without touching the filesystem; `confirm` returns the fenced block and, when `--interactive`/`-i` is set, asks for y/n confirmation before writing (without the flag, it behaves like `plan`). A clarifying question may always precede the reply.

When `{input}` includes referenced prompt files (workspace paths attached with `@`, or explicit paths to Markdown prompt or slash-command files under the workspace), read each referenced file **before** final rendering. Apply the user’s substantive update instructions to **every such file** whose scope clearly includes those paths (typically all `@`-mentioned targets sharing the same change); omit a file only when `{input}` clearly limits edits to one path. Preserve per-file REFINE invariants (H1 title and section ordering) unless `{input}` authorizes renaming or reordering. When save intent resolves to `{save_path}` for **one** file but other referenced prompts also require edits, the propagated edits are persisted at each referenced file's resolved path subject to `{update_mode}` (see step 9); in non-write modes they are shown in the rendered output or previewed as diffs rather than written.

When `{n}` is greater than 1, fan out into `{n}` parallel meta-prompt agents (running at most `{k}` at a time, default `{k} = {n}`), each in its own git worktree. Every agent runs the same `/meta-prompt` invocation independently. Whether the variant files are written, copied back to the calling worktree, or returned inline as fenced blocks depends on `{update_mode}` (see step 10); no branch merge is ever performed.

## Parameters

- `{input}` — everything the user typed after `/meta-prompt`. May be: empty, a help request, a short task description, or a full prompt that already follows the Output Format below.
- `{update_mode}` — optional; default `auto`. One of `auto`, `plan`, `agent`, `dry-run`, `confirm`. Controls whether the rendered prompt is written to disk when a target is resolvable and otherwise shown (`auto`), always shown to the user (`plan`), always written to disk silently (`agent`, aborts when no target), previewed as a manifest plus diffs (`dry-run`), or confirmed via `AskQuestion` before writing (`confirm`, interactive only — without `--interactive`/`-i` it falls back to `plan`). Parse from `{input}` as `update-mode=<value>` (whitespace-delimited); strip the token once parsed.
- `{style}` / `{styles}` — optional; synonyms. Type: a single trait name (`str`) or multiple traits (`Iterable[str]`). Describes design dimensions to prioritize when drafting or refining wording and criteria (accuracy, consistency, reliability, conciseness, simplicity, and similar traits the user lists). Omit when unspecified. Parse from `{input}` as `style=…` or `styles=…` (comma-separated list allowed for multiple traits); strip those tokens once parsed.
- `{save_path}` — optional path at which to persist the generated prompt as a slash command. Inferred from `{input}` context when the user expresses save intent (e.g., "save this", "make it a slash command", "create a `/<name>` command", or a literal path). When intent is detected but no path is given, default to `.cursor/commands/<kebab-name>.md` where `<kebab-name>` is derived from the H1 title. When no save intent is detected, leave unset. Drives a write when `{update_mode}` resolves to `auto` (and a target exists), `agent`, or `confirm` answered yes; in `plan`, `dry-run`, unconfirmed/declined `confirm`, and `auto` with no target, the path is resolved for reporting purposes only.
- `{worktree}` — optional name of a git worktree to write the persisted prompt file into; only relevant when `{save_path}` is set, `{n}` is `1`, and a write occurs (`{update_mode}` resolves to `auto` with a target, `agent`, or `confirm` answered yes). Default: empty. When empty, the file is written into the current working tree (no worktree is created); in `interactive` mode the workflow may offer 2–4 kebab-case worktree-name suggestions derived from the H1 title and the user may pick one or decline.
- `{n}` — number of parallel meta-prompt agents (one experiment each); optional, default: `1`. MUST be an integer `>= 1`. When `1`, no fan-out happens and the workflow runs entirely in the calling agent.
- `{k}` — maximum number of agents active concurrently when `{n} > 1`; optional, default: `{n}`. MUST be an integer in `1..{n}`.
- `--interactive` / `-i` — flag enabling interactive mode: clarifying follow-ups are asked about ambiguous inputs, missing critical slots, and the `{worktree}` choice before the prompt is rendered. Optional. Default: absent (non-interactive). When the flag is absent, no questions are asked; the workflow runs to completion using only inferable inputs and aborts with an explanatory error if a critical slot is missing.

## Success Criteria

- [ ] In HELP mode, the reply is the Help Message body verbatim.
- [ ] In CREATE or REFINE mode with `{n} = 1` and `{update_mode}` = `plan` (or `auto` with no resolvable write target, or `confirm` without `--interactive`/`-i`, or `confirm` answered no), the reply contains exactly one fenced ```markdown block whose body matches the Output Format.
- [ ] In CREATE or REFINE mode with `{n} = 1` and `{update_mode}` = `agent` (or `auto` with a resolvable write target), the reply is exactly the line `Wrote N file(s).` (where `N` is the number of files written) with no fenced block and no manifest.
- [ ] In CREATE or REFINE mode with `{n} = 1` and `{update_mode}` = `dry-run`, the reply contains exactly one fenced ```markdown block whose body is, in order, an intended-writes manifest (one `<path>: <bytes> bytes` line per target), a unified diff per referenced prompt that would change, and the full rendered body of any net-new file.
- [ ] In CREATE or REFINE mode with `{n} = 1`, `{update_mode}` = `confirm`, `--interactive`/`-i` present, and the user answered yes, the reply is the fenced ```markdown block followed by `Wrote N file(s).` on its own line.
- [ ] In CREATE or REFINE mode with `{n} > 1` and `{update_mode}` = `agent` (or `auto` with a resolvable `{save_path}`), the reply is a manifest with one line per variant (worktree branch, worktree path, copied file path in the calling worktree, and terminal status, per step 10) and contains no top-level fenced markdown block.
- [ ] In CREATE or REFINE mode with `{n} > 1` and `{update_mode}` ∈ {`plan`, `dry-run`, unconfirmed `confirm`, declined `confirm`, `auto` with no resolvable `{save_path}`}, the reply is a sequence of `{n}` numbered fenced ```markdown blocks (`## Variant 1` ... `## Variant N`) and no variant file is copied into the calling worktree.
- [ ] No `<...>` placeholder text and no standalone uses of `good`, `clean`, `nice`, or `fast` as qualifiers remain in the body; sections that would be empty are omitted.
- [ ] At least one Success Criterion is present, and each is observable / checkable (not a vague adjective).
- [ ] At least one Guardrail is present, expressed as MUST / MUST NOT / Scope.
- [ ] Parameters are included only when the task has values that legitimately vary between invocations; otherwise the Parameters section is omitted.
- [ ] Any wording the user supplied verbatim is preserved verbatim.
- [ ] In REFINE mode, every section that existed in the input still exists in the output (or the user was asked before removal), and the H1 title and section ordering are preserved.
- [ ] If a write target is resolvable, `{n}` is `1`, and `{update_mode}` is `agent`, `auto`, or `confirm` (interactive, answered yes), the file at `{save_path}` exists and contains the rendered prompt body verbatim. In every other `{update_mode}` resolution (including `plan`, `dry-run`, unconfirmed/declined `confirm`, and `auto` with no resolvable target), the file at `{save_path}` is neither created nor modified by this invocation.
- [ ] When `{update_mode}` ∈ {`plan`, `dry-run`}, `{update_mode}` = `confirm` with `--interactive`/`-i` absent or the user declined, or `{update_mode}` = `auto` with no resolvable write target, no file at `{save_path}` and no referenced-prompt file is created or modified by this invocation.
- [ ] When `{worktree}` resolves to a non-empty name, `{n}` is `1`, and a write occurs (`{update_mode}` = `agent`, `auto` with a target, or `confirm` answered yes), the persisted file is written inside that git worktree (created via `git worktree add` if absent) and no files are written into the original working tree.
- [ ] When `{worktree}` is empty (the default), `{n}` is `1`, and a write occurs, the persisted file is written into the current working tree and no git worktree is created.
- [ ] When `--interactive` / `-i` is absent, the workflow makes no `AskQuestion` calls (including the `confirm`-mode y/n) and either renders with inferable inputs or aborts with an explanatory error naming the missing critical slot.
- [ ] Parameters `{n}`, `{k}`, and `{update_mode}` are validated before any worktree is created: `{n}` is an integer `>= 1`, `{k}` is an integer in `1..{n}`, and `{update_mode}` is one of `auto`, `plan`, `agent`, `dry-run`, `confirm`. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] When `{n} > 1`, exactly `{n}` isolated worktrees are created off the current branch, with at most `{k}` agents active concurrently, and each spawned agent runs the same `/meta-prompt` invocation (with `{n} = 1` to prevent recursive fan-out) inside its own worktree.
- [ ] When `{n} > 1` and `{update_mode}` = `agent` (or `auto` with a resolvable `{save_path}`, or `confirm` interactive answered yes), after all agents complete, `{n}` variant files exist in the calling worktree at `<save_path>` with `-<i>` appended before the file extension (1-based); no worktree branch is merged.
- [ ] When `{input}` names one or more referenced prompt/command Markdown paths (via `@`-style attachment or explicit workspace paths before flag stripping): each resolves to a readable file inside the workspace, is read before final output, and receives propagated substantive edits wherever the requested update plainly applies—with REFINE conventions preserved file-by-file unless the user authorizes broader rewrites (renames/reordering).
- [ ] When `{style}` / `{styles}` is non-empty, the rendered prompt visibly reflects those dimensions in choices of language and checkability (measurable criteria for accuracy/reliability, parallel structure for consistency, tightened prose for conciseness and simplicity)—without violating the bans on placeholders and vague qualifiers.

## Guardrails

- MUST NOT execute, plan, or begin the generated task. Only emit the prompt.
- MUST NOT bundle multiple unrelated tasks into one prompt. If the input asks for several, ask the user to pick one or split.
- MUST NOT invent constraints the user did not state; ask first.
- MUST keep the generated prompt self-contained: no references to this meta-prompt, no "see above," no out-of-band context.
- MUST validate `{n}`, `{k}`, and `{update_mode}` before creating any worktree or filesystem mutation; fail fast and create nothing on validation failure.
- MUST NOT write any file (primary `{save_path}` or referenced prompts) when `{update_mode}` is `plan`, `dry-run`, or `auto` with no resolvable write target, regardless of `{save_path}` resolution.
- MUST NOT call `AskQuestion` from `confirm` mode when `--interactive`/`-i` is absent; fall back to `plan` semantics (emit the block, write nothing).
- MUST keep each spawned agent's work isolated to its assigned worktree; spawned agents MUST NOT read, write, or run commands against the calling worktree or any sibling worktree.
- MUST NOT merge worktree branches when aggregating; aggregation is a file-copy of per-agent variant files into the calling worktree only.
- MUST NOT recursively fan out: spawned agents always run with `{n} = 1`.
- Scope: this command produces a reusable prompt artifact (or `{n}` variant artifacts when `{n} > 1`). It does not write files, run code, or modify the repo unless `{update_mode}` is `agent`, `auto` with a resolvable write target, or `confirm` with `--interactive`/`-i` answered yes.

## Workflow

1. **Parse flags and parallelism args.** Extract `--interactive` / `-i` from `{input}` and remove it; record interactive mode as on iff the flag is present (default off). Extract `n=<int>` and `k=<int>` tokens (whitespace-delimited) and remove them; record `{n}` (default `1`) and `{k}` (default `{n}`). Extract `update-mode=<value>` (whitespace-delimited) and remove it; record `{update_mode}` (default `auto`). Extract `style=` and `styles=` tokens (either form sets `{styles}`; last wins when both appear); split comma-separated values into a normalized ordered list of trimmed trait tokens; strip those tokens once parsed.

2. **Resolve referenced prompts.** From the full user-visible `{input}` (including paths attached with `@` and explicit workspace paths to Markdown), enumerate slash-command or prompt files. Dedupe paths. **Read** each file before synthesis or REFINE merges. Maintain a `{referenced_prompts}` list of `{ path, baseline_body }`.

3. **Detect mode** from the remaining `{input}`:
   - **HELP** if `{input}` is empty/whitespace, equals `help`, `--help`, `-h`, or otherwise reads as a request for help or usage.
   - **REFINE** if `{input}` begins with an `# <Title>` H1 and contains `## Task` plus at least one of `## Success Criteria` or `## Guardrails`. REFINE inputs are typically produced by pasting a previous `/meta-prompt` output back in.
   - **CREATE** otherwise.

4. **Validate parameters.** Confirm `{n}` is an integer `>= 1` and `{k}` is an integer in `1..{n}` (default `{k} = {n}`). Confirm `{update_mode}` ∈ `{auto, plan, agent, dry-run, confirm}`. When `{update_mode}` = `agent`, also confirm that save intent is detectable from `{input}` (explicit `{save_path}` or save-intent phrasing); if not, abort with an explanatory error naming the missing slot. `{update_mode}` = `auto` has no such precondition; absence of a write target simply triggers the `plan`-like fallback in step 9. Validation failure on any check aborts with an explanatory error and no filesystem side effects.

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

9. **Emit reply and persist per `{update_mode}` (when `{n} = 1`).** First compute the intended write set: `{save_path}` (or, per the `{input}` carve-out, the referenced-prompt path that becomes the sole authoritative target) for the primary, plus every edited entry in `{referenced_prompts}` for which the user asked to persist or implied command-file updates ("refine `@…`/command"). Then branch on `{update_mode}`:
   - **`auto`** (default): if the intended write set is non-empty, behave as `agent` below; otherwise behave as `plan` below.
   - **`plan`**: emit the rendered prompt body inside a single fenced ```markdown block as the entire reply. Write nothing; `{save_path}` and `{worktree}` are ignored as write triggers.
   - **`agent`**: write each path in the intended write set, creating parent directories as needed. For the primary write, when `{worktree}` resolves to a non-empty name, perform the write inside that git worktree, creating it via `git worktree add` off the current branch if it does not already exist; otherwise write into the current working tree. Referenced prompts outside `{worktree}` still update at resolved repo paths unless `{input}` forbids. Reply with exactly the line `Wrote N file(s).` where `N` is the total count; no fenced block, no manifest.
   - **`dry-run`**: emit a single fenced ```markdown block whose body is, in order, an intended-writes manifest (one `<path>: <bytes> bytes` line per target), then a unified diff for each referenced prompt that would change, then the full rendered body of any net-new file. Make no filesystem mutations.
   - **`confirm`** with `--interactive`/`-i`: emit the rendered prompt body inside a single fenced ```markdown block, then call `AskQuestion` with a y/n question summarizing the intended writes (paths and counts). On yes, perform the `agent` writes (per the rules above) and append `Wrote N file(s).` on its own line below the block. On no, write nothing further.
   - **`confirm`** without `--interactive`/`-i`: behave as `plan` (emit the fenced block, write nothing).

10. **Fan out and aggregate (when `{n} > 1`).** When `{n} > 1`, the calling agent skips steps 5 through 9 (single-agent gather / rules / propagation / render / persist) and instead:
   - Resolve `{save_path}` (explicit or inferred). When `{update_mode}` = `agent` (or `confirm` interactive), abort with an explanatory error if `{save_path}` cannot be resolved, since variant files require a destination. `{update_mode}` ∈ {`auto`, `plan`, `dry-run`} and non-interactive `confirm` have no `{save_path}` precondition; under `auto`, an unresolved `{save_path}` triggers the `plan`-like aggregation branch below.
   - For each `i` in `1..{n}`, create an isolated worktree off the current branch named `<kebab-name>-<i>` and dispatch one agent to run the same `/meta-prompt` invocation inside it (with `{n} = 1` to prevent recursive fan-out, the same `--interactive` setting, the same `{styles}`, and the same task input), respecting at most `{k}` concurrent agents.
   - **`{update_mode} = auto`**: if `{save_path}` resolved, behave as the `agent` branch below; otherwise behave as the `plan` branch below.
   - **`{update_mode} = agent`**: spawn each agent with `update-mode=agent`. Instruct each to persist its rendered prompt to `<save_path>` with `-<i>` appended before the file extension, written inside its own worktree. After all agents complete, copy every variant file back into the calling worktree at the matching path. Reply with a manifest listing each variant's worktree branch, worktree path, copied file path in the calling worktree, and per-agent terminal status (`success` / `failed` / `incomplete`).
   - **`{update_mode} ∈ {plan, dry-run}`**: spawn each agent with the same `update-mode` and collect the fenced reply block each returns. The calling agent aggregates the `{n}` blocks into a single reply, prefixed `## Variant 1`, `## Variant 2`, …, `## Variant N`. No variant file is copied into the calling worktree.
   - **`{update_mode} = confirm` with `--interactive`/`-i`**: spawn each agent with `update-mode=plan` and collect their fenced blocks. The calling agent emits the aggregated reply (numbered as above), then calls `AskQuestion` once asking whether to persist all `{n}` variants. On yes, the calling agent writes each already-collected variant body verbatim to `<save_path>` with `-<i>` appended before the extension in the calling worktree (no re-dispatch — re-running agents would persist different text than the user approved), and appends a per-variant write status to the reply. On no, write nothing further.
   - **`{update_mode} = confirm` without `--interactive`/`-i`**: behave as the `plan` branch above.
   - In all branches, do not merge worktree branches.

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
- **HELP** — show this help message.

**Save as a slash command**
Mention save intent in your input (e.g. "save this", "make it `/foo`") and a `{save_path}` is resolved to `.cursor/commands/<kebab-name>.md` by default. The default `update-mode=auto` writes the file when a target is resolvable and falls back to showing the markdown block when none is; pass `update-mode=plan` to always show the block instead of writing. Pass `worktree=<name>` to persist the file inside a named git worktree; leave it empty (the default) to write into the current working tree.

**Interaction mode**
Pass `-i` or `--interactive` to enable interactive mode: clarifying follow-ups are asked about ambiguous inputs, missing critical slots, and the `worktree` choice before the prompt is rendered. Without the flag, no questions are asked; missing critical inputs cause an early abort. Default: non-interactive — the workflow runs to completion using only inferable inputs.

**Update mode**
Pass `update-mode=<value>` to control what happens after rendering. Default: `auto`.
- `auto` (default) — write the rendered prompt (and any propagated referenced-prompt updates) to disk when a write target is resolvable; otherwise fall back to showing the rendered prompt as a fenced markdown block. The reply is `Wrote N file(s).` when writing, or the block when not.
- `plan` — always show the rendered prompt as a fenced markdown block; write nothing. Use this when you want to copy the block by hand instead of writing files.
- `agent` — always write the rendered prompt (and any propagated referenced-prompt updates) to disk silently; the reply is a single `Wrote N file(s).` line. Requires save intent or an explicit `{save_path}`; aborts otherwise.
- `dry-run` — show a preview block (intended-writes manifest, unified diffs for referenced prompts, full body for new files); write nothing.
- `confirm` — show the block, then ask y/n (interactive only); on yes, behave like `agent`. Without `-i`/`--interactive`, falls back to `plan` (does not auto-write).

**Styles**
Pass `style=<trait>` or `styles=<trait1>,<trait2>,…` (synonyms) to bias drafting and refinement toward named design dimensions such as accuracy, consistency, reliability, conciseness, and simplicity.

**Referenced prompts**
Attach `@path/to/prompt.md` or type an explicit workspace path; each referenced Markdown command or prompt is read and, when your instructions amount to an update, edited in lockstep with the primary output so shared wording stays aligned.

**Parallel experiments**
Pass `n=<int>` to fan out into `n` parallel meta-prompt agents, each in its own worktree, all running the same `/meta-prompt` invocation. Pass `k=<int>` to cap the number of agents active concurrently (default `k = n`). Aggregation depends on `update-mode`: in `agent` (and `auto` with a resolvable `{save_path}`), every agent writes its rendered prompt to a variant file (`<save_path>` with `-<i>` appended before the extension) inside its own worktree and the calling agent copies every variant file back into the calling worktree — `agent` requires save intent (explicit or inferable) and aborts without it. In `confirm` answered yes, the calling agent writes the approved variant blocks directly to the same variant paths in the calling worktree. In `plan`, `dry-run`, `auto` without a resolvable `{save_path}`, and unconfirmed/declined `confirm`, each agent's rendered block is collected and the calling agent emits `n` numbered fenced blocks inline, with no save-intent requirement. No branch merge is ever performed.

**Examples**
- `/meta-prompt write a prompt that reviews a PR for security issues` — no save target; default `auto` falls back to showing the markdown block.
- `/meta-prompt save as /pr-review: review a PR for security issues` — save intent resolves a target; default `auto` writes the file.
- `/meta-prompt update-mode=plan save as /pr-review: review a PR for security issues` — explicitly opt into the markdown block for copying.
- `/meta-prompt -i update-mode=confirm save as /pr-review: review a PR for security issues` — interactive confirm before writing.
- `/meta-prompt n=4 save as /pr-review: review a PR for security issues` — fan out into 4 variant files (default `auto` writes them).
- `/meta-prompt styles=accuracy,consistency refine @.cursor/commands/foo.md: …` — refine a referenced command; default `auto` writes the updated file.
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
