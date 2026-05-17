# Scope: `leaf` (terminal)

The **leaf scope** is any node in the tree that does **not** spawn children. Leaves do the actual concrete work — they read files, write code, run tests, produce reports. They are the only scope that **must** BUBBLE outputs back up the tree because they are the only scope that produces atomic results.

A leaf's identity is denoted by the same indexed path as a subagent, terminating in a node with no children:

- `root.leaf[i]` — the i-th direct leaf child of root (depth-1 tree, e.g. `critique.md`).
- `root.subagent[i].leaf[j]` — the j-th leaf grandchild via subagent `i` (depth-2 tree, e.g. `worktree-task-agent.md` with partitions).
- More generally `root.subagent[...].subagent[...].leaf[i_k]`.

A leaf is structurally identical to a subagent **except**:

1. It does not re-bind any of the *fan-out* parameters (`fan_out`, `parallel`, `num_partitions`, `k`, `num_experiments`, `subagent_*`, `depth > 0`). Attempting to spawn a child from a leaf is a tree-shape violation.
2. It owns the **bubbled output** parameters (section M below), which are the only "outputs" of the parameter system — every parameter elsewhere is an *input* to some scope, but bubbled outputs are *produced* by the leaf and *consumed* upward.

> **Resolution.** Most leaf input parameters resolve from the leaf's parent (a subagent) — see `1-subagent.md`. The leaf's contribution is to (a) execute concrete work and (b) bind the bubbled-output parameters of section M.

---

## Originating parameters (concrete-only)

These are bound at leaf scope but typically not at higher scopes — they pin down the **concrete** values that root and subagents had only as templates or lists.

### `leaf.slot`
- **Definition.** 1-based ordinal among siblings under the leaf's immediate parent. Same semantics as `subagent.slot`.
- **Inheritance.** Originates here.
- **Type.** `int_range >= 1`.
- **Default.** Required.
- **Example.** `root.subagent[1].leaf[2].slot = 2`.

### `leaf.id`
- **Definition.** Globally unique identifier for this leaf within the run, useful for log correlation.
- **Inheritance.** Originates here.
- **Type.** `string` (e.g. `"oauth-login-1.leaf-2"`).
- **Default.** Auto-generated from full scope path.
- **Example.** `root.subagent[3].leaf[1].id = "run-abc.subagent-3.leaf-1"`.

### `leaf.start_time`, `leaf.end_time`
- **Definition.** Wall-clock timestamps for leaf execution; `end_time` BUBBLES.
- **Inheritance.** Originates here. `end_time` BUBBLES.
- **Type.** ISO-8601 timestamp.
- **Default.** Set automatically by the dispatcher.
- **Example.** `root.leaf[1].start_time = "2026-05-16T23:30:00Z"`.

---

## A. Task / Intent (concrete)

