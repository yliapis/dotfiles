# Selection / Aggregation (Category G)

Covers *how* the orchestrator picks one (or none, or many) of the outer slot results, *how* it ranks them, *how* it merges them into a single artifact, and *what baseline* it compares against.

The selection layer always sits above replication (`outer_k`) and is gated by `min_successes`. None of these parameters split by depth in current usage; the canonical names have no layer prefix.

---

## `selection_mode`

**Aliases:** `pick_mode`, `mode`.
**Definition:** How the orchestrator selects which outer slot result(s) become the final artifact.
**Type:** enum: `manual` | `auto_best` | `synthesize` | `tournament` | `all_passing`.
  - `manual`: present every slot result and ask the user to pick.
  - `auto_best`: rank with `ranker`; pick the top.
  - `synthesize`: hand every passing slot result to `aggregator` and emit its output.
  - `tournament`: pairwise compare with `ranker`; pick the winner of a single-elimination bracket.
  - `all_passing`: emit every result that satisfies `min_successes`; no single pick.
**Default:** `manual` (matches `worktree-task-agent.md`'s `interactive` merge mode by spirit).
**Rename rationale (multi-depth):** layer-neutral; no rename.
**Consumed by:** future `refine-best-of-n`; `worktree-task-agent`'s `{merge_mode}` is a degenerate two-value form (`manual` ≈ `interactive`, `auto_best` ≈ `auto`).
**Example:**

```
selection_mode: auto_best
selection_mode: synthesize
```

---

## `ranker`

**Aliases:** `score_fn`, `scorer`.
**Definition:** The function or shell command that assigns a numeric score to one slot result; used by `selection_mode = auto_best` and `selection_mode = tournament`.
**Type:** one of:
  - shell command string (stdin = slot artifact, stdout = single float on first line)
  - named built-in: `test_exit_then_diff_size` | `lints_then_diff_size` | `length` | `random`
  - file path to a script that obeys the same stdin/stdout contract.
**Default:** `test_exit_then_diff_size` when `subagent_test_command` is set; `length` (smaller is better) otherwise.
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** orchestrator selection step; future `refine-best-of-n`.
**Example:**

```
ranker: test_exit_then_diff_size
ranker: "./scripts/score-candidate.sh"
```

---

## `aggregator`

**Aliases:** `synthesizer`, `merge_fn`, `candidate_aggregator`.
**Definition:** The prompt or command that merges multiple slot results into one synthesized artifact; used by `selection_mode = synthesize`.
**Type:** one of:
  - inline prompt string handed to a synthesizer subagent
  - file path to a prompt template
  - shell command string (stdin = JSON list of slot artifacts, stdout = synthesized artifact).
**Default:** unset; required when `selection_mode = synthesize`.
**Rename rationale (multi-depth):** layer-neutral. Aliased to `{candidate_aggregator}` from `trajectory.md`.
**Consumed by:** future `refine-best-of-n`.
**Example:**

```
aggregator: inline:"Merge the N candidate prompts below into a single best refinement. Preserve every constraint that appears in a majority."
aggregator: "./scripts/synthesize-candidates.sh"
```

---

## `compare_against`

**Aliases:** `baseline`, `against`.
**Definition:** A reference artifact used as the baseline for ranking or for emitting comparison diffs (e.g., the *original* prompt when ranking refinement candidates).
**Type:** any artifact-pointer shape (`file` | `directory` | `inline` | `url` — see `io.md`).
**Default:** unset.
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** future `refine-best-of-n` (compare candidates against the original prompt); reserved as a hook for `critique` (compare findings against a previous review).
**Example:**

```
compare_against: file:./.cursor/commands/meta-prompt.md
```

---

## `tie_break`

**Aliases:** `on_tie`.
**Definition:** How the orchestrator resolves ties when two or more slots receive identical scores from `ranker`.
**Type:** enum: `lowest_index` | `random` | `ask_user` | `keep_both`.
**Default:** `lowest_index` (matches `worktree-task-agent.md`'s "prefer the lowest-index branch" rule in `auto` mode).
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** orchestrator selection step.
**Example:**

```
tie_break: ask_user
```
