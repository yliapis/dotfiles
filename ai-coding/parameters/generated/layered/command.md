# `command.*` — Parameters of a Top-Level Command Invocation

The `command.*` namespace describes the **orchestration plane**: every parameter the user can supply (or that defaults) when invoking a top-level slash command. A `command.*` parameter is read by the orchestrator that runs the command, NOT by the subagents the orchestrator may launch. When a value needs to flow into subagent slots, the orchestrator either broadcasts it, zips a list across slots, or rewrites it — those rewrite rules live in `cross-layer.md`.

**Read order:** read `shared.md` for value-type references, then this file, then `cross-layer.md` for any parameter whose root name also appears in `subagent.*` or `skill.*`.

---

## Convention reminder

- Each `command.*` parameter below appears under its category, with: a one-sentence **Definition**, **Cross-layer notes** linking sibling roots, the resolved **Type**, the **Default**, and at least one **Example**.
- Cross-layer notes are NOT redundant restatements of `cross-layer.md`; they are signposts to it.
- "Required" means the orchestrator MUST fail validation if the parameter is unset.

---

## Index

### Intent
- `command.task`, `command.input`, `command.context`

### File I/O
- `command.save_path`, `command.output_format`

### Constraints
- `command.criteria`, `command.guardrails`, `command.stop_condition`, `command.test_command`

### Replication / fan-out
- `command.parallel`, `command.num_partitions`, `command.num_experiments`, `command.n_candidates`, `command.k`, `command.depth`, `command.fan_out`, `command.min_successes`

### Subagent shaping
- `command.subagent_type`, `command.subagent_prompt`, `command.subagent_constraints`, `command.model`, `command.agent_model`

### Diversity
- `command.focus_hints`, `command.seed`, `command.temperature`

### Selection / aggregation
- `command.selection_mode`, `command.ranker`, `command.aggregator`, `command.compare_against`

### Isolation / workspace
- `command.isolation`, `command.base_branch`, `command.worktree_start_ref`, `command.worktree_name`, `command.worktree_root`, `command.cleanup_policy`, `command.delete_worktree`

### Lifecycle / persistence
- `command.auto_save_winner`, `command.merge_mode`, `command.merge_count`

### Robustness / recovery
- `command.timeout`, `command.relaunch_on_hang_after`, `command.retry_policy`, `command.hang_policy`

### Reporting
- `command.verbosity`, `command.require_diff`, `command.include_terminal_log`

---

## Intent

### `command.task`

**Definition.** The top-level user-facing work the command was invoked to do, in natural language.

