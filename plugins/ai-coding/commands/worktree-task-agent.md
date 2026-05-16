# Worktree Task Agent

## Task
Launch an agent in an isolated git worktree to complete `{task}` end-to-end, then present the resulting diff and ask whether to merge the worktree branch back into the original branch and whether to delete the worktree.

## Parameters
- `{task}` — the task the agent must complete; required.
- `{base_branch}` — branch to fork the worktree from; optional, default: current branch.
- `{worktree_name}` — name for the worktree directory and branch suffix; optional, default: derived from `{task}`.
- `{delete_worktree}` — whether to delete the worktree after a successful merge; optional, default: `true`.
- `{merge_mode}` — merge behavior after showing the diff; optional, default: `interactive`. Allowed values: `interactive`, `auto`.
- `{test_command}` — command the agent should run before presenting the diff; optional.
- `{agent_model}` — model to use for the worktree agent, if supported; optional.
- `{stop_condition}` — explicit completion condition beyond "task implemented and verified"; optional.

## Success Criteria
- [ ] A new isolated worktree is created from `{base_branch}` or the current branch.
- [ ] The agent completes `{task}` in the worktree without modifying the original working tree.
- [ ] The final response shows a concise summary of the changes and the relevant git diff.
- [ ] If `{test_command}` is provided, the agent runs it and reports the result.
- [ ] In `interactive` merge mode, the user is asked whether to merge the worktree branch back into `{base_branch}`.
- [ ] In `auto` merge mode, the worktree branch is merged only if the task completed successfully, tests passed when provided, and there are no merge conflicts.
- [ ] If merging is approved or completed and `{delete_worktree}` is `true`, the worktree is deleted after merge.

## Guardrails
- MUST keep all task execution isolated to the worktree.
- MUST show the diff before any merge in `interactive` mode.
- MUST NOT delete the worktree before the user has seen the diff.
- MUST NOT merge if tests fail, the worktree has unresolved conflicts, or the task is incomplete.
- Scope: this workflow manages one task, one worktree, and one resulting branch.

## Workflow
1. Record the current branch as `{base_branch}` unless explicitly provided.
2. Create a new branch and worktree for `{task}`.
3. Launch an agent in that worktree with instructions to complete the task until done.
4. Have the agent run `{test_command}` if provided.
5. Collect the final status, summary, and git diff from the worktree branch.
6. Present the diff and verification results to the user.
7. If `{merge_mode}` is `interactive`, ask whether to merge into `{base_branch}`.
8. If merge is approved, or `{merge_mode}` is `auto` and all checks pass, merge the worktree branch back into `{base_branch}`.
9. If the merge succeeds and `{delete_worktree}` is `true`, delete the worktree.

## Output Format
Return:

- Worktree path
- Worktree branch
- Base branch
- Summary of changes
- Verification results
- Diff
- Merge recommendation
- Prompt asking whether to merge and whether to delete the worktree when `merge_mode` is `interactive`
