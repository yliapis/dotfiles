# Scope: `subagent` (level 1+)

The **subagent scope** is any non-root, non-leaf node in the tree. A subagent is created by its parent (root or another subagent), receives a slice of the parent's responsibility, and **may itself spawn children** (further subagents or leaves). This is the canonical *intermediate* scope.

A subagent's identity in the tree is denoted by an indexed path:

- `root.subagent[i]` — the i-th direct child of root (1-based; `i ∈ [1, root.fan_out]`).
- `root.subagent[i].subagent[j]` — the j-th grandchild via that subagent.
- More generally `root.subagent[i_1].subagent[i_2]...subagent[i_k]` for depth-k nodes.

The subagent scope is the same shape at every depth ≥ 1. A node is a subagent (this file) when it has at least one child; a node with no children is a leaf (`2-leaf.md`).

> **Resolution.** Most subagent parameters resolve from the parent via INHERIT or SHADOW. The few parameters that ORIGINATE at subagent scope (`slot`, `partition`, `worktree_path`, `branch`) are listed under "Originating parameters" below.

---

## Originating parameters

These parameters do **not** exist in the parent scope and are bound for the first time at this subagent. They are unique to a subagent's position in the tree.

### `subagent.slot` (a.k.a. `subagent.index`)
- **Definition.** The 1-based ordinal position of this subagent among its siblings under the same parent.
- **Inheritance.** Originates here. SHADOW into children: each child of this subagent observes a *fresh* `slot` numbering its own siblings.
- **Type.** `int_range >= 1`, bounded above by `parent.fan_out`.
- **Default.** Required (assigned by parent dispatch).
- **Example.** `root.subagent[3].slot = 3`. Inside that subagent's children: `root.subagent[3].subagent[1].slot = 1`.

### `subagent.partition`
- **Definition.** The partition this subagent belongs to (only present when `parent.num_partitions > 1`).
- **Inheritance.** Originates here. INHERIT to descendants (a leaf "knows" which partition it lives under).
- **Type.** `int_range >= 1`, bounded above by `parent.num_partitions`.
- **Default.** Required when `parent.num_partitions > 1`; absent otherwise.
- **Example.** With `root.parallelism = 4`, `root.num_partitions = 2`: `root.subagent[1].partition = 1`, `root.subagent[2].partition = 1`, `root.subagent[3].partition = 2`, `root.subagent[4].partition = 2`.

### `subagent.worktree_path`
- **Definition.** Absolute path to this subagent's isolated worktree on disk.
- **Inheritance.** Originates here. INHERIT to descendants — leaves under this subagent operate inside the same worktree.
- **Type.** `path` (created by `git worktree add` before subagent launch).
- **Default.** Required when `parent.isolation = worktree`.
- **Example.** `root.subagent[2].worktree_path = "~/.cursor/worktrees/run-abc/oauth-login-2"`.

### `subagent.branch`
- **Definition.** Git branch checked out in this subagent's worktree.
- **Inheritance.** Originates here. INHERIT to descendants.
- **Type.** Git branch name.
- **Default.** Derived from `parent.worktree_name` + `-{slot}` suffix when `parent.fan_out > 1`.
- **Example.** `root.subagent[2].branch = "oauth-login-2"`.

### `subagent.focus_hint` (singular)
- **Definition.** The specific refinement angle this subagent applies — singular, not a list.
- **Inheritance.** Originates here as the SHADOWED scalar of `parent.focus_hints[slot]`.
- **Type.** `string | null`.
- **Default.** `parent.focus_hints[slot]` when set; `null` otherwise.
- **Example.** With `root.focus_hints = ["tighten guardrails", "clarify parameters"]`: `root.subagent[1].focus_hint = "tighten guardrails"`.

---

## A. Task / Intent (mostly SHADOWED)

### `subagent.task`
- **Definition.** This subagent's slice of the work — a verbatim or specialized derivation of `parent.task`.
- **Inheritance.** SHADOW from `parent.task`. Re-binding rules (in priority order):
  1. If `parent.subagent_prompt` is set, use it as the new `task`.
  2. If `parent.focus_hints[slot]` is set, append the hint to a SHADOWED slice of `parent.task`.
  3. If `parent.num_partitions > 1`, scope `task` to the partition's slice.
  4. Otherwise, INHERIT `parent.task` verbatim (broadcast).
- **Type.** Same as `root.task` — `string | markdown`.
- **Default.** Required (every subagent must have a task).
- **Example.**
  - Broadcast: `root.task = "implement OAuth"`, `root.subagent[1].task = "implement OAuth"`.
  - With focus hint: `root.subagent[1].task = "implement OAuth — angle: tighten guardrails"`.

