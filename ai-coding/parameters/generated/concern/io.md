# Concern: File I/O

> **Responsibility:** Resolve the *bytes in* (where the agent reads from) and the *bytes out* (where the agent writes to). I/O is the data plumbing; what those bytes *mean* belongs to other concerns (`task`, `criteria`, etc.).
>
> **Primary parameters:** `file`, `directory`, `glob`, `url`, `inline`, `format`, `save_path`, `output_format`

## Why this concern exists

Every command that takes a `context` or produces an artifact needs to resolve abstract handles ("the auth file", "the criteria", "the rendered report") into concrete bytes. We separate this from the Task concern because:

- The same `context` may be resolved from any of five sources (`file`, `directory`, `glob`, `url`, `inline`) and the resolution rules are identical regardless of *what verb* the command is running.
- The same `task` may need to write to different destinations (`save_path`) or render in different shapes (`output_format`) depending on the user's intent, not the task itself.

Grouping these together gives every prompt one place to look for "how do I declare input/output mechanics?".

## Parameters

### `file`

**Aliases:** `path`
**Definition:** A single filesystem path the agent reads (or, if used as a destination, writes).
**Type:** `string` — absolute or workspace-relative path; must point to a regular file when used as input.
**Default:** N/A — used as a *value shape* for `context`, `criteria`, `save_path`, etc.

**Cross-refs:**

- [`context` (task.md)](./task.md#context) — `file` is one resolver for `context`.
- [`file_type` (constraints.md)](./constraints.md#file_type) — restriction on accepted extensions.

**Example:** `/critique context=./README.md` — `context` resolves via the `file` resolver.

---

### `directory`

**Aliases:** `dir`
**Definition:** A single filesystem directory the agent walks (recursively unless `glob` narrows it).
**Type:** `string` — absolute or workspace-relative path; must point to a directory when used as input.
**Default:** N/A — used as a *value shape*.

**Cross-refs:**

- [`context` (task.md)](./task.md#context) — `directory` is one resolver.
- [`glob` (this file)](#glob) — narrows the walk.
- [`file_type` (constraints.md)](./constraints.md#file_type) — extension filter applied during the walk.

**Example:** `/critique context=./src/auth/` — the directory is walked; `file_type` (if set) trims which files are read.

---

### `glob`

**Aliases:** `pattern`
**Definition:** A glob pattern (POSIX-style with `**` for recursion) that enumerates files matching a path expression.
**Type:** `string` — e.g. `src/**/*.ts`, `docs/*.md`.
**Default:** N/A — used as a *value shape* or as a narrowing modifier on `directory`.

**Cross-refs:**

- [`context` (task.md)](./task.md#context) — `glob` is one resolver.
- [`directory` (this file)](#directory) — `glob` may be relative to a `directory` root.
- [`file_type` (constraints.md)](./constraints.md#file_type) — `file_type` is enforced *after* the glob expands.

**Example:** `/critique context='src/**/*.py'` — the glob expands, `file_type ∈ {.py}` filters the result.

---

### `url`

**Aliases:** `link`, `href`
**Definition:** A fetchable HTTP(S) URL the agent reads via web fetch.
**Type:** `string` — must parse as an absolute URL with scheme `http` or `https`.
**Default:** N/A — used as a *value shape*.

**Cross-refs:**

- [`context` (task.md)](./task.md#context) — `url` is one resolver.
- [`format` (this file)](#format) — content-type-derived format inference applies.

**Example:** `/critique context=https://example.com/spec.md` — fetched via web fetch; `format=md` inferred from `.md` and content-type.

---

### `inline`

**Aliases:** `literal`, `blob`
**Definition:** Content supplied verbatim inside the command invocation (no path or URL lookup).
**Type:** `string` (any length).
**Default:** N/A — used as a *value shape*.

**Cross-refs:**

- [`context` (task.md)](./task.md#context) — `inline` is one resolver.
- [`input` (task.md)](./task.md#input) — `input` is conceptually an `inline` resolver for the user text itself.

**Example:** `/critique context='```py\ndef f(x): return x+1\n```' criteria=correctness` — the python snippet is supplied inline.

---

### `format`

**Aliases:** `content_type`, `mime`
**Definition:** The semantic category of the bytes being read or written, used by downstream concerns to choose parsers / renderers.
**Type:** Enum: `code | md | json | image | csv | binary | text`. May be sub-typed (e.g. `code:python`).
**Default:** Inferred from extension or content-type; otherwise `text`.

**Cross-refs:**

- [`file` / `directory` / `glob` / `url` / `inline` (this file)](#file) — `format` annotates whatever was resolved.
- [`file_type` (constraints.md)](./constraints.md#file_type) — `file_type` constrains *which extensions* are accepted; `format` describes *how to interpret* what was accepted.
- [`output_format` (this file)](#output_format) — the *output* counterpart.

**Example:** `/critique context=./data.csv format=csv criteria=schema-conformance` — CSV parsing is used to validate schema.

---

### `save_path`

**Aliases:** `out`, `output_path`, `destination`
**Definition:** A filesystem path where the agent persists its primary artifact at the end of the run.
**Type:** `string` — absolute or workspace-relative path; parent directories may need to be created.
**Default:** Unset (no file is written) unless save intent is detected from `input` or another signal.

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | Optional; when set, the rendered artifact is written there. When unset, the artifact is returned only as chat output. `/meta-prompt` *infers* `save_path` from `input` ("save this as /foo"). |
| **subagent** | Each child's `save_path` is namespaced into the child's workspace (e.g. into its worktree) to prevent collisions. The parent's `save_path` is the *final* destination after selection / merge. |
| **skill** | Skills do not own `save_path`; they reference it when their workflow includes persistence (e.g. a "render report" skill writes to `save_path` if provided). |

**Cross-refs:**

- [`input` (task.md)](./task.md#input) — `save_path` may be inferred from `input`.
- [`auto_save_winner` (lifecycle.md)](./lifecycle.md#auto_save_winner) — the policy that promotes a winning candidate to `save_path`.
- [`output_format` (this file)](#output_format) — determines the serialization written to `save_path`.

**Example:** `/meta-prompt save as /pr-review: review a PR for security issues` → `save_path=.cursor/commands/pr-review.md` (inferred), written when the prompt is rendered.

---

### `output_format`

**Aliases:** `render_as`
**Definition:** The serialization shape of the agent's primary response (and of any file written to `save_path`).
**Type:** Enum: `markdown | json | diff | plain | structured`. May carry sub-options (e.g. `json:pretty`, `markdown:gfm`).
**Default:** `markdown`.

**Cross-refs:**

- [`save_path` (this file)](#save_path) — the file at `save_path` is serialized using `output_format`.
- [`verbosity` (reporting.md)](./reporting.md#verbosity) — affects depth, not shape; orthogonal to `output_format`.
- [`require_diff` (reporting.md)](./reporting.md#require_diff) — implies `output_format` includes a diff section.

**Example:** `/critique context=./src/auth.py output_format=json` — emits findings as a JSON array instead of the default markdown report.
