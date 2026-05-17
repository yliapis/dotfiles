# List Parameters

Every parameter whose **type** is an **ordered sequence of elements** of
some other type. The element type is itself drawn from this ontology
(`int`, `bool`, `enum`, `string`, `file`, `directory`, `path`, or a
compound from `compound-params.md`).

The key distinguishing feature of list parameters in this ontology is the
**length-link constraint**: a list's length may be required to equal
another integer parameter (typically `parallelism`, `k`, or
`n_candidates`). Length-link is a first-class field of the `list` type.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `list-of-T`

```
list-of-<T>(
  T=<element type>,            # any type from this ontology
  min_len=<int_range or int>,  # default 0
  max_len=<int_range or int>,  # default +inf
  len_link=<sibling param name>?, # length MUST equal that param's value
  uniqueness=<none | by_value | by_field(<name>)>,
  order=<preserved | sorted | unspecified>,
  broadcast=<scalar_ok | never>,
)
```

| Field        | Meaning                                                                |
|--------------|------------------------------------------------------------------------|
| `T`          | Element type (a typed entry from this ontology).                        |
| `min_len`    | Minimum length. Either an `int` or an `int_range` (e.g. `>= 1`).        |
| `max_len`    | Maximum length.                                                         |
| `len_link`   | Name of a sibling parameter whose value the list's length MUST equal. |
| `uniqueness` | Whether duplicates are allowed.                                         |
| `order`      | Whether positional order is meaningful.                                  |
| `broadcast`  | `scalar_ok` ⇒ a scalar input is accepted and broadcast to every slot. `never` ⇒ a scalar input is rejected. |

### Validation contract

- Length and `len_link` MUST be validated **before any side effect**. If
  `len_link` is set and the linked sibling is missing, the consumer MUST
  reject the call with an explanatory error (do not infer length).
- When `broadcast=scalar_ok` and a scalar is supplied, the consumer fans
  it out to length `len_link` (or `min_len` if that is fixed). The
  validation log MUST record the broadcast.
- When `uniqueness != none`, duplicates MUST be rejected.
- When `order=preserved`, downstream consumers (especially subagents
  indexed by position) MUST honor the order. When `order=sorted`, the
  consumer sorts on intake.

### Length-link patterns

The two recurring length-link patterns in this ontology:

| Pattern                    | Where it appears                                   |
|----------------------------|----------------------------------------------------|
| `len_link=parallelism`     | `agent_model`, `seeds`, `temperatures`, `worktree_names` |
| `len_link=n_candidates`    | `focus_hints`, `candidate_seeds`                   |
| `len_link=num_partitions`  | `agents_per_partition`, `partition_labels`         |

A consumer that exposes any `len_link` field MUST document which sibling
the link points to (see the catalog entries below for each).

---

## Catalog

Each entry: typed name; full `list-of-T` schema; semantic aliases;
default; layer; ≥1 example.

### `list-of-int`

- **Schema:** `list-of-int(T=positive_count, min_len=1, broadcast=scalar_ok)`
  (the exact `T` varies per use; documented per alias below).
- **Semantic aliases:**
  - `seeds` — `T=seed`, `len_link=n_candidates`, `broadcast=scalar_ok`.
  - `fan_outs` — `T=positive_count`, `len_link=depth + 1`, `broadcast=never`
    (each tree level needs its own value).
  - `partition_sizes` — `T=positive_count`, `len_link=num_partitions`,
    `broadcast=scalar_ok` (must sum to `parallelism`).
- **Default:** typically unset; missing ⇒ the scalar variant from
  `int-params.md` is used.
- **Layer:** command (assigned by parent), subagent (per-level branching).
- **Example:**

  ```text
  /worktree-task-agent parallelism=8 num_partitions=2 partition_sizes="3,5" task="..."
  ```

  Validates: `len(partition_sizes) == num_partitions` AND `sum == parallelism`.

### `list-of-float`

- **Schema:** `list-of-float(T=temperature, min_len=1, broadcast=scalar_ok,
  len_link=n_candidates)`.
- **Semantic aliases:** `temperatures`, `per_candidate_temperatures`.
- **Default:** unset; missing ⇒ all candidates use the same `temperature`
  scalar from `int-params.md`.
- **Layer:** command, subagent.
- **Example:** `temperatures="0.2,0.7,1.0,1.0"` for a 4-candidate fan-out.

### `list-of-bool`

- **Schema:** `list-of-bool(min_len=1, broadcast=scalar_ok)`.
- **Semantic aliases:**
  - `per_candidate_require_diff` — `len_link=n_candidates`.
  - `per_worktree_delete` — `len_link=parallelism`.
- **Default:** unset; missing ⇒ the scalar bool from `bool-params.md` is
  broadcast.
- **Layer:** command.

### `list-of-enum`

- **Schema:** `list-of-enum(T=<enum>, min_len=1)`.
- **Semantic aliases:**
  - `per_candidate_selection_mode` — `T=selection_mode`,
    `len_link=n_candidates`.
  - `per_subagent_role` — `T=subagent_type`, `len_link=parallelism`,
    `broadcast=scalar_ok`.
