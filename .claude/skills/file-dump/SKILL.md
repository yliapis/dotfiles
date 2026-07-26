---
name: file-dump
description: "Dump ad-hoc content from the current session — an analysis, review, report, comparison, plan, or tool output — into one well-named file at the standard dump location. Use when the user asks to dump something to a file, dump this to disk, write the analysis out to a file, save the output as a file, or export content to a file without naming a destination. For session trajectories use trajectory-snapshot; for resumable session state use the save-session-state command."
license: MIT
---

# File Dump

## Task
Write the requested content — whatever the user asked to dump: an analysis, review, report, comparison, plan, or output produced in this session — to exactly one file whose name and location follow the standard dump convention: `{description}-{model}-{date}-{session}` plus an extension, saved under `{save_dir}` (default `.ai-coding-artifacts/dumps/` in the workspace root). This skill owns the naming convention; `trajectory-snapshot` follows the same convention for session-trajectory dumps.

Deferral: when the thing being dumped is the session trajectory (the ordered timeline of what happened), use the `trajectory-snapshot` skill instead; when it is resumable session state for continuing work in another chat or tool, use the `save-session-state` command.

## Parameters
- `{description}` — kebab-case slug naming the content; optional, default: derived from the user's request and the content itself (1–5 lowercase words joined by hyphens, e.g. `api-error-analysis`). MUST match `[a-z0-9]+(-[a-z0-9]+)*`.
- `{save_dir}` — directory the dump is written into; optional, default: `.ai-coding-artifacts/dumps/`, resolved relative to the current workspace root (MAY be an absolute path). An explicit directory or full path in the user's request overrides the default.
- `{filename_format}` — filename template; optional, default: `{description}-{model}-{date}-{session}.md`. Field order in the default is exactly description, model, date, session. The default renders like `api-error-analysis-claude-4.5-opus-2026-07-12T21-04-30Z-a1b2c3d4.md`. When the content is natively a non-markdown format (JSON, YAML, CSV, JSONL, patch, plain log text), the `.md` extension is replaced by the content's native extension. When the user supplies an explicit filename, it is used as given and no tokens are imposed on it.
- `{model}` — slug of the model powering this agent session (e.g. `claude-4.5-opus`, `gpt-5.2`); optional, default: auto-detected from the session's own metadata or system context, normalized to lowercase with spaces and slashes replaced by hyphens (dots are kept); `unknown-model` when undeterminable.
- `{date}` — filesystem-safe UTC timestamp from `date -u +%Y-%m-%dT%H-%M-%SZ` (e.g. `2026-07-12T21-04-30Z`); not user-set.
- `{session}` — first 8 characters of the current session id; optional, default: auto-detected from the tool's transcript location — Cursor: `~/.cursor/projects/<workspace-slug>/agent-transcripts/<session-id>/`; Claude Code: `~/.claude/projects/<munged-cwd>/<session-id>.jsonl`; when the id is unknown, the most recently modified transcript in that directory is the current session (it is being appended live); `unknown` when undeterminable.

## Success Criteria
- [ ] Parameters resolve to explicit or default values before any write; a resolved `{description}` that does not match `[a-z0-9]+(-[a-z0-9]+)*` aborts with an explanatory error and no filesystem side effects.
- [ ] The dump exists at the absolute path resolved from `{save_dir}` plus the rendered `{filename_format}` against the workspace root, parent directories created as needed, and is non-empty.
- [ ] The filename is rendered with all tokens substituted; no unresolved `{…}` tokens remain; undeterminable `{model}` / `{session}` render as `unknown-model` / `unknown` rather than being omitted.
- [ ] No pre-existing file is overwritten: on collision, a `-2` (then `-3`, …) suffix is appended before the extension.
- [ ] An explicit path or filename in the user's request wins over the convention: it is used as given (resolved against the workspace root when relative), and only the collision rule still applies.
- [ ] Markdown dumps open with the provenance header from Output Format; non-markdown dumps contain the content raw with no header or wrapper.
- [ ] The dumped content is exactly what was asked for — nothing fabricated, nothing silently truncated.
- [ ] Secrets that appeared in the session (tokens, private keys, `.env` contents, `password=` / `Authorization:`-style literals) appear in the dump only as `<redacted>`.
- [ ] The chat reply is a one-line confirmation with the absolute dump path; the file body is not duplicated into chat.

## Guardrails
- MUST NOT overwrite any existing file; resolve collisions with numeric suffixes.
- MUST create missing parent directories for the resolved output path.
- MUST honor an explicit user-supplied path or filename over every convention default.
- MUST NOT fabricate content: the dump contains what the session actually produced; unknown facts are recorded as `unknown`, not invented.
- MUST NOT inline secrets; redact with `<redacted>`.
- MUST NOT commit, push, or modify any file other than the dump file itself (including `.gitignore` — leave untracked dumps untracked).
- Scope: write one requested dump file. Out of scope: session trajectories (use `trajectory-snapshot`), resumable session state (use `save-session-state`), uploading artifacts anywhere.

## Workflow
1. Classify the request: session trajectory → `trajectory-snapshot`; resumable session state → `save-session-state`; anything else continues here.
2. Resolve `{description}`: take the user's slug when given; otherwise derive a 1–5-word kebab-case slug from the request and content; abort if the resolved value fails the slug pattern.
3. Detect `{model}` from the session's own metadata or system context and normalize it; detect `{session}` from the transcript location; take `{date}` from `date -u +%Y-%m-%dT%H-%M-%SZ`; fall back to `unknown-model` / `unknown` rather than guessing.
4. Pick the extension: `.md` for markdown or prose content; the content's native extension otherwise.
5. Render the filename from `{filename_format}`; resolve it against `{save_dir}` (or the user's explicit path) into an absolute path; create missing parent directories; on collision append `-2`, `-3`, … before the extension until the name is free.
6. Write the file: provenance header plus content for markdown dumps, raw content otherwise; redact secrets.
7. Reply with the one-line confirmation.

## Output Format

**Chat reply** — one line: `Dump written: <absolute path> (<bytes> bytes)`.

**File when the dump is markdown** — provenance header, then the content:

````markdown
# {Human-readable title of the dump}

- **Description:** {description}
- **Model:** {model}
- **Captured at (UTC):** {iso_8601_utc}
- **Session:** {session_id_or_unknown}

---

{content}
````

**File when the dump is not markdown** — the content exactly as produced, in its native format; no header, wrapper, or commentary.
