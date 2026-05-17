# Scope: `root` (level 0)

The **root scope** is the outermost frame of a command invocation. It is the only scope that the user directly populates from the slash-command line and the only scope where orchestration parameters (replication, fan-out, selection, aggregation) are *first-class*. Every other scope in the tree is created by the root or by an ancestor that itself was created by the root.

A command always has exactly one root scope. The root may have zero children (flat shape — see `tree-shapes.md#flat-depth-0`), one layer of children (fan-out — `critique.md`), or arbitrarily nested children (partition fan-out, recursive — see `tree-shapes.md`).

This file documents every parameter that can be bound at `root.*`. Children either INHERIT, SHADOW, RESET, or BUBBLE these (see `inheritance.md`).

> **Naming convention.** Within prose, parameters are written `root.<name>` (e.g. `root.task`, `root.parallel`). Within a command file (Markdown prompt) the same parameter is referenced by `{<name>}` because there is only one scope visible to that file's author at write time.

---

## A. Task / Intent

Parameters that describe **what** the command is being asked to do at the top level.

### `root.task`
- **Definition.** The imperative work the command performs end-to-end.
- **Inheritance.** SHADOW down by default — children re-bind `task` to their assigned slice, never to the original verbatim string. (See `inheritance.md#shadow`.)
- **Type.** `string` (single-line summary) or `markdown` (multi-line spec).
- **Default.** Required for action-shaped commands (`worktree-task-agent`, `refine-best-of-n`); not present on read-only inquiry commands.
- **Example.** `root.task = "implement OAuth login and verify with the test suite"` → propagates as `root.subagent[i].task = "implement OAuth login (slot i of N)"` → resolves at `root.subagent[i].leaf.task = "implement OAuth login"` (see `inheritance.md#shadow`).

### `root.input`
- **Definition.** The exact text the user typed after the slash command, preserved verbatim before any parsing or normalization.
- **Inheritance.** INHERIT (often unused below root because children receive a derived `task` instead).
- **Type.** `string` (verbatim, may be empty).
- **Default.** Required when the command parses free-form user input (`meta-prompt`); optional otherwise.
- **Example.** `root.input = "save as /pr-review: review a PR for security issues"` (consumed by `meta-prompt.md`).

### `root.context`
- **Definition.** The artifact(s) the command consumes as the subject of analysis or transformation, distinct from `root.task` (which is the verb) and `root.input` (which is the raw user string).
- **Inheritance.** INHERIT down — every child needs the same context unless explicitly shadowed.
- **Type.** Tagged union `{file, directory, glob, url, inline}`; see `root.format` for content typing.
- **Default.** Required for analysis commands (`critique`); absent for synthesis-from-scratch commands.
- **Example.** `root.context = {kind: "file", path: "src/auth.ts"}` (consumed by `critique.md`).

---

## B. File I/O

Parameters that describe **how** content is loaded and emitted at the root level.

### `root.file`
- **Definition.** A single absolute or repo-relative file path the command reads from.
- **Inheritance.** INHERIT.
- **Type.** `path` (existing file) constrained by `root.file_type` when set.
- **Default.** Optional; mutually exclusive with `directory` / `glob` / `url` / `inline`.
- **Example.** `root.file = "ai-coding/plugins/ai-coding/commands/critique.md"`.

### `root.directory`
- **Definition.** A directory whose contents the command consumes recursively.
- **Inheritance.** INHERIT.
- **Type.** `path` (existing directory).
- **Default.** Optional.
- **Example.** `root.directory = "ai-coding/parameters/"`.

### `root.glob`
- **Definition.** A glob pattern resolving to a multi-set of files.
- **Inheritance.** INHERIT (children typically operate on the **same** resolved set; partitions may SHADOW to a slice).
- **Type.** `string` matching glob syntax (`**/*.md`, `src/**/*.ts`, …).
- **Default.** Optional.
- **Example.** `root.glob = "**/*.md"`.

### `root.url`
- **Definition.** A remote URL the command fetches and treats as input.
- **Inheritance.** INHERIT.
- **Type.** `url` (HTTP/HTTPS).
- **Default.** Optional.
- **Example.** `root.url = "https://www.conventionalcommits.org/en/v1.0.0/"`.

### `root.inline`
- **Definition.** Content provided inline in the user's invocation string, with no path indirection.
- **Inheritance.** INHERIT.
- **Type.** `string` | `markdown`.
- **Default.** Optional.
- **Example.** `root.inline = "## Task\nClassify these reviews..."`.