- **Default:** unset; missing ⇒ the scalar enum from `enum-params.md`.
- **Layer:** command, subagent.
- **Example:** `per_subagent_role="critic,critic,implementer,implementer"`
  for a heterogenous 4-agent fan-out.

### `list-of-string`

- **Schema:** `list-of-string(T=<string form>, min_len=1)`. Per-alias
  `T` and `len_link`:

  | Alias               | `T`                                       | `len_link`        | `broadcast`     |
  |---------------------|-------------------------------------------|-------------------|-----------------|
  | `agent_model`       | `string(format=model-id)`                 | `parallelism`     | `scalar_ok`     |
  | `subagent_model`    | `string(format=model-id)`                 | `parallelism`     | `scalar_ok`     |
  | `focus_hints`       | `string(format=prose)`                    | `n_candidates`    | `never`         |
  | `worktree_names`    | `string(format=kebab-case)`               | `parallelism`     | `never`         |
  | `criteria_list`     | `string(format=prose)`                    | none              | `never`         |
  | `guardrails`        | `string(format=prose)`                    | none              | `never`         |
  | `criterion_labels`  | `string(format=prose, max_len=80)`        | none              | `never`         |
  | `tags`              | `string(format=kebab-case)`               | none              | `never`         |

- **Per-alias default:**
  - `agent_model` → broadcast of the parent's model (per
    `worktree-task-agent.md`).
  - `focus_hints` → unset; missing ⇒ candidates are not diversified by
    hint (per `trajectory.md`).
  - `worktree_names` → derived as `<worktree_name>-<i>` (per
    `worktree-task-agent.md`).
- **Layer:** command (assigned by parent), subagent (when nested
  fan-outs).
- **Example:**

  ```text
  /worktree-task-agent parallelism=4 \
    agent_model="opus-4,opus-4,sonnet-4,sonnet-4" task="..."

  /meta-prompt n_candidates=3 \
    focus_hints="tighten guardrails,clarify parameters,improve workflow"
  ```

  In the first call, validation requires `len(agent_model) == parallelism`.

### `list-of-file`

- **Schema:** `list-of-file(T=<file form>, min_len=1, broadcast=never)`.
- **Semantic aliases:**
  - `context_files` — `T=single_file`, no `len_link`.
  - `criteria_files` — `T=prompt_file`, no `len_link`.
  - `report_paths` — `T=report_path`, `len_link=n_candidates`.
- **Default:** unset; the singular form from `file-params.md` is used.
- **Layer:** command.
- **Example:** `/critique context_files="./README.md,./docs/auth.md"`.

### `list-of-directory`

- **Schema:** `list-of-directory(T=<directory form>, min_len=1,
  broadcast=never)`.
- **Semantic aliases:** `context_dirs`, `corpus_directories`.
- **Default:** unset; the singular form from `directory-params.md` is used.
- **Layer:** command.

### `list-of-path`

- **Schema:** `list-of-path(T=<path-union>, min_len=1, broadcast=never)`.
  Useful when a single `context` parameter must accept several mixed-shape
  inputs.
- **Semantic aliases:** `contexts` (the plural of `context`),
  `analyzable_inputs`.
- **Default:** unset; the singular `path` from `path-params.md` is used.
- **Layer:** command.
- **Example:** `/critique contexts="./README.md,./docs/,https://example.com/spec.md"`.

### `list-of-compound`

- **Schema:** `list-of-compound(T=<compound type>, min_len=1)`.
- **Semantic aliases:**
  - `findings` — `T=finding` (see `compound-params.md`); produced by
    analysis subagents.
  - `worktree_results` — `T=worktree_result` (see `compound-params.md`);
    produced by `worktree-task-agent.md`.
  - `subagent_specs` — `T=subagent_spec`; one per slot in a heterogenous
    fan-out, `len_link=parallelism`.
- **Default:** depends per alias.
- **Layer:** subagent (produced and reported upward).
- **Example:** the `Findings` section of `critique.md` Output Format is a
  `list-of-compound(T=finding)` rendered as Markdown.

---

## Length-link validation reference

Consumers MUST run this validation when any `list-of-T` parameter has a
non-null `len_link`:

```text
let n = len_link.resolve()      # the integer value of the sibling
let xs = this_list

if xs is scalar and broadcast == scalar_ok:
    xs = [xs] * n
elif xs is scalar and broadcast == never:
    reject("scalar not accepted; expected length n")
elif len(xs) != n:
    reject(f"length mismatch: got {len(xs)}, expected {n}")
```

This is the contract `worktree-task-agent.md` step 1 implements for
`agent_model` vs `parallelism`.

---

## Cross-references

- Element type catalogs: `int-params.md`, `bool-params.md`,
  `enum-params.md`, `string-params.md`, `file-params.md`,
  `directory-params.md`, `path-params.md`, `compound-params.md`.
- Sibling parameters that act as `len_link` targets are themselves
  documented in `int-params.md → positive_count`.
- Semantic-name lookup: `semantic-aliases.md`.
