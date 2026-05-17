# Compound Parameters

Every parameter whose **type** is an **object with named sub-fields**, each
of which has its own type drawn from this ontology. Compounds are the "last
mile" of the type-first system: anything that can't be expressed as a
scalar, enum, path, list, or simple string lives here.

Compounds are also where this ontology composes its building blocks
(`int_range`, `file_type`, `enum<...>`, `list-of-T`) into richer shapes
like a `retry_policy` or a `finding`.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `compound`

```
compound(
  fields={
    <name>: { type: <T>, required: <bool>, default: <value>, doc: "..." },
    ...
  },
  extra_fields=<reject | ignore | passthrough>,
  validation_order=<as_declared | by_dependency>,
)
```

| Field              | Meaning                                                              |
|--------------------|----------------------------------------------------------------------|
| `fields`           | Map from sub-field name to its type spec, required flag, default, and inline documentation. |
| `extra_fields`     | What to do with unknown keys: `reject` (default), `ignore`, or `passthrough`. |
| `validation_order` | Whether sub-fields are validated in declared order or in a dependency-aware order (relevant when one field's value constrains another's, e.g. `parallelism` ⇒ `len(agent_model)`). |

### Validation contract

- Required sub-fields MUST be present. Missing required ⇒ reject before
  side effects.
- Field types are validated using the same contracts as the rest of this
  ontology — there is no relaxation just because they live inside a
  compound.
- Cross-field constraints (e.g. "`detect_after_s < timeout_seconds`") are
  declared as a `validation_order=by_dependency` rule and enforced after
  per-field validation.

### Notation

Throughout this file, compound schemas use a compact form:

```
compound {
  field_name: <type>     (required, default=..., doc="...")
  other_field: <type>    (optional, default=..., doc="...")
}
```

`<type>` is a typed entry from this ontology (e.g. `positive_count`,
`enum<a | b>`, `string(format=prose)`, `list-of-string(...)`).

---

## Catalog

Each entry: typed name; full `compound { ... }` schema; semantic aliases;
default (per sub-field); layer; ≥1 example.

### `retry_policy`

- **Semantic aliases:** `retry_policy`.

  ```
  compound {
    max_attempts: positive_count       (optional, default=3,
                                        doc="max total tries including the first")
    on_failure: retry_on               (optional, default=transient,
                                        doc="see enum-params.md → retry_on")
    backoff: backoff                   (optional, default=exponential,
                                        doc="see enum-params.md → backoff")
    base_delay: duration_str           (optional, default="1s")
    max_delay: duration_str            (optional, default="60s")
    jitter_ratio: float_range(0,1)     (optional, default=0.25)
    log_file: file(file_type=text,
                   existence=maybe,
                   access=write)       (optional, default=unset)
  }
  ```

