---
name: prompt-template-library
description: "Pick a starting skeleton from the prompt template library when an agent is drafting a new prompt. Use whenever a new prompt is being drafted (typically via `/meta-prompt` or any equivalent flow) to seed the draft with the highest-scoring template from `templates/*.md` automatically, or to flip to interactive selection when `--interactive-template` is set."
license: MIT
---

# Prompt Template Library

## Task

Choose a starting skeleton for the prompt the agent is about to draft. By default, score every template at `templates/` against the drafting intent and hand the highest-scoring template's body to the caller as the seed skeleton; when `--interactive-template` is set, present the catalog (`name` plus `description`) and ask the user via `AskQuestion` which template to use.

This skill owns template selection only. It does not render the final prompt, does not write new templates, and does not modify existing prompts. The caller (typically `/meta-prompt`) consumes the chosen skeleton and proceeds with the rest of its workflow.

## Parameters

- `--interactive-template` — flag enabling interactive template selection. When present, the skill presents every catalog entry's `name` and `description` and calls `AskQuestion` to let the user pick one; the picked template's body becomes the seed skeleton. Optional. Default: absent (auto-select per the algorithm below). Validation: the parameter is a boolean flag with no value; supplying it in `key=value` form is rejected with an explanatory error before any template file is read.

## Success Criteria

- [ ] Templates are enumerated only from `templates/*.md`; `INDEX.md` is excluded; `default.md` is excluded from scoring but included in the interactive picker when present.
- [ ] Every candidate template's YAML frontmatter is parsed before scoring; templates with missing or malformed `name`, `description`, or `tags` are skipped and listed in the selection report under `skipped`.
- [ ] When `--interactive-template` is absent, the chosen template is the one with the highest score per the algorithm below; ties are broken by lexicographically lowest `name` (case-insensitive), then by lowest filename.
- [ ] When `--interactive-template` is present, the user is asked via `AskQuestion` to pick from the listed templates, and the picked template's body is used verbatim as the seed.
- [ ] When every candidate scores zero and `--interactive-template` is absent, `templates/default.md` is used if present, otherwise the inline minimal skeleton documented below.
- [ ] Selection is deterministic on identical inputs: the same `intent_terms` plus the same set of readable template files on disk produce the same winner across runs.
- [ ] The skill makes no edits to any file inside `templates/`, `ai-coding/plugins/writing/commands/`, or `ai-coding/plugins/writing/skills/`.

## Guardrails

- MUST read every candidate template's frontmatter before scoring; templates with missing or malformed `name`, `description`, or `tags` are skipped and surfaced in the report.
- MUST keep selection deterministic on identical inputs; no randomization, sampling, or model-variance-dependent choices are allowed inside the scoring procedure.
- MUST NOT write new template files; authoring new templates is a separate task left to the user.
- MUST NOT edit, rename, or delete existing template files.
- MUST NOT modify `ai-coding/plugins/writing/commands/meta-prompt.md` or any other command or skill file.
- MUST NOT orchestrate fan-out, spawn subagents, or perform any parallelism; the skill is a single read-and-pick pass.
- MUST NOT run shell commands beyond what is required to list and read template files (e.g., directory enumeration plus file reads).
- Scope: pick a starting skeleton for a prompt that is about to be drafted, and hand it back to the caller. Out of scope: rendering the final prompt, authoring or editing templates, orchestrating subagents, modifying any command or skill file.

## Library Location and File Convention

