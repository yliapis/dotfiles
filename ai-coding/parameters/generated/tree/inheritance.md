# Inheritance, Shadowing, Reset, Bubbling

Parameter resolution in the tree-shaped ontology obeys exactly four rules. Every parameter, in every scope, picks one of these four rules as its **propagation policy**. The rules are intentionally orthogonal: any parameter can change which rule applies in a particular command (by being declared explicitly), but the *default* rule is fixed in `0-root.md`, `1-subagent.md`, `2-leaf.md`.

The four rules:

| Rule       | Direction | Meaning |
|------------|-----------|---------|
| INHERIT    | down      | Child reads parent's value verbatim unless explicitly overridden. |
| SHADOW     | down      | Child re-binds the **same name** to a new value (often with new semantics or scope-relative path). |
| RESET      | down      | Child explicitly clears (the parameter is treated as **undefined** in the child, which then falls back to scope-default). |
| BUBBLE     | up        | Child writes a value that the parent (and ancestors) read back when child terminates. |

The remainder of this file specifies each rule precisely, gives the resolution algorithm, documents two type formalisms (`int_range` and `file_type`), and works two examples end-to-end.

---

## 1. INHERIT (down)

A parameter `P` with policy INHERIT is resolved at child scope `c` as follows:

```
resolve(c.P) = c.P            if c declares c.P explicitly
             | resolve(parent(c).P)   otherwise
             | scope_default(c, P)    if c is root (or all ancestors are silent)
```

INHERIT is the default for "configuration"-shaped parameters whose semantics are constant top-to-bottom: `criteria`, `guardrails`, `stop_condition`, `test_command`, `model`, `temperature`, `verbosity`, `timeout`, `format`, `file_type`, `isolation`, `worktree_root`, `cleanup_policy`, `delete_worktree`, `base_branch` (when not committing in a recursive tree).

### Special case: ADDITIVE inheritance for `guardrails`

`guardrails` and `subagent_constraints` are **additive**: a child's effective guardrails are the *union* of parent's guardrails and any guardrails the child explicitly declares. A child MUST NOT remove a parent's guardrail (only further restrict). RESET is forbidden for `guardrails`.

```
resolve(c.guardrails) = parent(c).guardrails ∪ c.declared_guardrails ∪ parent(c).subagent_constraints
```

### Worked example

```
root.criteria = "ai-coding/criteria/quality.md"
root.subagent[1].criteria  # not declared
→ resolve = "ai-coding/criteria/quality.md"   (INHERIT)
```

---

## 2. SHADOW (down)

A parameter `P` with policy SHADOW is **expected** to be re-bound at child scope. The child's value of `P` is *related to* the parent's value (often a slice, projection, or per-slot transform) but is **not** the parent's value verbatim. SHADOW differs from INHERIT in two ways:

1. The **transform** is mandatory and well-defined — it's not optional override, it's part of the parameter's contract.
2. The child's value of `P` may have a **different type** or **narrower meaning** than the parent's value. (In particular, list-valued parameters at parent level often shadow into scalar-valued parameters at child level.)

Common SHADOW transforms:

| Parent type | Child type | Transform |
|---|---|---|
| `list[T]` of length `fan_out` | `T` | `child.P = parent.P[child.slot]` (zip by slot) |
| `T` (scalar) | `T` | `child.P = parent.P` (broadcast) |
| `string` template | `string` (rendered) | substitute `{slot}`, `{focus_hint}` |
| absolute `path` | absolute `path` | rebase under `child.worktree_path` |
| `int` (parent seed) | `int` (child seed) | `parent.seed + child.slot` |
| `string` (parent task) | `string` (child slice) | `parent.task` + slice annotation |

### SHADOW is the default for

`task`, `input`, `save_path`, `model` (resolved from `agent_model`), `seed`, `focus_hint` (singular form, derived from `focus_hints` list), `worktree_name` (suffixed with `-i`), `subagent_type`, `subagent_model`, `subagent_prompt`, `output_format`.

### Worked example

```
root.agent_model = ["claude-opus-4", "claude-sonnet-4", "gpt-5"]
root.subagent[2].model  →  "claude-sonnet-4"           (SHADOW: zip by slot=2)

root.focus_hints = ["tighten guardrails", "clarify parameters", "improve workflow steps"]
root.subagent[1].focus_hint  →  "tighten guardrails"   (SHADOW: zip by slot=1)

root.seed = 1234
root.subagent[3].seed  →  1237                          (SHADOW: offset by slot=3)

root.save_path = ".cursor/commands/foo.md"
root.subagent[1].save_path  →
  "$WORKTREE/.cursor/commands/foo.md"                   (SHADOW: rebase under worktree_path)
```

### Validation contract (parent-side)

When SHADOW uses zip-by-slot, the parent MUST validate **before** spawning that the parent's list is shaped correctly:

- `len(parent.agent_model) == parent.fan_out`, OR
- `len(parent.agent_model) == parent.num_partitions` (each partition broadcasts to its slots), OR
- `parent.agent_model` is scalar (broadcast to all).

Validation failure aborts the run with no filesystem side effects (mirrors `worktree-task-agent.md`'s existing contract).

---

## 3. RESET (down)

A parameter `P` with policy RESET is **explicitly cleared** at child scope. The child treats `P` as undefined and (re-)derives a value from scratch using the child scope's default — never from the parent's value.

RESET is the default for **fan-out / orchestration parameters** because each scope owns its own fan-out decision:

- `fan_out`, `parallel`, `parallelism`, `num_partitions`, `k`, `n_candidates`, `num_experiments`
- `subagent_type`, `subagent_model`, `subagent_prompt`, `subagent_constraints`
- `selection_mode`, `min_successes`, `ranker`, `aggregator`, `compare_against`, `merge_count`, `merge_mode`
- `retry_policy`, `hang_policy`
- `auto_save_winner`

A subagent that does NOT spawn children leaves all RESET parameters at their defaults (typically `1` or unset). A subagent that DOES spawn children re-binds them.

### Worked example

```
root.parallel = 4
root.subagent[1].parallel        # NOT inherited; defaults to 1 (this subagent does not spawn)
root.subagent[1].subagent[*]     # zero children → leaf

root.subagent[2].parallel = 3    # explicitly re-bound; this subagent will spawn 3 grandchildren
```

If a subagent could simply INHERIT `parallel`, every leaf in the tree would erroneously try to spawn `root.parallel` further children.

### `depth` is a special case: INHERIT-with-decrement

`depth` is technically INHERIT-shaped but the inherited value is `parent.depth - 1`. This is documented as INHERIT in the per-scope tables but called out here: spawning a child when `c.depth == 0` is a tree-shape violation and the dispatcher rejects it before any side effects.

---

## 4. BUBBLE (up)

A parameter `P` with policy BUBBLE is **produced** by a child (typically a leaf) and **read** by ancestors. BUBBLE is the only direction that is "up" in the tree.

The set of bubbled parameters is documented in `2-leaf.md#m-bubbled-outputs`. Bubbled values are the **only** outputs of the parameter system — every other parameter is an *input* to some scope.

Resolution at an ancestor:

```
resolve(ancestor.children_P) = [ resolve(child.P) for child in ancestor.children ]
```

For example, root reads `root.children_statuses = [root.leaf[i].status for i in 1..fan_out]` and applies `root.selection_mode`, `root.min_successes`, and `root.aggregator` to reduce the list back into a single root-level outcome.

### Reduction operators (typical)

| Bubbled param | Common reduction at ancestor |
|---|---|
| `status` | count successes; gate on `min_successes` |
| `result` / `diff` | rank via `ranker`; pick top-1 (`auto-best`) or merge (`synthesize`) |
| `verification` | aggregate exit codes; require all-pass for auto-merge |
| `findings` | merge by `(location, criterion)`; record agreement count |
| `terminal_log` | concatenate when `include_terminal_log = true`, else drop |
| `elapsed_ms` | sum or max for run-level reporting |
| `error` | propagate first non-null error (or all errors) |

### Worked example: `critique.md` aggregating findings

```
# leaves bubble:
root.leaf[1].findings = [
  {location: "src/auth.ts:42", criterion: "robustness", severity: "major", ...},
  {location: "src/auth.ts:88", criterion: "clarity",     severity: "minor", ...},
]
root.leaf[2].findings = [
  {location: "src/auth.ts:42", criterion: "robustness", severity: "major", ...},  # match
]
root.leaf[3].findings = [
  {location: "src/auth.ts:99", criterion: "determinism", severity: "critical", ...},  # only run 3
]

# root aggregates:
root.aggregate.findings = {
  convergent: [ {location: "src/auth.ts:42", criterion: "robustness", agreement: 2/3 } ],
  divergent:  [ {location: "src/auth.ts:88", criterion: "clarity",     agreement: 1/3 },
                {location: "src/auth.ts:99", criterion: "determinism", agreement: 1/3 } ],
}
```

### BUBBLE through intermediate subagents

When a subagent spawns its own children, it is itself a "root" for those grandchildren. The subagent applies its own selection / aggregation, produces a single bubbled value, and passes it up. Root sees the subagent's reduced output, not the raw grandchildren.

```
root.subagent[1].leaf[1..3]  →  bubble  →  root.subagent[1].result  →  bubble  →  root.children_results
```

---

## 5. Resolution algorithm

For any parameter `P` and any scope `c`, the resolved value is computed by:

```
def resolve(c, P):
    policy = policy_for(c, P)            # from per-scope tables (0-root.md, 1-subagent.md, 2-leaf.md)

    if policy == INHERIT:
        if c.declares(P):
            return c.P
        elif c.parent is not None:
            return resolve(c.parent, P)
        else:
            return scope_default(c, P)

    elif policy == SHADOW:
        # SHADOW always re-binds; the value MUST be derived from parent.
        if c.parent is None:
            return scope_default(c, P)
        return shadow_transform(c, P, parent_value=resolve(c.parent, P))

    elif policy == RESET:
        if c.declares(P):
            return c.P
        else:
            return scope_default(c, P)   # ignore parent

    elif policy == BUBBLE:
        # Resolution is upward; only meaningful AFTER children settle.
        return c.bubbled_value(P)        # set by child completion
```

Validation runs **before** spawning at every scope:

1. Every required parameter resolves to a non-null value.
2. Every `int_range`-typed parameter satisfies its range constraint.
3. Every `file_type`-typed parameter resolves to files matching the constraint.
4. Every list-typed SHADOW source has the right length (`len == fan_out` or `len == num_partitions`).
5. `depth` is non-negative at every scope that spawns.

---

## 6. Type formalisms

These are referenced from per-scope files under "constraint" labels.

### 6.1 `int_range` formalism

`int_range` is a constraint on integer-typed parameters that specifies an allowed interval. Syntax:

| Notation | Meaning |
|---|---|
| `>= n` | half-open `[n, ∞)` |
| `>  n` | open `(n, ∞)` |
| `<= n` | half-open `(-∞, n]` |
| `<  n` | open `(-∞, n)` |
| `[lo, hi]` | closed `[lo, hi]` |
| `(lo, hi)` | open `(lo, hi)` |
| `(lo, hi]` / `[lo, hi)` | half-open |
| `(0, ∞)` | strictly positive |

Example bindings (cross-referenced from `0-root.md` and others):

- `root.parallel: int_range >= 1`
- `root.fan_out:  int_range >= 1`
- `root.depth:    int_range >= 0`
- `root.min_successes: int_range [0, fan_out]`
- `root.temperature` is **not** an `int_range` (it's a `float [0, 2]`).

Validation: a parameter declared with an `int_range` must satisfy the range or the dispatcher fails fast (no filesystem side effects).

### 6.2 `file_type` formalism

`file_type` (a.k.a. `extension`) is a constraint on `file` / `directory` / `glob` resolution. It restricts which extensions are eligible. Syntax: a set of strings, each beginning with `.`:

| Notation | Meaning |
|---|---|
| `{".md"}` | only Markdown files |
| `{".md", ".mdx"}` | Markdown variants |
| `{".py", ".pyi"}` | Python sources + stubs |
| `{}` (empty) or unset | no restriction |
| `*` | shorthand for unset |

Inheritance: INHERIT (children read the parent's `file_type` unless they declare their own).

Validation: any resolved file whose extension is not in `file_type` is rejected from the input set; the dispatcher reports the rejection list.

Example cross-references:

- `root.file_type = {".md"}`, `root.glob = "**/*"` → only `.md` files are loaded.
- `root.subagent[1].file_type = {".md", ".mdx"}` (SHADOW; broadens for this partition).

---

## 7. Conflict resolution

When multiple rules could apply, the priority order is:

1. **Explicit declaration at `c`**: always wins, regardless of policy. (Even an INHERIT parameter can be explicitly overridden at any scope.)
2. **Validation check**: if step 1's value violates `int_range`, `file_type`, list-length, or `guardrails`-additivity, fail fast.
3. **Policy-driven derivation**: apply INHERIT, SHADOW, or RESET as documented per scope.
4. **Scope default**: documented in `0-root.md`, `1-subagent.md`, `2-leaf.md`.

For BUBBLE the order is:

1. **Child has not completed**: BUBBLE'd value at ancestor is `null` / `pending`.
2. **Child completed**: ancestor reads the bubbled value; multiple children's values are aggregated per the parent's reduction operator (see section 4).

### Override of policy itself

A command author MAY explicitly mark a parameter with a different policy in a specific scope (e.g. "this command treats `criteria` as RESET at subagent scope so partitions can choose their own criteria"). Doing so requires the command file to spell out the override; otherwise the per-scope-file policy applies.

---

## 8. End-to-end worked example: `worktree-task-agent.md` with partitions

```
root: {
  task: "implement OAuth login and verify tests",
  parallelism: 4,
  num_partitions: 2,
  agent_model: ["claude-opus-4", "claude-sonnet-4", "claude-opus-4", "gpt-5"],
  base_branch: "main",
  worktree_name: "oauth-login",   # slug from task
  test_command: "pytest tests/auth/",
  merge_mode: "interactive",
  fan_out: 4,                      # equal to parallelism
  selection_mode: "manual",        # because merge_mode = interactive
  depth: 2,
}
```

### Validation (before any worktree is created)

- `int_range`: `parallelism = 4 >= 1` ✓, `num_partitions = 2 >= 1` ✓, `depth = 2 >= 0` ✓.
- List-shape: `len(agent_model) = 4 == parallelism` ✓.
- Partition contract: `4 % 2 == 0` ✓ (2 leaves per partition).

### Tree expansion

```
root
├── subagent[1]  (partition=1, slot=1, model=?)
│   ├── leaf[1]  (slot=1, model=agent_model[1])
│   └── leaf[2]  (slot=2, model=agent_model[2])
└── subagent[2]  (partition=2, slot=2, model=?)
    ├── leaf[1]  (slot=1, model=agent_model[3])
    └── leaf[2]  (slot=2, model=agent_model[4])
```

### Resolution by parameter

| Parameter | At `root` | At `subagent[1]` | At `subagent[1].leaf[1]` | Rule |
|---|---|---|---|---|
| `task` | "implement OAuth..." | "implement OAuth (partition 1)" | "implement OAuth (partition 1, slot 1)" | SHADOW |
| `model` | claude-opus-4 (root) | claude-opus-4 (parent's model in this case) | claude-opus-4 (= `agent_model[1]`) | SHADOW (zip) |
| `criteria` | unset → default | unset → INHERIT default | unset → INHERIT default | INHERIT |
| `test_command` | "pytest tests/auth/" | "pytest tests/auth/" | "pytest tests/auth/" | INHERIT |
| `parallel` | 4 | 1 (RESET; subagent does not re-fan-out beyond its children) | n/a | RESET |
| `worktree_name` | "oauth-login" | "oauth-login-1" | "oauth-login-1" (inherited from subagent) | SHADOW |
| `worktree_path` | n/a | (originates) `~/.cursor/worktrees/run-abc/oauth-login-1` | INHERITED | originate / INHERIT |
| `branch` | n/a | "oauth-login-1" | INHERITED | originate / INHERIT |
| `seed` | unset | (no seed → unset) | unset | INHERIT |
| `status` | aggregated from leaves | aggregated from this subagent's leaves | "success"/"failed"/etc. | BUBBLE |
| `verification` | aggregated | aggregated | `{exit_code: 0, ...}` | BUBBLE |
| `diff` | n/a | aggregated (per-partition merge candidate) | per-leaf diff | BUBBLE |
| `merge_recommendation` | one branch overall (or none) | per partition | per leaf | BUBBLE → reduce |

### Final reduction

Root applies `merge_mode = interactive`: present per-leaf reports and ask user which branch to merge.

The user's answer triggers exactly one merge into `main` and (per `delete_worktree = true` default) deletes that worktree. The other 3 worktrees are left in place per existing `worktree-task-agent.md` semantics.

---

## 9. End-to-end worked example: `critique.md` (depth-1 fan-out)

```
root: {
  context: {kind: "file", path: "src/auth.ts"},
  criteria: "ai-coding/criteria/quality.md",
  model: "claude-opus-4",
  num_experiments: 3,
  parallel: 2,
  fan_out: 3,
  depth: 1,
  selection_mode: "synthesize",
  aggregator: "merge-findings",
}
```

### Tree

```
root
├── leaf[1]  (slot=1, run #1)
├── leaf[2]  (slot=2, run #2)
└── leaf[3]  (slot=3, run #3)
```

(There are no subagents because `critique.md` does not partition or recurse.)

### Resolution

| Parameter | `root` | `leaf[1]` | Rule |
|---|---|---|---|
| `context` | `src/auth.ts` | `src/auth.ts` | INHERIT |
| `criteria` | quality.md | quality.md | INHERIT |
| `model` | claude-opus-4 | claude-opus-4 | INHERIT (no `agent_model` set) |
| `num_experiments` | 3 | n/a (RESET; leaf doesn't re-fan-out) | RESET |
| `parallel` | 2 | n/a | RESET |
| `findings` | aggregated | per-run list | BUBBLE |
| `verification` | n/a (no `test_command`) | n/a | INHERIT (null) |

### Reduction

Root applies `selection_mode = synthesize` with `aggregator = merge-findings`:

- Group findings by `(location, criterion)`.
- Convergent set: appearing in ≥ 2 runs.
- Divergent set: appearing in exactly 1 run.
- Render as `## Findings` / `## Divergent Findings` per `critique.md`'s output format.

---

## 10. Quick reference

When in doubt, ask: **does the parameter make sense at child scope?**

- *Yes, with the same value* → INHERIT.
- *Yes, with a derived/sliced value* → SHADOW.
- *No, the child decides for itself* → RESET.
- *It's the child's output, not its input* → BUBBLE.
