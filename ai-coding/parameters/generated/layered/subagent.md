# `subagent.*` — Parameters of a Single Subagent Slot

The `subagent.*` namespace describes the **execution plane**: every parameter that lives *inside one subagent slot*. A `subagent.*` parameter is read by that single subagent (typically supplied to it by the orchestrator at launch time) or reported back by it. It is NEVER the same value as the like-named `command.*` parameter, even when the orchestrator broadcasts unchanged — the semantic scope shrinks to "this slot only".

This file is also the canonical place to describe parameters whose meaning is *intrinsically scoped to one slot*: `subagent.worktree_path`, `subagent.slot_index`, `subagent.status`, etc.

**Read order:** read `shared.md` for value-type references, then this file alongside `command.md`, then `cross-layer.md` for the resolution rules that bind `command.*` to `subagent.*`.

---

## Convention reminder

- A subagent reads its `subagent.*` parameters as effectively read-only inputs (with one exception: *outbound* parameters like `subagent.status` and `subagent.summary` are values the subagent *produces*, not consumes).
- "Defaulted from `command.X`" in the Default cell means: when the orchestrator does not explicitly set the subagent value, it derives it from the named `command.*` parameter per the rule in `cross-layer.md`.
- The subagent does NOT see the orchestrator's `command.*` namespace directly; only the resolved `subagent.*` parameters.

---

## Index

### Identity / intent
- `subagent.slot_index`, `subagent.task`, `subagent.context`

### File I/O
- `subagent.save_path`, `subagent.output_format`

### Constraints
- `subagent.criteria`, `subagent.guardrails`, `subagent.stop_condition`, `subagent.test_command`

### Models / sampling
- `subagent.model`, `subagent.seed`, `subagent.temperature`

### Inner concurrency
- `subagent.parallel`

### Isolation
- `subagent.worktree_path`, `subagent.base_branch`

### Robustness
- `subagent.timeout`, `subagent.retry_policy`

### Reporting (outbound)
- `subagent.status`, `subagent.summary`, `subagent.verification`, `subagent.diff`, `subagent.verbosity`

---

## Identity / intent

### `subagent.slot_index`

**Definition.** The 1-based index of this slot within the orchestrator's fan-out (`1..command.parallel`). Identifies the slot in logs, worktree names, and lists indexed by position.

**Cross-layer notes.** Has no `command.*` sibling — the orchestrator owns slot indexing.

**Type.** `int with shared.int_range [1, command.parallel]`.

**Default.** Required (assigned by orchestrator).

**Example.**
```text
subagent.slot_index: 3
```

---

### `subagent.task`

**Definition.** The scoped piece of work this slot must complete — typically a *rewrite* of `command.task` narrowed to this slot's responsibility (e.g., one focus hint, one partition, one criterion).

