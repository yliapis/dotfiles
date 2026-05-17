# Integer Parameters

Every parameter whose **type** is an integer-valued scalar. Float-valued
scalars are covered by the `float_range` subtype at the bottom of this file
(there are very few of them; `temperature` is the main one).

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `int_range`

`int_range` is the schema language used **everywhere** in this ontology to
constrain integer parameters. A parameter's `int_range` is what callers and
commands validate against before any side effect.

### Form

```
int_range(lower, upper, *, lower_inclusive=true, upper_inclusive=true)
```

| Field             | Meaning                                                   |
|-------------------|-----------------------------------------------------------|
| `lower`           | Lower bound. Use `-inf` for no lower bound.               |
| `upper`           | Upper bound. Use `+inf` for no upper bound.               |
| `lower_inclusive` | Bool, default `true`. `false` ⇒ strict `>`.               |
| `upper_inclusive` | Bool, default `true`. `false` ⇒ strict `<`.               |

### Shortcut notations

All notations below are equivalent to a full `int_range` and are used
interchangeably across this ontology and the consuming commands:

| Shorthand    | Equivalent                                       |
|--------------|--------------------------------------------------|
| `>= 1`       | `int_range(1, +inf)`                             |
| `>= 0`       | `int_range(0, +inf)`                             |
| `> 0`        | `int_range(0, +inf, lower_inclusive=false)`      |
| `[1, 8]`     | `int_range(1, 8)`                                |
| `[0, 1]`     | `int_range(0, 1)`                                |
| `(0, 1)`     | `int_range(0, 1, lower_inclusive=false, upper_inclusive=false)` |
| `int`        | `int_range(-inf, +inf)` — full signed integer    |

### Validation contract

A consumer MUST validate every integer parameter against its declared
`int_range` **before any filesystem, network, or subprocess side effect**.
On failure the consumer aborts with an explanatory error and creates
nothing. See `worktree-task-agent.md` step 1 ("validate parameters") and
`critique.md` Guardrails ("MUST honor the requested replication").

### Where `int_range` appears in this ontology

- Direct: every entry in this file.
- Indirect: every `list-of-int` entry in `list-params.md` carries a per-element
  `int_range` plus a length-link constraint.
- Sub-field: compound parameters in `compound-params.md` use `int_range` for
  their integer fields (e.g. `retry_policy.max_attempts: int_range(1, 100)`).

---

## Catalog

Each entry has: the typed name; the `int_range` it satisfies; semantic
aliases (roles it can play); per-role default + layer; ≥1 example.

### `positive_count`

- **Schema:** `int_range(1, +inf)` — i.e. `>= 1`.
- **Semantic aliases:** `parallel`, `parallelism`, `k`, `n_candidates`,
  `num_experiments`, `num_partitions`, `fan_out`, `merge_count` (only when
  the consumer takes an integer instead of the `merge_count` enum — see
  `enum-params.md`).
- **Per-role default + layer:**
  - `parallel` → `1` — command (`critique.md`).
  - `parallelism` → `1` — command (`worktree-task-agent.md`).
  - `num_experiments` → `1` — command (`critique.md`).
  - `num_partitions` → `1` — command (`worktree-task-agent.md`).
  - `n_candidates` → `1` — command (`meta-prompt.md`, proposed in
    `trajectory.md`).
  - `k` → `1` — command / subagent (generic best-of-N count).
  - `fan_out` → `1` — subagent (per-level branching factor in a tree-shaped
    workflow).
- **List form:** `list-of-positive_count` exists when each tree level has its
  own branching factor (e.g. `fan_out=[4,2]` for a two-level tree). See
  `list-params.md → list-of-int`.
- **Example (single role):**

  ```text
  /critique parallel=4 num_experiments=8 context=README.md
  ```

  Both `parallel` and `num_experiments` resolve to `positive_count` and are
  validated against `int_range(1, +inf)` before the first worker starts.

- **Example (two roles in one call):**

  ```text
  /worktree-task-agent parallelism=8 num_partitions=2 task="..."
  ```

  Two `positive_count` parameters with independent values; both validated
  before any worktree is created (see `worktree-task-agent.md` Workflow §1).

