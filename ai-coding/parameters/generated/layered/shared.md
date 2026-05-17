# `shared.*` — Primitive Value Types and Addressing Forms

The `shared.*` namespace holds value-level building blocks that any other layer (`command.*`, `subagent.*`, `skill.*`) can compose with its domain parameters. **Shared definitions never carry orchestration semantics on their own**: they describe shapes and validation, not what a parameter *means* in a given layer. When a layer parameter says "type: `shared.int_range >= 1`", the layer file owns the meaning; this file owns the formalism.

This file is also the canonical home for *cross-cutting primitives that would otherwise be redefined per layer* (e.g., the addressing union used wherever a file/dir/url/inline blob can appear).

> **Reading order.** Read this file first when you encounter a layer parameter whose `Type` cell references `shared.*`. Then read `cross-layer.md` for inheritance / shadowing rules that bind layer parameters with the same root name.

---

## Conventions

- Names use lowercase with underscores. Multi-word primitives use snake_case (e.g., `shared.int_range`).
- A type spec written `T?` means "T or unset".
- A type spec written `T | U` is a tagged union; the layer parameter that uses it MUST document which variant it accepts.
- A type spec written `list<T>` is an ordered, possibly-empty list whose elements all satisfy `T`.
- Numeric ranges use math interval notation: `[a, b]` (closed), `(a, b)` (open), `[a, ∞)` (half-open), etc.

---

## Index of `shared.*` parameters

| Name | Kind | One-liner |
| --- | --- | --- |
| `shared.int_range` | formalism | Spec for an integer domain (e.g. `>= 1`, `[1, 8]`). |
| `shared.float_range` | formalism | Spec for a float / real domain with optional precision. |
| `shared.enum` | formalism | Closed set of allowed literal values. |
| `shared.duration` | value type | A time interval (e.g., `30s`, `5m`, `2h`). |
| `shared.file_type` | formalism | Restriction on accepted file extensions / MIME / language. |
| `shared.path` | value type | A repo- or absolute-path string referring to a file or directory. |
| `shared.file` | value type | A `shared.path` constrained to point at a regular file. |
| `shared.directory` | value type | A `shared.path` constrained to point at a directory. |
| `shared.glob` | value type | A glob pattern resolved against the active working tree. |
| `shared.url` | value type | A fully-qualified URL accepted by `WebFetch`-class tools. |
| `shared.inline` | value type | A literal in-message blob (text/markdown/code). |
| `shared.addressable` | tagged union | Any of `file` \| `directory` \| `glob` \| `url` \| `inline`. |
| `shared.format` | enum | Content kind: `code` \| `md` \| `json` \| `image` \| `csv` \| `binary` \| `text`. |
| `shared.output_format` | value type | A rendering contract for emitted artifacts (`markdown`, `diff`, `json-schema:…`). |
| `shared.commit_ish` | value type | Any commit-ish git accepts (branch, tag, SHA, `origin/main`, `HEAD~3`). |
| `shared.branch_ref` | value type | A `commit_ish` constrained to resolve to a branch tip. |
| `shared.model_id` | value type | A model identifier string accepted by the agent runtime. |
| `shared.seed` | value type | An integer RNG seed for determinism-friendly runs. |
| `shared.temperature` | value type | A non-negative real used as sampling temperature. |
| `shared.severity` | enum | A finding's severity: `critical` \| `major` \| `minor` \| `nit`. |
| `shared.exit_code` | value type | An integer process exit code; `0` denotes success. |
| `shared.shell_command` | value type | A string interpretable by the active shell. |
| `shared.boolean` | value type | `true` \| `false`. |
| `shared.policy_string` | value type | A short controlled-vocabulary string keyed by the consuming layer. |
| `shared.list_or_scalar<T>` | tagged union | `T` (broadcast) \| `list<T>` (zip-positional). |

---

## Formalisms

### `shared.int_range`

**Definition.** A constraint shape used to validate an integer parameter's domain. Written as one of: `>= n`, `<= n`, `> n`, `< n`, `[a, b]`, `(a, b)`, `[a, ∞)`, `(-∞, b]`, or a finite set like `{1, 2, 4, 8}`.

**Cross-layer notes.** Used by every integer parameter, including `command.parallel`, `command.num_partitions`, `command.num_experiments`, `command.n_candidates`, `command.depth`, `command.fan_out`, `command.min_successes`, `subagent.parallel`, etc. Each consuming layer parameter MUST cite its `shared.int_range` in its own `Type` cell.

**Type.** Formalism, not a value. Validators accept the shorthand strings above and reject inputs outside the closed/open bounds.

