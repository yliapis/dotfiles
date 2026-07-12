---
name: worktree-task
description: "Launch agents in isolated git worktrees to execute a task end-to-end, then present per-worktree diffs for review and selective merge. Use when worktrees are referenced to execute a task resulting in file changes, when sandboxing risky edits, or when running parallel attempts on one task. Composed by the `agent-swarm` skill as the worktree primitive."
license: MIT
---

# Worktree Task

## Task
Launch an agent in an isolated git worktree to complete `{task}` end-to-end, then present the resulting diff and ask whether to merge the worktree branch back into the original branch and whether to delete the worktree. When `{parallelism}` is greater than 1, launch that many sibling agents in independent worktrees (optionally one model per agent from `{agent_model}`, and at most `{concurrency}` running at once) and present a per-worktree report so the user can pick at most one branch to merge.

The `agent-swarm` skill composes this skill as the worktree primitive; `agent-swarm` owns the swarm-vs-single decision, sizing, model mix, and selection.

## Parameters
- `{task}` — the task each agent must complete; required.
- `{base_branch}` — branch to fork the worktree(s) from; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name}` — base name for the worktree directory and branch; optional, default: a filesystem-safe kebab-case slug derived from `{task}`. When `{parallelism}` is greater than 1, a 1-based index suffix (`-1`, `-2`, …) is appended per agent.
- `{delete_worktree}` — whether to delete a worktree after its branch is merged successfully; optional, default: `true`. Worktrees whose branches are not merged are left in place.
- `{merge_mode}` — merge behavior after showing the diff(s); optional, default: `interactive`. Allowed values: `interactive`, `auto`.
- `{test_command}` — shell command each agent runs inside its worktree before the diff is presented; optional. Exit code `0` counts as pass; any other exit code counts as fail.
- `{agent_model}` — model(s) to use for the worktree agent(s); optional, default: the parent agent's model. Accepts a single model identifier (broadcast to every agent), a list of length `{parallelism}` (one model per agent, mapped positionally by index), or a list of length `{num_partitions}` (one model per partition, broadcast within each contiguous slice).
- `{parallelism}` — total number of sibling agents to launch, each in its own worktree; optional, default: `1`. MUST be an integer `>= 1`; otherwise the workflow fails before any worktree is created.
- `{concurrency}` — maximum number of agents running simultaneously; optional, default: `{parallelism}` (all agents launch together). MUST be an integer in `1..{parallelism}`. Changes pacing only, never the total: exactly `{parallelism}` worktrees are created regardless.
- `{num_partitions}` — number of contiguous model-assignment partitions over the `{parallelism}` agents; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` that evenly divides `{parallelism}`. When set together with a list-valued `{agent_model}`, the list length MUST be either `{parallelism}` (per agent) or `{num_partitions}` (per partition, broadcast within each contiguous slice of `{parallelism} / {num_partitions}` agents).
- `{stop_condition}` — explicit completion condition beyond "task implemented and verified"; optional.

## Success Criteria
- [ ] Parameters are validated before any worktree is created: `{parallelism}` and `{num_partitions}` are integers `>= 1`; `{num_partitions}` evenly divides `{parallelism}`; `{concurrency}` is an integer in `1..{parallelism}`; if `{agent_model}` is a list its length equals `{parallelism}` or `{num_partitions}`. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] Exactly `{parallelism}` isolated worktrees are created from `{base_branch}` (or the current branch when omitted), each on its own branch derived from `{worktree_name}`; at most `{concurrency}` agents run at any moment, and every slot keeps its 1-based launch index regardless of scheduling order.
- [ ] Each agent completes `{task}` (and `{stop_condition}` when provided) inside its own worktree, producing no edits, staged changes, or untracked files in the original working tree or in any sibling worktree.
- [ ] If `{test_command}` is provided, each agent runs it once inside its worktree and the captured exit code is reported per worktree.
- [ ] The final response includes, per worktree: worktree path, branch, agent model, terminal status (`success` / `failed` / `incomplete`), change summary, verification result, and the `git diff {base_branch}..<worktree_branch>` output.
- [ ] In `interactive` merge mode, the user is explicitly asked which worktree branch (if any) to merge back into `{base_branch}` and whether to delete each worktree before any merge or deletion happens.
- [ ] In `auto` merge mode, at most one worktree branch is merged, and only when its agent reported `success`, `{test_command}` (when provided) exited `0`, `{stop_condition}` (when provided) is satisfied, and `git merge --no-ff` against `{base_branch}` produces no conflicts.
- [ ] When a worktree branch is merged and `{delete_worktree}` is `true`, that worktree is removed via `git worktree remove` and its branch deleted via `git branch -d` after the merge succeeds.

