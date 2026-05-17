# Stage 4 — Evaluate

**Position in lifecycle:** runs after **execute** has collected per-slot outputs. Runs before **select**.

**Purpose:** turn raw per-slot outputs into **judgments** — pass / fail signals, severity-tagged findings, ranking scores. Evaluate consumes `criteria` against `slot_artifact`s; it does not pick winners (that's select), and it does not commit or report anything (those are persist / report).

**Flows in:** per-slot outputs from execute (`slot_status`, `slot_artifact`, `slot_test_exit_code`, `slot_log_tail`), plus the criteria / ranker / `min_successes` / `compare_against` parameters from input.
**Flows out:** per-slot evaluation records — `{slot_id, pass: bool, score: ranking-comparable, findings: list, agreement: int (for convergent findings across runs)}`.

**Skipped when:** rarely. Commands that produce a single deterministic artifact and never verify it (e.g. `meta-prompt.md` in CREATE mode, where the "evaluate" is just the agent's own success-criteria self-check) have a degenerate evaluate stage. Most multi-candidate or test-gated commands have a substantive evaluate.

**Key invariant:** evaluate is **read-only on the world**. It may run `test_command`, `ranker`, judge prompts, and arbitrary heuristics — but it never writes outside the temp space the evaluator itself owns.

---

## Parameters whose primary semantic lives in evaluate

Most parameters here are *consumed from input or plan*; only a handful have evaluate as their home. The two new homes are below.

### `pass_predicate`

**Aliases:** `success_predicate`
**Definition:** The rule that turns `slot_test_exit_code` (and other signals) into a per-slot pass / fail boolean.
**Stages:** evaluate (defined and applied).
**Depth:** both. Outer = "did this whole invocation succeed?" Inner = "did this slot pass?"
**Type:** predicate. Common defaults:
   - `exit == 0` (for `test_command`)
   - `slot_status == "success" AND test_exit_code == 0`
   - `slot_status == "success"` when no `test_command`
**Default:** the conjunction of `slot_status == "success"` and (if `test_command` provided) `slot_test_exit_code == 0`.

**Example:**

```
{pass_predicate} = "status=success AND (test_exit_code is null OR test_exit_code=0)"
```

This is largely implicit in most current commands; naming it makes the contract explicit and overrideable (e.g. allow `incomplete` slots when the partial diff is still useful).

### `severity_scale`

**Aliases:** `severity_levels`
**Definition:** Ordered set of severity labels used for findings.
**Stages:** evaluate (assigned per finding) → report (rendered in severity buckets).
**Depth:** outer (rarely varies per slot).
**Type:** ordered enum. `critique.md` uses `critical | major | minor | nit`.
**Default:** `critical | major | minor | nit` (matches `critique.md`).

**Example:**

```
{severity_scale} = ["critical", "major", "minor", "nit"]
{severity_scale} = ["block", "warn", "info"]   # custom scale
```

---

## Parameters consumed in evaluate (canonical homes elsewhere)

| Parameter         | Home    | What evaluate does with it                                                |
| ----------------- | ------- | ------------------------------------------------------------------------- |
| `criteria`        | input   | the yardstick applied to each `slot_artifact`                            |
| `compare_against` | input   | baseline reference for relative ranking                                   |
| `test_command`    | input   | already *run* by execute; evaluate consumes its `slot_test_exit_code`   |
| `ranker`          | input   | the mechanism that orders surviving candidates                            |
| `guardrails`      | input   | post-hoc check that the agent didn't violate them                        |
| `stop_condition`  | input   | verified — did the slot actually meet the explicit stop condition?       |
| `min_successes`   | plan    | counted: if `count(pass==true) < min_successes`, fail the invocation     |
| `subagent_constraints` | plan | per-slot guardrail post-check, layered on top of outer `guardrails`   |
| `slot_*` outputs  | execute | the inputs of evaluate                                                    |

---

## Stage outputs (what evaluate produces for select / report)

### `slot_evaluation`

**Definition:** Per-slot judgment record.
**Type:** object — `{ slot_id, pass: bool, score: number | tuple, findings: list, notes: text }`.
**Producer:** evaluate.
**Consumer:** select (uses `pass` and `score`), report (uses `findings`).

### `convergence_record`

**Definition:** When `n_candidates > 1`, the per-finding agreement count — how many slots raised the same `{location, criterion}` finding.
**Type:** map `(location, criterion) → int`.
**Producer:** evaluate (during the aggregation pass).
**Consumer:** report (separates convergent vs. divergent findings).

From `critique.md`:

> "When `{num_experiments} > 1`, the report distinguishes convergent findings (raised by multiple runs) from divergent findings (raised by some) and records the agreement count per finding."

This convergence pass is an evaluate-stage operation, even though it is rendered in report.

### `gate_result`

**Definition:** The boolean answer to "did this invocation, as a whole, pass evaluate?" — typically `count(pass==true) >= min_successes`.
**Type:** bool, plus a structured reason when false.
**Producer:** evaluate.
**Consumer:** select (a `false` gate skips selection and routes to a fail-fast report).

---

## Cross-stage notes

- **Why evaluate is its own stage** even though it "borrows" most of its inputs: the *semantics* of judgment are distinct from the mechanics of running (`execute`) and the policy of picking a winner (`select`). Evaluate is the only place where:
   - `criteria` are applied,
   - `pass_predicate` converts raw exit codes to pass / fail,
   - convergence is computed across N runs.
- **Multi-run aggregation is central to evaluate, not select.** Select picks *among* judgments; evaluate produces them — including the cross-run agreement counts. This separation matters when a future `/refine-best-of-n` command (per `trajectory.md`) wants to swap `ranker` without rewriting the merge logic.
- **Read-only on the world:** evaluate may execute helper tools (linters, type checkers, judge models) — those run *inside* slot sandboxes or in a temp dir owned by the evaluator. Anything that would leave a trace on the user's working tree belongs in persist.
- **Evaluate has no `parallel` parameter of its own.** It can run judgments in parallel internally (e.g. judge-model calls for N candidates), but that's an implementation detail; the *exposed* fan-out belongs to plan / execute.
