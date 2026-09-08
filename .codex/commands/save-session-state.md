# Save Session State

## Task
Persist a self-contained snapshot of the current Cursor agent thread and workspace context to `{output_path}` so a human or another agent can continue analysis in a new chat, external tool, or async review without re-reading the full conversation.

The snapshot favors factual, citable state (resolved paths, git identifiers, structured summaries) over verbatim replay of long tool transcripts.

## Parameters

- `{output_path}` — destination file for the snapshot; required. MAY be absolute or relative to a workspace root. Parent directories are created when `{mode}` is `write`.
- `{format}` — `markdown` or `json`; optional, default: `markdown`.
- `{mode}` — `write` or `preview`; optional, default: `write`. In `preview`, emit the snapshot body in the chat inside one fenced block and create or replace no file.
- `{workspace_roots}` — explicit list of repository or workspace roots to include in the **Git / workspace** section; optional, default: every root from the active workspace list when available, else the single implied root from `{output_path}` resolution.
- `{transcript_paths}` — zero or more filesystem paths to agent transcript or log files to cite in **Artifact pointers** (paths only; do not inline full transcripts); optional, default: empty.
- `{include_sections}` — ordered subset of `header`, `goal`, `thread_summary`, `decisions`, `blockers`, `open_questions`, `todos`, `open_files`, `git_workspace`, `artifact_pointers`, `resume_instructions`; optional, default: all sections in that order. Omitted sections MUST NOT appear in the saved file or preview.
- `-i` / `--interactive` — when set and `{mode}` is `write`, ask for confirmation before overwriting an existing `{output_path}`; when absent and the target exists, abort with an explanatory error naming the path. Optional, default: absent.

## Success Criteria

- [ ] `{output_path}` is non-empty before any gather step runs; otherwise the workflow aborts with an explanatory error and performs no filesystem writes.
- [ ] When `{mode}` is `write` and `{output_path}` already exists, the workflow either aborts before overwrite (non-interactive) or obtains explicit user confirmation (`-i` / `--interactive`); no silent truncation of a pre-existing file.
- [ ] When `{mode}` is `write`, the snapshot file exists at the resolved absolute `{output_path}`, parent directories were created as needed, and the file is non-empty.
- [ ] The saved or previewed snapshot includes **Header** with UTC ISO-8601 timestamp (second or finer precision), resolved absolute `{output_path}`, and resolved `{format}` and `{mode}`.
- [ ] **Thread summary** states the user’s underlying goal in one short paragraph and lists the main tasks attempted in bulleted form with current completion state (`done` / `in progress` / `blocked` / `not started`) per item.
- [ ] **Decisions** lists at least zero explicit decisions or constraints stated in the thread; when none exist, the section body is exactly `_None recorded._`
- [ ] **Blockers** and **Open questions** each list at least zero items using the same `_None recorded._` convention when empty.
- [ ] When `todos` is included and a todo tool or explicit inline checklist exists in the thread, **Todos** reflects the latest known states; when no todos exist, the section body is `_None recorded._`
- [ ] When `open_files` is included, **Open / recent files** lists paths from the IDE context when available; when unavailable, the section states that explicitly in one line.
- [ ] When `git_workspace` is included, **Git / workspace** runs `git rev-parse --show-toplevel`, `git branch --show-current`, and `git status --short --branch` (or equivalents) once per resolved root in `{workspace_roots}` and records verbatim command plus representative output lines; on non-git directories, records `_Not a git repository._` for that root.
- [ ] When `artifact_pointers` is included and `{transcript_paths}` is non-empty, **Artifact pointers** lists each path on its own line; when empty, the section body is `_None._`
- [ ] **Resume instructions** contains three to seven imperative steps a follow-up agent should run first (e.g., read named files, run named tests, answer named questions).
- [ ] When `{format}` is `json`, the file is a single JSON object with keys that correspond to the included sections (snake_case keys matching section slugs) plus `header` metadata; no trailing commentary outside the JSON value.

