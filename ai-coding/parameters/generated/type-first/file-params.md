# File Parameters

Every parameter whose **type** is a filesystem path that MUST resolve to a
**regular file** (not a directory). For paths that resolve to a directory,
see `directory-params.md`. For paths that accept either, see
`path-params.md`. For lists of files, see `list-params.md`.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `file`

```
file(*,
     file_type=<file_type spec>?,
     existence=<must_exist | must_not_exist | maybe>,
     access=<read | write | read_write>,
     resolution=<absolute | relative_to_cwd | relative_to_repo_root | any>)
```

| Field        | Meaning                                                                   |
|--------------|---------------------------------------------------------------------------|
| `file_type`  | Optional constraint on extension / mimetype (see formalism below).         |
| `existence`  | Whether the consumer requires the file to exist, not exist, or either.    |
| `access`     | Required access mode (`read`, `write`, `read_write`).                     |
| `resolution` | How relative paths are resolved.                                          |

### Validation contract

- Existence, access, and `file_type` MUST be validated **before any other
  side effect**. Failure aborts with a clear error.
- A parameter with `existence=must_exist` that resolves to a directory
  MUST be rejected (do not silently treat as a directory; use `path-params.md`
  if either is acceptable).

---

## Type formalism: `file_type`

`file_type` is the schema language for restricting which file extensions
and/or MIME types a `file` parameter accepts. It is the **file-shaped
counterpart** of `int_range`.

### Form

```
file_type(
  extensions=[".ext", ...]?,    # leading dot, lowercase
  mimetypes=["type/sub", ...]?, # IANA MIME types
  any_of=[file_type, ...]?,     # union
  all_of=[file_type, ...]?,     # intersection (rare)
)
```

| Field        | Meaning                                                  |
|--------------|----------------------------------------------------------|
| `extensions` | Allowed extensions (case-insensitive). `[]` ⇒ any.       |
| `mimetypes`  | Allowed MIME types. `[]` ⇒ any. Detected from the file content when possible; else inferred from extension. |
| `any_of`     | Union of `file_type` specs; the value matches if any does. |
| `all_of`     | Intersection (e.g. `.md` extension AND `text/*` MIME). Rare; mainly to detect mis-extensioned binaries. |

### Convenience aliases

| Alias         | Equivalent                                                     |
|---------------|----------------------------------------------------------------|
| `markdown`    | `file_type(extensions=[".md", ".markdown"], mimetypes=["text/markdown"])` |
| `json`        | `file_type(extensions=[".json"], mimetypes=["application/json"])` |
| `yaml`        | `file_type(extensions=[".yaml", ".yml"], mimetypes=["application/yaml", "text/yaml"])` |
| `text`        | `file_type(mimetypes=["text/*"])`                              |
| `code`        | `file_type(extensions=[".py", ".ts", ".tsx", ".js", ".jsx", ".rs", ".go", ".java", ".c", ".cpp", ".h", ".hpp", ".rb", ".php", ".swift", ".kt", ".scala", ".sh", ".zsh", ".bash"])` |
| `image`       | `file_type(mimetypes=["image/*"])`                             |
| `csv`         | `file_type(extensions=[".csv", ".tsv"], mimetypes=["text/csv"])` |
| `binary`      | `file_type(mimetypes=["application/octet-stream", "application/*"])` |
| `any`         | `file_type()` — no constraint                                  |

### Where `file_type` appears in this ontology

- Direct: every entry in this file may carry a `file_type` constraint.
- Sub-field: `path-params.md → context` accepts a `file_type` when its
  resolution is a file.
- List form: `list-of-file` parameters in `list-params.md` carry a per-element
  `file_type`.

---

## Catalog

Each entry: typed name; `file_type` (or `any`); other `file(...)` fields;
semantic aliases; default; layer; ≥1 example.

### `single_file`

- **Schema:** `file(file_type=any, existence=must_exist, access=read,
  resolution=any)`.
