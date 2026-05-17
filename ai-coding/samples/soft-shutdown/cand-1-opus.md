# Soft Shutdown

## Task
Inspect the current agent thread's outstanding work and emit a single-line verdict — `READY_TO_EXIT` when every shutdown gate passes, otherwise `STAY_ON_THREAD` followed by an itemized list of blocking items. The command is purely diagnostic: it never commits, merges, pushes, or deletes; it only reports.

## Parameters
- `{session_branches}` — list of branch names created during this thread that gate shutdown; optional, default: every local branch ahead of `{base_branch}` other than `{base_branch}` itself, derived from `git for-each-ref --format='%(refname:short)' refs/heads/` filtered by `git rev-list --count {base_branch}..<branch>` greater than `0`.
- `{session_worktrees}` — list of worktree absolute paths created during this thread that gate shutdown; optional, default: every worktree returned by `git worktree list --porcelain` other than the main worktree.
- `{base_branch}` — branch each session branch is expected to merge back into; optional, default: `main`.
- `{remote}` — remote checked for unpushed commits on `{base_branch}`; optional, default: `origin`.
- `{todo_source}` — where to read this thread's TODO/task list from; one of `agent`, `path:<file>`, `none`; optional, default: `agent` (the calling agent's in-memory task list).
- `{allow_unpushed}` — whether unpushed commits on `{base_branch}` are tolerated without blocking shutdown; optional, default: `false`.
- `{mode}` — operating mode; one of `report`, `strict`; optional, default: `report`. Both modes are read-only; `strict` additionally appends a `Terminal status: non-zero` marker when the verdict is `STAY_ON_THREAD` so callers can branch on the outcome.

## Success Criteria
- [ ] The response begins with a single-line verdict token on its own line, exactly one of `READY_TO_EXIT` or `STAY_ON_THREAD`, with no surrounding markup, prose, or whitespace.
- [ ] Every gate `G1`…`G6` is evaluated, has an outcome of `pass`, `fail`, or `n/a`, and cites the exact shell command(s) plus a verbatim slice of the captured output.
- [ ] The verdict is `READY_TO_EXIT` if and only if every applicable gate is `pass` and zero gates are `fail`; any single `fail` outcome produces `STAY_ON_THREAD`.
- [ ] When the verdict is `STAY_ON_THREAD`, the report contains an `Outstanding Items` section that lists every failing gate under a named category with the concrete blockers (paths, branches, SHAs, or TODO entries) and one advisory remediation hint per category.
- [ ] When the verdict is `READY_TO_EXIT`, the `Outstanding Items` section is omitted entirely.
- [ ] The `Header` section restates the resolved values of `{session_branches}`, `{session_worktrees}`, `{base_branch}`, `{remote}`, `{todo_source}`, `{allow_unpushed}`, and `{mode}` so the decision is reproducible from the report alone.
- [ ] `git status --porcelain` captured immediately before and immediately after this command runs is byte-identical in the calling worktree and in every path listed in `{session_worktrees}`.
- [ ] When `{mode}` is `strict` and the verdict is `STAY_ON_THREAD`, the response ends with `Terminal status: non-zero`; in every other case it ends with `Terminal status: zero`.
- [ ] When `{todo_source}` is `agent` and no in-memory task list is available, the TODO gate reports `n/a` (not `pass`) and the Header records `TODO source: agent (unavailable)`.
- [ ] When an explicitly supplied parameter is malformed (unknown `{mode}` value, unknown `{todo_source}` shape, non-list session collections), the workflow aborts with the failing token named in the error and no gate is evaluated.

## Guardrails
- MUST be read-only: no `git commit`, `git merge`, `git push`, `git worktree remove`, `git worktree prune`, `git branch -d`, `git branch -D`, `git reset`, file write, or file delete is executed under any branch or mode.
- MUST evaluate every gate even when an earlier gate fails; never short-circuit the diagnosis.
- MUST cite the literal shell command and a verbatim slice of its captured output for every gate; MUST NOT paraphrase, summarize, or fabricate the git state.
- MUST NOT propose forceful remediation (for example `git reset --hard`, `git push --force`, `rm -rf` of a worktree); remediation hints remain advisory and reference existing slash commands when applicable.
- MUST NOT classify a worktree absent from `{session_worktrees}` or a branch absent from `{session_branches}` as outstanding; out-of-session items are ignored on purpose.
- MUST NOT silently substitute a default when an explicitly supplied parameter is malformed; abort with the failing token instead.
- Scope: diagnose the current thread's shutdown readiness and emit a verdict plus an evidence report. Out of scope: committing, merging, pushing, deleting worktrees or branches, mutating any TODO list, killing the agent process, or signalling other agents.

