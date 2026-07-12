---
name: trajectory-snapshot
description: "Snapshot the current agent session's trajectory into a file at a chosen granularity — verbatim replay, condensed per-turn bullets, summary narrative, or a lossless copy of the tool's native session transcript. Use when the user asks to snapshot this session, save or export the trajectory, dump the conversation to markdown, export the raw session transcript, or capture the session timeline before wrapping up."
license: MIT
---

# Trajectory Snapshot

## Task
Write the current agent session's trajectory — the ordered timeline of user messages, assistant responses, and tool activity — to one snapshot file at the path resolved from `{filename_format}`, at the detail level selected by `{granularity}`. Rendered granularities (`verbatim`, `condensed`, `summary`) produce markdown; `native` produces a byte-identical copy of the tool's own session transcript so session management stays lossless.

Complements the `save-session-state` command: that captures resumable *state*; this skill captures the *trajectory* (what happened, in order).

## Parameters
- `{filename_format}` — output path template; optional, default: `{coding_tool}-snapshot-{datetime_timestamp}.md`, resolved relative to the current workspace root (MAY include directory components or an absolute path). Recognized tokens: `{coding_tool}` (resolved tool slug) and `{datetime_timestamp}` (filesystem-safe UTC from `date -u +%Y-%m-%dT%H-%M-%SZ`, e.g. `2026-07-04T07-25-30Z`). The default renders like `cursor-snapshot-2026-07-04T07-25-30Z.md`. When `{granularity}` is `native`, the `.md` extension is replaced by the native transcript's extension (e.g. `.jsonl`).
- `{granularity}` — detail level; optional, default: `summary`. Allowed values:
  - `verbatim` — full turn-by-turn replay: user messages and assistant responses verbatim, every tool call with its parameters and output. Any single tool output longer than ~200 lines is truncated with an explicit `... (truncated, K lines omitted)` marker.
  - `condensed` — user messages verbatim; assistant work and tool activity compressed to per-turn bullets (action — target — outcome).
  - `summary` — high-level narrative: goal, timeline of major phases, key decisions, files touched, outcomes, open questions.
  - `native` — the tool's own session transcript, copied byte-identically (e.g. the Cursor or Claude Code session `.jsonl`), so nothing is lost to rendering and the file can be re-ingested by the tool's session management. No truncation, reformatting, or redaction is applied; when the native transcript cannot be located, abort with an explanatory error rather than write a lossy reconstruction.
- `{coding_tool}` — tool slug for the filename template; optional, default: auto-detected — `cursor` when the session transcript lives under `~/.cursor/projects/`, `claude-code` when under `~/.claude/projects/`, else `agent`.

## Success Criteria
- [ ] Parameters resolve to explicit or default values before any write; an unrecognized `{granularity}` aborts with an explanatory error and no filesystem side effects.
- [ ] The snapshot exists at the absolute path resolved from `{filename_format}` against the workspace root, parent directories created as needed, and is non-empty.
- [ ] The path is rendered from `{filename_format}` with `{coding_tool}` and `{datetime_timestamp}` substituted; no unresolved `{…}` tokens remain in the final path.
- [ ] No pre-existing file is overwritten: on collision, a `-2` (then `-3`, …) suffix is appended before the extension.
- [ ] For rendered granularities, the file header records coding tool, session id (or `unknown`), UTC ISO-8601 capture time, granularity, and source (raw transcript path, or `in-context reconstruction`).
- [ ] The body matches the `{granularity}` contract: verbatim replay, condensed per-turn bullets, summary narrative, or byte-identical native copy.
- [ ] For `verbatim`, when the on-disk transcript is locatable it is used as the source and its absolute path is cited in the header; when it is not, the header says `in-context reconstruction` and notes that earlier turns may be compacted.
- [ ] For `native`, the written snapshot is byte-identical to the located native transcript (`cmp` exits `0`); when no native transcript can be located, the workflow aborts with an explanatory error and no writes.
- [ ] Secrets that appeared in the session (tokens, private keys, `.env` contents, `password=` / `Authorization:`-style literals) appear in rendered snapshots only as `<redacted>`; a `native` copy is exempt because it is byte-identical by contract.
- [ ] The chat reply is a one-line confirmation with the absolute snapshot path; the file body is not duplicated into chat.