### `non_negative_count`

- **Schema:** `int_range(0, +inf)` — i.e. `>= 0`.
- **Semantic aliases:** `depth`, `min_successes`, `retry_count`, `merge_count`
  when `0` is a meaningful "merge nothing" value.
- **Per-role default + layer:**
  - `depth` → `0` — subagent (zero ⇒ leaf, no further fan-out).
  - `min_successes` → `1` — command (`worktree-task-agent.md`, proposed in
    `trajectory.md`).
  - `retry_count` → `0` — command / subagent.
- **List form:** `list-of-non_negative_count` for per-level depth or
  per-attempt retry budgets; see `list-params.md`.
- **Example:**

  ```text
  /worktree-task-agent parallelism=8 min_successes=5 task="..."
  ```

  The run is considered viable only if ≥5 of 8 agents reported `success`.

### `bounded_count`

- **Schema:** `int_range(lower, upper)` — generic bounded interval, typically
  `[1, N]` or `[0, N]`. Used inline when a command needs a hard upper bound
  (e.g. `k <= parallelism`, `merge_count <= 1`).
- **Semantic aliases:** no reserved alias; this is a **parameterized shape**
  applied at the call site, with `lower` / `upper` resolved from siblings.
- **Layer:** command (validator) and subagent (when constraining its own
  fan-out).
- **Example:**

  In `worktree-task-agent.md`, `merge_count` is implicitly `bounded_count`
  with `int_range(0, 1)` because Guardrails state "MUST NOT merge more than
  one worktree branch per invocation". A consumer that supports `>1` would
  widen the upper bound.

### `seed`

- **Schema:** `int_range(-inf, +inf)`. Many runtimes restrict to
  `int_range(0, 2**32 - 1)`; record the runtime bound at the call site.
- **Semantic aliases:** `seed`, `random_seed`.
- **Per-role default + layer:**
  - `seed` → unset (default ⇒ non-deterministic provider sampling).
- **List form:** `list-of-seed` with `len = n_candidates` for per-candidate
  reproducibility (`list-params.md → list-of-int`).
- **Example:**

  ```text
  /critique seed=42 num_experiments=4
  ```

  The four runs derive seeds `42, 43, 44, 45` or use a documented derivation
  scheme; the report records the seed per run for replay.

### `timeout_seconds`

- **Schema:** `int_range(1, +inf)` (seconds). Most commands prefer a duration
  **string** (`30s`, `5m`); see `string-params.md → duration` for that form.
  When the consumer accepts a raw integer, this is the type.
- **Semantic aliases:** `timeout`, `relaunch_on_hang_after` (when expressed in
  seconds rather than as a duration string).
- **Per-role default + layer:** unset by default ⇒ no timeout.
- **Example:**

  ```text
  /worktree-task-agent parallelism=8 relaunch_on_hang_after=300 task="..."
  ```

  Any subagent that emits no progress for 300 s is aborted and relaunched
  (per the policy proposed in `trajectory.md`).

---

## Float subtype: `float_range`

A small number of parameters are real-valued. `float_range` mirrors
`int_range` but with `float` bounds.

### Form

```
float_range(lower, upper, *, lower_inclusive=true, upper_inclusive=true)
```

### Catalog

#### `temperature`

- **Schema:** `float_range(0.0, 2.0)`. Clamp at the call site to the model's
  supported range.
- **Semantic aliases:** `temperature`, `sampling_temperature`.
- **Per-role default + layer:** unset; the provider default applies.
- **List form:** `list-of-float` with `len = n_candidates` for per-candidate
  diversification (see `list-params.md`).
- **Example:**

  ```text
  /critique temperature=0.9 num_experiments=4
  ```

  Paired with `seed` to make divergent yet reproducible candidates.

---

## Cross-references

- Multi-element shapes: `list-params.md`.
- Object fields whose values are integers: `compound-params.md`
  (e.g. `retry_policy.max_attempts`, `hang_policy.detect_after_s`).
- Semantic lookup (e.g. "I need the parallelism knob") →
  `semantic-aliases.md`.
