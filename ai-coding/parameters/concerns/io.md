# I/O

How inputs are addressed and where outputs land. Input-side parameters
(`context`, `criteria`, `worklist`) accept several addressing forms;
output-side parameters name destination paths. Whether a write may be skipped
or previewed is a lifecycle concern — see the
[write gate family](lifecycle.md#write_gate-family) — as is what happens when
the target already exists
([overwrite postures](lifecycle.md#overwrite-postures)).

## Addressing forms

Vocabulary shared by every parameter that accepts "an artifact reference":

- **file** — a single file path; read whole.
- **directory** — a directory path; contents enumerated and read.
- **url** — fetched at resolution time.
- **inline** — literal text supplied in the invocation itself.

Consumers resolve the form at the start of the workflow and record what was
loaded and what was skipped or unreachable. Not every parameter accepts every
form; each declaring artifact lists its accepted subset (e.g. critique's
`{criteria}` accepts file | directory | inline but not url).

## Cards

### `artifact_path`
- **Aliases:** `save_path` (meta-prompt), `output_path` (save-session-state), `artifact_path` (designer, design-skill)
- **Applies to:** command, skill
- **Type:** file path (repo-relative in the design skills; absolute or workspace-relative in save-session-state)
- **Default:** artifact-specific — meta-prompt: `.cursor/commands/<kebab-name>.md` when save intent is detected, else unset; designer: `schemas/<kebab-target>.md`, plus per-round snapshots under `<artifact_path>.snapshots/`; design-skill: `ai-coding/plugins/design-suite/skills/designer/traits/<trait_name>.md`; save-session-state: required, no default
- **Meaning:** The destination file where the run persists its primary
  artifact (a generated prompt, a design deliverable, a session snapshot).
- **Validation:** whether the write actually happens is controlled by the
  [write gate family](lifecycle.md#write_gate-family); the design skills
  reject `artifact_path` when `persistence=chat`.
- **Propagation:** meta-prompt fan-out rewrites the path per variant, appending
  `-<i>` before the file extension. See [propagation.md](../propagation.md).
- **Used by:** meta-prompt, save-session-state, designer, design-skill

## Artifact-specific

- `{format}` (save-session-state) — snapshot serialization format:
  `markdown` | `json`. Default `markdown`.
- `{workspace_roots}` (save-session-state) — explicit list of repository or
  workspace roots for the Git / workspace section. Default: active workspace
  roots, else the root implied by `{output_path}`.
- `{transcript_paths}` (save-session-state) — transcript or log paths to cite
  in Artifact pointers (paths only, never inlined). Default: empty.
- `{include_sections}` (save-session-state) — ordered subset of the documented
  section slugs; omitted sections must not appear in the output. Default: all
  sections in documented order.
- `{archive_root}` (wrap-up) — root directory for category archives. Default:
  `ai-coding/samples/`.
- `{event_log_path}` (wrap-up) — where the JSONL event log is persisted;
  events are always also emitted inline. Default:
  `.ai-coding-artifacts/wrap-up/<utc-iso-timestamp>.jsonl`.
- `{trajectory_path}` (wrap-up) — session trajectory log path. Default:
  `.ai-coding-artifacts/trajectories/<utc-iso-timestamp>.jsonl`.
- `{learnings_path}` (wrap-up) — session learnings note path. Default:
  `.ai-coding-artifacts/learnings/<utc-iso-timestamp>.md`.
- `{filename_format}` (trajectory-snapshot) — snapshot output path *template*:
  an output-path concept adjacent to the [`artifact_path`](#artifact_path)
  family, but in an addressing form the vocabulary above does not cover — the
  path is rendered by substituting `{coding_tool}` and `{datetime_timestamp}`
  tokens, then resolved against the workspace root. Default:
  `{coding_tool}-snapshot-{datetime_timestamp}.md`; when
  [`{granularity}`](reporting.md#trajectory-snapshot) is
  `native`, the `.md` extension is swapped for the native transcript's
  extension. Collisions never overwrite: a `-2` (then `-3`, …) suffix is
  appended before the extension — a third suffix semantics, distinct from the
  fan-out index `-<i>` on [`worktree_name`](isolation.md#worktree_name) and on
  meta-prompt's rewritten [`artifact_path`](#artifact_path), and a third
  overwrite posture (see
  [lifecycle.md](lifecycle.md#overwrite-postures)).
- `{coding_tool}` (trajectory-snapshot) — tool slug substituted into
  `{filename_format}` and used to locate the native transcript. Default:
  auto-detected — `cursor` when the session transcript lives under
  `~/.cursor/projects/`, `claude-code` when under `~/.claude/projects/`, else
  `agent`.
- `{granularity}` (ticket-create) — ticket splitting policy: closed enum
  `one-to-one` | `split-composites` | `theme-grouped`. Default
  `split-composites`. A different concept from trajectory-snapshot's
  [`{granularity}`](reporting.md#trajectory-snapshot) under the same spelling:
  there it sets the detail level of one rendered artifact, here it sets how
  extracted work items map to tickets (split composite items, merge same-theme
  items), so it stays an io concern.
- `{id_prefix}` (ticket-create) — prefix for rendered ticket ids
  (`{id_prefix}-NNN`, zero-padded). Default `TKT`. Validation:
  `^[A-Z][A-Z0-9]{1,9}$`.
- `{output_dir}` (ticket-create) — directory the ticket files and
  `WORKLIST.md` land in; a directory-valued sibling of the
  [`artifact_path`](#artifact_path) family. Default:
  `.ai-coding-artifacts/tickets/<source-slug>/` resolved against the workspace
  root. `{on_existing}` controls deterministic reuse, failure, or a
  ticket-set-hash suffix; numeric suffixes are forbidden (see
  [overwrite postures](lifecycle.md#overwrite-postures)).
