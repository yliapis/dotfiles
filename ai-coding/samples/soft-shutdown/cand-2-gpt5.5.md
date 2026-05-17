# Soft Shutdown

## Task
Check whether the current agent thread is ready to end, then emit either a `ready_to_exit` soft-shutdown signal with a final-state report or a `stay_on_thread` signal with every outstanding item that still requires attention.

## Parameters
- `{session_scope}` — how to identify worktrees, branches, TODOs, and tasks created during this agent thread; optional, default: infer from the current conversation, current repository, current branch, and any worktree-agent outputs in this thread.
- `{base_branch}` — branch used to judge whether session branches are merged; optional, default: the branch recorded by the current worktree-task-agent run, then the current branch upstream target, then `main`.
- `{remote}` — remote used to check whether commits on the current branch are unpushed; optional, default: the current branch upstream remote, then `origin`.
- `-i` / `--interactive` — flag enabling interactive mode; optional. When present, ask for clarification if `{session_scope}`, `{base_branch}`, or `{remote}` cannot be inferred. When absent, treat unresolved scope as an outstanding item and do not ask clarifying questions.

## Success Criteria
- [ ] The final response contains exactly one decision signal: `ready_to_exit` or `stay_on_thread`.
- [ ] The decision is `ready_to_exit` only when all shutdown gates pass: no staged, unstaged, or untracked changes; no relevant undeleted worktrees; no incomplete TODOs or tasks from this thread; no unmerged session branches; no unpushed commits on the current branch; and no in-progress merge, rebase, cherry-pick, revert, or bisect operation.
- [ ] When any shutdown gate fails or cannot be inspected, the decision is `stay_on_thread` and the report lists the blocking items under the matching outstanding-item category.
- [ ] The outstanding-item report includes, at minimum, categories for uncommitted changes, undeleted worktrees, incomplete TODOs/tasks, unmerged session branches, unpushed commits on the current branch, and in-progress git operations.
- [ ] Each outstanding item includes concrete evidence: a file path, worktree path, branch name, commit SHA, TODO/task label, git-operation marker, or the command/check that could not be resolved.
- [ ] The report records the resolved `{session_scope}`, `{base_branch}`, `{remote}`, current repository root, current branch, and current HEAD SHA.
- [ ] When `-i` / `--interactive` is absent, the workflow asks no clarifying questions; unresolved scope or missing upstream data is reported as a blocker.

## Guardrails
- MUST NOT emit `ready_to_exit` if any shutdown gate fails, is ambiguous, or cannot be inspected.
- MUST inspect all required outstanding-item categories before making the final decision.
- MUST NOT modify repository state: do not stage, commit, merge, rebase, push, abort git operations, delete branches, or remove worktrees.
- MUST NOT hide empty categories; show every required category with either `clear` or `blocked`.
- MUST treat unknown session ownership for a worktree, branch, TODO, or task as an outstanding item unless interactive clarification resolves it.
- Scope: this command is a shutdown readiness check for the current agent thread. It reports whether the thread can end and what remains to do; it does not perform cleanup, merge work, push commits, or close tasks.

## Workflow
1. Resolve context: identify the repository root, current branch, current HEAD SHA, `{session_scope}`, `{base_branch}`, and `{remote}`. In interactive mode, ask for missing scope values before continuing; otherwise record unresolved values as blockers.
2. Inspect uncommitted changes with `git status --porcelain=v1 --untracked-files=all`, grouping results into staged changes, unstaged changes, and untracked files.
3. Inspect in-progress git operations using `git status --short --branch` plus git-path checks for merge, rebase, cherry-pick, revert, and bisect markers such as `MERGE_HEAD`, `rebase-merge`, `rebase-apply`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, and `BISECT_LOG`.
4. Inspect worktrees with `git worktree list --porcelain`; compare each worktree against `{session_scope}` and list relevant worktrees that still exist, excluding the current worktree only when it is the active thread location.
5. Inspect session branches from conversation history, worktree-agent outputs, and branch names matching `{session_scope}`. For each branch that still exists, check whether it has been merged into `{base_branch}`; unmerged or unclassified session branches are blockers.
6. Inspect unpushed commits on the current branch. If an upstream is configured, compare `HEAD` with `@{u}` and list commits in `@{u}..HEAD`; otherwise compare against `{remote}/{current_branch}` when that ref exists. If no remote comparison can be resolved, list the missing upstream or remote ref as a blocker.
7. Inspect TODOs and tasks tracked during this thread from the active task list, conversation state, and worktree-agent summaries. List any item not explicitly completed, closed, committed, merged, deleted, or cancelled as incomplete.
8. Build the shutdown gate result. If every required category is clear and all inspections succeeded, set `Signal` to `ready_to_exit`; otherwise set `Signal` to `stay_on_thread`.
9. Emit the report using the Output Format below. When `Signal` is `ready_to_exit`, include the exact final line `Soft shutdown: ready to exit this thread.` When `Signal` is `stay_on_thread`, include the exact final line `Soft shutdown: stay on thread until blockers are resolved.`

## Output Format
Return a single markdown report with these sections, in order:

### Decision
- `Signal`: `ready_to_exit` or `stay_on_thread`.
- `Reason`: one sentence explaining why the signal was selected.

### Session Context
- `Repository`: absolute repository root.
- `Current branch`: branch name.
- `HEAD`: current commit SHA.
- `Session scope`: resolved `{session_scope}` or the blocker that prevented resolution.
- `Base branch`: resolved `{base_branch}` or the blocker that prevented resolution.
- `Remote`: resolved `{remote}` or the blocker that prevented resolution.

### Shutdown Gates
List every required gate with `clear` or `blocked`, one bullet per gate:
- `Uncommitted changes`: clear or blocked.
- `Undeleted worktrees`: clear or blocked.
- `Incomplete TODOs/tasks`: clear or blocked.
- `Unmerged session branches`: clear or blocked.
- `Unpushed commits`: clear or blocked.
- `In-progress git operations`: clear or blocked.

### Outstanding Items
For each required category, include either `_None._` or a bullet list with concrete evidence:
- `Uncommitted changes`: staged paths, unstaged paths, and untracked paths.
- `Undeleted worktrees`: worktree paths and branch names.
- `Incomplete TODOs/tasks`: task labels, statuses, and source in the current thread.
- `Unmerged session branches`: branch names, base branch, and relevant SHAs.
- `Unpushed commits`: commit SHAs and subjects, or the missing upstream/remote comparison.
- `In-progress git operations`: operation name and marker path or status output.

### Evidence
List the read-only commands or checks used to reach the decision and summarize any inspection that could not run.

### Final Signal
One exact line:
- `Soft shutdown: ready to exit this thread.`
- `Soft shutdown: stay on thread until blockers are resolved.`