### `root.format`
- **Definition.** Declares the content type of the resolved input so children know how to parse it.
- **Inheritance.** INHERIT.
- **Type.** Enum `code | md | json | image | csv | binary | text`.
- **Default.** Inferred from extension when one of `file` / `glob` is set; otherwise `text`.
- **Example.** `root.format = "md"`.

### `root.file_type` (a.k.a. `root.extension`)
- **Definition.** Constrains which file extensions are accepted when resolving `file` / `directory` / `glob`.
- **Inheritance.** INHERIT.
- **Type.** Set of extensions written with leading dot (e.g. `{".md"}`, `{".py", ".pyi"}`); the `file_type` formalism is defined formally in `inheritance.md#formalism-file_type`.
- **Default.** Unset (no restriction).
- **Example.** `root.file_type = {".md"}` rejects `src/auth.ts` even when matched by `root.glob`.

### `root.save_path`
- **Definition.** Where the root product is persisted on disk after the run completes.
- **Inheritance.** SHADOW down — leaves write to a per-leaf path (e.g. `root.save_path = ".cursor/commands/foo.md"` becomes `leaf.save_path = "$WORKTREE/.cursor/commands/foo.md"`); root reads the bubbled artifact and may finalize at its own `save_path`.
- **Type.** `path` (created if missing).
- **Default.** Unset (write nothing) or inferred (`meta-prompt` infers `.cursor/commands/<kebab>.md` when save intent is detected).
- **Example.** `root.save_path = ".cursor/commands/pr-review.md"`.

### `root.output_format`
- **Definition.** The required structure of the root reply (the final message the command emits to the user).
- **Inheritance.** Does not propagate — only root has an "output" in this sense (children BUBBLE into root, not back to the user). See `inheritance.md#bubble`.
- **Type.** `markdown` template | enum `{report, prompt, diff, json, plain}`.
- **Default.** Determined by the command's `## Output Format` section.
- **Example.** `root.output_format = "report"` (`critique.md`).

---

## C. Constraints

Parameters that restrict, validate, or terminate work performed under root.

### `root.criteria`
- **Definition.** The judgment / quality rubric against which work or artifacts are evaluated.
- **Inheritance.** INHERIT (children evaluate against the same rubric); may SHADOW for specialized children (e.g. a "security-only" subagent).
- **Type.** `path` | `directory` | `inline markdown` (list of criterion bullets).
- **Default.** When unset, root supplies a **default rubric** (e.g. `critique.md` defaults to "quality + determinism").
- **Example.** `root.criteria = "ai-coding/criteria/security.md"`; `root.subagent[1].criteria = "ai-coding/criteria/security.md#auth"` (SHADOWED slice).

### `root.guardrails`
- **Definition.** Hard MUST / MUST NOT rules that apply to every scope under root.
- **Inheritance.** INHERIT (always); guardrails MUST NOT be RESET by children — only further constrained.
- **Type.** Markdown bullet list, each prefixed `MUST`, `MUST NOT`, or `Scope:`.
- **Default.** Populated from the command file's `## Guardrails` section.
- **Example.** `root.guardrails = ["MUST keep agent execution isolated to its assigned worktree", ...]` (`worktree-task-agent.md`).

### `root.stop_condition`
- **Definition.** Explicit termination predicate beyond the implicit "task implemented" check.
- **Inheritance.** INHERIT.
- **Type.** `string` (natural-language predicate) | `command` (shell predicate exit code 0).
- **Default.** Unset (terminate when `task` is judged complete).
- **Example.** `root.stop_condition = "until pytest -x exits 0 three times in a row"`.

### `root.test_command`
- **Definition.** Shell command run to verify completion; exit code 0 = pass.
- **Inheritance.** INHERIT (every leaf runs the same test); BUBBLES its `exit_code` and `verification` log up.
- **Type.** `shell command string`.
- **Default.** Unset.
- **Example.** `root.test_command = "pytest tests/"`.

### `root.int_range` (formalism)
- **Definition.** Not a parameter itself — a **type formalism** for validating any integer-typed parameter (`parallel`, `num_experiments`, `min_successes`, …). Defined formally in `inheritance.md#formalism-int_range`.
- **Type.** Interval written `[lo, hi]`, `(lo, hi)`, `>= n`, `(0, ∞)`, etc.
- **Example.** `root.parallel: int_range >= 1`; `root.fan_out: int_range [1, 16]`.

