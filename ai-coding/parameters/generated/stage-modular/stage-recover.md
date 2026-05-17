# Stage: `recover`

## Purpose
Apply timeout / hang / retry policy to `execute`. Wraps an execution stage and re-emits its results enriched with `final_status` and `recovery_attempts`, replacing hung/failed runs with retries or abandoning them per policy.

## Position
Wraps `execute`. Conceptually a decorator: `recover(execute)` instead of an in-line stage. Recorded as its own stage so the recovery params have an unambiguous home.

## Input Contract

### Required
- `execute_stage` (ref) — reference to the `execute` instance being wrapped (e.g., `execute[0]`).

### Optional
- `timeout` (duration, default: `null` — wait indefinitely) — per-job hard wall clock budget; jobs exceeding this are aborted.
- `relaunch_on_hang_after` (duration, default: `null`) — softer timeout: if a job produces no terminal output for this duration, treat it as hung and trigger the configured `hang_policy`.
- `hang_policy` (enum: `abort` | `retry` | `replace`, default: `abort`) — what to do when a job hangs.
  - `abort`: kill the job; mark `final_status: incomplete`.
  - `retry`: kill and re-launch the same `job_spec` (preserving index and isolation).
  - `replace`: kill, then if `fan-out` is the predecessor, request a replacement `job_spec` from a diversification policy (e.g., next-best model) — falls back to `retry` if the predecessor was `replicate`.
- `retry_policy` (map, default: `{ max_attempts: 1 }`) — retry semantics:
  - `max_attempts` (int, int_range: `>= 1`, default: `1`) — counting the initial attempt.
  - `backoff` (enum: `none` | `linear` | `exponential`, default: `none`).
  - `retry_on` (list<enum: `failed` | `incomplete` | `nonzero-exit`>, default: `[incomplete]`).
- `cooldown_between_attempts` (duration, default: `0s`) — sleep between retries.
- `min_successes` (int, int_range: `>= 0`, default: `0`) — minimum number of jobs that MUST achieve `final_status: success` for the wrapped stage to be considered satisfied; surfaced as a flag, not enforced (enforcement is in `aggregate`).

## Output Contract

- `executions` (list<execution_result>) — same shape as `execute.executions`, with the following additions per record:
  - `final_status` (enum: `success` | `failed` | `incomplete` | `aborted`) — terminal verdict after recovery.
  - `recovery_attempts` (int) — number of attempts made (1 if no retry needed).
  - `attempt_log` (list<{ attempt, status, reason }>) — per-attempt trail.
  - `was_replaced` (bool) — `true` when the slot was filled by a `replace` policy substitution.
- `recover_summary` (map) — `{ total: int, succeeded: int, retried: int, aborted: int, replaced: int, min_successes: int, threshold_met: bool }`.

## Depth-Aware Aliasing

- `recover[0]` wraps `execute[0]`; `recover[1]` wraps `execute[1]`. Wrapping is depth-local: an outer `recover` does NOT recover inner-stage failures; those are the inner `recover`'s responsibility.
- `timeout` and `relaunch_on_hang_after` cascade inward by default (inner inherits outer values, halved as a heuristic), but explicit inner values override.
- `min_successes` does NOT cascade; each depth's threshold is independent (e.g., outer `min_successes: 5 / 8` does not imply inner `min_successes: 5 / 8`).

## Composition Rules

- Predecessor: the `execute` it wraps (and transitively whatever feeds that `execute`).
- Successor: any stage that would have followed the unwrapped `execute` (`evaluate`, `aggregate`, `select`, `persist`, `report`).
- `recover` MUST NOT change the input `job_spec`s; replacements come from re-running the same spec or from the diversification predecessor's substitution callback.
- `recover` MUST surface every recovery event in `attempt_log` so `report` can render an accurate audit.

## Examples

### Example 1: worktree-task-agent — retry once on hang, abort after that

```yaml
stage: recover
execute_stage: execute[0]
timeout: 30m
relaunch_on_hang_after: 8m
hang_policy: retry
retry_policy:
  max_attempts: 2
  retry_on: [incomplete]
  backoff: linear
cooldown_between_attempts: 30s
min_successes: 5
outputs:
  executions:
    # ... shape extends execute's output:
    - { index: 3, final_status: success, recovery_attempts: 2, was_replaced: false, attempt_log: [
          { attempt: 1, status: incomplete, reason: "no output for 8m" },
          { attempt: 2, status: success, reason: "completed in 14m" } ] }
    - { index: 5, final_status: aborted,  recovery_attempts: 2, attempt_log: [
          { attempt: 1, status: failed, reason: "subagent crash" },
          { attempt: 2, status: failed, reason: "subagent crash" } ] }
  recover_summary: { total: 8, succeeded: 6, retried: 2, aborted: 1, replaced: 0, min_successes: 5, threshold_met: true }
```

### Example 2: critique — no recovery (read-only, single-shot)

```yaml
stage: recover
execute_stage: execute[0]
timeout: null
hang_policy: abort
retry_policy: { max_attempts: 1 }
outputs:
  executions: <pass-through with final_status = status, recovery_attempts: 1 each>
  recover_summary: { total: 5, succeeded: 5, retried: 0, aborted: 0, replaced: 0, min_successes: 0, threshold_met: true }
```
