# Concern: Constraints

> **Responsibility:** Declare what's *not allowed*, what counts as *done*, and what counts as *valid*. Constraints scope the agent's freedom and define the verification gate between "the agent finished" and "the result is acceptable".
>
> **Primary parameters:** `criteria`, `guardrails`, `stop_condition`, `test_command`, `file_type`, `int_range`
>
> This file also defines two **type formalisms** (`int_range`, `file_type`) referenced from every other concern.

## Why this concern exists

Without explicit constraints, an agent's "I'm done" is whatever the model decides. Constraints make that decision external and observable: a `test_command` exits 0, a `stop_condition` is satisfied, a `criteria` list is exhausted with findings attached, a `guardrails` list is honored throughout. Grouping these together lets a prompt author answer one question — "what would make this run *unacceptable*?" — by reading one file.

The two type formalisms (`int_range`, `file_type`) live here because they *are* constraints: they constrain the value domain of other parameters. Putting them in this concern (vs. a separate "types" file) keeps the ontology flat at the concern level and means a reader who already understands "constraints" already understands "value domains".

## Parameters

### `criteria`

**Aliases:** `judgment_criteria`, `rubric`
**Definition:** The criteria the agent's output (or the artifact under analysis) is judged against, supplied as a reference or inline text.
**Type:** Resolves like `context`: `file | directory | inline` (see [io.md](./io.md)). Each criterion is a named, observable check.
**Default:** Command-specific. `/critique` defaults to *quality* (clarity, correctness, completeness, robustness) + *determinism* (reproducibility, idempotency, stability across runs).

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | The full set of judgment criteria for this invocation. Restated in the report header. |
| **subagent** | Each child judging against the same `criteria` receives them by reference; aggregation happens at the parent. Children may *not* substitute their own preferences (see `/critique` guardrails). |
| **skill** | Skills referencing `criteria` add to (never replace) the active set. Skill-specific criteria are clearly attributed in the output. |

**Cross-refs:**