---

## D. Replication / Parallelism

Parameters that control how many children root spawns and how many run at once. **All replication / fan-out parameters are root-only by default** — only the orchestrator owns the multiplicity decision; children that re-fan-out re-bind these from scratch.

### `root.k` (a.k.a. `root.n_candidates`)
- **Definition.** Number of distinct candidate outputs root requests (best-of-N semantics).
- **Inheritance.** Does not INHERIT — children have already been spawned by root; "k" is meaningless inside a leaf.
- **Type.** `int_range >= 1`.
- **Default.** `1`.
- **Example.** `root.n_candidates = 4` (in a hypothetical `meta-prompt --n=4` mode).

### `root.num_experiments`
- **Definition.** Number of **independent replicas** of the same task (synonym with `k` when no diversification is involved; distinct when diversification of the children is intended).
- **Inheritance.** Does not INHERIT.
- **Type.** `int_range >= 1`.
- **Default.** `1`.
- **Example.** `root.num_experiments = 3` (`critique.md`).

### `root.parallel` (a.k.a. `root.parallelism`)
- **Definition.** Maximum concurrent children at any moment.
- **Inheritance.** Does not INHERIT (children have a separate concurrency budget if they themselves fan out; see `root.subagent[i].parallel`).
- **Type.** `int_range >= 1`; should satisfy `parallel <= max(k, num_experiments, fan_out)`.
- **Default.** `1` (sequential).
- **Example.** `root.parallel = 2` (`critique.md`); `root.parallelism = 4` (`worktree-task-agent.md`).

### `root.num_partitions`
- **Definition.** Number of partitions root groups its children into; partitions are intermediate scopes between root and leaves and induce a depth-2 tree.
- **Inheritance.** Does not INHERIT.
- **Type.** `int_range >= 1`; must divide evenly into `parallel` or `fan_out` per the partition contract.
- **Default.** `1` (no partitioning; depth-1 tree).
- **Example.** `root.num_partitions = 2`, `root.parallelism = 4` → 2 partitions × 2 leaves each (`worktree-task-agent.md`).

### `root.fan_out`
- **Definition.** Branching factor at root (how many direct children root creates). Often equal to `parallel` in fully-parallel commands; can exceed `parallel` when children are dispatched in waves.
- **Inheritance.** Does not INHERIT.
- **Type.** `int_range >= 1`.
- **Default.** Equal to `max(k, num_experiments, parallel)` when not explicitly set.
- **Example.** `root.fan_out = 8`, `root.parallel = 4` (8 children, 4 at a time).

---

## E. Subagent Tree Configuration

Parameters that describe **what kind** of children root creates (orthogonal to **how many** in section D).

### `root.subagent_type`
- **Definition.** The class of subagent root spawns: a slash-command name, a prompt template path, or a built-in identifier.
- **Inheritance.** SHADOW (each child re-binds to its own concrete prompt); RESET when a recursive child is the same class.
- **Type.** `string` (one of `worktree-agent`, `critique-runner`, `meta-prompt-runner`, …) | `path`.
- **Default.** Inferred from the parent command (`worktree-task-agent` → `worktree-agent`).
- **Example.** `root.subagent_type = "worktree-agent"`.

