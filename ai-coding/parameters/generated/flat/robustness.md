# Robustness / Recovery (Category J)

Covers *timeouts*, *retries*, and *hang handling* — the parameters that decide what happens when a subagent or the orchestrator stalls or fails. The motivating observation from `trajectory.md`: "Hung subagents (2 of 8 in one batch) returned no diff and required interrupt + relaunch; there is no built-in minimum success count or replacement policy."

Under the flat angle, `timeout` and `retry_policy` split by layer so a long-running orchestrator does not inherit short subagent budgets and vice versa.

---

## `command_timeout`

**Aliases (deprecated under this angle):** `timeout` (at the orchestrator layer), `total_timeout`.
**Definition:** Total wall-clock budget for the entire command, from invocation to final reply. When exceeded, the orchestrator aborts every still-running subagent and reports timeout.
**Type:** duration string with unit (`s`, `m`, `h`). Numeric-only values are interpreted as seconds.
**Allowed values:** parsed as positive duration (`> 0s`).
**Default:** unset (no command-level timeout).
**Rename rationale (multi-depth):** the command budget is fundamentally different from a per-slot budget; `outer_k * subagent_timeout` may legitimately exceed `command_timeout` if `command_parallel > 1`, and that math is only stateable with distinct names.
**Consumed by:** orchestrator main loop; future production runners.
**Example:**

```
command_timeout: 30m
```

---

## `subagent_timeout`

**Aliases (deprecated under this angle):** `timeout` (at the slot layer), `slot_timeout`.
**Definition:** Wall-clock budget for one subagent slot, from launch to completion.
**Type:** duration string per slot, OR a scalar broadcast.
**Allowed values:** parsed as positive duration (`> 0s`) per entry.
**Default:** unset (no slot-level timeout; only `command_timeout` and `relaunch_on_hang_after` constrain).
**Rename rationale (multi-depth):** see `command_timeout`.
**Consumed by:** subagent launcher; combines with `relaunch_on_hang_after` for hang detection.
**Example:**

```
subagent_timeout: 5m
subagent_timeout: ["5m", "5m", "10m", "10m"]    # heavier per-slot budgets for slower slots
```

---

## `relaunch_on_hang_after`

**Aliases:** `hang_timeout`, `idle_timeout`.
**Definition:** Duration of no-output / no-progress after which the orchestrator treats a slot as hung and triggers `hang_policy`.
**Type:** duration string with unit (`s`, `m`, `h`).
**Allowed values:** `> 0s`.
**Default:** unset (hang detection disabled; slots only end at completion or `subagent_timeout`).
**Rename rationale (multi-depth):** layer-neutral (applies per slot but is set once at the orchestrator); kept short by convention. Introduced in `trajectory.md`.
**Consumed by:** future revisions of `worktree-task-agent`; reserved.
**Example:**

```
relaunch_on_hang_after: 90s
hang_policy: interrupt_and_replace
```

---

## `hang_policy`

**Aliases:** `on_hang`.
**Definition:** What the orchestrator does when a slot is detected as hung (per `relaunch_on_hang_after`).
**Type:** enum: `interrupt_and_replace` | `wait` | `abort`.
  - `interrupt_and_replace`: kill the hung slot, count it as failed, launch a replacement slot (subject to `command_retry_policy`).
  - `wait`: leave the slot running until `subagent_timeout` or `command_timeout` fires.
  - `abort`: kill the hung slot, count it as failed, do not replace.
**Default:** `wait` (matches today's manual recovery behavior).
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** future revisions of `worktree-task-agent`.
**Example:**

```
hang_policy: interrupt_and_replace
```

---

## `command_retry_policy`

**Aliases (deprecated under this angle):** `retry_policy` (at the orchestrator layer).
**Definition:** Retry policy for the orchestrator's own retryable failures (e.g., transient orchestrator-side errors, not subagent failures).
**Type:** structured object with sub-fields:
  - `max_retries`: integer, `int_range: ">= 0"`. Default `0`.
  - `backoff`: enum `none` | `linear` | `exponential`. Default `none`.
  - `base_delay`: duration string. Default `0s`.
**Default:** `{max_retries: 0, backoff: none, base_delay: 0s}` (no retries).
**Rename rationale (multi-depth):** orchestrator retries and per-slot retries are fundamentally different failure modes (one rebuilds an entire run, the other replaces a slot); reusing one name made the math wrong (e.g., total possible work = `command_retries * (outer_k * (1 + subagent_retries))`).
**Consumed by:** orchestrator outer loop.
**Example:**

```
command_retry_policy:
  max_retries: 2
  backoff: exponential
  base_delay: 5s
```

---

## `subagent_retry_policy`

**Aliases (deprecated under this angle):** `retry_policy` (at the slot layer).
**Definition:** Retry policy applied per slot when a subagent reports a retryable failure (including hangs replaced by `interrupt_and_replace`).
**Type:** same structured-object shape as `command_retry_policy`.
**Default:** `{max_retries: 0, backoff: none, base_delay: 0s}`.
**Rename rationale (multi-depth):** see `command_retry_policy`.
**Consumed by:** subagent launcher; combines with `hang_policy` to define replacement behavior.
**Example:**

```
subagent_retry_policy:
  max_retries: 1
  backoff: linear
  base_delay: 10s
```

---

## `failure_classification`

**Aliases:** `failure_kind`.
**Definition:** How the orchestrator classifies a subagent failure, which gates which retry policy applies.
**Type:** enum: `retryable` | `permanent` | `transient_network` | `oom` | `tool_denied` | `unknown`.
**Default:** classification is computed by the orchestrator from the failure signal (exit code, exception type, log scan); users typically read this rather than set it. It is exposed as a parameter so that workflow definitions can match on it for routing decisions.
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** reporter output (`Status` field in `worktree-task-agent.md` could be enriched with this); reserved for future selection-mode routing.
**Example:**

```
# read-only: emitted by the orchestrator per slot
failure_classification: transient_network
```
