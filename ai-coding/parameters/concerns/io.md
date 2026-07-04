# I/O

How inputs are addressed and where outputs land. Input-side parameters
(`context`, `criteria`, `worklist`) accept several addressing forms; output-side
parameters name destination paths whose writes are gated by the
[write gate family](lifecycle.md#write_gate-family).

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
- **Aliases:** `save_path` (meta-prompt), `output_path` (save-session-state), `artifact_path` (ralph-design, design-skill, designer-controller)
- **Applies to:** command, skill
- **Type:** file path (repo-relative in the design skills; absolute or workspace-relative in save-session-state)
- **Default:** artifact-specific — meta-prompt: `.cursor/commands/<kebab-name>.md` when save intent is detected, else unset; ralph-design: `schemas/<kebab-domain>.md`; design-skill: `.cursor/skills/<trait_name>-design/SKILL.md`; designer-controller: `schemas/<kebab-target>.md`; save-session-state: required, no default
- **Meaning:** The destination file where the run persists its primary
  artifact (a generated prompt, a design deliverable, a session snapshot).
- **Validation:** whether the write actually happens is controlled by the
  [write gate family](lifecycle.md#write_gate-family); the design skills
  reject `artifact_path` when `persistence=chat`.
- **Propagation:** meta-prompt fan-out rewrites the path per variant, appending
  `-<i>` before the file extension. See [propagation.md](../propagation.md).
- **Used by:** meta-prompt, save-session-state, ralph-design, design-skill, designer-controller

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