Templates live at `templates/` with one Markdown file per template named in kebab-case (filename stem matches the template's `name` field). Every template file MUST carry YAML frontmatter with at least:

- `name` (string, required) — the template's canonical identifier, kebab-case, matching the filename stem.
- `description` (string, required) — one sentence describing what kind of prompt the template seeds and when it fits.
- `tags` (list of strings, required) — a small set (typically 3-7) of lowercase trigger terms the auto-selector matches against the drafting intent. Tags should be specific (e.g., `security`, `pr-review`, `refactor`), not generic (e.g., `prompt`, `task`).

The template body below the frontmatter is the seed skeleton: any Markdown content the caller can use as a starting point.

`templates/INDEX.md` documents the convention and lists every template; it is not itself a template. `templates/default.md` (when present) is the reserved fallback used when no other template scores above zero.

## Auto-Selection Algorithm

When `--interactive-template` is absent, run this procedure to pick a template deterministically.

### Step 1: Build `intent_terms`

Collect text fragments from the caller's drafting context, in this order:

1. The natural-language task description the caller will pass to the renderer.
2. Any requested output format (e.g., "yaml schema", "markdown report", "checklist").
3. Any keywords the user supplied inline in the invocation (no separate keywords parameter is introduced; user-supplied keywords appear in natural language inside items 1 and 2).

Concatenate the fragments, then tokenize:

- Lowercase every character.
- Split on whitespace and on any non-alphanumeric character (so `pr-review` becomes `pr` and `review`, and `code_quality` becomes `code` and `quality`).
- Drop tokens shorter than 3 characters.
- Drop English stopwords: `the`, `and`, `for`, `with`, `from`, `that`, `this`, `into`, `over`, `under`, `about`, `your`, `you`, `our`, `but`, `not`, `any`, `all`, `new`, `use`, `get`, `set`, `via`, `out`, `one`, `two`.
- Deduplicate.
- Sort lexicographically ascending.

Call the result `intent_terms`.

### Step 2: Enumerate candidates

List every file matching `templates/*.md` except `INDEX.md` and `default.md`. Sort the list ascending by filename (case-insensitive). For each file, read its YAML frontmatter. Skip any file whose frontmatter does not parse or is missing `name`, `description`, or `tags`; record the path and the reason under `skipped`.

### Step 3: Score each candidate

For each readable candidate template `T`:

1. Tokenize the three fields with the same rules used for `intent_terms` (lowercase, split on whitespace and non-alphanumerics, drop tokens shorter than 3 characters, drop stopwords, deduplicate):
   - `tag_tokens` = tokenize the concatenation of every entry in `T.tags`.
   - `name_tokens` = tokenize `T.name`.
   - `desc_tokens` = tokenize `T.description`.
2. For each `term` in `intent_terms`, award the **single highest weight that applies** (no double-counting):
   - `+3` if `term` is in `tag_tokens`.
   - `+2` else if `term` is in `name_tokens`.
   - `+1` else if `term` is in `desc_tokens`.
   - `+0` otherwise.
3. `score(T)` is the sum of per-term contributions.

### Step 4: Pick the winner

Choose the template with the highest `score`. Tie-break in this order:

1. Lexicographically lowest `name` (case-insensitive).
2. Lexicographically lowest filename.

### Step 5: Fallback when max score is zero

If every readable candidate scored `0`, use `templates/default.md` when it exists. If `default.md` is absent or unreadable, hand the caller the **inline minimal skeleton** documented below.

The procedure is deterministic on the same inputs: identical `intent_terms` plus an identical set of readable template files on disk yield the same winner across runs.

### Scoring Example

Drafting intent: "Draft a prompt to review pull requests for security issues, output a markdown report grouped by severity."

After tokenization (lowercase, split, drop short tokens, drop stopwords, dedupe, sort), `intent_terms` is:
`{draft, grouped, issues, markdown, output, prompt, pull, report, requests, review, security, severity}`.

Consider a template with frontmatter `name: code-review`, `description: "Review code changes for quality and security issues."`, `tags: [code-review, pr-review, security, quality, review]`. Its derived sets are:

- `tag_tokens = {code, quality, review, security}` (the `pr` from `pr-review` is dropped because it is shorter than 3 characters).
- `name_tokens = {code, review}`
- `desc_tokens = {changes, code, issues, quality, review, security}`

Per-term contributions against `intent_terms`:

- `review` → `+3` (in `tag_tokens`, highest weight wins so the name and description hits don't double-count).
- `security` → `+3` (in `tag_tokens`).
- `issues` → `+1` (in `desc_tokens`).
- Every other term in `intent_terms` is absent from all three sets and contributes `0`.

Total score: `7`.

A different template with `name: bugfix-investigation`, `description: "Investigate a reported bug, reproduce it, propose a fix."`, `tags: [bugfix, debugging, investigation, reproduction]` scores `0` against the same intent (no token overlap), so it loses to `code-review`.

## Interactive Mode

When `--interactive-template` is present:

1. List every readable candidate template (same enumeration as Auto-Selection Step 2) and, when present, `default.md`. Sort the list ascending by `name` (case-insensitive).
2. Present `name` and `description` for each entry as numbered options via `AskQuestion`.
3. Use the picked template's body verbatim as the seed skeleton.
4. If the user declines, cancels, or no option is picked, fall back to the auto-selection procedure for this invocation; the report records `mode: interactive-fallback-to-auto`.

The interactive prompt does not score templates; the user's pick is authoritative.

## Composition with `/meta-prompt`

This skill plugs into `/meta-prompt` at the seam between meta-prompt's gather step and its render step. Before meta-prompt renders the Output Format skeleton from scratch, this skill runs once: it picks a template (auto or interactive per `--interactive-template`), reads the template's body, and supplies that body as the seed skeleton. Meta-prompt then proceeds with its normal rendering, filling in the seed's sections rather than the built-in default skeleton. The integration is read-only on `/meta-prompt`'s side — this skill does not edit `meta-prompt.md` or alter its workflow shape, and meta-prompt's other parameters (`{styles}`, `{update_mode}`, `{n}`, `--interactive`, etc.) continue to apply unchanged. The skill composes the same way with any equivalent draft-a-new-prompt flow that emits a Markdown skeleton.

## Inline Minimal Skeleton

When no template scores above zero and `default.md` is absent or unreadable, hand the caller this skeleton as the seed:

````markdown
# <Title in Title Case>

## Task
<One sentence stating what the prompt accomplishes.>

## Success Criteria
- [ ] <Observable, checkable outcome.>

## Guardrails
- MUST <constraint>.
- MUST NOT <prohibition>.
- Scope: <what is in / out of scope>.

## Workflow
1. <Step.>

## Output Format
<Exact structure of what the executing agent should produce.>
````

The skeleton mirrors `/meta-prompt`'s built-in Output Format so callers can substitute it transparently.

## Workflow

1. **Detect mode.** If `--interactive-template` is present, take the interactive branch; otherwise take the auto branch.
2. **Enumerate templates.** List `templates/*.md`, excluding `INDEX.md`. Read each file's frontmatter. Skip and record any file whose frontmatter is missing or malformed.
3. **Auto branch.** Build `intent_terms` from the drafting context (Auto-Selection Step 1). Score each readable candidate (Step 3). Choose the highest-scoring template; tie-break deterministically (Step 4). If max score is zero, fall back to `default.md` or the inline minimal skeleton (Step 5).
4. **Interactive branch.** Present every readable template's `name` and `description` via `AskQuestion`. On a pick, use that template. On cancel, decline, or no pick, fall back to the auto branch for this invocation.
5. **Emit the seed.** Hand the chosen template's body (the Markdown content below the frontmatter) back to the caller as the starting skeleton. Yield control; the caller renders the final prompt.

## Output Format

Return to the caller a small named record:

- `mode`: `auto`, `interactive`, or `interactive-fallback-to-auto`.
- `chosen_template`: path to the chosen template (e.g., `templates/code-review.md`), `templates/default.md`, or `inline-minimal-skeleton` when the inline fallback was used.
- `score`: numeric score of the chosen template in `auto` mode; `n/a` for `interactive`, `default.md` fallback, and inline-skeleton fallback.
- `runner_up`: path to the second-highest-scoring template in `auto` mode (or `n/a` if fewer than two candidates scored above zero).
- `intent_terms`: the sorted `intent_terms` set used in `auto` mode (or `n/a` for `interactive`), useful for auditability.
- `skipped`: list of `{path, reason}` entries for any template whose frontmatter failed to parse.
- `seed_body`: the Markdown content below the chosen template's frontmatter, or the inline minimal skeleton text when applicable. This is the skeleton handed off to the caller's render step.