## Workflow
1. Resolve every parameter using the defaults above. Validate that `{mode}` is one of `report` or `strict`; that `{todo_source}` matches `agent`, `none`, or `path:<...>`; that `{session_branches}` and `{session_worktrees}` are lists of strings; and that `{allow_unpushed}` is a boolean. Abort with the failing token on any malformed value before evaluating any gate.
2. Snapshot `git status --porcelain` from the calling worktree and from every path in `{session_worktrees}`; retain each byte string keyed by path as `pre_state`.
3. Evaluate the six gates below in order, capturing `command`, `output`, and `outcome` per gate; never short-circuit:
   - **G1 — Uncommitted changes.** For the calling worktree and every path in `{session_worktrees}`, run `git -C <path> status --porcelain`. Outcome is `pass` only when every output is empty; otherwise `fail` with each non-empty output captured per path.
   - **G2 — In-progress git operations.** For each path covered by G1, check for any of `.git/MERGE_HEAD`, `.git/rebase-merge/`, `.git/rebase-apply/`, `.git/CHERRY_PICK_HEAD`, `.git/REVERT_HEAD`, `.git/BISECT_LOG`. Outcome is `pass` only when none exist; otherwise `fail` listing each present marker with its containing path.
   - **G3 — Undeleted session worktrees.** Run `git worktree list --porcelain` and intersect the returned paths with `{session_worktrees}`. Outcome is `pass` when the intersection is empty; otherwise `fail` listing each still-registered path.
   - **G4 — Unmerged session branches.** For each branch in `{session_branches}`, run `git merge-base --is-ancestor <branch> {base_branch}`. Outcome is `pass` when every branch is an ancestor of `{base_branch}` (already merged); otherwise `fail` listing each unmerged branch alongside `git log --oneline {base_branch}..<branch>` output.
   - **G5 — Unpushed commits on `{base_branch}`.** Run `git rev-list --count {remote}/{base_branch}..{base_branch}`. Outcome is `pass` when the count is `0`. When `{remote}/{base_branch}` does not exist (verified via `git rev-parse --verify {remote}/{base_branch}`), report `n/a` with the missing ref captured. When the count is non-zero and `{allow_unpushed}` is `true`, report `pass` with a `bypassed by {allow_unpushed}=true` note. When the count is non-zero and `{allow_unpushed}` is `false`, report `fail` listing the unpushed SHAs via `git log --oneline {remote}/{base_branch}..{base_branch}`.
   - **G6 — Incomplete TODOs / tasks.** When `{todo_source}` is `agent`, read the calling agent's in-memory task list and count entries whose status is not `completed` or `cancelled`; if no task list is exposed, report `n/a`. When `{todo_source}` is `path:<file>`, read the file and count unchecked markdown checkboxes (`- [ ]`). When `{todo_source}` is `none`, report `n/a`. Outcome is `pass` when the count is `0` or the gate is `n/a`; otherwise `fail` listing each incomplete entry verbatim.
4. Re-snapshot `git status --porcelain` for every path covered in step 2 and compare to `pre_state`. If any pair differs, abort the workflow: emit `STAY_ON_THREAD` followed by a single Outstanding Items entry naming the read-only invariant violation and the diff between snapshots.
5. Compute the verdict: `READY_TO_EXIT` if and only if every applicable gate is `pass` and zero gates are `fail`; otherwise `STAY_ON_THREAD`.
6. Group every `fail` gate into the Outstanding Items list, one entry per failing gate, ordered by gate ID.
7. Render the Output Format below. When `{mode}` is `strict` and the verdict is `STAY_ON_THREAD`, end the response with `Terminal status: non-zero`; otherwise end with `Terminal status: zero`.

## Output Format
A single response. The very first line is the verdict token on its own line, followed by the sections below in the order shown.

```
READY_TO_EXIT
```
or
```
STAY_ON_THREAD
```

### Header
- `Verdict`: `READY_TO_EXIT` or `STAY_ON_THREAD`.
- `Mode`: resolved `{mode}`.
- `Base branch`: resolved `{base_branch}`.
- `Remote`: resolved `{remote}`.
- `Session worktrees`: resolved list, one absolute path per line; `(none)` when empty.
- `Session branches`: resolved list, one branch name per line; `(none)` when empty.
- `TODO source`: resolved `{todo_source}` (with ` (unavailable)` suffix when the source could not be read).
- `Allow unpushed`: resolved `{allow_unpushed}`.

### Gates
One block per gate, in order `G1`…`G6`:

- `Gate`: `G<n> — <name>`.
- `Outcome`: `pass`, `fail`, or `n/a`.
- `Command`: the literal shell command(s) executed.
- `Output`: a fenced block containing the captured output, truncated above ~40 lines with `... (truncated, K lines omitted)`.
- `Notes`: a one-line remark when the outcome is `n/a`, or when a bypass (for example `{allow_unpushed}=true`) altered the default decision; omit otherwise.

### Outstanding Items
Present this section only when the verdict is `STAY_ON_THREAD`. A numbered list, one entry per failing gate, ordered by gate ID:

1. **G<n> — <Category>** — one-sentence summary of what blocks shutdown.
   - Items: bullet list of the concrete blockers (paths, branches, SHAs, TODO entries).
   - Remediation hint: one advisory next step (for example `commit or stash uncommitted changes in <path>`, `merge <branch> into {base_branch} via /merge-commit-push`, `mark TODO entry "<title>" as completed or cancelled`).

Omit this section entirely when the verdict is `READY_TO_EXIT`.

### Footer
A single line: `Terminal status: zero` or `Terminal status: non-zero`.