- **Semantic aliases:** `file`, `context` (when the user passes a file path
  instead of a directory or URL — see `path-params.md` for the union form).
- **Default:** required when invoked.
- **Layer:** command, subagent.
- **Example:** `/critique context=README.md`.

### `prompt_file`

- **Schema:** `file(file_type=markdown, existence=must_exist, access=read)`.
- **Semantic aliases:** `criteria` (file form), `compare_against` (file
  form), `subagent_prompt` (file form), `aggregator` (when expressed as a
  prompt file rather than inline text).
- **Default:** unset; missing ⇒ inline form from `string-params.md` is used.
- **Layer:** command.
- **Example:** `/critique context=README.md criteria=./criteria/quality.md`.

### `code_file`

- **Schema:** `file(file_type=code, existence=must_exist, access=read)`.
- **Semantic aliases:** `file` (when the consumer restricts to code),
  `context` (when restricted to code).
- **Default:** required when used.
- **Layer:** command, subagent.
- **Example:** A language-aware reviewer that refuses anything other than
  source code as `context`.

### `data_file`

- **Schema:** `file(file_type=file_type(any_of=[json, yaml, csv]),
  existence=must_exist, access=read)`.
- **Semantic aliases:** `data_file`, `dataset`, `input_data`.
- **Default:** required when used.
- **Layer:** command, subagent.
- **Example:** A summarizer that accepts JSON, YAML, or CSV input.

### `save_path`

- **Schema:** `file(file_type=any, existence=maybe, access=write,
  resolution=relative_to_cwd)`.
- **Semantic aliases:** `save_path`, `output_path`, `output_file`.
- **Per-role default:**
  - `meta-prompt.md` infers `.cursor/commands/<kebab-name>.md` from the H1
    when save intent is detected and no path is given (see
    `meta-prompt.md` Parameters).
  - `worktree-task-agent.md` does not write artifacts; `save_path` is not
    in scope.
- **Layer:** command.
- **Example:** `/meta-prompt save_path=.cursor/commands/foo.md input="..."`.

### `report_path`

- **Schema:** `file(file_type=markdown, existence=maybe, access=write)`.
- **Semantic aliases:** `report_path` (a `save_path` specialized to a
  Markdown report).
- **Default:** unset; missing ⇒ the report is emitted to the chat only,
  no file write.
- **Layer:** command.
- **Example:** `/critique context=README.md report_path=./reports/readme-critique.md`.

### `log_file`

- **Schema:** `file(file_type=text, existence=maybe, access=write)`.
- **Semantic aliases:** `log_file`, `terminal_log_path`.
- **Default:** unset; pair with `include_terminal_log` (`bool-params.md`)
  when the consumer supports persisted logs.
- **Layer:** command, subagent.

### `compare_against` (file form)

- **Schema:** `file(file_type=any, existence=must_exist, access=read)`.
- **Semantic aliases:** `compare_against`, `baseline`, `reference_file`.
- **Default:** unset.
- **Layer:** command.
- **Example:** `/meta-prompt refine ./prompts/foo.md compare_against=./prompts/foo.baseline.md`.

### `test_command_script` (file form)

- **Schema:** `file(file_type=file_type(extensions=[".sh", ".bash", ".zsh",
  ".py", ".js", ".ts"]), existence=must_exist, access=read)`.
- **Semantic aliases:** `test_command` (when the consumer accepts a script
  path; the inline shell-command form is in `string-params.md →
  shell_command`).
- **Default:** unset.
- **Layer:** command.
- **Example:** `/worktree-task-agent test_command=./scripts/ci.sh task="..."`.

---

## Cross-references

- For paths that may resolve to a directory or a URL, see `path-params.md`.
- For lists of files, see `list-params.md → list-of-file`.
- For object fields whose values are files (e.g. `retry_policy.log_file`),
  see `compound-params.md`.
- Semantic-name lookup: `semantic-aliases.md`.
