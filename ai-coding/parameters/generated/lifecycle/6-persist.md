# Stage 6 — Persist

**Position in lifecycle:** runs after **select** has chosen what to keep. Runs before **report**.

**Purpose:** apply the selection set to the durable state of the world — write files, merge branches, push remotes, delete worktrees. Persist is the only stage that mutates *outside* the isolation boundaries plan / execute set up.

**Flows in:** the `selection_set` (plus optional `synthesized_artifact`), plus persistence parameters resolved at input (`save_path`, `merge_mode`, `merge_strategy`, `cleanup_policy`, `commit_message`, `push_remote`).
**Flows out:** the durable side-effects — files on disk, commits in the repo, merged branches, cleaned-up worktrees.

**Skipped when:** read-only commands like `critique.md` ("MUST NOT modify `{context}` or any other file; analysis is read-only"). For these, persist is a true no-op. Persist is also skipped when the selection set is empty (no winner to persist).

**Key invariant:** persist is **all-or-nothing per item.** Each merge / write either succeeds atomically or fails leaving no half-state. Per `worktree-task-agent.md`: "abort the merge on conflict and report it" — i.e. a partial merge is never persisted.

---

## Parameters whose primary semantic lives in persist

These describe *how* to commit / merge, not whether to.

### `commit_message`

**Aliases:** `message`, `msg`
**Definition:** Commit message used when persist creates new commits (e.g. wrapping the synthesized artifact, or committing on top of a merge).
**Stages:** persist (used).
**Depth:** outer.
**Type:** text. Multi-line OK. Conventional Commits format is the house convention (see `skills/conventional-commits/SKILL.md`).
**Default:** derived from `{task}` plus the command name; the conventional-commits skill controls the exact rendering when applied.

**Example:**

```
{commit_message} = "feat(parameters): introduce lifecycle-first ontology"
```

### `merge_strategy`