## Guardrails
- MUST keep each agent's task execution isolated to its assigned worktree; agents MUST NOT read, write, or run commands against the original working tree or any sibling worktree.
- MUST validate `{parallelism}`, `{concurrency}`, `{num_partitions}`, and `{agent_model}` shape before creating any worktree; fail fast and create nothing on validation failure.
- MUST present every worktree's diff (and verification result, when applicable) to the user before any merge in `interactive` mode.
- MUST NOT delete a worktree before the user has seen its diff (in `interactive` mode) or before its merge has succeeded (in `auto` mode).
- MUST NOT merge a worktree branch if its agent reported failure, `{test_command}` exited non-zero, `{stop_condition}` is unmet, or the branch has unresolved conflicts with `{base_branch}`.
- MUST NOT merge more than one worktree branch per invocation.
- Scope: this workflow manages one `{task}`, up to `{parallelism}` sibling worktrees forked from one `{base_branch}`, and at most one resulting merge into `{base_branch}`. Out of scope: pushing, opening PRs, creating tags, rebasing pre-existing branches, or touching unrelated branches.

## Workflow
1. Validate parameters; fail fast if `{parallelism}` or `{num_partitions}` is not an integer `>= 1`, `{num_partitions}` does not evenly divide `{parallelism}`, `{concurrency}` is not an integer in `1..{parallelism}`, or `{agent_model}` is a list whose length is neither `{parallelism}` nor `{num_partitions}`. Create no worktrees on validation failure.
2. Record the current branch as `{base_branch}` unless explicitly provided.
3. Resolve the per-agent model assignment: broadcast a scalar `{agent_model}` to every agent; zip a length-`{parallelism}` list positionally by index; or expand a length-`{num_partitions}` list by broadcasting each entry across its contiguous slice of `{parallelism} / {num_partitions}` agents.
4. For each `i` in `1..{parallelism}`, create a new branch off `{base_branch}` named after `{worktree_name}` (with `-{i}` suffix when `{parallelism}` > 1) and add a matching worktree via `git worktree add`.
5. Launch one agent per worktree, each on its assigned model, with instructions to complete `{task}` until done (and until `{stop_condition}` is satisfied, when provided). Keep at most `{concurrency}` agents running at once: start slots in index order and start the next pending slot as a running one finishes. Slot indexes, worktree names, and model assignments are fixed at creation time and do not depend on scheduling order.
6. After each agent reports completion, run `{test_command}` (if provided) inside that worktree and capture the exit code.
7. Wait for all agents to finish, then collect per worktree: terminal status, change summary, test result, and `git diff {base_branch}..HEAD`.
8. Present the per-worktree report to the user using the Output Format below.
9. If `{merge_mode}` is `interactive`, ask which worktree branch (if any) to merge into `{base_branch}` and whether to delete each worktree.
10. If `{merge_mode}` is `auto`, select the worktree (if any) that satisfies all merge Guardrails; if more than one is eligible, prefer the lowest-index branch.
11. Merge the selected branch (if any) into `{base_branch}` with `git merge --no-ff`; abort the merge on conflict and report it.
12. If the merge succeeds and `{delete_worktree}` is `true`, remove the merged worktree via `git worktree remove` and delete its branch via `git branch -d`. Worktrees whose branches were not merged are left in place unless the user opted in to delete them during the interactive prompt.

## Output Format
Return a single response with the following named sections, in this order:

### Run Summary
- `Base branch`: resolved `{base_branch}`.
- `Parallelism`: `{parallelism}`.
- `Concurrency`: resolved `{concurrency}` (omit when equal to `{parallelism}`).
- `Merge mode`: `interactive` or `auto`.
- `Counts`: succeeded / failed / incomplete.

### Worktree Results
One block per worktree, in launch order:

- `Index`: 1-based agent index.
- `Worktree path`: absolute path.
- `Branch`: worktree branch name.
- `Agent model`: model identifier used.
- `Status`: `success`, `failed`, or `incomplete`.
- `Summary`: 1–5 bullets describing the changes and why.
- `Verification`: `{test_command}` exit code and a brief output tail, or `n/a` when `{test_command}` is not provided.
- `Diff`: a fenced ` ```diff ` block containing `git diff {base_branch}..<branch>`, truncated above ~400 lines with `... (truncated, K lines omitted)` when oversized.
- `Merge verdict`: `merge`, `skip`, or `hold`, with a one-line reason.

### Merge Recommendation
- The recommended worktree branch to merge (or `none`) and a one-line rationale.

### Merge Prompt
Present this section only in `interactive` mode. Ask, per worktree:
1. Merge `<worktree_branch>` into `{base_branch}`? (y/n)
2. Delete worktree at `<worktree_path>`? (y/n)