- **Default:** unset (the consumer's built-in retry behavior applies).
- **Layer:** command, subagent.
- **Example:**

  ```text
  /worktree-task-agent retry_policy='{
      "max_attempts": 5,
      "on_failure": "transient",
      "backoff": "jittered",
      "base_delay": "2s",
      "max_delay": "30s"
    }' task="..."
  ```

### `hang_policy`

- **Semantic aliases:** `hang_policy`.

  ```
  compound {
    detect_after: duration_str         (required, doc="quiet-period threshold")
    action: hang_action                (optional, default=relaunch,
                                        doc="see enum-params.md → hang_action")
    max_relaunches: non_negative_count (optional, default=2)
    escalate_after: non_negative_count (optional, default=0,
                                        doc="0 ⇒ never escalate")
  }
  ```

- **Default:** unset (no hang detection).
- **Layer:** command, subagent.
- **Example:**

  ```text
  /worktree-task-agent hang_policy='{
      "detect_after": "5m",
      "action": "relaunch",
      "max_relaunches": 2
    }' parallelism=8 task="..."
  ```

  Implements the `{relaunch_on_hang_after}` proposal from `trajectory.md`
  with explicit policy fields.

### `subagent_spec`

- **Semantic aliases:** `subagent_spec`, the per-slot entry in
  `subagent_specs` (`list-params.md`).

  ```
  compound {
    role: subagent_type                (required, doc="see enum-params.md → subagent_type")
    model: model_id                    (optional, default=inherit_from_parent)
    prompt: subagent_prompt            (required)
    constraints: subagent_constraints  (optional, default=unset)
    seed: seed                         (optional, default=unset)
    temperature: temperature           (optional, default=unset)
    focus_hint: focus_hint             (optional, default=unset)
    timeout: duration_str              (optional, default=unset)
    retry_policy: retry_policy         (optional, default=unset)
    hang_policy: hang_policy           (optional, default=unset)
  }
  ```

- **Default:** the per-slot defaults of each sub-field.
- **Layer:** command (constructs specs), subagent (consumed at launch).
- **Example:** see `worktree-task-agent.md` Workflow §3 (per-agent model
  resolution); a `subagent_spec` is the structured form that subsumes all
  per-agent overrides.

### `subagent_constraints`

- **Semantic aliases:** `subagent_constraints`.

  ```
  compound {
    must: list-of-string(T=string(format=prose))            (optional, default=[])
    must_not: list-of-string(T=string(format=prose))        (optional, default=[])
    scope: string(format=prose)                              (optional, default=unset)
    allowed_tools: list-of-string(T=string(format=kebab-case)) (optional, default=unset)
    forbidden_paths: list-of-path                            (optional, default=[])
    max_edits: positive_count                                (optional, default=unset)
  }
  ```

- **Default:** unset (the parent inherits the subagent's built-in
  guardrails).
- **Layer:** command (assigned by parent), subagent (consumed at launch).
- **Example:** Used to bound a subagent to read-only operation:
  `subagent_constraints='{"forbidden_paths":["./"]}'` (effectively read-only).

### `finding`

- **Semantic aliases:** `finding` (the per-finding shape in
  `critique.md` Output Format).

  ```
  compound {
    criterion: criterion_label         (required)
    location: string(format=prose)     (required, doc="file path, line range, or quoted span")
    severity: severity                 (required, doc="see enum-params.md")
    evidence: string(format=prose)     (required, doc="short quote or reference")
    rationale: string(format=prose)    (required, doc="one sentence")
    agreement_count: non_negative_count (optional, default=1,
                                         doc="how many of N runs raised this")
  }
  ```

- **Default:** every field is required per-finding.
- **Layer:** subagent / skill (produced by an analyzer, consumed by a
  reporter).
- **Example:** every bullet under `## Findings ### Critical` in
  `critique.md` Output Format is one rendered `finding`.

### `worktree_result`

- **Semantic aliases:** `worktree_result` (the per-worktree block in
  `worktree-task-agent.md` Output Format → Worktree Results).

  ```
  compound {
    index: positive_count              (required, doc="1-based agent index")
    worktree_path: worktree_path       (required)
    branch: branch-name                (required)
    agent_model: model_id              (required)
    status: enum<success | failed | incomplete> (required)
    summary: string(format=prose)      (required)
    verification: compound {
      command: shell_command           (optional)
      exit_code: int                   (optional)
      tail: string(format=prose)       (optional)
    }                                  (optional, default={})
    diff: string(format=prose)         (required, doc="`git diff base..branch`, truncated above ~400 lines")
    merge_recommendation: enum<merge | skip | hold> (required)
    reason: string(format=prose)       (required, doc="one-line rationale")
  }
  ```

- **Default:** every field is required per worktree.
- **Layer:** subagent (produced), command (rendered).
- **Example:** see `worktree-task-agent.md` Output Format → Worktree
  Results.

### `run_summary`

- **Semantic aliases:** `run_summary` (the header block in
  `worktree-task-agent.md` Output Format → Run Summary).

  ```
  compound {
    base_branch: branch-name           (required)
    parallelism: positive_count        (required)
    merge_mode: merge_mode             (required)
    counts: compound {
      succeeded: non_negative_count    (required)
      failed: non_negative_count       (required)
      incomplete: non_negative_count   (required)
    }                                  (required)
  }
  ```

- **Default:** every field is required.
- **Layer:** command.
- **Example:** rendered into the `### Run Summary` bullet list per
  `worktree-task-agent.md` Output Format.

### `selection_policy`

- **Semantic aliases:** `selection_policy` (a structured generalization of
  `selection_mode`, `ranker`, `aggregator`, `min_successes`).

  ```
  compound {
    mode: selection_mode               (required)
    min_successes: non_negative_count  (optional, default=1)
    ranker: string(format=markdown)    (optional, default=unset,
                                        doc="prompt or rule; see string-params.md → ranker_prompt")
    aggregator: string(format=markdown) (optional, default=unset,
                                         doc="prompt or shell-command; see string-params.md → aggregator_prompt")
    tie_break: enum<first | last | random | manual> (optional, default=first)
  }
  ```

- **Default:** `{ mode: manual, min_successes: 1, tie_break: first }`.
- **Layer:** command.
- **Example:**

  ```text
  /worktree-task-agent selection_policy='{
      "mode": "auto-best",
      "min_successes": 3,
      "ranker": "...markdown prompt...",
      "tie_break": "first"
    }' parallelism=8 task="..."
  ```

### `worktree_layout`

- **Semantic aliases:** `worktree_layout` (structured grouping of
  `worktree_root`, `worktree_name`, `cleanup_policy`, `delete_worktree`).

  ```
  compound {
    root: worktree_root                (optional, default=~/.cursor/worktrees/<WORKTREE_ID>/)
    name: worktree_name                (optional, default=<derived from task>)
    cleanup_policy: cleanup_policy     (optional, default=on-success)
    delete_worktree: bool              (optional, default=true)
    start_ref: git_ref                 (optional, default=HEAD)
  }
  ```

- **Default:** the per-sub-field defaults; this compound is offered as a
  convenience to callers that want to pass a single object instead of
  several siblings.
- **Layer:** command.
- **Example:**

  ```text
  /worktree-task-agent worktree_layout='{
      "root": "./.scratch/wt/",
      "name": "add-healthz",
      "cleanup_policy": "on-success",
      "start_ref": "origin/main"
    }' task="..."
  ```

### `divergent_finding`

- **Semantic aliases:** `divergent_finding` (per the `## Divergent
  Findings` section of `critique.md` Output Format).

  ```
  compound {
    finding: finding                   (required)
    runs_raising: list-of-int          (required, doc="indices of runs that raised this")
    runs_total: positive_count         (required, doc="num_experiments")
  }
  ```

- **Default:** required per divergent finding.
- **Layer:** subagent / skill.
- **Example:** rendered as the `## Divergent Findings` bullets when
  `num_experiments > 1` in `critique.md`.

---

## Cross-references

- Sub-field type catalogs: every other file in this directory.
- `list-params.md → list-of-compound` for lists of any compound defined
  here.
- Semantic-name lookup: `semantic-aliases.md`.
