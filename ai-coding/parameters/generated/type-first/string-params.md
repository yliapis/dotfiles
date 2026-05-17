# String Parameters

Every parameter whose **type** is a free-form string with no fixed-set
restriction. Many string parameters carry a **format constraint** (a regex,
grammar, or recognizer) that narrows the accepted syntax without enumerating
all valid values; those formats are first-class subtypes of `string` in this
ontology.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `string`

```
string(*, min_len=0, max_len=+inf, format=<format_name>?)
```

| Field      | Meaning                                                       |
|------------|---------------------------------------------------------------|
| `min_len`  | Minimum length in characters. `0` ⇒ empty allowed.            |
| `max_len`  | Maximum length in characters. `+inf` ⇒ no upper bound.        |
| `format`   | Optional named format (see formats below); `none` ⇒ free-form.|

### Validation contract

- A consumer MUST validate length bounds and (if `format` is set) the
  format recognizer **before any side effect**.
- A `format=none` string is opaque: the consumer treats it as user prose
  and MUST NOT parse it for hidden structure.

## Format subtypes

This ontology defines the following named string formats. Each format is a
**recognizer** with a canonical regex (or grammar) plus normalization
rules. The catalog below uses these names.

| Format            | Canonical pattern (informal)                                  | Normalization                              |
|-------------------|---------------------------------------------------------------|--------------------------------------------|
| `none`            | `.*`                                                          | none                                       |
| `kebab-case`      | `^[a-z0-9]+(-[a-z0-9]+)*$`                                    | lowercase + `-` separator                  |
| `snake_case`      | `^[a-z0-9]+(_[a-z0-9]+)*$`                                    | lowercase + `_` separator                  |
| `git-ref`         | a valid Git refname (`git check-ref-format`); SHA also allowed | trim whitespace                            |
| `branch-name`     | a Git refname, additionally constrained to NOT include `/HEAD` and to be writable | trim whitespace |
| `model-id`        | `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._:-]+$` OR a vendor-specific id  | trim whitespace                            |
| `glob`            | a POSIX-like glob (`*`, `?`, `**`, `[...]`)                   | none                                       |
| `url`             | RFC 3986 absolute URL                                         | unicode-normalize host                     |
| `shell-command`   | a non-empty string passed to a shell with `set -euo pipefail` semantics | none                                       |
| `duration`        | `^\d+(ns\|us\|ms\|s\|m\|h\|d)$` or compound (`1h30m`)         | normalize to lowercase                     |
| `prose`           | unrestricted human text                                       | none                                       |
| `markdown`        | CommonMark + extensions                                       | none                                       |
| `regex`           | a valid regex in the runtime's flavor                         | none                                       |
| `selector`        | a JSONPath, jq, or CSS-like selector path                     | none                                       |

Adding a new format is a non-breaking extension as long as no existing
typed entry adopts it without a migration.

---

## Catalog

Each entry: typed name; format (or `none`); semantic aliases; default;
layer; ≥1 example.

### `task_prompt`

- **Schema:** `string(format=prose, min_len=1)`.
- **Semantic aliases:** `task`, `task_description`, `input` (when the
  consumer treats the user's input as a single prose blob, e.g.
  `meta-prompt.md`).
- **Default:** required.
- **Layer:** command (parent input), subagent (handed down to children).
- **Example:** `/worktree-task-agent task="add a /healthz endpoint"`.

### `inline_artifact`

- **Schema:** `string(format=none, min_len=0)`.
- **Semantic aliases:** `inline`, `inline_content`, `context` (when the
  user pastes content directly rather than passing a path; see
  `path-params.md` for the path forms).
- **Default:** `""` (empty).
- **Layer:** command.
- **Example:** Pasting an entire snippet inline to `/critique` instead of
  a file path.

### `stop_condition`

- **Schema:** `string(format=prose, min_len=1)`.
- **Semantic aliases:** `stop_condition`, `done_when`.
- **Default:** unset (the agent uses "task implemented and verified").
- **Layer:** command, subagent.
- **Example:** `/worktree-task-agent task="..." stop_condition="all unit tests in ./tests pass and lint reports zero errors"`.

### `subagent_prompt`

- **Schema:** `string(format=prose, min_len=1)` or, when authored by the
  parent agent, may be a structured `markdown` document.
- **Semantic aliases:** `subagent_prompt`.
- **Default:** required when launching a subagent.
- **Layer:** subagent.
- **Example:** Used by `worktree-task-agent.md` to hand a fully-resolved
  task to each sibling agent.

### `model_id`

- **Schema:** `string(format=model-id, min_len=1)`.
- **Semantic aliases:** `model`, `agent_model`, `subagent_model` (when
  scalar; the list form is in `list-params.md`).
- **Per-role default:**
  - `model` → the parent agent's model (per `critique.md`).
  - `agent_model` → the parent agent's model, broadcast (per
    `worktree-task-agent.md`).
  - `subagent_model` → inherits `model_id` from the parent.
