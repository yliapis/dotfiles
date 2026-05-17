# Soft Shutdown

## Task

Inspect the current agent thread for outstanding work and either emit a clean-exit signal if all items are resolved, or stay on the thread and enumerate every blocking item that must be addressed first.

A soft shutdown succeeds only when all six checkpoint categories pass simultaneously: no uncommitted changes, no undeleted session worktrees, no incomplete TODOs, no unmerged session branches, no unpushed commits, and no in-progress git operations. If any checkpoint fails, the command prints the blocking items and the thread remains open.

## Parameters

- `{session_branches}` — whitespace- or comma-separated list of branch names created during this session; optional, default: inferred by stripping any trailing `-<N>` suffix from the current branch name, then collecting every local branch sharing that prefix via `git branch --list "<prefix>*"` plus the current branch itself.
- `{session_worktrees}` — whitespace- or comma-separated list of worktree paths created during this session; optional, default: inferred from `git worktree list --porcelain` by collecting all worktrees whose associated branch appears in `{session_branches}`, excluding the main working tree.
- `{todo_source}` — file path or glob pointing to a task/TODO file to inspect for unchecked items; optional, default: none (incomplete items are inferred from the current conversation's tracked task list only).

## Success Criteria

- [ ] All six checkpoint categories run in order; no category is skipped, even when an earlier one fails.
- [ ] Each checkpoint reports either PASS (zero items) or FAIL (one or more items, each listed with enough identifying detail to act on).
- [ ] The shutdown decision is derived deterministically: all six PASS → THREAD CLOSED; any FAIL → THREAD ACTIVE.
- [ ] The THREAD CLOSED output contains a final state summary (all six checkpoints: PASS, current branch name, HEAD SHA, and timestamp) and a single explicit "Ready to exit" line.
- [ ] The THREAD ACTIVE output contains the full checkpoint report and a numbered master list of every blocking item across all failing checkpoints.
- [ ] No files are modified, no git commands with side effects are run, and no worktrees or branches are created or deleted.
- [ ] When `{session_branches}` or `{session_worktrees}` is not explicitly provided, the inferred scope is printed in the report header before any checkpoint results, so the user can verify what is in scope.

## Guardrails

- MUST NOT run any git command that modifies repository state (no commit, merge, push, delete, reset, rebase, stash, or similar).
- MUST NOT delete worktrees, branches, files, or any other artifacts as a side effect.
- MUST run all six checkpoint categories regardless of earlier failures; do not short-circuit on the first FAIL.
- MUST make the inferred session scope explicit in the report header when either `{session_branches}` or `{session_worktrees}` was not supplied.
- Scope: read-only inspection of the current repository state and conversation task list. Out of scope: fixing outstanding items, committing, merging, pushing, or any other state-changing operation.

## Workflow

1. **Resolve session scope.**
   - `{session_branches}`: if provided, use as-is. If not, run `git rev-parse --abbrev-ref HEAD` to get the current branch; strip any trailing `-<digits>` suffix to derive a prefix; collect matching branches with `git branch --list "<prefix>*"` and add the current branch if absent.
   - `{session_worktrees}`: if provided, use as-is. If not, run `git worktree list --porcelain` and collect every worktree (excluding the main working tree) whose associated branch appears in the resolved `{session_branches}` list.
   - Print the resolved scope (branch list, worktree list) in the report header.

2. **Run checkpoint A — Uncommitted changes.** Execute `git status --porcelain` in the main working tree. PASS if output is empty. FAIL: list each modified, staged, or untracked file path.

3. **Run checkpoint B — Undeleted session worktrees.** Check each path in `{session_worktrees}` against the current `git worktree list` output. PASS if all resolved session worktrees are absent (deleted). FAIL: list each surviving worktree path.

4. **Run checkpoint C — Incomplete TODOs.** If `{todo_source}` is set, scan the referenced file(s) for lines matching `- [ ]`. Also inspect the current conversation's tracked task list for any item not in a `completed` or `cancelled` state. PASS if no incomplete items are found from either source. FAIL: list each incomplete item with its text.

5. **Run checkpoint D — Unmerged session branches.** For each branch in `{session_branches}` other than the current branch, run `git log <integration_branch>..<branch> --oneline` where `<integration_branch>` is inferred from `git symbolic-ref refs/remotes/origin/HEAD` (falling back to `main` then `master`). PASS if every session branch shows zero commits ahead. FAIL: list each branch with its unmerged commit count and the subject of the most recent unmerged commit.

6. **Run checkpoint E — Unpushed commits.** On the current branch, run `git log @{u}..HEAD --oneline`. If no upstream is configured, compare HEAD to the remote tip via `git ls-remote origin <current_branch>` and treat divergence as FAIL. PASS if there are no unpushed commits. FAIL: list each unpushed commit SHA and subject.

7. **Run checkpoint F — In-progress git operations.** Check for the presence of `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`, `rebase-merge/`, and `rebase-apply/` inside the `.git` directory (use `git rev-parse --git-dir` to locate it). PASS if none exist. FAIL: name each detected in-progress operation.

8. **Derive shutdown decision.** If all six checkpoints are PASS → THREAD CLOSED. If any are FAIL → THREAD ACTIVE.

9. **Emit the Output Format below.**

## Output Format

A single markdown report with these sections, in order:

### Session Scope

- `Current branch`: name and HEAD SHA.
- `Session branches`: numbered list of resolved branch names (or `(none inferred)` if the list is empty).
- `Session worktrees`: numbered list of resolved worktree paths (or `none`).
- `Scope inferred`: `yes` or `no` (yes when either list was not explicitly supplied).

### Checkpoint Results

One entry per checkpoint, labeled A–F:

```
[PASS] A — Uncommitted changes
[FAIL] B — Undeleted session worktrees
  - /path/to/worktree-foo   (branch: feature-foo)
  - /path/to/worktree-bar   (branch: feature-bar)
[PASS] C — Incomplete TODOs
...
```

### Shutdown Decision

**When all checkpoints pass:**

```
THREAD CLOSED
────────────────────────────────────────
All 6 checkpoints passed.
Branch : <current-branch> @ <sha>
Time   : <ISO-8601 timestamp>

Ready to exit.
```

**When any checkpoint fails:**

```
THREAD ACTIVE — <N> blocking item(s) across <M> failed checkpoint(s)
```

Followed by a numbered master list of every blocking item, each prefixed with its checkpoint letter and category name:

```
1. [B — Undeleted session worktrees] /path/to/worktree-foo  (branch: feature-foo)
2. [B — Undeleted session worktrees] /path/to/worktree-bar  (branch: feature-bar)
3. [D — Unmerged session branches]   feature-xyz  (3 commits ahead, latest: "add new widget")
```