### `root.subagent_model`
- **Definition.** Default model assigned to each child unless overridden by `root.agent_model`.
- **Inheritance.** Resolves into `root.subagent[i].model` (SHADOWS scalar; ZIPS list).
- **Type.** Model identifier (`claude-opus-4`, `claude-sonnet-4`, …) | list of identifiers.
- **Default.** `root.model` (the parent agent's model).
- **Example.** `root.subagent_model = "claude-opus-4"`.

### `root.subagent_prompt`
- **Definition.** Verbatim prompt body handed to each child (replaces or augments the implicit prompt derived from `root.subagent_type`).
- **Inheritance.** SHADOW per child when combined with `focus_hints` or `task` slicing.
- **Type.** `markdown` | `path`.
- **Default.** Unset (use `subagent_type`'s built-in template).
- **Example.** `root.subagent_prompt = "ai-coding/prompts/refine-prompt.md"`.

### `root.subagent_constraints`
- **Definition.** Additional MUST / MUST NOT rules that apply only to children (not to root itself).
- **Inheritance.** INHERIT down through every descendant.
- **Type.** Markdown bullet list.
- **Default.** Unset.
- **Example.** `root.subagent_constraints = ["MUST NOT push", "MUST NOT delete worktrees"]`.

### `root.depth`
- **Definition.** Maximum tree depth root permits its descendants to grow.
- **Inheritance.** Decremented by 1 at every level. A child observes `subagent.depth = root.depth - 1`; spawning further children is rejected when `depth == 0`.
- **Type.** `int_range >= 0`. `0` = leaf-only (root + leaves, no intermediate subagents); `1` = root + one subagent layer + leaves; etc.
- **Default.** `1` (one fan-out layer + leaves).
- **Example.** `root.depth = 2` permits `root → partition → subagent → leaf`.

---

## F. Models / Diversity

Parameters that pin or vary models, seeds, and stylistic dimensions across the tree.

### `root.model`
- **Definition.** The model running the root scope itself (the orchestrator).
- **Inheritance.** INHERIT — children default to root's model unless `agent_model` / `subagent_model` overrides.
- **Type.** Model identifier.
- **Default.** Parent agent's model (i.e., the model the user is currently chatting with).
- **Example.** `root.model = "claude-opus-4"`.

### `root.agent_model`
- **Definition.** Model(s) used per child agent — the canonical "child model" knob.
- **Inheritance.** SHADOW (scalar broadcasts to every child; list zips by index — child `i` receives `agent_model[i]`).
- **Type.** Model identifier (scalar) | list of identifiers (length MUST equal `parallel` or be a valid partition slice).
- **Default.** `root.model`.
- **Example.** `root.agent_model = ["claude-opus-4", "claude-sonnet-4", "gpt-5"]` with `parallel = 3`.

### `root.seed`
- **Definition.** Global RNG / sampling seed used for diversity control.
- **Inheritance.** SHADOW per child to `root.seed + i` so siblings are reproducibly distinct yet jointly seedable.
- **Type.** `int`.
- **Default.** Unset (non-deterministic).
- **Example.** `root.seed = 1234` → `root.subagent[2].seed = 1236`.

### `root.temperature`
- **Definition.** Sampling temperature for child models.
- **Inheritance.** INHERIT (or SHADOW per child for diversity).
- **Type.** `float` in `[0, 2]`.
- **Default.** Model-default.
- **Example.** `root.temperature = 1.0`.

### `root.focus_hints`
- **Definition.** A list of refinement angles (one per child) that diversifies otherwise-identical replicas.
- **Inheritance.** SHADOW per child — child `i` receives the singular `focus_hint = focus_hints[i]`.
- **Type.** `list[string]` of length `<= fan_out`; shorter lists left-pad with `null`.
- **Default.** Unset (no diversification).
- **Example.** `root.focus_hints = ["tighten guardrails", "clarify parameters", "improve workflow steps"]`.

---

## G. Selection / Aggregation

Parameters that control how root reduces per-child results back into a single output. **These parameters are root-only — children do not select or aggregate, they only BUBBLE.**

### `root.selection_mode`
- **Definition.** How root chooses among bubbled child results.
- **Type.** Enum `manual | auto-best | synthesize | all`.
  - `manual` — present results, ask user.
  - `auto-best` — apply `ranker` and pick top-1.
  - `synthesize` — apply `aggregator` to merge into a single output.
  - `all` — emit every result without selecting.
- **Default.** `manual` for interactive commands; `auto-best` when `test_command` is set.
- **Example.** `root.selection_mode = "auto-best"`.

### `root.min_successes`
- **Definition.** Minimum number of children that must report `status = success` before root proceeds to selection / aggregation.
- **Type.** `int_range [0, fan_out]`.
- **Default.** `1`.
- **Example.** `root.min_successes = 3` with `fan_out = 5` requires ≥ 3 successful leaves.

### `root.ranker`
- **Definition.** Function or prompt that orders bubbled results from best to worst.
- **Type.** Identifier (`test-pass-then-diff-size`, …) | `path` to ranker prompt | `null`.
- **Default.** Built-in `test-pass-then-diff-size` when `test_command` is set; otherwise `manual`.
- **Example.** `root.ranker = "ai-coding/rankers/clarity.md"`.

### `root.aggregator`
- **Definition.** Function or prompt that merges multiple bubbled results into one synthesized result.
- **Type.** Identifier | `path` to aggregator prompt | `null`.
- **Default.** Unset.
- **Example.** `root.aggregator = "ai-coding/aggregators/merge-findings.md"`.

### `root.compare_against`
- **Definition.** Baseline artifact every candidate is compared to (for ranking).
- **Type.** `path` | `inline` | `null`.
- **Default.** Unset.
- **Example.** `root.compare_against = "ai-coding/baselines/v1-prompt.md"`.

### `root.merge_mode`
- **Definition.** When the command's selection step is "merge a branch back", how the merge is decided.
- **Type.** Enum `interactive | auto`.
- **Default.** `interactive`.
- **Example.** `root.merge_mode = "auto"` (`worktree-task-agent.md`).

### `root.merge_count`
- **Definition.** How many branches root may merge back per invocation.
- **Type.** Enum `one | all-passing | user-pick-multi` | `int_range >= 0`.
- **Default.** `one`.
- **Example.** `root.merge_count = "one"`.

---

## H. Isolation / Workspace

Parameters that control filesystem and version-control isolation under root.

### `root.isolation`
- **Definition.** Strength of isolation between children's filesystems and the original working tree.
- **Type.** Enum `none | worktree | sandbox | container`.
- **Default.** `worktree` for action commands; `none` for read-only commands.
- **Example.** `root.isolation = "worktree"`.

### `root.base_branch`
- **Definition.** Branch from which child worktrees are forked.
- **Inheritance.** INHERIT (every child shares the same base).
- **Type.** Git ref (branch, tag, SHA).
- **Default.** Current branch (`git rev-parse --abbrev-ref HEAD`).
- **Example.** `root.base_branch = "main"`.

### `root.worktree_name`
- **Definition.** Base name for worktree directories and child branches; per-child suffix `-1`, `-2`, … is appended when fan_out > 1.
- **Inheritance.** SHADOW down — `subagent[i].worktree_name = root.worktree_name + "-" + i`.
- **Type.** Filesystem-safe kebab-case `string`.
- **Default.** Slug of `root.task`.
- **Example.** `root.worktree_name = "oauth-login"` → `subagent[3].worktree_name = "oauth-login-3"`.

### `root.worktree_root`
- **Definition.** Directory under which all child worktrees are created.
- **Inheritance.** INHERIT.
- **Type.** `path` (auto-created).
- **Default.** `~/.cursor/worktrees/<run-id>/`.
- **Example.** `root.worktree_root = "/tmp/wt"`.

### `root.cleanup_policy`
- **Definition.** What to do with worktrees and branches after merge / on failure.
- **Type.** Enum `keep | delete-on-success | delete-always | interactive`.
- **Default.** `delete-on-success`.
- **Example.** `root.cleanup_policy = "keep"` for forensic debugging.

### `root.delete_worktree`
- **Definition.** Convenience boolean equivalent to `cleanup_policy = delete-on-success` when `true`, `keep` when `false`.
- **Type.** `bool`.
- **Default.** `true`.
- **Example.** `root.delete_worktree = false` (`worktree-task-agent.md`).

---

## I. Lifecycle / Persistence

Parameters that control whether and where root persists output beyond the chat reply.

### `root.auto_save_winner`
- **Definition.** When `selection_mode = auto-best` and a clear winner is found, persist it to `save_path` automatically.
- **Type.** `bool`.
- **Default.** `false`.
- **Example.** `root.auto_save_winner = true`.

(`root.save_path` and `root.merge_mode` are documented in sections B and G respectively; they appear here only conceptually.)

---

## J. Robustness / Recovery

Parameters that govern hangs, timeouts, retries.

### `root.timeout` (a.k.a. `root.relaunch_on_hang_after`)
- **Definition.** Per-child wall-clock budget; a child that produces no progress for this duration is aborted.
- **Inheritance.** INHERIT — every child observes the same budget.
- **Type.** Duration (`30s`, `5m`, `1h`).
- **Default.** Unset (infinite).
- **Example.** `root.timeout = "10m"`.

### `root.retry_policy`
- **Definition.** When and how many times to retry a child that aborts or fails.
- **Type.** Enum `never | on-fail | on-hang | both` × `int_range >= 0` (max retries).
- **Default.** `(never, 0)`.
- **Example.** `root.retry_policy = ("on-hang", 1)`.

### `root.hang_policy`
- **Definition.** What to do when a child hangs past `timeout`.
- **Type.** Enum `abort | replace | manual`.
- **Default.** `abort`.
- **Example.** `root.hang_policy = "replace"`.

---

## K. Reporting

Parameters that control the verbosity and shape of root's reply to the user.

### `root.verbosity`
- **Definition.** How much detail root emits in its final reply.
- **Inheritance.** INHERIT (children with their own subtree apply the same verbosity).
- **Type.** Enum `silent | summary | full`.
- **Default.** `summary`.
- **Example.** `root.verbosity = "full"`.

### `root.require_diff`
- **Definition.** Whether root must emit a diff alongside the textual reply (relative to a baseline or the original artifact).
- **Type.** `bool`.
- **Default.** `false` for analysis commands; `true` for action commands when `selection_mode != silent`.
- **Example.** `root.require_diff = true`.

### `root.include_terminal_log`
- **Definition.** Whether per-leaf terminal logs (BUBBLED up) are included in the final reply.
- **Type.** `bool`.
- **Default.** `false`.
- **Example.** `root.include_terminal_log = true` (forensic mode).

---

## Summary table

| Family | Param | Type | Default | Inheritance |
|---|---|---|---|---|
| A | `task` | string \| md | required (action) | SHADOW |
| A | `input` | string | required (parser) | INHERIT |
| A | `context` | tagged union | required (analysis) | INHERIT |
| B | `file` | path | optional | INHERIT |
| B | `directory` | path | optional | INHERIT |
| B | `glob` | string | optional | INHERIT |
| B | `url` | url | optional | INHERIT |
| B | `inline` | string \| md | optional | INHERIT |
| B | `format` | enum | inferred | INHERIT |
| B | `file_type` | set of ext | unset | INHERIT |
| B | `save_path` | path | optional | SHADOW |
| B | `output_format` | template | required | not propagated |
| C | `criteria` | path \| md | command default | INHERIT |
| C | `guardrails` | md list | required | INHERIT (additive) |
| C | `stop_condition` | string \| cmd | optional | INHERIT |
| C | `test_command` | shell | optional | INHERIT (BUBBLES exit) |
| D | `k` / `n_candidates` | `int_range >=1` | 1 | not propagated |
| D | `num_experiments` | `int_range >=1` | 1 | not propagated |
| D | `parallel` | `int_range >=1` | 1 | not propagated |
| D | `num_partitions` | `int_range >=1` | 1 | not propagated |
| D | `fan_out` | `int_range >=1` | derived | not propagated |
| E | `subagent_type` | id \| path | inferred | SHADOW |
| E | `subagent_model` | id \| list | `root.model` | SHADOW |
| E | `subagent_prompt` | md \| path | unset | SHADOW |
| E | `subagent_constraints` | md list | unset | INHERIT (additive) |
| E | `depth` | `int_range >=0` | 1 | decrement |
| F | `model` | id | parent's model | INHERIT |
| F | `agent_model` | id \| list | `model` | SHADOW (broadcast/zip) |
| F | `seed` | int | unset | SHADOW (offset) |
| F | `temperature` | float [0,2] | model default | INHERIT |
| F | `focus_hints` | list[string] | unset | SHADOW (zip) |
| G | `selection_mode` | enum | `manual` | not propagated |
| G | `min_successes` | `int_range >=0` | 1 | not propagated |
| G | `ranker` | id \| path | unset | not propagated |
| G | `aggregator` | id \| path | unset | not propagated |
| G | `compare_against` | path \| inline | unset | not propagated |
| G | `merge_mode` | enum | `interactive` | not propagated |
| G | `merge_count` | enum \| int | `one` | not propagated |
| H | `isolation` | enum | `worktree` (action) | INHERIT |
| H | `base_branch` | git ref | current | INHERIT |
| H | `worktree_name` | kebab string | slug(`task`) | SHADOW (`-i`) |
| H | `worktree_root` | path | `~/.cursor/...` | INHERIT |
| H | `cleanup_policy` | enum | `delete-on-success` | INHERIT |
| H | `delete_worktree` | bool | `true` | INHERIT |
| I | `auto_save_winner` | bool | false | not propagated |
| J | `timeout` | duration | unset | INHERIT |
| J | `retry_policy` | enum × int | `(never, 0)` | not propagated |
| J | `hang_policy` | enum | `abort` | not propagated |
| K | `verbosity` | enum | `summary` | INHERIT |
| K | `require_diff` | bool | conditional | not propagated |
| K | `include_terminal_log` | bool | false | not propagated |

**Total root parameters: 50**.
