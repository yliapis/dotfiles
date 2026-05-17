# Stage 3 — Execute

**Position in lifecycle:** runs after **plan** has emitted an execution graph. Runs before **evaluate**.

**Purpose:** actually run the agents. Spin up the slots plan specified, hand each its prompt + model + sandbox + timeout, and collect raw outputs (diffs, reports, exit codes, terminal tails).

**Flows in:** the execution graph (slot definitions) and the resolved parameter bag.
**Flows out:** raw per-slot results — for each slot: status (`success` | `failed` | `incomplete`), produced artifacts (diff, text, files), `test_command` exit code (if run), captured logs.

**Skipped when:** **never in practice** — even a "no-op" command runs a trivial execute. The closest thing to a skipped execute is `meta-prompt.md` in HELP mode, which still runs a one-step "emit the help text" pseudo-execute.

**Key invariant:** execute is the **only** stage allowed to mutate the world (inside isolation boundaries). Plan is side-effect-free; evaluate is read-only; select is decision-only; persist mutates outside isolation (commits, merges); report is render-only.

---

## Models (the actual LLM that runs each slot)

### `model`

**Aliases:** `llm`, `agent_model`
**Definition:** Model identifier each slot runs on. `model` is the user-facing name when there's no nesting; `agent_model` is the conventional alias inside multi-slot commands like `worktree-task-agent.md`; `subagent_model` (see `2-plan.md`) is the inner-tree variant.
**Stages:** plan (assigned via `subagent_model`) → **execute (used)**.
**Depth:** **both.** Outer = the orchestrating model. Inner = each slot's model.
**Type:** model identifier string, or list of strings whose length equals `n_candidates` / `parallelism` (positional mapping).
**Default:** the parent agent's model (per both `critique.md` and `worktree-task-agent.md`).

**Examples:**

```
{model}        = "claude-opus-4"               # critique.md, broadcast
{agent_model}  = ["claude-opus-4", "gpt-5"]    # worktree-task-agent, per-slot
```

From `worktree-task-agent.md`:

> "Accepts a single model identifier (broadcast to every agent) or a list of identifiers whose length MUST equal `{parallelism}` (mapped positionally by index)."

The list-length validation lives in plan (it's a topology check); execute simply consumes the assignment.

---

## Runtime verification command (run during execute, exit code consumed during evaluate)

### `test_command`

**Aliases:** `verify_command`, `check_command`
**Definition:** A shell command run inside each slot's workspace after the slot reports its agent task complete. Exit code `0` counts as pass; any other exit code counts as fail.
**Stages:** input (read) → **execute (run)** → evaluate (exit code consumed) → report (surfaced per-slot).
**Depth:** both. Outer = a meta-test run across all candidates' merged result (rare). Inner = per-slot test (the common case, as in `worktree-task-agent.md`).
**Type:** shell command string.
**Default:** none (no verification).

**Example:**

```
{test_command} = "pytest tests/unit -x"
{test_command} = "npm test && npm run typecheck"
```

From `worktree-task-agent.md`:

> "If `{test_command}` is provided, each agent runs it once inside its worktree and the captured exit code is reported per worktree."

Execute's responsibility: invoke the command in the slot's isolated workspace, capture exit code and a bounded log tail. Evaluate's responsibility: convert the exit code into a pass/fail signal for the ranker.

---

## Parameters from earlier stages that execute *consumes* (back-references)

Execute is the largest *consumer* stage — almost every parameter is read here even when "owned" elsewhere. Listed here briefly for traceability; canonical definitions remain in their home stage.

| Parameter             | Home stage | What execute does with it                                  |
| --------------------- | ---------- | ---------------------------------------------------------- |
| `task`                | input      | each slot's agent receives its `subagent_prompt`-templated form |
| `context`             | input      | loaded into each slot's working set                        |
| `guardrails`          | input      | enforced as MUST / MUST-NOT rules during the agent loop   |
| `stop_condition`      | input      | consulted to decide when to stop                           |
| `subagent_prompt`     | plan       | the literal text the slot's agent is launched with         |
| `subagent_type`       | plan       | drives tool restrictions, system prompt selection          |
| `subagent_constraints`| plan       | enforced like outer guardrails, layered on top             |
| `focus_hints[i]`      | plan       | templated into slot `i`'s prompt                           |
| `seed`, `temperature` | plan       | forwarded to the model API call                            |
| `timeout`             | plan       | wall-clock deadline per slot                               |
| `relaunch_on_hang_after`, `hang_policy` | plan | monitored: kill / restart per policy            |
| `retry_policy`        | plan       | re-run a failed slot up to `max_retries`                  |
| `isolation`           | plan       | which sandbox (worktree / container / none) is created   |
| `worktree_name`, `worktree_root`, `base_branch` | plan | how the worktree is named, where, from which ref |
| `parallel`            | plan       | wall-clock width — how many slots may execute concurrently |
| `n_candidates`        | plan       | total slot count to launch (in waves of `parallel`)      |

---

## Stage outputs (what execute *produces* for evaluate / report)

These are **not user-supplied parameters** — they are intermediate values plan and downstream stages reference. They earn names here because evaluate, select, persist, and report all need to refer to them.

### `slot_status`

**Definition:** Per-slot terminal state.
**Type:** enum `success | failed | incomplete`.
**Producer:** execute (one per slot).

From `worktree-task-agent.md`'s required per-worktree report fields:

> "`Status`: `success`, `failed`, or `incomplete`."

### `slot_artifact`

**Definition:** The concrete output a slot produces (a diff, a generated file, a markdown report, structured findings).
**Type:** depends on `subagent_type` and command — for code commands, typically a git diff; for analysis commands, structured findings.
**Producer:** execute.

### `slot_log_tail`

**Definition:** Bounded tail of the slot's terminal output, captured for downstream reporting.
**Type:** text, length governed by `include_terminal_log` at report time.
**Producer:** execute.

### `slot_test_exit_code`

**Definition:** Exit code of the per-slot `test_command`, when one was run.
**Type:** int (POSIX exit code range).
**Producer:** execute. **Consumer:** evaluate.

---

## Cross-stage notes

- **Execute respects every plan decision verbatim.** It does not re-plan. If a slot fails in a way that demands re-planning (e.g. a model identifier turns out invalid), execute returns control to the orchestrator, not silently re-derives.
- **Isolation boundary is sacred.** From `worktree-task-agent.md`:
  > "MUST keep each agent's task execution isolated to its assigned worktree; agents MUST NOT read, write, or run commands against the original working tree or any sibling worktree."
- **Hang handling is an open design area** (per `trajectory.md`):
  > "Hung subagents (2 of 8 in one batch) returned no diff and required interrupt + relaunch; there is no built-in 'minimum success count' or replacement policy."
  Execute is where `hang_policy` is actually enforced; the policy itself is a plan parameter.
- **Execute does not select winners.** Even when a slot is obviously the best one (only one passed `test_command`), execute reports facts; select decides.