## Guardrails
- MUST NOT overwrite any existing file; resolve collisions with numeric suffixes.
- MUST create missing parent directories for the resolved output path.
- MUST NOT fabricate trajectory content: every turn, tool call, and outcome in the snapshot corresponds to something that actually happened in this session; unknown facts are recorded as `unknown`, not invented.
- MUST NOT inline secrets in rendered snapshots; redact with `<redacted>`.
- MUST NOT truncate, reformat, or redact a `native` copy — losslessness takes precedence; treat the copy with the same sensitivity as the original transcript.
- MUST NOT commit, push, or modify any file other than the snapshot file itself.
- Scope: capture the current session's trajectory into one snapshot file. Out of scope: multi-session exports, resumable-state capture (use `save-session-state`), uploading artifacts anywhere.

## Workflow
1. Resolve parameters to explicit or default values; abort before any write if `{granularity}` is not `verbatim`, `condensed`, `summary`, or `native`.
2. Detect `{coding_tool}` when not provided: `cursor` if a project transcript dir `~/.cursor/projects/<workspace-slug>/agent-transcripts/` exists for this workspace, `claude-code` if `~/.claude/projects/<munged-cwd>/` exists, else `agent`.
3. Render the output path from `{filename_format}` using `{coding_tool}` and `date -u +%Y-%m-%dT%H-%M-%SZ`; for `native`, swap the `.md` extension for the native transcript's extension.
4. Resolve the rendered path to an absolute path against the workspace root; create missing parent directories; on collision append `-2`, `-3`, … before the extension until the name is free.
5. Locate the raw transcript for this session when possible — Cursor: `~/.cursor/projects/<workspace-slug>/agent-transcripts/<session-id>/<session-id>.jsonl`; Claude Code: `~/.claude/projects/<munged-cwd>/<session-id>.jsonl`. When the session id is unknown, take the most recently modified transcript in that directory as the current session (it is being appended live). For `native`, a locatable transcript is required; abort with an explanatory error when none is found.
6. Build the body per the `{granularity}` contract in Output Format. For `verbatim`, prefer the on-disk transcript as the source, transforming it to markdown with a script (e.g. `jq` or a short Python one-liner) rather than re-emitting the whole transcript through the model; fall back to in-context reconstruction and mark it in the header. For `native`, skip rendering entirely: copy the transcript byte-identically and verify the copy with `cmp`.
7. For rendered granularities, redact secrets and write the file (the `native` copy was already written in step 6); reply with the one-line confirmation.

## Output Format

**Chat reply** — one line: `Snapshot written: <absolute path> (<bytes> bytes)`.

**File when `{granularity}` is `native`** — a byte-identical copy of the tool's session transcript in its native format (e.g. `.jsonl`); no markdown header, wrapper, or redaction is added. The sections below apply to the rendered granularities only.

**File header (rendered granularities)**

````markdown
# Session trajectory snapshot

- **Coding tool:** {coding_tool}
- **Session id:** {session_id_or_unknown}
- **Captured at (UTC):** {iso_8601_utc}
- **Granularity:** {granularity}
- **Source:** {absolute_transcript_path_or_in_context_reconstruction}
````

**Body when `{granularity}` is `verbatim`** — one section per turn, in order:

````markdown
## Turn {n} — user
{verbatim user message}

## Turn {n} — assistant
{verbatim assistant text}

### Tool call: {tool_name}
**Parameters**
```json
{parameters}
```
**Output**
```
{output, truncated above ~200 lines with an explicit `... (truncated, K lines omitted)` marker}
```
````

**Body when `{granularity}` is `condensed`** — same turn sections; user messages verbatim, each assistant turn as bullets:

````markdown
## Turn {n} — user
{verbatim user message}

## Turn {n} — assistant
- {action — target — outcome}
- …
````

**Body when `{granularity}` is `summary`**

````markdown
## Goal
{one_short_paragraph}

## Timeline
- {one bullet per major phase, in order}

## Key decisions
- …
_or_ `_None recorded._`

## Files touched
- {path} — {one-line what and why}

## Outcomes
- {what was delivered or verified}

## Open questions
- …
_or_ `_None recorded._`
````
