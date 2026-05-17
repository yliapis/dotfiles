# Soft Shutdown

## Task
Inspect the current agent thread for outstanding work and emit either a `READY_TO_EXIT` verdict with a final-state report — every session task is committed, every session worktree is deleted, every session branch is merged, and no other thread state remains — or a `STAY_ON_THREAD` verdict followed by an itemized list of blocking items that must be resolved first. The command is purely diagnostic: it never commits, merges, pushes, or deletes; it only reports.

## Parameters
- `{session_branches}` — list of branch names created during this thread that gate shutdown; optional, default: each branch associated with a path in the resolved `{session_worktrees}` set, plus the current branch when it differs from `{base_branch}`.
- `{session_worktrees}` — list of worktree absolute paths created during this thread that gate shutdown; optional, default: every worktree returned by `git worktree list --porcelain` other than the main worktree and the calling worktree.
- `{base_branch}` — branch each session branch is expected to merge back into; optional, default: `main`.
- `{remote}` — remote checked for unpushed commits on the current branch; optional, default: `origin`.
- `{todo_source}` — where to read this thread's TODO/task list from; one of `agent`, `path:<file>`, `none`; optional, default: `agent` (the calling agent's in-memory task list).
- `{allow_unpushed}` — whether unpushed commits on the current branch are tolerated without blocking shutdown; optional, default: `false`.
- `-i` / `--interactive` — flag enabling interactive mode: when present, ask clarifying questions about ambiguous session scope before evaluating gates. Optional. Default: absent (non-interactive); unresolved scope is recorded as a blocker.

## Success Criteria
- [ ] The response begins with a single-line verdict token on its own line, exactly one of `READY_TO_EXIT` or `STAY_ON_THREAD`, with no surrounding markup, prose, or leading whitespace.
- [ ] Every gate `G1`…`G6` is evaluated; no gate is skipped, even when an earlier gate fails. Each gate has an outcome of `pass`, `fail`, or `n/a`, and cites the literal shell command(s) plus a verbatim slice of the captured output.
- [ ] The verdict is `READY_TO_EXIT` if and only if every applicable gate is `pass` and zero gates are `fail`; any single `fail` outcome produces `STAY_ON_THREAD`.
- [ ] When the verdict is `STAY_ON_THREAD`, the report contains an Outstanding Items section that lists every failing gate under a named category with concrete blockers (paths, branches, SHAs, TODO entries) and one advisory remediation hint per category.
- [ ] When the verdict is `READY_TO_EXIT`, the report contains a Final State section recording the current branch and HEAD SHA, the disposition of every session worktree (`removed`), the disposition of every session branch (`merged into {base_branch}`), and a single ready-to-exit confirmation line.
- [ ] The Header section restates the resolved values of `{session_branches}`, `{session_worktrees}`, `{base_branch}`, `{remote}`, `{todo_source}`, `{allow_unpushed}`, plus the absolute repository root, current branch name, and current HEAD SHA, so the decision is reproducible from the report alone.
- [ ] `git status --porcelain` captured immediately before and immediately after this command runs is byte-identical in the calling worktree and in every path listed in `{session_worktrees}`.
- [ ] When `{todo_source}` is `agent` and no in-memory task list is exposed to this command, the TODO gate reports `n/a` (not `pass`) and the Header records `TODO source: agent (unavailable)`.
- [ ] When an explicitly supplied parameter is malformed (unknown `{todo_source}` shape, non-list session collections, non-boolean `{allow_unpushed}`), the workflow aborts with the failing parameter named and no gate is evaluated.
- [ ] When `-i` / `--interactive` is absent, the workflow asks no clarifying questions; unresolved scope or missing upstream data is recorded as a blocker.

## Guardrails
- MUST be read-only: no `git commit`, `git merge`, `git push`, `git worktree remove`, `git worktree prune`, `git branch -d`, `git branch -D`, `git reset`, `git rebase`, `git stash`, file write, or file delete is executed under any branch or mode.
- MUST evaluate every gate even when an earlier gate fails; never short-circuit the diagnosis.
- MUST cite the literal shell command and a verbatim slice of its captured output for every gate; MUST NOT paraphrase, summarize, or fabricate the git state.
- MUST NOT propose destructive remediation (for example `git reset --hard`, `git push --force`, `rm -rf` of a worktree); remediation hints stay advisory and reference existing slash commands when applicable.
- MUST NOT classify a worktree absent from `{session_worktrees}` or a branch absent from `{session_branches}` as outstanding; out-of-session items are ignored on purpose.
- MUST NOT silently substitute a default when an explicitly supplied parameter is malformed; abort with the failing parameter named.
- MUST NOT ask clarifying questions unless `-i` / `--interactive` is set; without the flag, ambiguous scope becomes a blocker.
- Scope: diagnose the current thread's shutdown readiness and emit a verdict plus an evidence report. Out of scope: committing, merging, pushing, deleting worktrees or branches, mutating any TODO list, killing the agent process, signalling other agents, or auto-cleanup of any kind.

