# Concern: Robustness / Recovery

> **Responsibility:** Declare *what happens when things hang, time out, or fail*. Robustness is about the operational quality of the run — it does not change the work or the result, it changes how reliably the run terminates and reports.
>
> **Primary parameters:** `timeout`, `retry_policy`, `hang_policy`

## Why this concern exists

In real fan-out runs, *some agents hang*. [`trajectory.md`](../plugins/ai-coding/commands/trajectory.md) documents the observed problem directly: "Hung subagents (2 of 8 in one batch) returned no diff and required interrupt + relaunch; there is no built-in minimum success count or replacement policy." Adding hang / retry / timeout knobs ad-hoc to each command duplicates logic and produces inconsistent behavior. This concern owns them.

The three parameters are deliberately layered: `timeout` is a *deadline*, `hang_policy` decides *what to do when the deadline hits without progress*, and `retry_policy` decides *what to do when a candidate failed* (independent of why). Together they describe the run's recovery behavior end-to-end.

## Parameters

### `timeout`

**Aliases:** `deadline`, `relaunch_on_hang_after`, `wall_clock_limit`
**Definition:** The maximum duration a candidate may run before being considered hung / failed.
**Type:** `duration` — ISO-8601 duration (`PT15M`) or shorthand (`15m`, `1h30m`, `90s`).
**Default:** Unset (no automatic timeout; user must manually interrupt).

**Cross-refs:**

- [`hang_policy` (this file)](#hang_policy) — decides what happens when `timeout` fires.
- [`retry_policy` (this file)](#retry_policy) — may interact with timeouts (e.g. retry once with a longer timeout).
- [`min_successes` (selection.md)](./selection.md#min_successes) — timed-out candidates count as failures against `min_successes`.

**Example:** `/worktree-task-agent task=X parallelism=8 timeout=20m hang_policy=relaunch` — any agent still running at 20m is auto-aborted and (per `hang_policy`) relaunched.

---

### `retry_policy`

**Aliases:** `retries`, `failure_policy`
**Definition:** What happens when a candidate completes with a failure (test failure, agent error, exit non-zero), independent of the reason.
**Type:** Struct:
- `max_retries` — `int_range >= 0`.
- `on` — `{test_failure, agent_error, any}`.
- `backoff` — `none | linear:<seconds> | exponential:<base>`.
- Or enum shorthand: `none`, `once`, `up-to-3-on-failure`.
**Default:** `none` (no automatic retries).

**Cross-refs:**

- [`min_successes` (selection.md)](./selection.md#min_successes) — `retry_policy` is a way to bring `successes` up to `min_successes`.
- [`hang_policy` (this file)](#hang_policy) — hang-induced failures may or may not consume retries depending on the chosen `hang_policy`.
- [`test_command` (constraints.md)](./constraints.md#test_command) — `on=test_failure` predicates on non-zero `test_command` exit.

**Example:** `/worktree-task-agent task=X parallelism=4 retry_policy={max_retries:1, on:test_failure, backoff:linear:30}` — each candidate gets one retry on test failure after a 30s wait.

---

### `hang_policy`

**Aliases:** `hang_recovery`, `on_hang`
**Definition:** What the workflow does when a candidate is judged to have hung (no progress for `timeout` or no completion signal within the deadline).
**Type:** Enum: `interrupt | relaunch | replace | fail | ignore`.
**Default:** `interrupt` when `timeout` is set; `ignore` (manual handling) when `timeout` is unset.

**Values:**

- `interrupt` — kill the hung agent and count it as a failure.
- `relaunch` — kill and re-spawn the same candidate (same model, same prompt).
- `replace` — kill and spawn a *new* candidate (different `agent_model` / `focus_hints` / `seed`).
- `fail` — kill the hung agent and abort the entire fan-out.
- `ignore` — leave the agent running and proceed (lets the user intervene manually); siblings finish without it.

**Cross-refs:**

- [`timeout` (this file)](#timeout) — defines when `hang_policy` fires.
- [`retry_policy` (this file)](#retry_policy) — `relaunch` and `replace` consume retry budget if any.
- [`min_successes` (selection.md)](./selection.md#min_successes) — `fail` aborts before checking quorum; `ignore` lets quorum decide the overall verdict.

**Example:** `/worktree-task-agent task=X parallelism=8 timeout=15m hang_policy=replace` — hung agents are killed and replaced with a fresh candidate that varies its model or seed, up to `retry_policy.max_retries`.