### `subagent.input`
- **Definition.** The verbatim input string passed *to this subagent*, distinct from the user's original `root.input`.
- **Inheritance.** SHADOW (typically derived from `parent.subagent_prompt` rendered with this subagent's slot/focus_hint).
- **Type.** `string | markdown`.
- **Default.** Empty.
- **Example.** `root.subagent[1].input = "Refine the prompt below; focus on guardrails."`.

### `subagent.context`
- **Definition.** The artifact subset this subagent consumes.
- **Inheritance.** INHERIT from `parent.context` by default; SHADOW when partitions slice the context (e.g. one partition per directory).
- **Type.** Same as `root.context`.
- **Default.** `parent.context`.
- **Example.** `root.context = {kind: "directory", path: "src/"}`, `root.subagent[1].context = {kind: "directory", path: "src/auth/"}` (SHADOWED partition slice).

---

## B. File I/O (INHERIT or SHADOW per partition)

### `subagent.file`, `subagent.directory`, `subagent.glob`, `subagent.url`, `subagent.inline`
- **Definition.** Same shapes as their root counterparts; they describe what content this subagent loads.
- **Inheritance.** INHERIT by default; SHADOW when this subagent represents a partition over the parent's file set.
- **Type.** As in `0-root.md` section B.
- **Default.** Inherited.
- **Example.** With `root.glob = "**/*.md"`, partition by language: `root.subagent[1].glob = "src/**/*.md"`, `root.subagent[2].glob = "docs/**/*.md"`.

### `subagent.format`, `subagent.file_type`
- **Definition.** Same as root.
- **Inheritance.** INHERIT (rarely shadowed).
- **Type.** As in `0-root.md` section B.

### `subagent.save_path`
- **Definition.** Where this subagent's product is written before being BUBBLED back to the parent.
- **Inheritance.** SHADOW — the path is rebased into this subagent's `worktree_path` (e.g. `parent.save_path = ".cursor/commands/foo.md"` becomes `subagent.save_path = "<worktree_path>/.cursor/commands/foo.md"`).
- **Type.** `path`.
- **Default.** Derived.
- **Example.** `root.subagent[1].save_path = "~/.cursor/worktrees/run-abc/oauth-login-1/.cursor/commands/oauth.md"`.

### `subagent.output_format`
- **Definition.** Required structure of the subagent's bubbled output (NOT the user-facing reply, which only root has).
- **Inheritance.** SHADOW per `subagent_type`.
- **Type.** `markdown` template | enum.
- **Default.** Determined by `subagent_type`.
- **Example.** `root.subagent[1].output_format = "diff + summary"` (`worktree-task-agent` child).

---

## C. Constraints (INHERIT, additive only)

### `subagent.criteria`
- **Definition.** Judgment rubric for this subagent's slice.
- **Inheritance.** INHERIT; may be SHADOWED to a slice when `parent.num_partitions > 1` (e.g. one partition per criterion).
- **Type.** As in `0-root.md` section C.
- **Default.** `parent.criteria`.
- **Example.** `root.criteria = "ai-coding/criteria/quality.md"`, `root.subagent[1].criteria = "ai-coding/criteria/quality.md#determinism"` (partitioned slice).

### `subagent.guardrails`
- **Definition.** MUST / MUST NOT rules in force for this subagent and its descendants.
- **Inheritance.** INHERIT — additive only (subagent may add new constraints; MUST NOT remove parent constraints).
- **Type.** Markdown bullet list.
- **Default.** `parent.guardrails`, optionally extended with `parent.subagent_constraints`.
- **Example.** `root.subagent[1].guardrails = root.guardrails + ["MUST NOT push to remote", ...]`.

### `subagent.stop_condition`
- **Definition.** Termination predicate for this subagent.
- **Inheritance.** INHERIT; SHADOW when partitioned (different stop conditions per partition).
- **Type.** As in `0-root.md` section C.
- **Default.** `parent.stop_condition`.
- **Example.** `root.subagent[1].stop_condition = "until eslint passes"`.

### `subagent.test_command`
- **Definition.** Verification command run inside this subagent's `worktree_path` after work is complete.
- **Inheritance.** INHERIT; BUBBLES `exit_code` and `verification` log up to parent (and from there up to root).
- **Type.** Shell command string.
- **Default.** `parent.test_command`.
- **Example.** `root.subagent[1].test_command = "pytest tests/auth/"`.

---

## D. Subtree Configuration (re-fan-out)

A subagent can itself spawn children. When it does, it re-binds the replication parameters from section D of `0-root.md` for *its own* subtree. The values do NOT INHERIT from `parent.parallel` etc.; they are RESET and then re-bound.

### `subagent.fan_out`, `subagent.parallel`, `subagent.num_partitions`, `subagent.k`, `subagent.num_experiments`
- **Definition.** Identical semantics to their root counterparts but apply only to this subagent's children.
- **Inheritance.** RESET — explicitly cleared by default; the subagent must declare these to spawn further children. (See `inheritance.md#reset`.)
- **Type.** `int_range >= 1`.
- **Default.** All `1` (no further fan-out).
- **Example.** `root.subagent[1].fan_out = 3` → `root.subagent[1]` has 3 grandchildren.

### `subagent.depth`
- **Definition.** Remaining tree depth this subagent may grow.
- **Inheritance.** INHERIT with `-1` decrement; spawning children when `subagent.depth == 0` is rejected.
- **Type.** `int_range >= 0`.
- **Default.** `parent.depth - 1`.
- **Example.** `root.depth = 2` → `root.subagent[i].depth = 1` → `root.subagent[i].subagent[j].depth = 0` (must be a leaf).

### `subagent.subagent_type`, `subagent.subagent_model`, `subagent.subagent_prompt`, `subagent.subagent_constraints`
- **Definition.** Same as the root counterparts (section E of `0-root.md`) but applied to this subagent's children.
- **Inheritance.** RESET by default — a subagent typically declares its own subtree composition.
- **Type.** As in `0-root.md` section E.
- **Default.** RESET (unset).
- **Example.** `root.subagent[1].subagent_type = "leaf-coder"`.

---

## E. Models / Diversity

### `subagent.model`
- **Definition.** The model running this subagent itself.
- **Inheritance.** SHADOW (resolved from `parent.agent_model[slot]` if `agent_model` is a list, else `parent.agent_model` broadcast, else `parent.model`).
- **Type.** Model identifier.
- **Default.** Resolved per the cascade above.
- **Example.** With `root.agent_model = ["claude-opus-4", "claude-sonnet-4"]`: `root.subagent[1].model = "claude-opus-4"`, `root.subagent[2].model = "claude-sonnet-4"`.

### `subagent.agent_model`
- **Definition.** Default model for this subagent's children (if it spawns any).
- **Inheritance.** RESET.
- **Type.** Model identifier | list.
- **Default.** `subagent.model`.
- **Example.** `root.subagent[1].agent_model = "claude-opus-4"`.

### `subagent.seed`
- **Definition.** This subagent's RNG seed.
- **Inheritance.** SHADOW with offset: `subagent.seed = parent.seed + slot`.
- **Type.** `int`.
- **Default.** Derived.
- **Example.** `root.seed = 1234` → `root.subagent[3].seed = 1237`.

### `subagent.temperature`, `subagent.focus_hint` (singular form already covered above)
- **Definition.** As in root, scoped to this subagent.
- **Inheritance.** INHERIT (`temperature`); SHADOW from `parent.focus_hints[slot]` (`focus_hint`).
- **Type.** `float [0, 2]`; `string | null`.
- **Default.** Inherited / derived.
- **Example.** `root.subagent[1].temperature = 1.2` (overridden for diversity).

---

## F. Selection / Aggregation

A subagent that itself spawns children may need to select among its **own** children before bubbling up. In that case it re-binds the section G parameters of `0-root.md`.

### `subagent.selection_mode`, `subagent.min_successes`, `subagent.ranker`, `subagent.aggregator`, `subagent.compare_against`, `subagent.merge_count`
- **Definition.** Same as root counterparts, applied within this subagent's local subtree.
- **Inheritance.** RESET — must be declared again to take effect.
- **Type.** As in `0-root.md` section G.
- **Default.** Defaults to `manual` selection at root behavior is NOT inherited; subagents typically run `auto-best` or `synthesize` because they must reduce children to one bubbled value.
- **Example.** `root.subagent[1].selection_mode = "synthesize"`, `root.subagent[1].aggregator = "merge-prompts"`.

> **Note.** A subagent that does NOT spawn children does not need these; in that case it is a leaf (`2-leaf.md`).

---

## G. Isolation / Workspace

### `subagent.isolation`
- **Definition.** Isolation strength for this subagent's children.
- **Inheritance.** INHERIT.
- **Type.** Enum `none | worktree | sandbox | container`.
- **Default.** `parent.isolation`.
- **Example.** `root.subagent[1].isolation = "worktree"`.

### `subagent.base_branch`
- **Definition.** Branch from which descendants of this subagent fork.
- **Inheritance.** SHADOW — typically `parent.base_branch` UNLESS this subagent represents a "checkpoint" branch (e.g. the subagent's own committed work). In recursive trees the descendants fork from this subagent's `branch`, not the original `base_branch`.
- **Type.** Git ref.
- **Default.** This subagent's `branch` if it is committing; otherwise `parent.base_branch`.
- **Example.** `root.subagent[1].base_branch = "oauth-login-1"` (children fork from this subagent's branch).

### `subagent.worktree_name`, `subagent.worktree_root`, `subagent.cleanup_policy`, `subagent.delete_worktree`
- **Definition.** As in root, scoped to this subagent's children.
- **Inheritance.** INHERIT for `worktree_root`, `cleanup_policy`, `delete_worktree`; SHADOW for `worktree_name` (rebased to include parent slot).
- **Type.** As in `0-root.md` section H.
- **Default.** Inherited / derived.
- **Example.** `root.subagent[1].worktree_name = "oauth-login-1"`.

---

## H. Robustness / Recovery

### `subagent.timeout`, `subagent.retry_policy`, `subagent.hang_policy`
- **Definition.** As in root.
- **Inheritance.** INHERIT (`timeout`); RESET (`retry_policy`, `hang_policy`) — recovery decisions are owned by the layer that's spawning, so a subagent re-binds them when it itself spawns.
- **Type.** As in `0-root.md` section J.
- **Default.** `timeout` inherited; `retry_policy = (never, 0)`; `hang_policy = abort`.
- **Example.** `root.subagent[1].retry_policy = ("on-fail", 1)`.

---

## I. Reporting

### `subagent.verbosity`
- **Definition.** Verbosity of this subagent's bubbled report.
- **Inheritance.** INHERIT.
- **Type.** As in `0-root.md` section K.
- **Default.** `parent.verbosity`.
- **Example.** `root.subagent[1].verbosity = "summary"`.

### `subagent.require_diff`, `subagent.include_terminal_log`
- **Definition.** As in root, scoped to this subagent's bubbled output.
- **Inheritance.** INHERIT.
- **Type.** As in `0-root.md` section K.
- **Default.** Inherited.

---

## Summary table (originating + re-bound)

| Family | Param | Originates? | Inheritance from parent | Default |
|---|---|---|---|---|
| – | `slot` | yes | — | required |
| – | `partition` | yes | — | required when partitioned |
| – | `worktree_path` | yes | — | required (action) |
| – | `branch` | yes | — | derived |
| – | `focus_hint` (singular) | yes | SHADOW from `focus_hints[slot]` | parent's slice |
| A | `task` | no | SHADOW | parent slice |
| A | `input` | no | SHADOW | derived |
| A | `context` | no | INHERIT (or SHADOW) | parent's |
| B | `file` / `directory` / `glob` / `url` / `inline` | no | INHERIT | parent's |
| B | `format`, `file_type` | no | INHERIT | parent's |
| B | `save_path` | no | SHADOW (rebased) | derived |
| B | `output_format` | no | SHADOW | per `subagent_type` |
| C | `criteria` | no | INHERIT | parent's |
| C | `guardrails` | no | INHERIT (additive) | parent's + `subagent_constraints` |
| C | `stop_condition` | no | INHERIT | parent's |
| C | `test_command` | no | INHERIT (BUBBLES exit) | parent's |
| D | `fan_out`, `parallel`, `num_partitions`, `k`, `num_experiments` | no | RESET | 1 |
| D | `depth` | no | INHERIT (-1) | parent's - 1 |
| D | `subagent_*` | no | RESET | unset |
| E | `model` | no | SHADOW | resolved from cascade |
| E | `agent_model` | no | RESET | `model` |
| E | `seed` | no | SHADOW (offset) | derived |
| E | `temperature` | no | INHERIT | parent's |
| F | `selection_mode`, `min_successes`, `ranker`, `aggregator`, `compare_against`, `merge_count` | no | RESET | unset |
| G | `isolation` | no | INHERIT | parent's |
| G | `base_branch` | no | SHADOW (own branch when committing) | derived |
| G | `worktree_name` | no | SHADOW (suffixed) | derived |
| G | `worktree_root`, `cleanup_policy`, `delete_worktree` | no | INHERIT | parent's |
| H | `timeout` | no | INHERIT | parent's |
| H | `retry_policy`, `hang_policy` | no | RESET | defaults |
| I | `verbosity`, `require_diff`, `include_terminal_log` | no | INHERIT | parent's |

**Total subagent parameters: 5 originating + 36 re-bound = 41**.
