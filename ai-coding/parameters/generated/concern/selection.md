# Concern: Selection / Aggregation

> **Responsibility:** Declare *which candidate(s) win* and *how they're combined*, when more than one candidate exists. Selection only meaningfully applies when `n_candidates > 1` (see [replication.md](./replication.md)); for single-candidate runs every parameter here is implicitly satisfied.
>
> **Primary parameters:** `selection_mode`, `min_successes`, `ranker`, `aggregator`, `compare_against`

## Why this concern exists

Fan-out is cheap; aggregation is the hard part. A best-of-N run can decide its winner in many ways: ask the user, run a test, score against a rubric, synthesize all outputs into one, or refuse to pick until enough candidates passed. Conflating these decisions with "how many candidates" (replication) makes prompts hard to refactor — switching from `auto-best` to `synthesize` should be one knob, not a rewrite. This concern owns the picker / synthesizer; the replication concern owns the producer.

Two parameters here (`ranker`, `aggregator`) are explicitly *callable* — they may be a command name, a prompt, or a shell command — which gives the ontology a place to plug richer scoring logic without inventing new concerns.

## Parameters

### `selection_mode`

**Aliases:** `winner_mode`, `pick_mode`
**Definition:** How a final result is chosen from the candidates produced by replication.
**Type:** Enum: `manual | auto-best | synthesize | all-passing`. Each value implies different supporting parameters.
**Default:** `manual` when no `ranker` / `test_command` is set; otherwise `auto-best`.

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | The selection policy for the command's own fan-out. `/worktree-task-agent`'s `merge_mode=interactive` is roughly `selection_mode=manual`; `merge_mode=auto` is `selection_mode=auto-best` with `test_command` as the implicit ranker. |
| **subagent** | The selection policy *within* a subagent's children (e.g. a parent that runs 3 critic children and picks the strongest critique). Independent of the parent's own selection mode. |
| **skill** | Skills do not own `selection_mode`; they may *recommend* a value in their workflow (e.g. a "best-of-N refinement" skill defaults to `auto-best`). |

**Values:**

- `manual` — present all candidates to the user; user picks (interactive).
- `auto-best` — rank candidates via `ranker` and pick the top one programmatically.
- `synthesize` — merge candidates into a single composite via `aggregator` instead of picking.
- `all-passing` — return every candidate that satisfies `test_command` / `stop_condition`; no single winner.

**Cross-refs:**

- [`ranker` (this file)](#ranker) — required for `auto-best`.
- [`aggregator` (this file)](#aggregator) — required for `synthesize`.
- [`min_successes` (this file)](#min_successes) — gates whether selection even runs.
- [`merge_mode` (lifecycle.md)](./lifecycle.md#merge_mode) — at the lifecycle layer, `merge_mode` is a selection-then-promotion compound; this concern owns the selection half.

**Example:** `/worktree-task-agent task=X parallelism=4 selection_mode=auto-best ranker=test_command test_command="pytest -q"` — four candidates run, the first one with `pytest` exit 0 wins.

---

### `min_successes`

**Aliases:** `quorum`, `min_pass_count`
**Definition:** The minimum number of candidates that must complete successfully before selection or synthesis is attempted; runs that do not meet the threshold report failure overall.
**Type:** `int_range [0, n_candidates]`. See [`constraints.md#int_range`](./constraints.md#int_range).
**Default:** `1`.

**Cross-refs:**

- [`n_candidates` (replication.md)](./replication.md#n_candidates) — upper bound on `min_successes`.
- [`test_command` (constraints.md)](./constraints.md#test_command) — typically counts "candidates whose `test_command` exited 0".
- [`hang_policy` (robustness.md)](./robustness.md#hang_policy) — interacts: hung candidates count as failures unless `hang_policy=relaunch` and the relaunch succeeds.
- [`retry_policy` (robustness.md)](./robustness.md#retry_policy) — `retry_policy` may be triggered to bring `successes` up to `min_successes`.

**Example:** `/worktree-task-agent task=X parallelism=8 min_successes=3 selection_mode=auto-best` — at least 3 of 8 must pass; otherwise the overall run reports incomplete and no merge happens.

---

### `ranker`

**Aliases:** `score_fn`, `judge`
**Definition:** The callable used to score candidates when `selection_mode=auto-best`. May be a test command, a prompt evaluating against `criteria`, or a built-in heuristic.
**Type:** One of:
- `test_command` — use exit code of `test_command` (0 = pass).
- `prompt:<path>` — invoke an evaluator agent with the given prompt.
- `builtin:diff-size` / `builtin:summary-coherence` / etc. — named heuristic.
- `command:<shell>` — run a shell command that prints a numeric score on stdout.
**Default:** `test_command` if `test_command` is set; otherwise required when `selection_mode=auto-best`.

**Cross-refs:**

- [`criteria` (constraints.md)](./constraints.md#criteria) — prompt-form rankers typically consume `criteria`.
- [`test_command` (constraints.md)](./constraints.md#test_command) — the most common `ranker`.
- [`selection_mode` (this file)](#selection_mode) — `ranker` is only consulted when `selection_mode=auto-best`.

**Example:** `ranker=prompt:.cursor/rankers/security-grade.md` — each candidate is scored 1–10 by a critic agent reading the security rubric.

---

### `aggregator`

**Aliases:** `candidate_aggregator`, `synthesizer`, `merger`
**Definition:** The callable used to *combine* candidates into a single composite when `selection_mode=synthesize`.
**Type:** One of:
- `prompt:<path>` — invoke a synthesizer agent with the given prompt and all candidate outputs as context.
- `command:<shell>` — run a shell command that consumes candidates and emits a composite.
- `builtin:diff-merge` — merge candidate diffs with conflict markers.
**Default:** Required when `selection_mode=synthesize`.

**Cross-refs:**

- [`selection_mode` (this file)](#selection_mode) — `aggregator` is only consulted when `selection_mode=synthesize`.
- [`output_format` (io.md)](./io.md#output_format) — the aggregator's output is rendered using `output_format`.
- [`merge_count` (lifecycle.md)](./lifecycle.md#merge_count) — synthesis is typically `merge_count=one` regardless of how many were aggregated.

**Example:** `selection_mode=synthesize aggregator=prompt:.cursor/synthesizers/critique-merge.md` — N critique reports become one merged critique report.

---

### `compare_against`

**Aliases:** `baseline`, `reference`
**Definition:** A baseline artifact against which candidates are compared for refinement-style runs (e.g. "is this refined prompt better than the original?").
**Type:** Same resolver family as `context` (see [io.md](./io.md)): `file | directory | inline`.
**Default:** Unset (no baseline comparison; candidates are judged absolutely against `criteria` instead).

**Cross-refs:**

- [`criteria` (constraints.md)](./constraints.md#criteria) — `compare_against` provides the *baseline*; `criteria` provides the *comparison rubric*.
- [`require_diff` (reporting.md)](./reporting.md#require_diff) — frequently set together so the report shows candidate-vs-baseline diffs.
- [`ranker` (this file)](#ranker) — refinement rankers consume both the candidate and `compare_against`.

**Example:** `/meta-prompt refine=existing.md compare_against=existing.md criteria=./criteria/prompt-quality.md` — refined candidates are ranked against the original.