**Default.** No default; range is parameter-specific.

**Examples.**
```text
command.parallel : int with shared.int_range >= 1
command.num_partitions : int with shared.int_range >= 1
subagent.retry_policy.max_retries : int with shared.int_range [0, 5]
```

---

### `shared.float_range`

**Definition.** Same as `shared.int_range` but for real-valued parameters, optionally annotated with precision (e.g., `[0.0, 2.0] step 0.1`).

**Cross-layer notes.** Primary consumers: `command.temperature`, `subagent.temperature`, anything sampling-related.

**Type.** Formalism.

**Default.** None.

**Examples.**
```text
command.temperature : float with shared.float_range [0.0, 2.0]
```

---

### `shared.enum`

**Definition.** A closed set of allowed literal string values. Written as `{a, b, c}` or as a named enum like `shared.severity`.

**Cross-layer notes.** Named enums in this file (e.g. `shared.format`, `shared.severity`) are themselves first-class `shared.*` parameters; ad-hoc enums embedded in a layer parameter (e.g. `command.merge_mode`'s allowed values) cite this formalism.

**Type.** Formalism.

**Default.** None.

**Examples.**
```text
command.merge_mode : shared.enum {interactive, auto}
command.selection_mode : shared.enum {manual, auto-best, synthesize, tournament}
```

---

### `shared.duration`

**Definition.** A time interval, written as a positive number followed by a unit suffix: `ms`, `s`, `m`, `h`, `d`. Examples: `500ms`, `30s`, `5m`, `2h`.

**Cross-layer notes.** Used by `command.timeout`, `command.relaunch_on_hang_after`, `subagent.timeout`, retry-policy backoff fields.

**Type.** Value type; parsed to a non-negative duration.

**Default.** None.

**Examples.**
```text
command.timeout : shared.duration   # e.g. "30m"
command.relaunch_on_hang_after : shared.duration   # e.g. "90s"
```

---

### `shared.file_type`

**Definition.** A restriction on which file extensions / languages a parameter accepts. Written as a list of extensions (`[".md", ".json"]`), MIME types (`["text/markdown"]`), or named language tags (`["python", "shell"]`). The consuming layer parameter MUST state how multiple entries combine (union vs. exclusive).

**Cross-layer notes.** Used by `command.test_command` (when scoped to specific files), `command.criteria` (when criteria are loaded from files), `skill.file_type` (when a skill activates only for certain files).

**Type.** Formalism.

**Default.** None; absence means "no restriction".

**Examples.**
```text
skill.file_type : shared.file_type [".md", ".mdx"]
command.criteria.source.file_type : shared.file_type [".md", ".yaml"]
```

---

## Addressing primitives

### `shared.path`

**Definition.** A path string referring to a file or directory. May be repo-relative (preferred for inputs) or absolute (preferred for outputs and tool outputs). Trailing slashes are not significant; the consuming parameter resolves the path against the appropriate working tree.

**Cross-layer notes.** Parent type of `shared.file` and `shared.directory`. Used directly when a parameter accepts either. The active working tree is `subagent.worktree_path` inside a subagent and `command.worktree_root`-relative outside.

**Type.** `string`.

**Default.** None.

**Example.**
```text
command.save_path : shared.path   # e.g. "results/critique.md"
```

---

### `shared.file`

**Definition.** A `shared.path` that MUST resolve to a regular file (not a directory, symlink loop, or socket).

**Cross-layer notes.** Used by every layer parameter that takes a single file address — `command.context` (when given a file), `command.criteria` (when given a file), `subagent.save_path`, `skill.references[]`.

**Type.** `shared.path` + file-kind constraint.

**Default.** None.

**Example.**
```text
command.criteria : shared.file   # e.g. "./.cursor/rubrics/security.md"
```

---

### `shared.directory`

**Definition.** A `shared.path` that MUST resolve to a directory; consumers typically recurse into it.

**Cross-layer notes.** Used by `command.context` (when given a directory of artifacts), `command.worktree_root`, `skill.references[]` (when a skill bundles a whole references/ folder).

**Type.** `shared.path` + dir-kind constraint.

**Default.** None.

**Example.**
```text
command.worktree_root : shared.directory   # e.g. "~/.cursor/worktrees/<id>"
```

---

### `shared.glob`

**Definition.** A glob pattern interpreted by the standard recursive matcher (`**`, `*`, `?`, `[…]`). Patterns NOT starting with `**/` are auto-prefixed with `**/` to enable recursive matching.

**Cross-layer notes.** Used by `command.context` (when given a glob), `skill.applies_to` (when a skill auto-activates on certain file patterns).

**Type.** `string` (glob pattern).

**Default.** None.

**Example.**
```text
command.context : shared.glob   # e.g. "**/*.py"
```

---

### `shared.url`

**Definition.** A fully-qualified URL acceptable to a fetch tool (`http://`, `https://`, or scheme explicitly supported by the runtime).

**Cross-layer notes.** Used by `command.context` (when given a URL).

**Type.** `string` (URL).

**Default.** None.

**Example.**
```text
command.context : shared.url   # e.g. "https://example.com/rfc.html"
```

---

### `shared.inline`

**Definition.** A literal in-message blob — text, markdown, code, or any other content the user pasted directly into the invocation. Consumers MUST NOT attempt to resolve `shared.inline` to a path.

**Cross-layer notes.** Used by `command.context`, `command.criteria`, `command.input`, `skill.task` (the activation description is itself `shared.inline`).

**Type.** `string` (raw blob).

**Default.** None.

**Example.**
```text
command.criteria : shared.inline   # e.g. "must compile, must not regress benchmarks"
```

---

### `shared.addressable`

**Definition.** Tagged union covering every way a layer parameter can accept content: `shared.file | shared.directory | shared.glob | shared.url | shared.inline`. Consumers MUST be able to distinguish which variant was supplied (typically by string inspection: leading `./` / `/` / `~` for paths, `http(s)://` for URLs, glob metacharacters for globs, anything else for inline).

**Cross-layer notes.** This is the canonical type for `command.context`, `command.criteria`, `command.aggregator` (when the aggregator is itself an artifact reference), `skill.references[]`.

**Type.** `shared.file | shared.directory | shared.glob | shared.url | shared.inline`.

**Default.** None.

**Example.**
```text
command.context : shared.addressable   # any of the five variants
```

---

## Content / format primitives

### `shared.format`

**Definition.** A content-kind enum: `code | md | json | image | csv | binary | text`. Used to tag what kind of content a parameter holds when the addressing variant alone is insufficient (e.g., an `inline` blob whose syntactic kind matters).

**Cross-layer notes.** Used by `command.context.format`, `command.output_format` (as the *kind* component of a richer rendering contract), `skill.input.format`.

**Type.** `shared.enum {code, md, json, image, csv, binary, text}`.

**Default.** Layer-specific; absence means "consumer infers from variant".

**Example.**
```text
command.context.format : shared.format = md
```

---

### `shared.output_format`

**Definition.** A rendering contract for emitted artifacts. Combines a `shared.format` kind with a structural sub-spec: e.g., `markdown:critique-report`, `diff:unified`, `json-schema:./schemas/finding.json`. Consumers MUST validate emitted output against this spec when one is supplied.

**Cross-layer notes.** Sibling parameters: `command.output_format` (final user-facing rendering), `subagent.output_format` (per-slot intermediate rendering — frequently a structured form the orchestrator parses and aggregates), `skill.output_format` (the structural contract the skill promises).

**Type.** `string` of the form `<format>[:<sub-spec>]`.

**Default.** Layer-specific.

**Example.**
```text
command.output_format : shared.output_format = "markdown:critique-report"
subagent.output_format : shared.output_format = "json-schema:./schemas/finding.json"
```

---

## Git primitives

### `shared.commit_ish`

**Definition.** Any commit-ish git accepts — a branch name, tag name, full or abbreviated SHA, remote ref (`origin/main`), or revision expression (`HEAD~3`, `feature^{commit}`).

**Cross-layer notes.** Used as the underlying type of `command.base_branch`, `command.worktree_start_ref`, `subagent.base_branch`.

**Type.** `string` (resolved via `git rev-parse`).

**Default.** None.

**Example.**
```text
command.worktree_start_ref : shared.commit_ish   # e.g. "origin/main"
```

---

### `shared.branch_ref`

**Definition.** A `shared.commit_ish` constrained to resolve to a branch tip (i.e., `git show-ref --verify refs/heads/<name>` or `refs/remotes/<remote>/<name>` succeeds). SHAs, tags, and detached refs are rejected.

**Cross-layer notes.** Used by `command.base_branch` (the branch worktrees fork from and merges target), `subagent.base_branch`.

**Type.** `string` + branch-kind constraint.

**Default.** Often `current branch` resolved via `git rev-parse --abbrev-ref HEAD`.

**Example.**
```text
command.base_branch : shared.branch_ref = "<current branch>"
```

---

## Model / sampling primitives

### `shared.model_id`

**Definition.** A model identifier accepted by the agent runtime. The exact format is runtime-specific; consumers MUST treat it as an opaque string and only the runtime resolves it.

**Cross-layer notes.** Used by `command.model`, `command.agent_model`, `subagent.model`.

**Type.** `string`.

**Default.** Often "parent agent's model".

**Example.**
```text
command.model : shared.model_id = "<parent model>"
```

---

### `shared.seed`

**Definition.** A non-negative integer RNG seed passed to the model runtime for determinism-friendly runs. Has effect only when the runtime supports seeding.

**Cross-layer notes.** Used by `command.seed`, `subagent.seed`. When a command broadcasts `shared.seed` to multiple subagents, each subagent typically receives `seed + index` rather than a literal repeat.

**Type.** `int with shared.int_range >= 0`.

**Default.** None (random).

**Example.**
```text
command.seed : shared.seed = 42
```

---

### `shared.temperature`

**Definition.** A non-negative real sampling temperature; semantics defined by the runtime.

**Cross-layer notes.** Used by `command.temperature`, `subagent.temperature`. Frequently varied across subagents in a fan-out for output diversity.

**Type.** `float with shared.float_range [0.0, 2.0]`.

**Default.** Runtime default.

**Example.**
```text
subagent.temperature : shared.temperature = 0.7
```

---

## Reporting primitives

### `shared.severity`

**Definition.** A finding severity enum, ordered `critical > major > minor > nit`. Used in critique-style outputs.

**Cross-layer notes.** Used by `subagent.output_format` when the contract is "list of findings", and indirectly by `command.criteria` when criteria are themselves severity-weighted.

**Type.** `shared.enum {critical, major, minor, nit}`.

**Default.** None (per finding).

**Example.**
```text
finding.severity : shared.severity = "major"
```

---

### `shared.exit_code`

**Definition.** An integer exit code returned by an external process. `0` denotes success; any non-zero value denotes failure.

**Cross-layer notes.** Used wherever a `shared.shell_command`'s outcome is reported: `command.test_command` result, `subagent.test_command` result.

**Type.** `int with shared.int_range [0, 255]`.

**Default.** None.

**Example.**
```text
verification.exit_code : shared.exit_code = 0
```

---

### `shared.shell_command`

**Definition.** A string interpretable by the active shell (`zsh`, `bash`, `pwsh`). Consumers MUST quote / escape inputs interpolated into the command.

**Cross-layer notes.** Used by `command.test_command`, `subagent.test_command`.

**Type.** `string`.

**Default.** None.

**Example.**
```text
command.test_command : shared.shell_command = "pytest -q"
```

---

## Generic helpers

### `shared.boolean`

**Definition.** A two-valued primitive: `true` or `false`. Truthy strings (`yes`, `1`, `on`) are NOT accepted unless the consuming parameter explicitly says so.

**Cross-layer notes.** Used by `command.auto_save_winner`, `command.require_diff`, `command.include_terminal_log`, `command.delete_worktree`.

**Type.** `bool`.

**Default.** Layer-specific.

**Example.**
```text
command.auto_save_winner : shared.boolean = false
```

---

### `shared.policy_string`

**Definition.** A short controlled-vocabulary string whose allowed values are owned by the consuming layer parameter (i.e., this primitive only encodes "small enum, layer-defined"). Consumers MUST enumerate the allowed values inline.

**Cross-layer notes.** Used wherever a parameter is "a small enum we'd otherwise inline" — `command.cleanup_policy`, `command.retry_policy.kind`, `command.hang_policy`.

**Type.** `string` from a layer-defined finite set.

**Default.** Layer-specific.

**Example.**
```text
command.cleanup_policy : shared.policy_string {keep, delete-on-merge, delete-always}
```

---

### `shared.list_or_scalar<T>`

**Definition.** A tagged union that accepts either a single value of type `T` (broadcast semantics — every consumer receives the same value) or a list of values of type `T` (zip-positional semantics — the i-th consumer receives the i-th element). The consuming layer parameter MUST state the cardinality contract for the list variant (typically "length MUST equal `command.parallel`").

**Cross-layer notes.** The dominant fan-out shape across the orchestrator. Used by `command.agent_model`, `command.focus_hints`, `command.subagent_prompt`, `command.subagent_constraints`. The matching consumer parameter (e.g. `subagent.model`) holds the *resolved* per-slot scalar.

**Type.** `T | list<T>`.

**Default.** Layer-specific.

**Example.**
```text
command.agent_model : shared.list_or_scalar<shared.model_id>
  # scalar form: "claude-sonnet-4"             -> every subagent gets the same
  # list form:   ["claude-sonnet-4", "gpt-5"]  -> length MUST equal command.parallel
```
