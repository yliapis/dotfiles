# Enum Parameters

Every parameter whose **type** is a string drawn from a small, fixed,
documented set of allowed values. An enum with two values is **not** a bool —
booleans express polarity (`true`/`false`), enums express discrete choice.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `enum<...>`

```
enum<value_1 | value_2 | value_3 | ...>
```

### Validation contract

- The input MUST be string-equal (case-sensitive unless the entry says
  otherwise) to one of the listed values. No prefix matching, no fuzzy
  matching.
- A value not in the set MUST be rejected before any side effect, with an
  error that lists the allowed values.
- Adding a value is a **non-breaking** change only if all existing
  consumers handle the new value via an `unknown ⇒ fallback` branch; this
  ontology recommends explicit-only handling. Treat enum extensions as
  breaking by default.

### Closed vs. open enums

- **Closed (default):** the full value set is documented here. Unlisted
  values are rejected.
- **Open:** the value set is documented as "well-known + caller-defined".
  Open enums are explicitly marked below.

---

## Catalog

Each entry: typed name; allowed values with one-line meanings; semantic
aliases; default; layer; ≥1 example.

### `merge_mode`

- **Type:** `enum<interactive | auto>`
- **Semantic aliases:** `merge_mode`.
- **Values:**
  - `interactive` — ask the user which branch (if any) to merge and which
    worktrees to delete (see `worktree-task-agent.md` Workflow §9).
  - `auto` — pick at most one branch automatically per the merge guardrails
    (clean status, passing test command, no conflicts).
- **Default:** `interactive`.
- **Layer:** command (`worktree-task-agent.md`).
- **Example:** `/worktree-task-agent merge_mode=auto parallelism=4 task="..."`.

### `selection_mode`

- **Type:** `enum<manual | auto-best | synthesize>`
- **Semantic aliases:** `selection_mode`, `aggregation_mode`.
- **Values:**
  - `manual` — present all candidates; the user picks.
  - `auto-best` — rank candidates by `{test_command}` exit + summary
    heuristics and select the top one.
  - `synthesize` — merge outputs into a single result rather than picking
    one (delegates to `aggregator` from `string-params.md`).
- **Default:** `manual`.
- **Layer:** command (`worktree-task-agent.md`, proposed in `trajectory.md`).
- **Example:** `/worktree-task-agent parallelism=4 selection_mode=auto-best task="..."`.

### `merge_count`

- **Type:** `enum<one | all-passing | user-pick-multi>`
- **Semantic aliases:** `merge_count` (enum form). The **integer** form lives
  in `int-params.md → bounded_count`.
- **Values:**
  - `one` — at most one branch is merged per invocation (current
    `worktree-task-agent.md` behavior).
  - `all-passing` — every candidate whose test/stop conditions are
    satisfied is merged.
  - `user-pick-multi` — interactive multi-select.
- **Default:** `one`.
- **Layer:** command (proposed in `trajectory.md`).
- **Example:** `/worktree-task-agent merge_count=all-passing merge_mode=auto task="..."`.

### `format` (artifact content format)

- **Type:** `enum<code | md | json | image | csv | binary | text>`
- **Semantic aliases:** `format`, `content_format`, `input_format`.
- **Values:**
  - `code` — source code (any language).
  - `md` — Markdown.
  - `json` — structured JSON.
  - `image` — raster/vector image.
  - `csv` — tabular CSV / TSV.
  - `binary` — opaque bytes.
  - `text` — plain text without structure assumptions.
- **Default:** inferred from the consumed `file` / `path` via `file_type`
  (see `file-params.md`); explicit value overrides inference.
- **Layer:** command (parameter passed to skills that need to know).
- **Example:** A summarize command may take `format=code` to enable
  language-aware summarization.

### `output_format`

- **Type:** `enum<markdown | json | text | diff | yaml>`
- **Semantic aliases:** `output_format`, `report_format`.
- **Values:**
  - `markdown` — a structured Markdown report (default for `critique.md`).
  - `json` — machine-readable structured output.
  - `text` — flat prose.
  - `diff` — a unified diff (e.g. for `meta-prompt.md refine` output).
  - `yaml` — structured YAML.
- **Default:** `markdown`.
- **Layer:** command.
- **Example:** `/critique context=README.md output_format=json`.

### `severity` (finding severity)