**Cross-layer notes.** Sibling root: `command.task` (the originating user-facing intent) and `skill.task` (a skill's activation trigger). The orchestrator MUST rewrite `command.task` into `subagent.task` per slot; it MUST NOT pass `command.task` verbatim unless every slot is doing the identical job. See `cross-layer.md § task`.

**Type.** `shared.inline`.

**Default.** Derived from `command.task` (per slot rewrite, possibly enriched with `command.focus_hints[slot_index-1]`).

**Example.**
```text
# command.task:        "Critique the parseConfig migration."
# command.focus_hints: ["security", "perf", "ergonomics", "tests"]
# subagent[2].task -> "Critique the parseConfig migration with a perf focus."
subagent.task: "Critique the parseConfig migration with a perf focus."
```

---

### `subagent.context`

**Definition.** The artifact(s) this slot operates on. May be the full `command.context` (broadcast), a partition of it (split per slot), or a derived view (e.g., one finding to evaluate).

**Cross-layer notes.** Sibling root: `command.context`. The mapping `command.context -> {subagent[i].context}` is `command.*` policy; `subagent.context` only records the resolved per-slot value. See `cross-layer.md § context`.

**Type.** `shared.addressable`.

**Default.** Derived from `command.context` (broadcast unless the command partitions).

**Example.**
```text
subagent.context: "./src/parseConfig.ts"
```

---

## File I/O

### `subagent.save_path`

**Definition.** Where this slot persists its intermediate / candidate artifact. Distinct from `command.save_path` — that is the merged / chosen / synthesized final, while `subagent.save_path` is one of several inputs to that selection.

**Cross-layer notes.** Sibling root: `command.save_path`. See `cross-layer.md § save_path`.

**Type.** `shared.path?`.

**Default.** Derived: `<command.worktree_root>/<command.worktree_name>-<slot_index>/.candidate.<format>` (or unset when the slot does not persist).

**Example.**
```text
subagent.save_path: "/tmp/wt/refine-3/candidate.md"
```

---

### `subagent.output_format`

**Definition.** The rendering contract this slot's output MUST satisfy. Typically a *structured* contract (JSON Schema, table) so the orchestrator can parse and aggregate.

**Cross-layer notes.** Sibling root: `command.output_format` (user-facing). The orchestrator may transform `subagent.output_format` outputs into the final `command.output_format`.

**Type.** `shared.output_format`.

**Default.** Derived from `command.output_format`, frequently downgraded to a structured form (e.g., `command.output_format = "markdown:report"` → `subagent.output_format = "json-schema:./schemas/finding.json"`).

**Example.**
```text
subagent.output_format: "json-schema:./schemas/finding.json"
```

---

## Constraints

### `subagent.criteria`

**Definition.** The criterion (or sub-rubric) THIS slot evaluates against. May equal the full `command.criteria` (broadcast) or a per-slot subset (one criterion per slot in a tournament).

**Cross-layer notes.** Sibling roots: `command.criteria`, `skill.criteria`. See `cross-layer.md § criteria`.

**Type.** `shared.addressable`.

**Default.** Derived from `command.criteria` (broadcast unless command partitions).

**Example.**
```text
subagent.criteria: "Determinism: outputs MUST be stable across runs given identical inputs."
```

---

### `subagent.guardrails`

**Definition.** The effective MUST / MUST NOT / Scope set this slot operates under. Always the *union* of `command.guardrails` ∪ `command.subagent_constraints` ∪ any skill's `skill.guardrails` that the subagent activates.

**Cross-layer notes.** Sibling roots: `command.guardrails`, `skill.guardrails`. Merge rule: union, with the strictest interpretation when constraints conflict. See `cross-layer.md § guardrails`.

**Type.** `shared.addressable` (list).

**Default.** Computed at orchestrator → subagent launch from the union above.

**Example.**
```text
subagent.guardrails:
  - MUST NOT modify the original working tree.
  - MUST NOT call WebFetch.
  - MUST stay inside {subagent.worktree_path}.
```

---

### `subagent.stop_condition`

**Definition.** This slot's completion bar. The subagent MUST NOT report `status: success` until the condition holds.

**Cross-layer notes.** Sibling root: `command.stop_condition` (broadcast by default).

**Type.** `shared.inline?`.

**Default.** Derived from `command.stop_condition`.

**Example.**
```text
subagent.stop_condition: "all tests under tests/parser/ pass"
```

---

### `subagent.test_command`

**Definition.** The shell command this slot runs to verify its own work before reporting `status`.

**Cross-layer notes.** Sibling root: `command.test_command` (broadcast). The exit code becomes `subagent.verification.exit_code`.

**Type.** `shared.shell_command?`.

**Default.** Derived from `command.test_command`.

**Example.**
```text
subagent.test_command: "pytest -q tests/parser/"
```

---

## Models / sampling

### `subagent.model`

**Definition.** The model identifier this single slot runs on.

**Cross-layer notes.** Sibling root: `command.model` (the *orchestrator's* model — NOT what subagents inherit) and `command.agent_model` (the *per-slot* model spec). Resolution: when `command.agent_model` is scalar, `subagent.model = command.agent_model`; when list-shaped, `subagent.model = command.agent_model[subagent.slot_index - 1]`; when unset, `subagent.model = command.model`. See `cross-layer.md § model`.

**Type.** `shared.model_id`.

**Default.** Resolved per the rule above.

**Example.**
```text
subagent.model: "gpt-5"
```

---

### `subagent.seed`

**Definition.** The RNG seed this slot uses.

**Cross-layer notes.** Sibling root: `command.seed`. By default `subagent.seed = command.seed + (subagent.slot_index - 1)` so siblings do not collapse to identical outputs.

**Type.** `shared.seed?`.

**Default.** Derived per the rule above (unset if `command.seed` is unset).

**Example.**
```text
subagent.seed: 44   # command.seed=42, slot 3
```

---

### `subagent.temperature`

**Definition.** The sampling temperature this slot uses.

**Cross-layer notes.** Sibling root: `command.temperature`. Often deliberately varied across slots for diversity.

**Type.** `shared.temperature?`.

**Default.** Derived from `command.temperature`.

**Example.**
```text
subagent.temperature: 0.9   # slot 3 in a diversity sweep
```

---

## Inner concurrency

### `subagent.parallel`

**Definition.** The maximum number of tools this **single subagent** runs concurrently inside its own loop (e.g., parallel file reads, parallel test shards). Distinct from `command.parallel`, which is the number of *subagents*, not the parallelism inside one of them.

**Cross-layer notes.** Sibling root: `command.parallel` — same root name, ORTHOGONAL semantics. NEVER inherited by default. See `cross-layer.md § parallel`.

**Type.** `int with shared.int_range >= 1`.

**Default.** `1`.

**Example.**
```text
command.parallel: 4    # four subagents
subagent.parallel: 8   # each subagent may run up to 8 inner tool calls in parallel
```

---

## Isolation

### `subagent.worktree_path`

**Definition.** The absolute path of the worktree this slot is bound to. The subagent MUST treat this as its filesystem root for all reads, edits, shell, and git operations.

**Cross-layer notes.** No `command.*` sibling with this exact name. Derived from `command.worktree_root`, `command.worktree_name`, and `subagent.slot_index`.

**Type.** `shared.directory`.

**Default.** Computed: `<command.worktree_root>/<command.worktree_name>[-<slot_index>]/`.

**Example.**
```text
subagent.worktree_path: "/Users/me/.cursor/worktrees/parse-config-toml/parse-config-toml-3"
```

---

### `subagent.base_branch`

**Definition.** The branch this slot's worktree was forked from. The subagent uses this as the diff base when reporting `subagent.diff`.

**Cross-layer notes.** Sibling root: `command.base_branch`. Broadcast unchanged.

**Type.** `shared.branch_ref`.

**Default.** Equals `command.base_branch`.

**Example.**
```text
subagent.base_branch: "main"
```

---

## Robustness

### `subagent.timeout`

**Definition.** Wall-clock budget for THIS slot. On exceeding, the orchestrator marks the slot per `command.hang_policy`.

**Cross-layer notes.** Sibling root: `command.timeout`. NOT derived — the per-slot budget defaults independently. See `cross-layer.md § timeout`.

**Type.** `shared.duration?`.

**Default.** Conservative default such as `15m`.

**Example.**
```text
subagent.timeout: "10m"
```

---

### `subagent.retry_policy`

**Definition.** Retry behaviour for the subagent's OWN internal tool calls (e.g., a failed shell or a transient API error). Distinct from `command.retry_policy`, which governs re-running the whole subagent.

**Cross-layer notes.** Sibling root: `command.retry_policy` — different scope (per-tool vs per-slot). NEVER inherited.

**Type.** Same composite shape as `command.retry_policy`.

**Default.** `{kind: fixed, max_retries: 1, backoff: 1s, retry_on: failure}`.

**Example.**
```text
subagent.retry_policy:
  kind: fixed
  max_retries: 2
  backoff: 2s
  retry_on: failure
```

---

## Reporting (outbound)

The parameters below are *produced* by the subagent and consumed by the orchestrator. They are part of `subagent.*` because their scope is one slot; they are NOT reflected back into `command.*`.

### `subagent.status`

**Definition.** The terminal status this slot reports to the orchestrator.

**Cross-layer notes.** Consumed by `command.min_successes`, `command.hang_policy`, `command.merge_count`, `command.auto_save_winner`.

**Type.** `shared.enum {success, failed, incomplete, hung}`.

**Default.** Required (subagent MUST set this on exit).

**Example.**
```text
subagent.status: "success"
```

---

### `subagent.summary`

**Definition.** A 1–5 bullet human-readable summary of what this slot did and why. Used in the per-slot section of the orchestrator's final report.

**Cross-layer notes.** No `command.*` sibling.

**Type.** `shared.inline` (markdown bullets).

**Default.** Required when `subagent.status = success`; optional otherwise.

**Example.**
```text
subagent.summary:
  - Migrated parseConfig to TOML using toml-rs.
  - Updated 4 call sites; no behaviour changes.
  - Added 3 fixture tests.
```

---

### `subagent.verification`

**Definition.** Structured outcome of running `subagent.test_command`: exit code, brief output tail, duration.

**Cross-layer notes.** Consumed by `command.ranker` (in `auto-best` mode) and `command.auto_save_winner`.

**Type.** Composite:
- `exit_code`: `shared.exit_code`
- `output_tail`: `shared.inline` (last ~20 lines, truncated)
- `duration`: `shared.duration`

**Default.** Required when `subagent.test_command` is set; `n/a` otherwise.

**Example.**
```text
subagent.verification:
  exit_code: 0
  output_tail: "12 passed in 0.42s"
  duration: 1.4s
```

---

### `subagent.diff`

**Definition.** Unified diff of this slot's changes against `subagent.base_branch`. Truncated above ~400 lines with a `... (truncated, K lines omitted)` marker.

**Cross-layer notes.** Consumed when `command.require_diff = true`.

**Type.** `shared.inline` (fenced ` ```diff ` block content).

**Default.** Required when `command.require_diff = true` and the slot produced changes; empty string otherwise.

**Example.**
```text
subagent.diff: |
  diff --git a/src/parseConfig.ts b/src/parseConfig.ts
  --- a/src/parseConfig.ts
  +++ b/src/parseConfig.ts
  @@ ...
```

---

### `subagent.verbosity`

**Definition.** How chatty this slot's own report (summary + verification + diff) is. The orchestrator may further trim per `command.verbosity`.

**Cross-layer notes.** Sibling root: `command.verbosity`. Broadcast by default. The subagent applies its own value; the orchestrator may downcast (never upcast) in the final report.

**Type.** `shared.enum {silent, minimal, normal, detailed, trace}`.

**Default.** Derived from `command.verbosity`.

**Example.**
```text
subagent.verbosity: "minimal"
```
