# Directory Parameters

Every parameter whose **type** is a filesystem path that MUST resolve to a
**directory** (not a regular file). For file paths see `file-params.md`. For
paths that accept either, see `path-params.md`.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `directory`

```
directory(*,
          existence=<must_exist | must_not_exist | maybe>,
          access=<read | write | read_write>,
          mode=<flat | recursive>,
          contains=<file_type spec>?,
          must_be_repo=<true | false>?,
          must_be_worktree=<true | false>?,
          resolution=<absolute | relative_to_cwd | relative_to_repo_root | any>)
```

| Field             | Meaning                                                                 |
|-------------------|-------------------------------------------------------------------------|
| `existence`       | Whether the consumer requires the directory to exist, not exist, or either. |
| `access`          | Required access mode.                                                   |
| `mode`            | How the consumer enumerates contents: `flat` (one level) or `recursive`. |
| `contains`        | Optional `file_type` filter applied during enumeration (see `file-params.md`). |
| `must_be_repo`    | If `true`, MUST be the root of (or inside) a git repository.            |
| `must_be_worktree`| If `true`, MUST be a `git worktree` registered to a parent repo.        |
| `resolution`      | How relative paths are resolved.                                        |

### Validation contract

- Existence, access, and (where set) `must_be_repo` / `must_be_worktree`
  MUST be validated **before any other side effect**.
- A directory parameter that resolves to a regular file MUST be rejected;
  if the consumer can accept either, use `path-params.md`.
- For consumers that enumerate contents, the `mode` and `contains` fields
  MUST be honored — no implicit recursion, no implicit type filtering.

---

## Catalog

Each entry: typed name; `directory(...)` schema; semantic aliases; default;
layer; ≥1 example.

### `single_directory`

- **Schema:** `directory(existence=must_exist, access=read, mode=recursive)`.
- **Semantic aliases:** `directory`, `context` (when the user passes a
  directory; see `path-params.md` for the union form).
- **Default:** required when used.
- **Layer:** command, subagent.
- **Example:** `/critique context=./docs/`.

### `criteria_directory`

- **Schema:** `directory(existence=must_exist, access=read, mode=flat,
  contains=markdown)`.
- **Semantic aliases:** `criteria` (directory form — each `.md` file inside
  contributes one criteria set).
- **Default:** unset; missing ⇒ the inline / file / default form takes
  precedence (see `critique.md`).
- **Layer:** command.
- **Example:** `/critique context=README.md criteria=./criteria/`.

### `output_directory`

- **Schema:** `directory(existence=maybe, access=write, mode=flat)`. When
  missing, the consumer MUST create the directory before writing.
- **Semantic aliases:** `output_dir`, `out_dir`, `report_dir`.
- **Default:** unset; missing ⇒ outputs are emitted to chat or to an
  inferred `save_path` (see `file-params.md`).
- **Layer:** command.
- **Example:** `/critique context=./docs/ output_dir=./reports/`.

### `worktree_root`

- **Schema:** `directory(existence=maybe, access=write, mode=flat,
  must_be_repo=false)`. The consumer creates the directory if missing.
- **Semantic aliases:** `worktree_root`.
- **Default:** `~/.cursor/worktrees/<WORKTREE_ID>/` for the `/worktree`
  command; `worktree-task-agent.md` proposes making this caller-overridable
  (per `trajectory.md`).
- **Layer:** command.
- **Example:** `/worktree-task-agent worktree_root=./.scratch/wt/ task="..."`.

### `repo_root`

- **Schema:** `directory(existence=must_exist, access=read_write,
  must_be_repo=true)`.
- **Semantic aliases:** `repo_root`, `REPO_ROOT` (per `/worktree`).
- **Default:** `git rev-parse --show-toplevel` from the caller's CWD.
- **Layer:** command.
- **Example:** Computed automatically by `/worktree`; rarely user-supplied.

### `worktree_path`

- **Schema:** `directory(existence=must_exist, access=read_write,
  must_be_worktree=true)`.
- **Semantic aliases:** `worktree_path`, `WORKTREE_PATH` (per `/worktree`),
  `ROOT_WORKTREE_PATH` when referring to the parent of nested worktrees.
- **Default:** assigned by `/worktree` on creation; subsequent commands
  read it from the chat-wide mapping.
- **Layer:** command.
- **Example:** Every read/edit/shell call after `/worktree` runs against
  this path (per the `/worktree` command spec).

### `scratch_dir`

- **Schema:** `directory(existence=maybe, access=read_write, mode=flat)`.
  Created on first use.
- **Semantic aliases:** `scratch_dir`, `tmp_dir`, `work_dir`.
- **Default:** an OS-temp subdirectory chosen by the consumer.
- **Layer:** command, subagent.

### `corpus_directory`

- **Schema:** `directory(existence=must_exist, access=read, mode=recursive,
  contains=file_type(any_of=[markdown, code, text]))`.
- **Semantic aliases:** `corpus`, `corpus_dir`, `docs_dir`.
- **Default:** required when used.
- **Layer:** command, subagent.
- **Example:** A corpus-wide critique that walks every `.md`, `.py`, and
  `.txt` under the given root.

---

## Cross-references

- For paths that may resolve to a file or a directory, see `path-params.md`.
- For lists of directories, see `list-params.md → list-of-directory`.
- For object fields whose values are directories (e.g.
  `worktree_layout.root`), see `compound-params.md`.
- Semantic-name lookup: `semantic-aliases.md`.