- **Type:** `enum<critical | major | minor | nit>`
- **Semantic aliases:** `severity`, `severity_label`.
- **Values:** as named in `critique.md` Success Criteria.
- **Default:** required per finding; no implicit value.
- **Layer:** subagent / skill (produced by analysis tools, consumed by
  reporters).
- **Example:** `critique.md` requires every finding to carry exactly one
  `severity` value.

### `verbosity`

- **Type:** `enum<quiet | normal | verbose | debug>`
- **Semantic aliases:** `verbosity`, `log_level`.
- **Values:**
  - `quiet` — only the final result.
  - `normal` — result + section headings.
  - `verbose` — adds per-step traces.
  - `debug` — adds raw tool I/O.
- **Default:** `normal`.
- **Layer:** command, subagent.
- **Example:** `/worktree-task-agent verbosity=verbose parallelism=2 task="..."`.

### `isolation`

- **Type:** `enum<none | worktree | sandbox | container>`
- **Semantic aliases:** `isolation`, `isolation_mode`.
- **Values:**
  - `none` — run in the caller's working tree.
  - `worktree` — run in a `git worktree` (per `worktree-task-agent.md`).
  - `sandbox` — run in a filesystem sandbox (no git).
  - `container` — run in a containerized environment.
- **Default:** `worktree` for `worktree-task-agent.md`; `none` for read-only
  commands like `critique.md`.
- **Layer:** command.
- **Example:** `/run-task isolation=container task="..."`.

### `cleanup_policy`

- **Type:** `enum<always | on-success | on-failure | never>`
- **Semantic aliases:** `cleanup_policy`.
- **Values:**
  - `always` — clean up unconditionally after the run.
  - `on-success` — clean up only if the run reported success.
  - `on-failure` — clean up only on failure (retain successful artifacts).
  - `never` — never clean up; leave artifacts in place.
- **Default:** `on-success`.
- **Layer:** command.
- **Example:** Pair with `delete_worktree` (bool) for fine-grained control:
  `cleanup_policy=on-success delete_worktree=true`.

### `subagent_type`

- **Type:** `enum<critic | implementer | tester | refiner | aggregator | router>`
  (open enum — callers MAY add domain-specific roles).
- **Semantic aliases:** `subagent_type`, `agent_role`.
- **Values:** the well-known roles in this ontology. New values are
  permitted but MUST be documented at the call site.
- **Default:** `implementer` (most commands' default).
- **Layer:** subagent (assigned by the parent).
- **Example:**

  ```text
  /worktree-task-agent parallelism=4 subagent_type=critic task="review the auth module"
  ```

### `hang_action`

- **Type:** `enum<abort | relaunch | escalate>`
- **Semantic aliases:** `hang_action`, the `action` sub-field of `hang_policy`
  (see `compound-params.md`).
- **Values:**
  - `abort` — kill the subagent and report failure.
  - `relaunch` — kill and restart on a fresh seed/model.
  - `escalate` — notify the user and pause.
- **Default:** `relaunch` (when `hang_policy` is set).
- **Layer:** command, subagent.
- **Example:** see `hang_policy` in `compound-params.md`.

### `retry_on`

- **Type:** `enum<never | transient | always>`
- **Semantic aliases:** `retry_on`, the `on_failure` sub-field of
  `retry_policy` (see `compound-params.md`).
- **Values:**
  - `never` — fail immediately.
  - `transient` — retry only on transient classes (network, timeout,
    rate-limit).
  - `always` — retry on any failure.
- **Default:** `transient`.
- **Layer:** command, subagent.
- **Example:** `retry_policy.on_failure=transient` (see
  `compound-params.md`).

### `backoff`

- **Type:** `enum<none | linear | exponential | jittered>`
- **Semantic aliases:** the `backoff` sub-field of `retry_policy`.
- **Values:**
  - `none` — fixed-interval retries.
  - `linear` — `delay = base * attempt`.
  - `exponential` — `delay = base * 2^attempt`.
  - `jittered` — exponential plus random jitter in `[0, delay]`.
- **Default:** `exponential`.
- **Layer:** command, subagent.

---

## Cross-references

- An enum's allowed-value list is the canonical specification for its
  domain; do NOT re-derive from the consuming command.
- Pair enum + bool only when the bool is a true shorthand (see
  `bool-params.md → interactive`, `bool-params.md → verbose`).
- Lists of enum values: `list-params.md → list-of-enum`.
- Object containers that include enum sub-fields: `compound-params.md`.
- Semantic-name lookup: `semantic-aliases.md`.