## Workflow
1. Parse parameters and validate. Extract `-i` / `--interactive` and remove it from the input. Validate that `{todo_source}` matches `agent`, `none`, or `path:<...>`; that `{session_branches}` and `{session_worktrees}` are lists of strings; and that `{allow_unpushed}` is a boolean. Abort with the failing parameter named on any malformed value before evaluating any gate.
2. Resolve defaults: `{session_worktrees}` defaults to every path returned by `git worktree list --porcelain` other than the main worktree and the calling worktree; `{session_branches}` defaults to each branch associated with those worktrees plus the current branch when it differs from `{base_branch}`. Record whether each list was supplied explicitly or inferred, so the Header can surface the source.
3. Snapshot `git status --porcelain` from the calling worktree and from every path in `{session_worktrees}`; retain each byte string keyed by path as `pre_state`.
4. Evaluate the six gates below in order, capturing `command`, `output`, and `outcome` per gate; never short-circuit:
   - **G1 — Uncommitted changes.** For the calling worktree and every path in `{session_worktrees}`, run `git -C <path> status --porcelain --untracked-files=all`. Outcome is `pass` only when every output is empty; otherwise `fail` with each non-empty output captured per path (staged, unstaged, and untracked entries are reported as a single block per worktree).
   - **G2 — In-progress git operations.** For each path covered by G1, locate `.git` via `git -C <path> rev-parse --git-dir`, then check for any of `MERGE_HEAD`, `rebase-merge/`, `rebase-apply/`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`. Outcome is `pass` only when none exist; otherwise `fail` listing each present marker with its containing path and the matching operation name.
   - **G3 — Undeleted session worktrees.** Run `git worktree list --porcelain` and intersect the returned paths with `{session_worktrees}`. Outcome is `pass` when the intersection is empty; otherwise `fail` listing each still-registered path alongside its associated branch.
   - **G4 — Unmerged session branches.** For each branch in `{session_branches}`, run `git merge-base --is-ancestor <branch> {base_branch}`. Outcome is `pass` when every branch is an ancestor of `{base_branch}` (already merged); otherwise `fail` listing each unmerged branch alongside `git log --oneline {base_branch}..<branch>` output.
   - **G5 — Unpushed commits on the current branch.** Resolve the current branch via `git rev-parse --abbrev-ref HEAD`, then prefer its configured upstream (`git rev-parse --abbrev-ref --symbolic-full-name @{u}`); fall back to `{remote}/<current_branch>` when no upstream is configured. Verify the chosen remote-tracking ref exists via `git rev-parse --verify <ref>`. When the ref is missing, report `n/a` with the missing refspec captured. Otherwise run `git rev-list --count <ref>..HEAD`. When the count is `0`, `pass`. When the count is non-zero and `{allow_unpushed}` is `true`, `pass` with a `bypassed by allow_unpushed=true` note. When the count is non-zero and `{allow_unpushed}` is `false`, `fail` listing the unpushed SHAs via `git log --oneline <ref>..HEAD`.
   - **G6 — Incomplete TODOs / tasks.** When `{todo_source}` is `agent`, read the calling agent's in-memory task list and count entries whose status is not `completed` or `cancelled`; if no task list is exposed, report `n/a`. When `{todo_source}` is `path:<file>`, read the file and count unchecked markdown checkboxes (`- [ ]`); when the file is missing or unreadable, report `n/a` with the path captured. When `{todo_source}` is `none`, report `n/a`. Outcome is `pass` when the count is `0` or the gate is `n/a`; otherwise `fail` listing each incomplete entry verbatim.
5. Re-snapshot `git status --porcelain` for every path covered in step 3 and compare to `pre_state`. If any pair differs, abort the workflow: emit `STAY_ON_THREAD` with a single Outstanding Items entry naming the read-only invariant violation and the diff between snapshots.
6. Compute the verdict: `READY_TO_EXIT` if and only if every applicable gate is `pass` and zero gates are `fail`; otherwise `STAY_ON_THREAD`.
7. Render the Output Format below. When the verdict is `STAY_ON_THREAD`, group every `fail` gate into the Outstanding Items list ordered by gate ID. When the verdict is `READY_TO_EXIT`, populate the Final State section instead.

## Output Format
A single response. The very first line is the verdict token on its own line, followed by the named sections below in order. Omit the section (Outstanding Items or Final State) whose precondition does not hold.

```
READY_TO_EXIT
```
or
```
STAY_ON_THREAD
```

### Header
- `Verdict`: `READY_TO_EXIT` or `STAY_ON_THREAD`.
- `Repository`: absolute repository root.
- `Current branch`: branch name and HEAD SHA.
- `Base branch`: resolved `{base_branch}`.
- `Remote`: resolved `{remote}`.
- `Session worktrees`: resolved list (one absolute path per line, suffixed with the associated branch) plus `(inferred)` or `(explicit)`; `(none)` when empty.
- `Session branches`: resolved list (one branch name per line) plus `(inferred)` or `(explicit)`; `(none)` when empty.
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

### Final State
Present this section only when the verdict is `READY_TO_EXIT`. Confirms the shutdown disposition:

- `All gates`: `pass` (zero `fail`).
- `Session worktrees`: each path → `removed (verified absent from git worktree list)`, or `(none)` when the list was empty.
- `Session branches`: each branch → `merged into {base_branch}` (verified by `git log --oneline {base_branch}..<branch>` being empty), or `(none)` when the list was empty.
- `Current branch`: `<branch> @ <HEAD SHA>`.
- `Outstanding TODOs`: `0`.
- `Ready to exit`: a single confirmation line stating that the thread may be closed cleanly.

Omit this section entirely when the verdict is `STAY_ON_THREAD`.
