# Stage: `execute`

## Purpose
Run one or more `job_spec`s — invoking the configured agent / model on the configured task — and return their raw execution results (status, exit codes, artifacts, diffs, terminal logs). Where the actual work happens.

## Position
Runs after `replicate` or `fan-out` (which produce `jobs[]`), and after `isolate` when isolation is enabled. Side effects: spawns subagents, writes inside assigned workspaces, runs `test_command`. Wrapped by `recover` when a recovery policy is set.

## Input Contract

### Required
- `jobs` (list<job_spec>) — produced by `replicate` or `fan-out`. Each `job_spec` carries the per-slot resolved fields below.

### Per-job_spec required
- `task` (string) — the work to do; usually `resolved_task` from `input-resolve`.
- `model` (model_id, aliases: `agent_model`, `subagent_model`) — model to invoke for this job.

### Per-job_spec optional
- `subagent_type` (enum: `general` | `worker` | `verifier` | `custom`, default: `general`) — subagent role.
- `subagent_prompt` (string | path, default: derived from `task`) — explicit prompt override (e.g., for verifier subagents).
- `subagent_constraints` (list<string>, default: `[]`) — additional guardrails injected into the subagent's system prompt.
- `context` (list<artifact>, default: `[]`) — usually `resolved_context` from `input-resolve`.
- `guardrails` (list<string>, default: `[]`) — execution-time constraints (e.g., "MUST NOT push to remote").
- `stop_condition` (string, default: `null`) — explicit completion condition beyond "task implemented and verified".
- `test_command` (command, default: `null`) — shell command run inside the workspace after the agent reports completion; exit code captured.
- `seed` (int, default: `null`) — passed to the model when supported.
- `temperature` (float, default: model default) — passed to the model when supported.
- `isolation_id` (string, default: `null`) — binding to an `isolation_record`; when set, `cwd = isolation_record.worktree_path`.
- `working_directory` (path, default: parent CWD or `isolation_record.worktree_path`) — explicit override.

### Pipeline-level optional
- `parallel` (int, int_range: `>= 1`, default: `len(jobs)`) — max concurrent job executions.
- `dispatch_strategy` (enum: `eager` | `staggered` | `partitioned`, default: `eager`) — when `partitioned`, jobs of the same `partition_id` run together but partitions stagger.

## Output Contract

- `executions` (list<execution_result>) — one per input job, in input order. Each `execution_result`:
  - `index` (int) — mirrors `job.index`
  - `partition_id` (int | null)
  - `model` (model_id)
  - `status` (enum: `success` | `failed` | `incomplete`)
  - `exit_code` (int | null) — from `test_command` when present, else `null`
  - `terminal_log` (string) — captured stdout/stderr tail (length bounded by `report.include_terminal_log`)
  - `diff` (string | null) — `git diff base_branch..HEAD` inside the workspace, when isolation is `worktree`
  - `artifacts` (list<{ path, kind, bytes }>) — created/modified files
  - `summary` (string) — agent's own change summary (1–5 bullets)
  - `stop_condition_met` (bool | null)
  - `duration_ms` (int)
  - `error` (string | null) — populated when `status != success`
- `execute_summary` (map) — `{ total: int, succeeded: int, failed: int, incomplete: int, parallel: int }`.

## Depth-Aware Aliasing

- `execute[0]` is the outer execution; `execute[1]` is a nested execution (e.g., inside an outer slot a verifier subagent runs another `execute` to grade the work).
- `parallel` cascades inward: inner `parallel` defaults to `1` (sequential) regardless of outer setting, because inner concurrency × outer concurrency easily exceeds budgets. Explicit override required.
- `model` does NOT cascade across depths; each `execute` instance resolves its own from its `jobs[].model` field.
- `isolation_id` cascades: an inner `execute` inherits the outer `cwd` unless it has its own `isolation_id` from a nested `isolate`.

## Composition Rules

- Predecessors: `replicate` or `fan-out` (both produce compatible `jobs[]`).
- Successors: `recover` (wraps), `evaluate`, `aggregate`, `select`, `persist`, `report`.
- Wrapper relationship: `recover` does not produce its own jobs; it wraps `execute` and re-emits its outputs with recovery metadata.
- MUST honor `isolation_id` bindings; an execution MUST NOT read/write outside its assigned `worktree_path` (matches `worktree-task-agent.md` guardrail).
- MUST NOT mutate `template`, `jobs`, or outputs of earlier stages.

## Examples

### Example 1: worktree-task-agent — 8 parallel agent runs, each in its own worktree

```yaml
stage: execute
jobs: <from fan-out output, len=8>
parallel: 8
dispatch_strategy: eager
outputs:
  executions:
    - { index: 1, model: opus,   status: success,    exit_code: 0,   duration_ms: 184_000, diff: "...", summary: "...", stop_condition_met: true }
    - { index: 2, model: opus,   status: success,    exit_code: 0,   ... }
    - { index: 3, model: sonnet, status: incomplete, exit_code: null, error: "hung at minute 12", terminal_log: "..." }
    - { index: 4, model: sonnet, status: success,    exit_code: 1,   summary: "...", terminal_log: "1 test failed" }
    - { index: 5, model: haiku,  status: failed,     exit_code: null, error: "subagent crashed" }
    - { index: 6, ... }
    - { index: 7, ... }
    - { index: 8, ... }
  execute_summary: { total: 8, succeeded: 5, failed: 1, incomplete: 2, parallel: 8 }
```

### Example 2: critique — 5 read-only runs (no isolation, no test_command)

```yaml
stage: execute
jobs: <from replicate output, len=5>
parallel: 3
outputs:
  executions:
    - { index: 1, status: success, diff: null, summary: "12 findings: 1 critical, 3 major, 5 minor, 3 nit" }
    - { index: 2, status: success, diff: null, summary: "10 findings: 1 critical, 2 major, 4 minor, 3 nit" }
    - { index: 3, ... }
    - { index: 4, ... }
    - { index: 5, ... }
  execute_summary: { total: 5, succeeded: 5, failed: 0, incomplete: 0, parallel: 3 }
```
