# File I/O (Category B)

Covers the *shape* of inputs that parameters point to, the *format* of bytes flowing in and out, and the *write locations* where artifacts are persisted.

Under the flat angle, `format` and `save_path` are renamed by direction and by layer so each canonical name has exactly one meaning.

---

## `file`

**Aliases:** none.
**Definition:** A single filesystem path identifying one regular file. One of the five input shape variants any artifact-pointer parameter (e.g. `command_context`, `subagent_context`) may take.
**Type:** absolute or workspace-relative POSIX path string. MUST point at a regular file (not a directory).
**Default:** n/a (this is a shape, not a parameter that takes a default).
**Rename rationale (multi-depth):** none — `file` describes a shape, not a layer-specific concept.
**Consumed by:** any parameter whose value resolves to an artifact (`command_context`, `subagent_context`, `command_criteria`, `command_save_path`, `subagent_save_path`).
**Example:**

```
command_context: file:./src/auth/login.ts
```

---

## `directory`

**Aliases:** `dir`, `folder`.
**Definition:** A single filesystem path identifying one directory. The reader expands this to all regular files at the configured depth.
**Type:** absolute or workspace-relative POSIX path string. MUST point at a directory.
**Default:** n/a.
**Rename rationale (multi-depth):** none.
**Consumed by:** any artifact-pointer parameter; commonly `command_context` for directory-wide analysis.
**Example:**

```
command_context: directory:./docs/rfcs
```

---

## `glob`

**Aliases:** `pattern`.
**Definition:** A glob expression matching zero or more files; the reader expands the matches at load time.
**Type:** glob string (`**`, `*`, `?`, `[...]` per POSIX glob).
**Default:** n/a.
**Rename rationale (multi-depth):** none.
**Consumed by:** any artifact-pointer parameter; commonly used to slice `subagent_context` from `command_context`.
**Example:**

```
subagent_context: glob:./src/**/*.ts
```

---

## `url`

**Aliases:** `link`, `uri`.
**Definition:** A fully-qualified URL the reader fetches as if it were a file.
**Type:** RFC 3986 URL string with scheme `http` or `https`.
**Default:** n/a.
**Rename rationale (multi-depth):** none.
**Consumed by:** any artifact-pointer parameter where remote fetch is acceptable.
**Example:**

```
command_context: url:https://example.com/api/spec.json
```

---

## `inline`

**Aliases:** `literal`, `text`.
**Definition:** An inline string passed directly in the parameter value, with no file lookup or network fetch.
**Type:** any string. May span multiple lines.
**Default:** n/a.
**Rename rationale (multi-depth):** none.
**Consumed by:** any artifact-pointer parameter; common for `command_criteria` ad-hoc rubrics.
**Example:**

```
command_criteria: inline:"clarity, correctness, completeness, robustness"
```

---

## `input_format`

**Aliases (deprecated under this angle):** `format` (when describing the shape of incoming bytes).
**Definition:** Declared content type of bytes resolved from an artifact-pointer parameter, used by the reader to pick a parser.
**Type:** enum: `code` | `md` | `json` | `image` | `csv` | `binary` | `text`.
**Default:** auto-detected from extension; `text` when extension is unknown.
**Rename rationale (multi-depth):** the same word `format` was used for both incoming and outgoing payload shape; splitting by direction kills the ambiguity. `input_format` is always about reading; `output_format` is always about writing.
**Consumed by:** any command that reads artifacts. `critique` infers it from `command_context`.
**Example:**

```
command_context: file:./data/users.csv
input_format: csv
```

---

## `output_format`

**Aliases (deprecated under this angle):** `format` (when describing the shape of returned bytes).
**Definition:** Declared content type the command must emit as its final artifact.
**Type:** enum: `markdown` | `json` | `diff` | `report`. `report` is a structured markdown variant with named sections.
**Default:** `markdown` for analysis-style commands; `report` for `critique`-style commands; `diff` for code-edit commands.
**Rename rationale (multi-depth):** see `input_format`. Splits direction.
**Consumed by:** `critique` (`report`), `meta-prompt` (`markdown`), `worktree-task-agent` (`report` containing fenced `diff` blocks).
**Example:**

```
output_format: report
```

---

## `command_save_path`

**Aliases (deprecated under this angle):** `save_path` (when referring to the final user-facing write location).
**Definition:** Filesystem path at which the command persists its *final* artifact (typically the artifact the user will keep and reference later).
**Type:** absolute or workspace-relative POSIX path string. Parent directories are created on demand.
**Default:** when unset, the command writes nothing and returns the artifact inline in the reply.
**Rename rationale (multi-depth):** `save_path` was also used for per-slot intermediate writes in fan-out workflows; renaming by layer makes "final" vs. "intermediate" unambiguous and removes accidental overwrites where a subagent persistence stomps the command's final write.
**Consumed by:** `meta-prompt` (writes the rendered prompt body when save intent is detected); any command with an explicit `--save` mode.
**Example:**

```
command_save_path: .cursor/commands/pr-review.md
```

---

## `subagent_save_path`

**Aliases (deprecated under this angle):** `save_path` (when referring to a per-slot intermediate artifact).
**Definition:** Filesystem path at which a single subagent slot persists its *intermediate* artifact, typically under a worktree-local or run-scoped directory so slots cannot collide.
**Type:** absolute or workspace-relative POSIX path string per slot, OR a templated string with `{slot_index}` substitution.
**Default:** when unset, slots return artifacts in-memory and the orchestrator decides whether to persist them via `auto_save_winner`.
**Rename rationale (multi-depth):** keeps "what a single subagent writes" separate from "what the user keeps" so cleanup, deletion, and overwrite policies can be set differently per layer.
**Consumed by:** future `refine-best-of-n`; any fan-out that wants per-candidate artifacts on disk.
**Example:**

```
subagent_save_path: ".cursor/runs/{run_id}/candidate-{slot_index}.md"
```