## Guardrails

- MUST create parent directories for `{output_path}` when `{mode}` is `write`.
- MUST NOT inline secrets: no `.env` contents, private keys, tokens, or `password=` / `Authorization:`-style literals; redact or replace with `<redacted>` when such material appeared in the thread.
- MUST NOT claim git or filesystem facts without running the cited shell commands or reading the cited files in the same invocation, except when the section explicitly states unavailability.
- MUST keep the snapshot self-contained: no references like "see above" or "the earlier message" without a one-line paraphrase of the needed fact.
- MUST NOT commit, push, merge, rebase, or delete branches as part of this command.
- Scope: capture session state to disk or preview only. Out of scope: modifying application code, running application test suites unless listed as a resume step for a follow-up, or uploading artifacts.

## Workflow

1. **Parse.** Extract `-i` / `--interactive` and remove it. Parse `{output_path}` as the first path-like token (quoted paths allowed); parse optional `format=json`, `mode=preview`, `include_sections=…` as whitespace-delimited `key=value` tokens where specified in the user text; collect `{transcript_paths}` when the user prefixes paths with a literal `transcript=` token or lists paths after a `transcripts:` marker. Abort if `{output_path}` resolves empty.
2. **Overwrite policy.** If `{mode}` is `write` and the resolved file exists, either abort (non-interactive) or confirm overwrite (`-i`).
3. **Gather.** From the live thread, extract goal, task list, decisions, blockers, questions, todos, and open-file hints. Resolve `{workspace_roots}` defaults. Run git commands per root when `git_workspace` is included.
4. **Render.** Build the snapshot per `## Output Format` and `{format}`.
5. **Emit.** If `{mode}` is `preview`, print the snapshot once in chat inside a single fenced block labeled with `{format}`. If `{mode}` is `write`, write the file and reply with the absolute path and byte size only (one short confirmation paragraph, no full duplicate dump).

## Output Format

**Chat reply when `{mode}` is `write`**

A short markdown fragment:

- **Path:** resolved absolute `{output_path}`
- **Bytes:** integer byte length of the written file

**File body when `{format}` is `markdown`**

Use this section order and headings. Replace brace placeholders with captured values (no bare angle-bracket placeholders in the final file).

````markdown
# Session state snapshot

## Header
- **Captured at (UTC):** {iso_8601_utc}
- **Output path:** {absolute_output_path}
- **Format:** markdown

## Goal
{one_paragraph_goal}

## Thread summary
- {task_line_with_state}
- …

## Decisions
- …
_or the literal line:_ `_None recorded._`

## Blockers
- …
_or_ `_None recorded._`

## Open questions
- …
_or_ `_None recorded._`

## Todos
- …
_or_ `_None recorded._`

## Open / recent files
- {path}
- …

## Git / workspace
### {root_label}
**Shell (run in this root)**

git rev-parse --show-toplevel
git branch --show-current
git status --short --branch

**Captured output (abridged after 80 lines)**

{fenced_or_indented_git_output}

## Artifact pointers
- {transcript_or_log_path}

## Resume instructions
1. {imperative_step}
2. …
````

**File body when `{format}` is `json`**

A single JSON object. Each key mirrors an included section slug in snake_case (`header`, `goal`, `thread_summary`, `decisions`, `blockers`, `open_questions`, `todos`, `open_files`, `git_workspace`, `artifact_pointers`, `resume_instructions`). Arrays contain strings or objects as appropriate; omit keys excluded by `{include_sections}`.

Omit keys entirely when the matching entry is excluded via `{include_sections}`.

## Help

`/save-session-state <output_path>` — write markdown snapshot (default).

`/save-session-state mode=preview <output_path>` — show snapshot without writing.

`/save-session-state format=json <output_path>` — JSON snapshot.

`/save-session-state -i <output_path>` — confirm before replacing an existing file.