**Aliases:** `git_merge_strategy`
**Definition:** The git merge mode used when persist merges a candidate branch.
**Stages:** persist (applied).
**Depth:** outer.
**Type:** enum `ff | no-ff | squash | rebase`.
   - `ff`: fast-forward when possible (no merge commit).
   - `no-ff`: always create a merge commit (`worktree-task-agent.md`'s default).
   - `squash`: squash all candidate commits into one on the target.
   - `rebase`: rebase the candidate branch onto target, then fast-forward.
**Default:** `no-ff`.

**Example:**

```
{merge_strategy} = no-ff   # matches worktree-task-agent.md
{merge_strategy} = squash  # collapse fan-out commits into one
```

From `worktree-task-agent.md`:

> "Merge the selected branch (if any) into `{base_branch}` with `git merge --no-ff`; abort the merge on conflict and report it."

### `push_remote`

**Aliases:** `push`, `auto_push`
**Definition:** Whether to push the post-merge branch (or the new commit) to the configured remote after a successful local persist.
**Stages:** persist (applied).
**Depth:** outer.
**Type:** bool, or remote name string (e.g. `"origin"`) for explicit selection.
**Default:** `false`. `worktree-task-agent.md` keeps push explicitly out of scope: "Out of scope: pushing, opening PRs, creating tags …"

**Example:**

```
{push_remote} = false
{push_remote} = "origin"
```

When `true` is honored, persist runs `git push <remote> <branch>` after merge.

---

## Parameters consumed in persist (canonical homes elsewhere)

| Parameter            | Home    | What persist does with it                                              |
| -------------------- | ------- | ---------------------------------------------------------------------- |
| `save_path`          | input   | writes `synthesized_artifact` (or the winner's artifact) to this path |
| `output_format`      | input   | dictates the serialized shape of the file written to `save_path`     |
| `merge_mode`         | input   | gating: `interactive` already paused at select; persist trusts the user's call. `auto` proceeds based on `selection_set`. |
| `merge_count`        | input   | upper bound on sequential merges performed                            |
| `cleanup_policy`     | input   | what to do with worktrees (and their branches) after merge succeeds   |
| `worktree_name`, `worktree_root` | plan | identify which worktrees / branches to clean up               |
| `base_branch`        | plan    | the merge target                                                       |
| `auto_save_winner`   | input   | if true, persist skips the "are you sure?" beat and writes immediately |
| `isolation`          | plan    | governs whether cleanup tears down worktrees, containers, or nothing |
| `selection_set`      | select  | the work-list                                                          |
| `synthesized_artifact`| select | the artifact to persist in `synthesize` mode                          |

---

## Persist subroutines (the canonical operations)

These are not parameters but named procedures so the contract is unambiguous.

### `persist_artifact(slot_id | synthesized)`

**Definition:** Write the artifact to `save_path`. Creates parent directories. Honors `output_format`.
**Triggers:** `save_path` is set, AND (`auto_save_winner = true` OR the user confirmed in `interactive` select).

### `persist_merge(slot_id)`

**Definition:** Merge slot's branch into `base_branch` via `merge_strategy`. Abort and report on conflict.
**Triggers:** isolation is `worktree`, slot is in `selection_set`, and either `merge_mode = auto` with all guardrails passing OR user confirmed at select.

From `worktree-task-agent.md`'s contract:

> "MUST NOT merge a worktree branch if its agent reported failure, `{test_command}` exited non-zero, `{stop_condition}` is unmet, or the branch has unresolved conflicts with `{base_branch}`."

These are precondition guards inside `persist_merge`; they MUST be checked again at persist time (defense in depth) even though select has already screened.

### `persist_cleanup(slot_id)`

**Definition:** Remove the slot's worktree via `git worktree remove`, delete its branch via `git branch -d`.
**Triggers:** `cleanup_policy = delete` (always), or `cleanup_policy = delete-merged-only` AND the merge succeeded.

From `worktree-task-agent.md`:

> "When a worktree branch is merged and `{delete_worktree}` is `true`, that worktree is removed via `git worktree remove` and its branch deleted via `git branch -d` after the merge succeeds."

### `persist_push()`

**Definition:** Push the now-merged `base_branch` to `push_remote`.
**Triggers:** `push_remote` truthy AND `persist_merge` succeeded.

---

## Stage outputs (what persist produces for report)

### `persistence_record`

**Definition:** Per-item record of what persist did.
**Type:** list of records — `{ slot_id (or "synthesized"), action: "write" | "merge" | "cleanup" | "push", target: path-or-ref, outcome: "succeeded" | "failed" | "skipped", reason: text }`.
**Producer:** persist.
**Consumer:** report (rendered as the "Persistence" / "Merge Outcome" section).

---

## Cross-stage notes

- **Persist re-checks guards.** Even though select already enforced merge-eligibility, persist re-validates `slot_status`, `slot_test_exit_code`, and `stop_condition` before merging. If anything changed (e.g. user edited a file between select and persist in interactive mode), persist aborts that item and reports it.
- **Per-item isolation.** Multiple items in the selection set persist sequentially, each atomic. A failure in item N does not roll back items 1..N-1, but it does prevent items N+1..M from proceeding (fail-fast). Per-item outcomes go in `persistence_record`.
- **Conventional Commits skill applies here.** When persist creates commits (squash merge, synthesize-mode artifact commit), the `conventional-commits` skill governs the message structure. The skill is consumed at persist; its result is `commit_message`.
- **Minimal-diffs skill is *not* a persist concern.** It's an execute-time skill (it shapes what the agent writes); persist just takes the resulting diff and merges it. The two skills cleanly partition by stage.
- **Persist has no parallel execution.** Even with `merge_count > 1`, merges happen in a deterministic order (ranker order, then `tie_breaker`), one at a time, because git operations on the same `base_branch` cannot safely interleave.