- [`context` (task.md)](./task.md#context) — `criteria` is applied *to* `context`.
- [`ranker` (selection.md)](./selection.md#ranker) — when multiple candidates exist, the ranker often consumes `criteria` as its judgment basis.
- [`compare_against` (selection.md)](./selection.md#compare_against) — for refine-style runs, criteria can include a comparison rubric.

**Example:** `/critique context=./auth.py criteria=./criteria/security.md` — judgment is loaded from a file and applied per finding.

---

### `guardrails`

**Aliases:** `prohibitions`, `must_nots`
**Definition:** Hard prohibitions and scope statements the agent must honor throughout the run (`MUST` / `MUST NOT` / `Scope`).
**Type:** `inline` list of natural-language constraints, often embedded directly in the command's prompt rather than passed at invocation time.
**Default:** Command-specific; declared in each command's `## Guardrails` section.

**Cross-refs:**

- [`subagent_constraints` (subagent-tree.md)](./subagent-tree.md#subagent_constraints) — children inherit / extend the parent's `guardrails`.
- [`stop_condition` (this file)](#stop_condition) — `stop_condition` is a positive completion gate; `guardrails` are negative prohibitions.

**Example:** `/critique` declares `MUST NOT modify {context} or any other file; analysis is read-only.` as a guardrail; it applies to every analysis run regardless of `parallel`.

---

### `stop_condition`

**Aliases:** `done_when`, `completion_condition`
**Definition:** An explicit completion condition beyond the implicit "task implemented and verified".
**Type:** `string` — natural-language predicate the agent must reach (e.g. "all unit tests in `tests/auth/` pass and the new endpoint is documented").
**Default:** Unset; agents use the implicit "task done" heuristic.

**Cross-refs:**

- [`task` (task.md)](./task.md#task) — `stop_condition` augments the implicit done-ness of `task`.
- [`test_command` (this file)](#test_command) — `test_command` is a *programmatic* completion gate; `stop_condition` is a *narrative* one.
- [`min_successes` (selection.md)](./selection.md#min_successes) — when replicated, `stop_condition` is per-candidate; `min_successes` is the across-candidate threshold.

**Example:** `/worktree-task-agent task="Migrate config loader" stop_condition="Old loader file is deleted and no remaining call sites import it."`

---

### `test_command`

**Aliases:** `verify`, `check_command`
**Definition:** A shell command executed once per candidate after the agent reports completion; exit code `0` counts as pass, any other value as fail.
**Type:** `string` — a shell-quoted command line executed inside the candidate's workspace.
**Default:** Unset (no programmatic verification gate).

**Cross-refs:**

- [`stop_condition` (this file)](#stop_condition) — programmatic vs narrative gates.
- [`min_successes` (selection.md)](./selection.md#min_successes) — `min_successes` typically counts candidates whose `test_command` passed.
- [`merge_mode` (lifecycle.md)](./lifecycle.md#merge_mode) — `auto` merge mode predicates on `test_command` exit code.
- [`isolation` (isolation.md)](./isolation.md#isolation) — `test_command` runs *inside* the isolated workspace.

**Example:** `/worktree-task-agent task="Update API" test_command="pnpm test --filter=api"` — each candidate's test result decides merge eligibility.

---

### `file_type`

**Aliases:** `extension`, `ext`, `accepted_extensions`
**Definition:** A domain spec restricting which file extensions a parameter may resolve. Also a referenced type formalism.
**Type:** Set notation `{.ext1, .ext2, ...}` or a category mapping to `format` (e.g. `code`, `text`). May include `*` as wildcard.
**Default:** Unrestricted (`*`) unless a parameter explicitly tightens it.

**Examples of the formalism in use:**

- `{.md, .json}` — only markdown or JSON.
- `{.py}` — only Python source.
- `code` — anything classified as `format=code` by [io.md](./io.md#format).

**Cross-refs:**

- [`file` / `directory` / `glob` (io.md)](./io.md#file) — `file_type` filters their resolution.
- [`format` (io.md)](./io.md#format) — `format` describes how to *interpret* bytes; `file_type` decides whether they're *accepted*.
- [`context` (task.md)](./task.md#context) — `file_type` on a `context` rejects extensions outside the set during resolution.

**Example:** `/critique context=./src/ file_type='{.py}' criteria=performance` — the directory walk yields only `.py` files.

---

### `int_range`

**Aliases:** `integer_interval`, `int_domain`
**Definition:** A domain spec for integer-valued parameters. Defines a half-open or closed interval; values outside it cause fail-fast validation.
**Type:** Interval notation:
- `>= N` / `<= N` — half-line.
- `[a, b]` — closed interval.
- `(a, b)` — open interval.
- `(a, b]`, `[a, b)` — half-open.
- `(0, ∞)`, `[1, ∞)` — half-line with infinity.
**Default:** Per-parameter; usually `>= 1`.

**Examples of the formalism in use:**

- `parallelism`: `int_range >= 1`.
- `num_partitions`: `int_range >= 1`.
- `n_candidates`: `int_range >= 1`.
- `depth`: `int_range >= 0` (root agent is depth 0).
- `fan_out`: `int_range >= 1`.
- `merge_count`: `int_range [0, parallelism]` or enum override.
- `min_successes`: `int_range [0, n_candidates]`.

**Cross-refs:**

- All numeric parameters across [`replication.md`](./replication.md), [`subagent-tree.md`](./subagent-tree.md), [`selection.md`](./selection.md), [`lifecycle.md`](./lifecycle.md), and [`robustness.md`](./robustness.md) cite `int_range` in their type line.

**Example:** `/worktree-task-agent parallelism=8` — passes (`8 >= 1`); `parallelism=0` fails fast with an explanatory error and no filesystem side effects (per the command's validation rules).