### `leaf.task`
- **Definition.** The concrete imperative this leaf executes; once a leaf binds `task`, it is fully resolved (no further slicing).
- **Inheritance.** SHADOW (typically `parent.task` verbatim or with the leaf's `slot` substituted into a template).
- **Type.** `string | markdown`.
- **Default.** Required.
- **Example.** `root.subagent[1].leaf[1].task = "implement OAuth login (slot 1, focus: tighten guardrails)"`.

### `leaf.input`, `leaf.context`
- **Definition.** Verbatim input string and consumed artifact set, as resolved at this leaf.
- **Inheritance.** INHERIT from parent subagent (or SHADOW when the parent partitioned context).
- **Type.** As in `0-root.md`.
- **Default.** Inherited.
- **Example.** `root.leaf[1].context = {kind: "file", path: "src/auth.ts"}`.

---

## B. File I/O (concrete)

### `leaf.file`, `leaf.directory`, `leaf.glob`, `leaf.url`, `leaf.inline`
- **Definition.** Same shapes as in root; resolved to concrete paths at this leaf.
- **Inheritance.** INHERIT.
- **Type.** As in `0-root.md` section B.
- **Default.** Inherited.
- **Example.** `root.subagent[1].leaf[1].file = "src/auth.ts"`.

### `leaf.format`, `leaf.file_type`
- **Definition.** As in root.
- **Inheritance.** INHERIT.
- **Type.** As in `0-root.md` section B.

### `leaf.save_path`
- **Definition.** Where this leaf writes its in-worktree product before BUBBLING the artifact reference up.
- **Inheritance.** SHADOW — `leaf.save_path = leaf.parent.worktree_path + leaf.parent.save_path_rel`.
- **Type.** Absolute `path`.
- **Default.** Derived.
- **Example.** `root.leaf[1].save_path = "/.../worktrees/run-abc/oauth-login-1/.cursor/commands/oauth.md"`.

### `leaf.output_format`
- **Definition.** Required structure of this leaf's bubbled output.
- **Inheritance.** SHADOW from parent's `subagent_prompt` or built-in.
- **Type.** Markdown template | enum.
- **Default.** Determined by `subagent_type`.

---

## C. Constraints (concrete, INHERITED)

### `leaf.criteria`, `leaf.guardrails`, `leaf.stop_condition`, `leaf.test_command`
- **Definition.** Same as in subagent; resolved to concrete values at the leaf.
- **Inheritance.** INHERIT (always); guardrails additive only.
- **Type.** As in `0-root.md` section C.
- **Default.** Inherited.
- **Example.** `root.leaf[1].test_command = "pytest tests/auth/"`.

---

## D. Models / Diversity (concrete)

### `leaf.model`
- **Definition.** The model executing this leaf — fully resolved (no list, no broadcast).
- **Inheritance.** SHADOW from `parent.model` (already resolved at subagent scope).
- **Type.** Model identifier (always scalar).
- **Default.** Inherited.
- **Example.** `root.leaf[3].model = "claude-opus-4"`.

### `leaf.seed`
- **Definition.** The seed actually fed to the leaf's model.
- **Inheritance.** SHADOW (`leaf.seed = parent.seed + leaf.slot`).
- **Type.** `int`.
- **Default.** Derived.
- **Example.** `root.leaf[3].seed = 1237`.

### `leaf.temperature`, `leaf.focus_hint`
- **Definition.** As in subagent; resolved to scalars at leaf.
- **Inheritance.** INHERIT (`temperature`); SHADOW (`focus_hint`).
- **Type.** `float [0, 2]`; `string | null`.
- **Default.** Inherited.

---

## E. Workspace (concrete)

### `leaf.worktree_path`, `leaf.branch`
- **Definition.** As in subagent; for leaves without a wrapping subagent (depth-1 tree with worktree per leaf), the leaf scope ORIGINATES these.
- **Inheritance.** When parent is a subagent: INHERIT. When parent is root and `root.isolation = worktree`: ORIGINATES.
- **Type.** `path`; git branch name.
- **Default.** Derived.
- **Example.** `root.leaf[3].worktree_path = "/.../worktrees/run-abc/oauth-login-3"`.

### `leaf.cwd`
- **Definition.** The working directory the leaf process actually runs from (often equal to `worktree_path`).
- **Inheritance.** Originates here.
- **Type.** `path`.
- **Default.** `leaf.worktree_path` if isolation is on; otherwise `process.cwd()`.

---

## F. Robustness (concrete)

### `leaf.timeout`
- **Definition.** Wall-clock budget for *this* leaf execution.
- **Inheritance.** INHERIT.
- **Type.** Duration.
- **Default.** Inherited.
- **Example.** `root.leaf[1].timeout = "10m"`.

### `leaf.attempt`
- **Definition.** 1-based attempt counter; incremented when `parent.retry_policy` re-launches this leaf.
- **Inheritance.** Originates here. BUBBLES (see section M).
- **Type.** `int_range >= 1`.
- **Default.** `1`.
- **Example.** `root.leaf[1].attempt = 2` (this is the second attempt after a hang).

---

## M. Bubbled outputs (LEAF-ORIGINATED, READ-UP)

> This section is unique to the leaf scope. Every parameter here is **produced** by the leaf at completion and **read by ancestors** as it bubbles up the tree. See `inheritance.md#bubble`.

### `leaf.status`
- **Definition.** The terminal disposition of this leaf's execution.
- **Inheritance.** BUBBLE (read at `parent.subagent[i].leaf[j].status`, then aggregated as `parent.children_statuses` at each ancestor).
- **Type.** Enum `success | failed | incomplete | hung | aborted`.
- **Default.** Set automatically.
- **Example.** Root reads `root.subagent[1].leaf[2].status = "success"`.

### `leaf.result`
- **Definition.** The primary artifact this leaf produced (text, diff, prompt, finding list, …).
- **Inheritance.** BUBBLE.
- **Type.** Tagged union `{text, diff, prompt, findings, json, file_ref}`.
- **Default.** Required when `status = success`.
- **Example.** `root.leaf[1].result = {kind: "diff", path: "<worktree>/.git/diffs/HEAD..base.diff"}`.

### `leaf.diff`
- **Definition.** Convenience view of `leaf.result` when the result is a diff (cf. `git diff base..HEAD` inside `worktree_path`).
- **Inheritance.** BUBBLE.
- **Type.** `string` (unified diff).
- **Default.** Empty when result is not a diff.
- **Example.** Root reads `root.leaf[1].diff` to render the report block in `worktree-task-agent.md`'s output.

### `leaf.verification`
- **Definition.** Outcome of `test_command`.
- **Inheritance.** BUBBLE.
- **Type.** Record `{exit_code: int, stdout_tail: string, stderr_tail: string, elapsed_ms: int}`.
- **Default.** `null` when no `test_command` is set.
- **Example.** `root.leaf[1].verification = {exit_code: 0, stdout_tail: "27 passed", elapsed_ms: 4321}`.

### `leaf.change_summary`
- **Definition.** Short bullets describing what the leaf changed and why (1-5 bullets).
- **Inheritance.** BUBBLE.
- **Type.** `list[string]`.
- **Default.** Required when `status = success`.
- **Example.** `root.leaf[1].change_summary = ["added OAuth provider class", "wired into AuthMiddleware", "covered by 8 new tests"]`.

### `leaf.terminal_log`
- **Definition.** Captured stdout/stderr from the leaf's terminal session.
- **Inheritance.** BUBBLE (filtered when `parent.include_terminal_log = false`).
- **Type.** `string` (may be truncated).
- **Default.** Captured automatically.
- **Example.** Root logs `root.leaf[1].terminal_log` only when `root.include_terminal_log = true`.

### `leaf.exit_code`
- **Definition.** Process-level exit code of the leaf's overall execution (not just `test_command`).
- **Inheritance.** BUBBLE.
- **Type.** `int`.
- **Default.** `0` for success, non-zero otherwise.
- **Example.** `root.leaf[1].exit_code = 0`.

### `leaf.elapsed_ms`
- **Definition.** Total wall-clock time the leaf executed for.
- **Inheritance.** BUBBLE.
- **Type.** `int_range >= 0` (milliseconds).
- **Default.** Measured.
- **Example.** `root.leaf[1].elapsed_ms = 18432`.

### `leaf.attempts_made`
- **Definition.** Final value of `leaf.attempt` once the leaf settles.
- **Inheritance.** BUBBLE.
- **Type.** `int_range >= 1`.
- **Default.** `1`.
- **Example.** `root.leaf[1].attempts_made = 2`.

### `leaf.findings` (analysis-shaped commands only)
- **Definition.** Structured per-criterion findings produced by an analysis leaf.
- **Inheritance.** BUBBLE — root aggregates findings across replicas (e.g. `critique.md`'s convergent / divergent reduction).
- **Type.** `list[{location, criterion, severity, evidence, rationale, run_id}]`.
- **Default.** Empty list when no findings.
- **Example.** `root.leaf[1].findings = [{location: "src/auth.ts:42", criterion: "robustness", severity: "major", evidence: "no null check", rationale: "throws on missing token"}]`.

### `leaf.error`
- **Definition.** Structured error info when `status != success`.
- **Inheritance.** BUBBLE.
- **Type.** Record `{kind: "hang"|"crash"|"validation"|"guardrail"|"unknown", message: string, traceback?: string}`.
- **Default.** `null` on success.
- **Example.** `root.leaf[1].error = {kind: "hang", message: "no progress for 10m"}`.

### `leaf.merge_recommendation`
- **Definition.** Per-leaf recommendation for whether the parent should merge this leaf's branch.
- **Inheritance.** BUBBLE — root collects these and applies `selection_mode` to pick the actual merge target.
- **Type.** Record `{action: "merge"|"skip"|"hold", reason: string}`.
- **Default.** Computed from `status`, `verification`, `stop_condition`.
- **Example.** `root.leaf[1].merge_recommendation = {action: "merge", reason: "tests passed, stop_condition met, no conflicts"}`.

---

## Summary table

| Family | Param | Originates here? | Inheritance | Type | Default |
|---|---|---|---|---|---|
| – | `slot` | yes | — | int >= 1 | required |
| – | `id` | yes | — | string | derived |
| – | `start_time` | yes | — | ISO-8601 | set by dispatcher |
| – | `end_time` | yes | BUBBLE | ISO-8601 | set on completion |
| A | `task` | no | SHADOW | string | required |
| A | `input`, `context` | no | INHERIT/SHADOW | as in root | inherited |
| B | `file`, `directory`, `glob`, `url`, `inline` | no | INHERIT | as in root | inherited |
| B | `format`, `file_type` | no | INHERIT | as in root | inherited |
| B | `save_path` | no | SHADOW (rebased) | path | derived |
| B | `output_format` | no | SHADOW | template | per `subagent_type` |
| C | `criteria`, `guardrails`, `stop_condition`, `test_command` | no | INHERIT | as in root | inherited |
| D | `model` | no | SHADOW | id | inherited |
| D | `seed` | no | SHADOW (offset) | int | derived |
| D | `temperature` | no | INHERIT | float | inherited |
| D | `focus_hint` | no | SHADOW | string \| null | inherited |
| E | `worktree_path`, `branch` | sometimes | INHERIT or originates | path; git ref | derived |
| E | `cwd` | yes | — | path | `worktree_path` |
| F | `timeout` | no | INHERIT | duration | inherited |
| F | `attempt` | yes | BUBBLES `attempts_made` | int >= 1 | 1 |
| **M** | `status` | yes | **BUBBLE** | enum | computed |
| **M** | `result` | yes | **BUBBLE** | tagged union | required on success |
| **M** | `diff` | yes | **BUBBLE** | string | empty if non-diff |
| **M** | `verification` | yes | **BUBBLE** | record | null when no test |
| **M** | `change_summary` | yes | **BUBBLE** | list[string] | required on success |
| **M** | `terminal_log` | yes | **BUBBLE** | string | captured |
| **M** | `exit_code` | yes | **BUBBLE** | int | 0 on success |
| **M** | `elapsed_ms` | yes | **BUBBLE** | int >= 0 | measured |
| **M** | `attempts_made` | yes | **BUBBLE** | int >= 1 | 1 |
| **M** | `findings` | yes | **BUBBLE** | list[record] | [] |
| **M** | `error` | yes | **BUBBLE** | record \| null | null on success |
| **M** | `merge_recommendation` | yes | **BUBBLE** | record | computed |

**Total leaf parameters:**
- 4 originating identity / timing
- 18 inherited / shadowed inputs (see rows above)
- 11 bubbled outputs (section M)
- = **33 leaf parameters**.