**Cross-layer notes.** Sibling roots: `subagent.task` (a *scoped* per-slot rewrite of this same work) and `skill.task` (the activation-trigger description in a skill's `description` field). `command.task` is NEVER passed verbatim to subagents; the orchestrator rewrites it into `subagent.task` per slot. See `cross-layer.md § task`.

**Type.** `shared.inline` (natural language; typically 1–5 sentences).

**Default.** Required.

**Example.**
```text
command.task: "Migrate parseConfig from JSON to TOML; preserve every existing call site."
```

---

### `command.input`

**Definition.** The raw text the user typed after the slash-command literal (everything to the right of `/foo`), including any flags or paste-in artifacts. Distinct from `command.task`: `input` is unparsed; `task` is its parsed intent.

**Cross-layer notes.** Sibling root: `skill.input` (the *kind* of input a skill expects). No `subagent.input` — subagents receive `subagent.task` and `subagent.context`, not raw user input.

**Type.** `shared.inline` (raw string).

**Default.** Empty string (when the user invoked the command with no argument).

**Example.**
```text
command.input: "save as /pr-review: review a PR for security issues"
```

---

### `command.context`

**Definition.** The artifact(s) the command operates on — code, prose, schemas, URLs — that the command MUST resolve and read before producing output.

**Cross-layer notes.** Sibling root: `subagent.context` (per-slot scope). When a command fans out, the orchestrator typically partitions or duplicates `command.context` into per-slot `subagent.context` payloads. See `cross-layer.md § context`.

**Type.** `shared.addressable` (any of `file | directory | glob | url | inline`).

**Default.** Required for most commands; `/meta-prompt` is the notable exception.

**Example.**
```text
command.context: "./src/parseConfig.ts"                # file
command.context: "./rfcs/"                             # directory
command.context: "**/*.py"                             # glob
command.context: "https://example.com/spec.html"       # url
command.context: "<paste of the snippet to critique>"  # inline
```

---

## File I/O

### `command.save_path`

**Definition.** Where the command's final user-facing artifact is persisted on success. Unset means "do not persist; render in chat only".

**Cross-layer notes.** Sibling root: `subagent.save_path` (per-slot intermediate output location). The two are NOT the same file — `command.save_path` is the merged / chosen / synthesized final; `subagent.save_path` is one candidate. See `cross-layer.md § save_path`.

**Type.** `shared.path?`.

**Default.** Unset (no persistence).

**Example.**
```text
command.save_path: ".cursor/commands/pr-review.md"
```

---

### `command.output_format`

**Definition.** The rendering contract for the command's final artifact.

**Cross-layer notes.** Sibling roots: `subagent.output_format` (per-slot, typically structured for the orchestrator to parse), `skill.output_format` (the format the skill promises). See `cross-layer.md § output_format`.

**Type.** `shared.output_format`.

**Default.** `"markdown"` for most commands; `"diff:unified"` for commands whose primary artifact is a code change.

**Example.**
```text
command.output_format: "markdown:critique-report"
```

---

## Constraints

### `command.criteria`

**Definition.** The judgment rubric the command applies — what counts as "good" output for this invocation.

**Cross-layer notes.** Sibling roots: `subagent.criteria` (per-finding / per-slot criterion the subagent evaluates against), `skill.criteria` (the skill's quality bar for its own activation conditions). The orchestrator may broadcast `command.criteria` to every subagent or split it (one criterion per slot in a tournament). See `cross-layer.md § criteria`.

**Type.** `shared.addressable`. When `shared.inline`, the value is the rubric body. When `shared.file` or `shared.directory`, the consumer reads the contents.

**Default.** Command-specific. Critique-style commands default to `{quality, determinism}`; many commands have no default and require explicit criteria.

**Example.**
```text
command.criteria: "./.cursor/rubrics/security.md"
command.criteria: "must compile; must not regress benchmarks"
```

---

### `command.guardrails`

**Definition.** Hard constraints the command MUST respect — things the orchestrator and its subagents are forbidden from doing regardless of `command.task`.

**Cross-layer notes.** Sibling roots: `subagent.guardrails` (additional per-slot constraints layered onto the command's set), `skill.guardrails` (constraints a skill brings into every command that activates it). The effective guardrail set is the union. See `cross-layer.md § guardrails`.

**Type.** `shared.addressable` (list of MUST / MUST NOT / Scope lines).

**Default.** Command-specific. Critique-style commands default to "read-only; no edits".

**Example.**
```text
command.guardrails:
  - MUST NOT modify the original working tree.
  - MUST NOT push to remote.
  - Scope: read-only analysis of {command.context}.
```

---

### `command.stop_condition`

**Definition.** An explicit completion bar beyond "task implemented". The command (and its subagents) MUST NOT report success until this condition is satisfied.

**Cross-layer notes.** Sibling root: `subagent.stop_condition` — by default the command broadcasts its stop condition to every subagent. See `cross-layer.md § stop_condition`.

**Type.** `shared.inline` (predicate written in natural language; SHOULD be observable).

**Default.** Unset (success = task done as the agent judges it).

**Example.**
```text
command.stop_condition: "all unit tests under tests/parser/ pass and a diff exists"
```

---

### `command.test_command`

**Definition.** A shell command the orchestrator (or each subagent) runs to verify success. Exit code `0` is pass; non-zero is fail.

**Cross-layer notes.** Sibling root: `subagent.test_command` — by default the command broadcasts to every subagent and the per-slot exit code is reported back. See `cross-layer.md § test_command`.

**Type.** `shared.shell_command?`.

**Default.** Unset (no automated verification).

**Example.**
```text
command.test_command: "pytest -q tests/parser/"
```

---

## Replication / fan-out

### `command.parallel`

**Definition.** The maximum number of subagents the orchestrator runs **concurrently at the outer fan-out level** (one per worktree, one per slot, etc.).

**Cross-layer notes.** Sibling root: `subagent.parallel` — that is the *inner* concurrency (tools a single subagent runs in parallel), NOT a rebroadcast of this value. The two are independent. See `cross-layer.md § parallel`.

**Type.** `int with shared.int_range >= 1`.

**Default.** `1`.

**Example.**
```text
command.parallel: 4   # four subagents at once
```

---

### `command.num_partitions`

**Definition.** The number of disjoint partitions the orchestrator splits its fan-out into. Often used with a per-partition variant of a `shared.list_or_scalar<T>` parameter (e.g., one model per partition rather than one per slot).

**Cross-layer notes.** No `subagent.num_partitions` — partitioning is an orchestrator-only concern. Validation interaction with `command.agent_model` (the iterable MUST be a full iteration or a correctly-sized slice for the partitions) is documented in `cross-layer.md § partitions`.

**Type.** `int with shared.int_range >= 1`.

**Default.** `1`.

**Example.**
```text
command.num_partitions: 2
command.agent_model: ["claude-sonnet-4", "gpt-5"]   # one model per partition
command.parallel: 4                                 # 2 slots per partition
```

---

### `command.num_experiments`

**Definition.** The number of independent replicate runs (typically with the same `command.context` and `command.criteria`) used to assess robustness or to vote/aggregate findings.

**Cross-layer notes.** Distinct from `command.n_candidates` (which produces *different* outputs to choose among) — `num_experiments` produces *replicates* meant to converge. No subagent sibling: each experiment is itself a subagent slot.

**Type.** `int with shared.int_range >= 1`.

**Default.** `1`.

**Example.**
```text
command.num_experiments: 3
command.parallel: 3   # all three at once
```

---

### `command.n_candidates`

**Definition.** The number of *deliberately diverse* outputs the orchestrator produces in one invocation (e.g., N refined prompt candidates, N code-change attempts) so the user or a `command.ranker` can pick a winner.

**Cross-layer notes.** Aliased by `command.k` for compactness in best-of-N style commands. Differs from `command.num_experiments` (which converges) and from `command.fan_out` (which is the tree-shaped branching factor).

**Type.** `int with shared.int_range >= 1`.

**Default.** `1`.

**Example.**
```text
command.n_candidates: 5
command.focus_hints: ["tighten guardrails", "clarify parameters", "improve workflow", "shrink output", "add examples"]
```

---

### `command.k`

**Definition.** Shorthand alias for `command.n_candidates` in commands that talk in best-of-N terms.

**Cross-layer notes.** This alias is layer-internal; subagents and skills do not use `k`. A command that exposes both `k` and `n_candidates` MUST treat them as synonyms and reject the invocation if both are set with conflicting values.

**Type.** Same as `command.n_candidates`.

**Default.** Same as `command.n_candidates`.

**Example.**
```text
command.k: 8   # equivalent to command.n_candidates: 8
```

---

### `command.depth`

**Definition.** The maximum allowed depth of the subagent tree the command may construct. A command whose subagents themselves spawn subagents MUST cap recursion at `command.depth`.

**Cross-layer notes.** No subagent sibling. Subagents read this transitively through their own bounded `command.depth - 1` budget.

**Type.** `int with shared.int_range >= 1`.

**Default.** `1` (no nested subagents).

**Example.**
```text
command.depth: 2   # orchestrator -> subagent -> sub-subagent allowed
```

---

### `command.fan_out`

**Definition.** The branching factor at each level of the subagent tree (orthogonal to `command.depth`). Useful when the tree is regular.

**Cross-layer notes.** With `command.depth: 1`, `command.fan_out` collapses to `command.parallel`. With `command.depth > 1`, total slots can grow to `fan_out ^ depth`.

**Type.** `int with shared.int_range >= 1`.

**Default.** Equal to `command.parallel`.

**Example.**
```text
command.fan_out: 3
command.depth: 2   # up to 9 leaves
```

---

### `command.min_successes`

**Definition.** The minimum number of subagent slots whose `subagent.status` MUST be `success` before the orchestrator proceeds to selection or aggregation. If fewer slots succeed, the command fails (or, depending on `command.hang_policy`, relaunches).

**Cross-layer notes.** No subagent sibling — this is purely an orchestrator-level threshold.

**Type.** `int with shared.int_range >= 1` AND `<= command.parallel`.

**Default.** `1`.

**Example.**
```text
command.parallel: 8
command.min_successes: 5   # require >= 5 successful slots before selection
```

---

## Subagent shaping

### `command.subagent_type`

**Definition.** A label or role identifier the orchestrator stamps on every subagent it launches (e.g., `analyzer`, `implementer`, `critic`). The subagent runtime may use this to load a role-specific system prompt or tool allowlist.

**Cross-layer notes.** No `subagent.subagent_type` — the type is set externally by the orchestrator, not by the subagent itself.

**Type.** `shared.policy_string` (consumer-defined finite set).

**Default.** Command-specific (e.g., `worktree-task-agent` uses `implementer`).

**Example.**
```text
command.subagent_type: "critic"
```

---

### `command.subagent_prompt`

**Definition.** The full prompt the orchestrator sends to each subagent. May embed `{subagent.task}`, `{subagent.context}`, `{subagent.criteria}`, etc. — the orchestrator substitutes those per slot.

**Cross-layer notes.** No `subagent.subagent_prompt` — the resolved prompt becomes the subagent's input, not a re-readable parameter. Use `shared.list_or_scalar<shared.inline>` when distinct prompts per slot are desired.

**Type.** `shared.list_or_scalar<shared.inline>`.

**Default.** Command-specific. Many commands derive the subagent prompt internally and do not expose this parameter to the user.

**Example.**
```text
command.subagent_prompt: "Critique {subagent.context} against {subagent.criteria}. Return findings as JSON."
```

---

### `command.subagent_constraints`

**Definition.** Additional MUST / MUST NOT lines layered onto `command.guardrails` only for subagents (the orchestrator itself is not bound by these).

**Cross-layer notes.** These become part of `subagent.guardrails` after merge with the broadcast `command.guardrails`. See `cross-layer.md § guardrails`.

**Type.** `shared.addressable` (list of MUST / MUST NOT lines).

**Default.** Unset.

**Example.**
```text
command.subagent_constraints:
  - MUST NOT call WebFetch.
  - MUST stay inside its assigned worktree.
```

---

### `command.model`

**Definition.** The model identifier used by the **orchestrator** (the command's own reasoning loop).

**Cross-layer notes.** Sibling root: `subagent.model` (per-slot model). When `command.agent_model` is unset, `subagent.model` defaults to `command.model`. See `cross-layer.md § model`.

**Type.** `shared.model_id`.

**Default.** Parent agent's model.

**Example.**
```text
command.model: "claude-sonnet-4"
```

---

### `command.agent_model`

**Definition.** The model identifier(s) used by **each subagent slot**. Distinct from `command.model` (the orchestrator's own model).

**Cross-layer notes.** Resolves into `subagent.model` per slot via `shared.list_or_scalar<shared.model_id>` rules. Interaction with `command.num_partitions` is enforced at validation time (see `command.num_partitions` and `cross-layer.md § partitions`).

**Type.** `shared.list_or_scalar<shared.model_id>`. If list-shaped, length MUST equal `command.parallel` (or equal `command.num_partitions` when used in partition mode).

**Default.** `command.model`.

**Example.**
```text
command.agent_model: "claude-sonnet-4"                   # broadcast
command.agent_model: ["claude-sonnet-4", "gpt-5", ...]   # zip; length MUST match
```

---

## Diversity

### `command.focus_hints`

**Definition.** A list of refinement angles, one per subagent slot, used to *deliberately diversify* the outputs in a best-of-N invocation (`command.n_candidates > 1`).

**Cross-layer notes.** Each hint resolves into the corresponding slot's `subagent.task` prefix or `subagent.criteria` enrichment, depending on the consuming command. No `subagent.focus_hints` parameter — by the time the subagent runs, the hint is already baked into its task.

**Type.** `list<shared.inline>` whose length MUST equal `command.n_candidates`.

**Default.** Unset (all slots get the same task).

**Example.**
```text
command.focus_hints: ["tighten guardrails", "clarify parameters", "improve workflow", "shrink output"]
```

---

### `command.seed`

**Definition.** The base RNG seed broadcast to subagents for repeatability.

**Cross-layer notes.** When broadcast, the orchestrator typically passes `command.seed + i` (where `i` is the 0-based slot index) into each `subagent.seed` to avoid identical outputs from identical seeds.

**Type.** `shared.seed`.

**Default.** Unset.

**Example.**
```text
command.seed: 42
```

---

### `command.temperature`

**Definition.** The sampling temperature used by the orchestrator and (by default) broadcast to subagents.

**Cross-layer notes.** Sibling root: `subagent.temperature`. Frequently overridden per slot when diversity is the goal.

**Type.** `shared.temperature`.

**Default.** Runtime default.

**Example.**
```text
command.temperature: 0.7
```

---

## Selection / aggregation

### `command.selection_mode`

**Definition.** How the orchestrator turns N subagent outputs into one final artifact.

**Cross-layer notes.** No subagent sibling — selection is orchestrator-only. `command.ranker` and `command.aggregator` give concrete semantics to two of the modes below.

**Type.** `shared.enum {manual, auto-best, synthesize, tournament}`.
- `manual`: present all N to the user; user picks.
- `auto-best`: rank with `command.ranker`, return the top.
- `synthesize`: feed all N to `command.aggregator` to merge into one new artifact.
- `tournament`: pairwise compare and progressively eliminate.

**Default.** `manual`.

**Example.**
```text
command.selection_mode: "auto-best"
```

---

### `command.ranker`

**Definition.** A reference to logic that produces a total order over subagent outputs. May be a shell command, a sub-prompt, or a built-in heuristic name.

**Cross-layer notes.** Used only when `command.selection_mode ∈ {auto-best, tournament}`.

**Type.** `shared.addressable | shared.shell_command`.

**Default.** Command-specific (e.g., "exit code of `command.test_command` then summary heuristics").

**Example.**
```text
command.ranker: "./scripts/rank.sh"
command.ranker: "prefer fewer findings of severity >= major"
```

---

### `command.aggregator`

**Definition.** A reference to logic that synthesizes N outputs into one. Used when `command.selection_mode = "synthesize"`.

**Cross-layer notes.** Distinct from `command.ranker` — the aggregator *combines*, the ranker *orders*.

**Type.** `shared.addressable | shared.shell_command`.

**Default.** Unset.

**Example.**
```text
command.aggregator: "./scripts/merge-findings.py"
```

---

### `command.compare_against`

**Definition.** A baseline artifact (typically the input being refined) plus an optional comparison rubric, so candidate outputs in a refine-style command can be scored against the baseline rather than against each other.

**Cross-layer notes.** Often passed through to subagents as part of `subagent.context`.

**Type.** `shared.addressable`.

**Default.** Unset.

**Example.**
```text
command.compare_against: "./prompts/original.md"
```

---

## Isolation / workspace

### `command.isolation`

**Definition.** How the command isolates each subagent's filesystem and process state.

**Cross-layer notes.** Determines the meaning of `command.base_branch`, `command.worktree_root`, and the existence of `subagent.worktree_path`. With `isolation = none`, those parameters are inert.

**Type.** `shared.enum {worktree, container, sandbox, none}`.

**Default.** `worktree` for git-aware commands; `none` for read-only analytical commands.

**Example.**
```text
command.isolation: "worktree"
```

---

### `command.base_branch`

**Definition.** The branch from which each subagent's worktree is forked, and (in `merge_mode = auto`) the merge target.

**Cross-layer notes.** Sibling root: `subagent.base_branch` (which the subagent sees as a read-only label for diffs).

**Type.** `shared.branch_ref`.

**Default.** Current branch (`git rev-parse --abbrev-ref HEAD`).

**Example.**
```text
command.base_branch: "main"
```

---

### `command.worktree_start_ref`

**Definition.** Any commit-ish from which `git worktree add --detach` starts the new worktree. Used when the start point is NOT a branch tip (e.g., a tag or a SHA).

**Cross-layer notes.** Supersedes `command.base_branch` for the start point, but `command.base_branch` is still used as the merge target. When unset, the start point equals `command.base_branch`.

**Type.** `shared.commit_ish`.

**Default.** `HEAD`.

**Example.**
```text
command.worktree_start_ref: "origin/release-2.4"
```

---

### `command.worktree_name`

**Definition.** The base filesystem-safe name used for each worktree directory and branch.

**Cross-layer notes.** When `command.parallel > 1`, the orchestrator appends a 1-based `-{i}` suffix per slot. No subagent sibling — the resolved per-slot name lives in `subagent.worktree_path`.

**Type.** `string` (kebab-case slug).

**Default.** Slug derived from `command.task`.

**Example.**
```text
command.worktree_name: "parse-config-toml"
```

---

### `command.worktree_root`

**Definition.** The directory under which all worktrees are created.

**Cross-layer notes.** No subagent sibling — subagents only see their own `subagent.worktree_path`.

**Type.** `shared.directory`.

**Default.** `$HOME/.cursor/worktrees/<command.worktree_name>/`.

**Example.**
```text
command.worktree_root: "/tmp/wt"
```

---

### `command.cleanup_policy`

**Definition.** What to do with each worktree after the command finishes.

**Cross-layer notes.** Distinct from `command.delete_worktree` (a boolean shortcut). When both are set, `command.cleanup_policy` wins.

**Type.** `shared.policy_string {keep, delete-on-merge, delete-always, delete-on-success}`.

**Default.** `delete-on-merge`.

**Example.**
```text
command.cleanup_policy: "keep"
```

---

### `command.delete_worktree`

**Definition.** Boolean shortcut: `true` is equivalent to `command.cleanup_policy = delete-on-merge`; `false` is equivalent to `keep`.

**Cross-layer notes.** Provided for backward compatibility with commands that only expose the boolean. New commands SHOULD use `command.cleanup_policy`.

**Type.** `shared.boolean`.

**Default.** `true`.

**Example.**
```text
command.delete_worktree: false
```

---

## Lifecycle / persistence

### `command.auto_save_winner`

**Definition.** When `command.n_candidates > 1` and a single winner is identified (by `command.ranker` or by user pick), automatically persist that winner to `command.save_path` without further prompting.

**Cross-layer notes.** Inert when `command.n_candidates = 1` or `command.save_path` is unset.

**Type.** `shared.boolean`.

**Default.** `false`.

**Example.**
```text
command.auto_save_winner: true
```

---

### `command.merge_mode`

**Definition.** Behaviour for merging a subagent's branch back into `command.base_branch`.

**Cross-layer notes.** No subagent sibling — merging is an orchestrator-only operation.

**Type.** `shared.enum {interactive, auto}`.

**Default.** `interactive`.

**Example.**
```text
command.merge_mode: "auto"
```

---

### `command.merge_count`

**Definition.** Maximum number of subagent branches the orchestrator may merge in one invocation.

**Cross-layer notes.** No subagent sibling. Today MOST commands cap this at `1` for safety; `command.merge_count` makes that cap explicit.

**Type.** `shared.enum {one, all-passing, user-pick-multi}` OR `int with shared.int_range >= 1`.

**Default.** `one`.

**Example.**
```text
command.merge_count: "all-passing"
```

---

## Robustness / recovery

### `command.timeout`

**Definition.** Wall-clock budget for the entire command (orchestrator + all subagents). On exceeding, the orchestrator aborts in-flight slots per `command.hang_policy`.

**Cross-layer notes.** Sibling root: `subagent.timeout` (per-slot budget). Per-slot budgets are NOT derived from `command.timeout`; they default to their own conservative value.

**Type.** `shared.duration?`.

**Default.** Unset (no wall-clock cap; the orchestrator relies on `subagent.timeout` per slot).

**Example.**
```text
command.timeout: "30m"
```

---

### `command.relaunch_on_hang_after`

**Definition.** If any subagent produces no progress for this duration, the orchestrator marks it hung and (per `command.hang_policy`) relaunches it or replaces it.

**Cross-layer notes.** No subagent sibling — hang detection is observed from the orchestrator side.

**Type.** `shared.duration?`.

**Default.** Unset (manual intervention only).

**Example.**
```text
command.relaunch_on_hang_after: "90s"
```

---

### `command.retry_policy`

**Definition.** What the orchestrator does when a subagent reports failure: number of retries, backoff, whether to retry on a different model.

**Cross-layer notes.** Sibling root: `subagent.retry_policy` (which the subagent may use for its *own internal* tool retries; a totally separate concern).

**Type.** Composite object:
- `kind`: `shared.policy_string {none, fixed, exponential}`
- `max_retries`: `int with shared.int_range [0, 5]`
- `backoff`: `shared.duration?`
- `retry_on`: `shared.enum {failure, hang, both}`

**Default.** `{kind: none, max_retries: 0}`.

**Example.**
```text
command.retry_policy:
  kind: exponential
  max_retries: 2
  backoff: 30s
  retry_on: both
```

---

### `command.hang_policy`

**Definition.** What to do with a slot that exceeds `command.relaunch_on_hang_after`: `abort` (record `incomplete` and proceed), `relaunch` (same model, fresh attempt), or `replace` (new attempt, possibly different model from `command.agent_model`).

**Cross-layer notes.** No subagent sibling.

**Type.** `shared.policy_string {abort, relaunch, replace}`.

**Default.** `abort`.

**Example.**
```text
command.hang_policy: "relaunch"
```

---

## Reporting

### `command.verbosity`

**Definition.** How chatty the orchestrator's final report is.

**Cross-layer notes.** Sibling root: `subagent.verbosity` (per-slot output detail; the orchestrator may further trim).

**Type.** `shared.enum {silent, minimal, normal, detailed, trace}`.

**Default.** `normal`.

**Example.**
```text
command.verbosity: "detailed"
```

---

### `command.require_diff`

**Definition.** Whether the final report MUST include a diff (against `command.base_branch`) for each subagent that produced changes.

**Cross-layer notes.** Inert when `command.isolation = none` (no diffs to compute).

**Type.** `shared.boolean`.

**Default.** `true` for commands that modify code; `false` for read-only commands.

**Example.**
```text
command.require_diff: true
```

---

### `command.include_terminal_log`

**Definition.** Whether the final report includes (a tail of) each subagent's terminal output.

**Cross-layer notes.** Inert when `command.verbosity ∈ {silent, minimal}`.

**Type.** `shared.boolean`.

**Default.** `false`.

**Example.**
```text
command.include_terminal_log: true
```