- **Layer:** command, subagent.
- **Example:** `/critique model="anthropic/claude-opus-4.1" context=README.md`.

### `worktree_name`

- **Schema:** `string(format=kebab-case, min_len=1, max_len=200)`. MUST
  additionally be filesystem-safe (no `/`, no `..`, no leading `-`).
- **Semantic aliases:** `worktree_name`.
- **Default:** a `kebab-case` slug derived from `task` (per
  `worktree-task-agent.md`).
- **Layer:** command.
- **Example:** `/worktree-task-agent worktree_name=add-healthz task="..."`.

### `base_branch`

- **Schema:** `string(format=branch-name, min_len=1)`.
- **Semantic aliases:** `base_branch`.
- **Default:** current branch via `git rev-parse --abbrev-ref HEAD` (per
  `worktree-task-agent.md`).
- **Layer:** command.
- **Example:** `/worktree-task-agent base_branch=main task="..."`.

### `git_ref`

- **Schema:** `string(format=git-ref, min_len=1)`.
- **Semantic aliases:** `WORKTREE_START_REF`, `start_ref`, `pin`,
  `compare_against` (when comparison target is a git ref rather than a file).
- **Default:** `HEAD` when used as `WORKTREE_START_REF` (per
  `/worktree` command spec).
- **Layer:** command.
- **Example:** `/worktree branch=origin/main`.

### `shell_command`

- **Schema:** `string(format=shell-command, min_len=1)`.
- **Semantic aliases:** `test_command`, `verify_command`, `bootstrap_command`,
  `aggregator` (when the aggregator is a shell command instead of a prompt).
- **Default:** unset.
- **Layer:** command, subagent.
- **Example:** `/worktree-task-agent test_command="pnpm test && pnpm lint" task="..."`.

### `glob_pattern`

- **Schema:** `string(format=glob, min_len=1)`.
- **Semantic aliases:** `glob`.
- **Default:** unset; when set, MUST match at least one path or the
  consumer reports zero hits and proceeds.
- **Layer:** command, subagent.
- **Example:** `/critique context=README.md include_glob="**/*.py"`.

### `url_ref`

- **Schema:** `string(format=url, min_len=1)`. MUST be absolute (have a
  scheme).
- **Semantic aliases:** `url`, `context` (when the user passes a URL
  instead of a path; see `path-params.md`).
- **Default:** unset.
- **Layer:** command, subagent.
- **Example:** `/critique context=https://example.com/spec.md`.

### `duration_str`

- **Schema:** `string(format=duration, min_len=2)`.
- **Semantic aliases:** `timeout`, `relaunch_on_hang_after`,
  `hang_policy.detect_after`.
- **Default:** unset.
- **Layer:** command, subagent.
- **Example:** `relaunch_on_hang_after=5m` (the integer-seconds form is in
  `int-params.md → timeout_seconds`).

### `criterion_label`

- **Schema:** `string(format=prose, min_len=1, max_len=80)`.
- **Semantic aliases:** the **per-criterion name** within `guardrails`,
  `criteria`, `subagent_constraints` (see `compound-params.md` and
  `list-params.md` for the containers).
- **Default:** required per criterion.
- **Layer:** subagent / skill (produced and consumed during analysis).
- **Example:** in `critique.md`, each finding references one
  `criterion_label` from the active `criteria` set.

### `focus_hint`

- **Schema:** `string(format=prose, min_len=1, max_len=200)`.
- **Semantic aliases:** the per-candidate hint within the `focus_hints`
  list (see `list-params.md`).
- **Default:** required per slot.
- **Layer:** command (assigned by the parent), subagent (used to
  diversify candidate generation).
- **Example:**

  ```text
  /meta-prompt refine ./prompts/foo.md n_candidates=3 \
    focus_hints="tighten guardrails,clarify parameters,improve workflow"
  ```

### `aggregator_prompt`

- **Schema:** `string(format=markdown, min_len=1)` (or `format=prose`).
- **Semantic aliases:** `aggregator` (when expressed as a prompt rather
  than a `shell_command`), `synthesize_prompt`.
- **Default:** unset.
- **Layer:** command (handed down to the synthesizing subagent).
- **Example:** a Markdown document instructing the aggregator how to
  merge sibling outputs.

### `ranker_prompt`

- **Schema:** `string(format=markdown, min_len=1)`.
- **Semantic aliases:** `ranker`.
- **Default:** unset; missing ⇒ default ranker (test exit code + summary
  heuristics) applies.
- **Layer:** command, subagent.

---

## Cross-references

- The path-typed forms of `context`, `criteria`, etc. live in
  `path-params.md`, `file-params.md`, `directory-params.md`.
- For list-of-string entries with length-link constraints (e.g.
  `agent_model: list-of-string len=parallelism`), see `list-params.md`.
- Object-typed wrappers around strings (e.g. `subagent_constraints` whose
  fields are strings) live in `compound-params.md`.
- Semantic-name lookup: `semantic-aliases.md`.
