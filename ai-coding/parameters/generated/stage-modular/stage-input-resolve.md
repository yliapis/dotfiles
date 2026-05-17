# Stage: `input-resolve`

## Purpose
Materialize raw user-supplied references (`file`, `directory`, `glob`, `url`, `inline`) into structured, loaded artifacts and named slots (`resolved_task`, `resolved_context`, `resolved_criteria`) that downstream stages can consume without re-fetching.

## Position
First non-validation stage. Runs before `validate`, `isolate`, `replicate`, `fan-out`, `execute`, `evaluate`. Pure read-only side effects (loads files, fetches URLs, captures inline blobs).

## Input Contract

### Required
- `input` (string | path | url | inline) — the raw user payload to resolve. Exactly one of: free text, a path, a URL, or an inline literal. At least one of `input`, `task`, or `context` MUST be present at stage entry.

### Optional
- `task` (string, default: derived from `input`) — explicit task statement; bypasses derivation from `input` when supplied directly.
- `context` (file | directory | glob | url | inline | list<…>, default: `null`) — artifact references to load alongside the task. Lists are resolved element-wise.
- `criteria` (file | directory | inline, default: `null`) — judgment/evaluation criteria reference; loaded eagerly so `evaluate` does not re-fetch.
- `format` (enum: `code` | `md` | `json` | `image` | `csv` | `binary` | `text`, default: inferred from extension/MIME) — format hint per artifact reference.
- `file_type` (file_type: e.g. `.md,.json,.py`, default: `*`) — allowed extensions when `context`/`criteria` is a directory or glob; non-matching entries are skipped (recorded in `skipped`).
- `glob` (string, default: `null`) — explicit glob pattern when `context` is a directory; ignored otherwise.
- `inline` (string, default: `null`) — inline literal content (already-loaded; bypasses fetch).
- `url_timeout` (duration, default: `30s`) — abort URL fetches that exceed this duration; records partial loads in `skipped`.
- `max_bytes_per_artifact` (int, int_range: `>= 1`, default: `1048576`) — truncate larger artifacts and flag them in `loaded_artifacts[].truncated`.

## Output Contract

- `resolved_task` (string) — the task statement after derivation/normalization; identity-mapped from `task` when supplied.
- `resolved_context` (list<artifact>) — fully loaded context artifacts. Each `artifact` is `{ ref, kind, format, bytes, content, truncated }`.
- `resolved_criteria` (list<criterion> | null) — parsed criteria; each `criterion` is `{ id, statement, source_ref }`.
- `loaded_artifacts` (list<ref>) — all references successfully materialized (used for audit / report header).
- `skipped` (list<{ ref, reason }>) — references that were not loaded (file_type filter, unreachable URL, oversized, timeout, etc.).
- `resolution_warnings` (list<string>) — non-fatal issues to surface in the final report.

## Depth-Aware Aliasing

When `input-resolve` runs again inside an inner composition (e.g., a per-candidate sub-pipeline that needs to load its own per-candidate context), parameters are qualified as `input-resolve[<depth>].<param>`:

- `input-resolve[0].context` — outer context (shared by all candidates).
- `input-resolve[1].context` — inner per-candidate context (loaded inside a `fan-out` iteration).
- Inheritance: when a key is unset at depth `d > 0`, it falls back to depth `d - 1`. Explicit `null` at depth `d` blocks inheritance.
- Outputs are likewise qualified: an inner `resolved_context` does not overwrite the outer one; both exist as `input-resolve[0].resolved_context` and `input-resolve[1].resolved_context` in the shared environment.

## Composition Rules

- Feeds: `validate` (so the validator sees concrete loaded shapes), `execute` (consumes `resolved_task`, `resolved_context`), `evaluate` (consumes `resolved_criteria`).
- Re-entry: legal at any depth; outputs are namespaced by depth.
- Idempotency: re-running with identical inputs MUST produce byte-identical `resolved_context` (modulo network responses). Implementations SHOULD cache by `(ref, etag/mtime)`.

## Examples

### Example 1: critique — load context and criteria from disk

```yaml
stage: input-resolve
input:
  context: ai-coding/plugins/ai-coding/commands/critique.md
  criteria: .cursor/commands/critique-criteria.md
  format: md
  file_type: ".md"
outputs:
  resolved_task: "Critique the file at ai-coding/.../critique.md"
  resolved_context: [{ ref: ".../critique.md", kind: file, format: md, bytes: 4096, truncated: false }]
  resolved_criteria: [{ id: c1, statement: "clarity", source_ref: ".../critique-criteria.md" }, ...]
  loaded_artifacts: [".../critique.md", ".../critique-criteria.md"]
  skipped: []
```

### Example 2: meta-prompt — derive task from raw inline input

```yaml
stage: input-resolve
input:
  input: "save this and make it a /pr-review slash command that audits a PR for security issues"
outputs:
  resolved_task: "Refine and persist a slash command that audits a PR for security issues, saved at .cursor/commands/pr-review.md"
  resolved_context: []
  resolved_criteria: null
  resolution_warnings: ["save_path inferred from save intent; confirm before persist"]
```
