# Path Parameters (Union)

Every parameter whose **type** is a tagged union over the path-shaped types:
`file`, `directory`, `url`, and `inline` (a string blob standing in for a
path). This file is for parameters where the consumer **legitimately
accepts more than one of these shapes** at the same parameter slot — for
example `critique.md`'s `context`, which may be a file, a directory, a URL,
or inline content.

For paths pinned to a single shape, see `file-params.md`,
`directory-params.md`, or `string-params.md → url_ref` / `inline_artifact`.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `path`

```
path(
  any_of=[
    file(...)?,
    directory(...)?,
    url(...)?,
    inline(*, format=<format_name>?)?,
  ],
  resolution_order=<as_listed | most_specific_first | by_scheme>
)
```

| Field              | Meaning                                                         |
|--------------------|-----------------------------------------------------------------|
| `any_of`           | The set of accepted shapes. At least 2 entries (else use the pinned type). |
| `resolution_order` | How the consumer disambiguates ambiguous input.                  |

### Shape detection

A consumer presented with a string MUST classify it in this order
(`by_scheme` resolution):

1. If the string starts with `http://`, `https://`, `ftp://`, `s3://`, or
   any other recognized URL scheme ⇒ **url**.
2. Else if the string is a syntactically valid path and resolves to an
   existing **directory** ⇒ **directory**.
3. Else if it is a syntactically valid path and resolves to an existing
   **file** ⇒ **file**.
4. Else if it contains a newline OR the consumer has been called with an
   explicit `inline=...` flag ⇒ **inline**.
5. Else: reject with "could not classify input as url, file, directory, or
   inline".

A consumer that uses `most_specific_first` resolution prefers the
narrowest shape that satisfies the input (e.g. file over directory when
both would match — relevant only for symlinks).

### Validation contract

- After classification, the consumer MUST run the corresponding shape's
  validation contract (file → `file-params.md`, directory →
  `directory-params.md`, url → `string-params.md → url_ref`, inline →
  `string-params.md → inline_artifact`).
- A `path` parameter MUST report the **resolved shape** in any user-facing
  summary (e.g. `critique.md` Success Criteria: "report header restates the
  resolved `{context}`").

---

## Catalog

Each entry: typed name; `path(...)` schema (union members); semantic
aliases; default; layer; ≥1 example.

### `analyzable_input`

- **Schema:**

  ```
  path(any_of=[
         file(file_type=any, existence=must_exist, access=read),
         directory(existence=must_exist, access=read, mode=recursive),
         url(),
         inline(format=prose),
       ],
       resolution_order=by_scheme)
  ```

- **Semantic aliases:** `context`, `input` (when `input` may be any of
  these shapes; the prose-only form is in `string-params.md →
  inline_artifact`).
- **Default:** required when used.
- **Layer:** command (e.g. `critique.md` Parameters; `meta-prompt.md` for
  `input` when extended).
- **Example:**

  ```text
  /critique context=README.md
  /critique context=./docs/
  /critique context=https://example.com/spec.md
  /critique inline="paste the entire snippet here"
  ```

  All four resolve to `analyzable_input`; the report header restates the
  resolved shape per `critique.md` Success Criteria.

### `criteria_input`

- **Schema:**

  ```
  path(any_of=[
         file(file_type=markdown, existence=must_exist, access=read),
         directory(existence=must_exist, access=read, mode=flat,
                   contains=markdown),
         inline(format=prose),
       ],
       resolution_order=by_scheme)
  ```

- **Semantic aliases:** `criteria`.
- **Default:** the default criteria set defined in `critique.md` Parameters
  (quality + determinism); missing ⇒ default applies.
- **Layer:** command (`critique.md`).
- **Example:**

  ```text
  /critique context=README.md criteria=./criteria/quality.md
  /critique context=README.md criteria=./criteria/
  /critique context=README.md criteria="must be runnable; must be idempotent"
  ```

### `comparison_target`

- **Schema:**

  ```
  path(any_of=[
         file(file_type=any, existence=must_exist, access=read),
         git_ref_string,
         inline(format=prose),
       ],
       resolution_order=as_listed)
  ```

  Where `git_ref_string` is a `string-params.md → git_ref` (a Git refname
  or SHA, classified by `git rev-parse --verify` instead of filesystem
  existence).

- **Semantic aliases:** `compare_against`.
- **Default:** unset.
- **Layer:** command (`meta-prompt.md` refine mode per `trajectory.md`).
- **Example:**

  ```text
  /meta-prompt refine ./prompts/foo.md compare_against=HEAD~1
  /meta-prompt refine ./prompts/foo.md compare_against=./prompts/foo.baseline.md
  ```

### `artifact_target`

- **Schema:**

  ```
  path(any_of=[
         file(file_type=any, existence=maybe, access=write),
         directory(existence=maybe, access=write),
       ],
       resolution_order=most_specific_first)
  ```

- **Semantic aliases:** `save_path` (when the consumer accepts either a
  file or a directory and infers the leaf name from context),
  `output_path`.
- **Default:** unset; per-command inference applies (see `file-params.md
  → save_path` for `meta-prompt.md`'s rule).
- **Layer:** command.
- **Example:**

  ```text
  /meta-prompt save_path=./out/foo.md
  /meta-prompt save_path=./out/    # consumer derives foo.md from H1
  ```

### `reference_pin`

- **Schema:**

  ```
  path(any_of=[
         git_ref_string,
         file(file_type=any, existence=must_exist, access=read),
         url(),
       ],
       resolution_order=as_listed)
  ```

- **Semantic aliases:** `WORKTREE_START_REF`, `pin`, `source`.
- **Default:** `HEAD` for `/worktree`'s `WORKTREE_START_REF`.
- **Layer:** command.
- **Example:** `/worktree branch=origin/main` (git ref); a future
  extension could accept a file or URL pinning a snapshot.

---

## Cross-references

- Pinned shapes: `file-params.md`, `directory-params.md`, `string-params.md
  → url_ref` / `inline_artifact`.
- For list-of-path (e.g. multiple `context` inputs to a single critique),
  see `list-params.md → list-of-path`.
- Semantic-name lookup: `semantic-aliases.md`.
