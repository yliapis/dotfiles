# Concern: Lifecycle / Persistence

> **Responsibility:** Declare *what happens to the chosen result* after the agent finishes: is it auto-promoted to a saved location, merged into a base branch, and how many candidates are promoted at once. Lifecycle is the bridge from "selection picked a winner" to "the winner is materialized in the user's project".
>
> **Primary parameters:** `auto_save_winner`, `merge_mode`, `merge_count`

## Why this concern exists

Selection (see [selection.md](./selection.md)) ends with a winning candidate (or several). Lifecycle answers *what to do with it*: write to a file (`auto_save_winner`), merge into a branch (`merge_mode`), and how many such promotions are allowed in one invocation (`merge_count`). These knobs would clutter `selection.md` if mixed in, because the user often wants to *change selection without changing promotion* (e.g. switch from `manual` to `auto-best` but keep merging interactive). Keeping them separate lets the two halves vary independently.

The shared file destination (`save_path`) lives in [io.md](./io.md) because it's an I/O concern (where bytes go). This concern owns the *policy* that decides whether and when `save_path` gets written.

## Parameters

### `auto_save_winner`

**Aliases:** `auto_persist`, `promote_winner`
**Definition:** Whether a clearly-selected winning candidate is automatically written to `save_path` without further user confirmation.
**Type:** `boolean`.
**Default:** `false`.

**Cross-refs:**

- [`save_path` (io.md)](./io.md#save_path) — the destination written to when `auto_save_winner=true`.
- [`selection_mode` (selection.md)](./selection.md#selection_mode) — `auto_save_winner=true` requires `selection_mode != manual` (a programmatic winner) and `n_candidates > 1`.
- [`min_successes` (selection.md)](./selection.md#min_successes) — auto-save is suppressed if `successes < min_successes`.
- [`require_diff` (reporting.md)](./reporting.md#require_diff) — frequently paired with `auto_save_winner=true` so the user can audit what was promoted.

**Example:** `/meta-prompt n_candidates=4 selection_mode=auto-best auto_save_winner=true save_path=.cursor/commands/pr-review.md` — the winner is written to disk without an extra confirmation step.

---

### `merge_mode`

**Aliases:** `promotion_mode`, `merge_strategy`
**Definition:** How a winning worktree branch (or a selected candidate diff) is promoted into `base_branch`.
**Type:** Enum: `interactive | auto | none`.
**Default:** `interactive`.

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | The promotion policy for *this command's* candidates. `/worktree-task-agent`'s `merge_mode` parameter is exactly this. |
| **subagent** | A subagent's own merge decisions, e.g. a subtree of children that have their own internal promotion logic. Typically `none` (subtree results bubble up to the parent for the parent's merge decision). |
| **skill** | Skills do not own `merge_mode`; they reference the calling command's value to decide whether to render a merge prompt vs. proceed silently. |

**Values:**

- `interactive` — present every candidate diff to the user and ask explicitly which to merge.
- `auto` — merge at most one candidate that satisfies all gates (test_command, stop_condition, no conflicts); skip if none qualify.
- `none` — never merge; leave candidates in their worktrees / on their branches for the user to handle manually.

**Cross-refs:**

- [`selection_mode` (selection.md)](./selection.md#selection_mode) — `merge_mode=interactive` is roughly `selection_mode=manual` at the lifecycle layer.
- [`base_branch` (isolation.md)](./isolation.md#base_branch) — the merge target.
- [`merge_count` (this file)](#merge_count) — caps how many merges happen.
- [`test_command` (constraints.md)](./constraints.md#test_command) — `merge_mode=auto` predicates on it.
- [`cleanup_policy` (isolation.md)](./isolation.md#cleanup_policy) — merged worktrees are deleted when `cleanup_policy=delete-on-merge`.

**Example:** `/worktree-task-agent task=X parallelism=4 merge_mode=auto test_command="pytest -q"` — the first passing candidate is merged automatically; the others are left in place.

---

### `merge_count`

**Aliases:** `max_merges`, `promotion_quota`
**Definition:** The maximum number of candidate branches merged into `base_branch` in this invocation.
**Type:** `int_range [0, n_candidates]` (see [`constraints.md#int_range`](./constraints.md#int_range)) **or** enum `{one, all-passing, user-pick-multi}`.
**Default:** `1` (matches `/worktree-task-agent`'s current implicit cap).

**Cross-refs:**

- [`n_candidates` (replication.md)](./replication.md#n_candidates) — upper bound.
- [`merge_mode` (this file)](#merge_mode) — `auto` mode plus `merge_count > 1` introduces ordering questions (per `/worktree-task-agent`'s "prefer the lowest-index branch" tiebreaker).
- [`selection_mode` (selection.md)](./selection.md#selection_mode) — `all-passing` selection naturally pairs with `merge_count=all-passing`.

**Example:** `/worktree-task-agent task=X parallelism=4 merge_mode=auto merge_count=all-passing` — every candidate that passes `test_command` is merged in order (cherry-pick-like flow); conflicts abort the chain.
