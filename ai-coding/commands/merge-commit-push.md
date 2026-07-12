# Merge Commit Push

## Task
Merge a source branch into a target branch with an explicit merge strategy, then push the updated target branch to a configured remote, in a single composed workflow that fails fast on a dirty working tree, merge conflicts, or push rejection.

## Parameters
- `{source_branch}` — branch to merge into the target; optional, default: the current branch (`git rev-parse --abbrev-ref HEAD`).
- `{target_branch}` — branch the source is merged into; optional, default: `main`.
- `{merge_strategy}` — git merge flag governing the merge commit shape; one of `--no-ff`, `--ff-only`, `--squash`; optional, default: `--no-ff`.
- `{remote}` — remote name to push the target branch to; optional, default: `origin`.
- `{commit_message}` — commit message for the squash commit; required when `{merge_strategy}` is `--squash`, otherwise ignored.
- `{include_push}` — whether to push after a successful merge; optional, default: `true`.

## Success Criteria
- [ ] Validation runs before any state-changing git command: `{source_branch}` and `{target_branch}` both exist locally, `{remote}` is configured, and the current working tree is free of staged or unstaged changes (`git status --porcelain` is empty) before any branch switch.
- [ ] When `{merge_strategy}` is `--squash`, `{commit_message}` is set; otherwise the workflow aborts before staging the squash.
- [ ] After merge, `{target_branch}` HEAD incorporates `{source_branch}` (its HEAD advanced, or was already up to date under `--ff-only`); no conflict markers remain.
- [ ] When `{include_push}` is `true` and the merge succeeded, `git push {remote} {target_branch}` exits `0` and the local and remote tips of `{target_branch}` match.
- [ ] On any failing step (validation, merge conflict, push rejection), the workflow stops at that step, reports the failing command and its stderr, and leaves the repository in an inspectable state — no automatic abort, reset, or retry.
- [ ] The final report names the source SHA, the target SHA before merge, the target SHA after merge, the merge commit SHA (when applicable), and the pushed refspec (when push ran).

## Guardrails
- MUST verify the current working tree is clean before switching branches; abort if `git status --porcelain` returns any output.
- MUST NOT push when the merge produced conflicts, was aborted, or did not advance `{target_branch}`'s HEAD.
- MUST use `git push {remote} {target_branch}`; MUST NOT use `--force` or `--force-with-lease`.
- MUST refuse if `{target_branch}` is not a local branch; bail before any switch.
- MUST detect when `{target_branch}` is checked out in a different worktree and surface that worktree's path instead of forcing a switch.
- Scope: one source → one target merge in one local repository followed by an optional single-remote push. Out of scope: opening PRs, force pushes, cross-repo workflows, rebasing, multi-target merges, branch creation, fetching from the remote, conflict resolution.

## Workflow
1. Resolve parameters: `{source_branch}` defaults to the current branch via `git rev-parse --abbrev-ref HEAD`; `{target_branch}` defaults to `main`; `{merge_strategy}` defaults to `--no-ff`; `{remote}` defaults to `origin`; `{include_push}` defaults to `true`.
2. Validate: `git rev-parse --verify {source_branch}` and `git rev-parse --verify {target_branch}` succeed; `git remote get-url {remote}` succeeds; `git status --porcelain` in the current working tree is empty; when `{merge_strategy}` is `--squash`, `{commit_message}` is non-empty. Abort with the failing check on any failure.
3. Switch to `{target_branch}` via `git switch {target_branch}`. If git refuses because the target is checked out in another worktree, abort and report the conflicting worktree path.
4. Merge: run `git merge {merge_strategy} {source_branch}`, except for `--squash` where the workflow runs `git merge --squash {source_branch}` followed by `git commit -m "{commit_message}"`. On conflict, run `git status` to surface the conflicting paths, leave the merge in progress, and stop the workflow.
5. When `{include_push}` is `true` and the merge succeeded, run `git push {remote} {target_branch}`. On non-fast-forward rejection, do NOT auto-fetch or rebase; surface the rejection and stop.
6. Capture the report data: pre-merge target SHA, post-merge target SHA, source SHA, merge commit SHA (when not fast-forward), and the pushed refspec.
7. Emit the Output Format below.

## Output Format
A short report with these named sections, in order:

### Plan
- `Source`: branch name and resolved SHA.
- `Target`: branch name and pre-merge SHA.
- `Strategy`: chosen `{merge_strategy}` (and `{commit_message}` when `--squash`).
- `Remote`: chosen `{remote}` (and whether push is enabled).

### Validation
One pass/fail bullet per check: working tree clean on source; source and target both exist; remote configured; squash message present when applicable.

### Merge
- `Command`: the literal `git merge` invocation used.
- `Result`: `success` or `conflict`.
- `New target SHA`: post-merge SHA on `{target_branch}` (and the merge-commit SHA when applicable).

### Push
- `Command`: the literal `git push` invocation used, or `skipped` with the reason.
- `Result`: `success`, `rejected`, or `skipped`.
- `Refspec`: pushed `{remote}/{target_branch}` and the resolved remote SHA.

### Outcome
One sentence summarizing the final state and any next step the user must take.
