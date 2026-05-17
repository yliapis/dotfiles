# Lifecycle / Persistence (Category I)

Covers *what gets saved automatically*, *how merges happen*, and *how many slots' results survive past the run*. Lifecycle parameters orchestrate the transitions between intermediate (slot-local) state and final (user-visible) state.

`command_save_path` and `subagent_save_path` are the on-disk targets for these transitions and are defined in `io.md`; this file references but does not redefine them.

---

## `auto_save_winner`

**Aliases:** `persist_winner`, `auto_persist`.
**Definition:** Whether the orchestrator automatically writes the winning slot's artifact to `command_save_path` after selection.
**Type:** boolean.
**Default:** `false` (the user always sees the artifact in the reply, but persistence is opt-in to avoid surprise writes).
**Rename rationale (multi-depth):** layer-neutral; introduced in `trajectory.md` for `meta-prompt` fan-out.
**Consumed by:** future `refine-best-of-n`.
**Example:**

```
auto_save_winner: true
command_save_path: .cursor/commands/refactor-auth.md
```

---

## `merge_mode`

**Aliases:** `merge_style`.
**Definition:** How the orchestrator handles merging slot branches into `base_branch` after selection. The interactive vs. automatic dial.
**Type:** enum: `interactive` | `auto` | `dry_run`.
  - `interactive`: present every diff and ask per slot whether to merge.
  - `auto`: select per `selection_mode` and merge with `git merge --no-ff`; abort on any conflict.
  - `dry_run`: produce the merge plan but execute no merges.
**Default:** `interactive`.
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** `worktree-task-agent` (`{merge_mode}`).
**Example:**

```
merge_mode: auto
merge_mode: dry_run        # preview only, no writes to base_branch
```

---

## `merge_count`

**Aliases:** `max_merges`, `merges_per_run`.
**Definition:** How many slot branches are eligible to merge in a single run.
**Type:** enum: `one` | `all_passing` | `user_pick_multi`, OR integer.
  - `one`: exactly one branch (current `worktree-task-agent.md` behavior).
  - `all_passing`: every branch that satisfies all merge guardrails.
  - `user_pick_multi`: user is asked to pick any subset.
  - integer N: at most N branches, picked by `ranker`. `int_range: ">= 1"`.
**Default:** `one`.
**Rename rationale (multi-depth):** layer-neutral; introduced in `trajectory.md` as an explicit replacement for the currently implicit cap.
**Consumed by:** `worktree-task-agent` (currently hard-coded to `one`); future commands.
**Example:**

```
merge_count: one
merge_count: all_passing
merge_count: 3              # pick top 3 by ranker
```

---

## `apply_strategy`

**Aliases:** `apply_mode`, `merge_strategy`.
**Definition:** The git strategy used to bring a selected branch into `base_branch`.
**Type:** enum: `merge_no_ff` | `merge_ff` | `rebase` | `squash` | `cherry_pick`.
**Default:** `merge_no_ff` (matches `worktree-task-agent.md`'s `git merge --no-ff` choice).
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** `worktree-task-agent` (implicitly `merge_no_ff`); reserved for future commands that prefer linear history.
**Example:**

```
apply_strategy: squash
apply_strategy: rebase
```

---

## `on_merge_conflict`

**Aliases:** `conflict_policy`.
**Definition:** What the orchestrator does when `apply_strategy` produces conflicts.
**Type:** enum: `abort_and_report` | `keep_workspace_and_skip` | `ask_user`.
  - `abort_and_report`: abort the merge, restore `base_branch`, report the conflict, do not modify any tree.
  - `keep_workspace_and_skip`: leave the slot's workspace in place so the user can resolve manually; skip merging this slot and continue with the next eligible one.
  - `ask_user`: prompt for a per-conflict decision.
**Default:** `abort_and_report` (matches `worktree-task-agent.md`).
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** `worktree-task-agent`; future fan-out commands.
**Example:**

```
on_merge_conflict: keep_workspace_and_skip
```
