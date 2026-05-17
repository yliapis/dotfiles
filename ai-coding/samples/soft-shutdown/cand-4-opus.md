# Soft Shutdown

## Task
Evaluate six gating categories on the current agent session and either emit a `SHUTDOWN: READY` exit signal with a final-state report, or emit `SHUTDOWN: BLOCKED` with an enumerated list of outstanding items keeping the thread alive. In `resolve` mode, attempt safe auto-cleanup (commit pending changes, push, run `/merge-commit-push` for unmerged session branches, remove merged worktrees) before re-evaluating the gates.

## Parameters
- `{mode}` — `check` (read-only diagnosis) or `resolve` (attempts auto-cleanup, then re-evaluates); optional, default: `check`.
- `{session_scope}` — how to identify session-relevant worktrees, branches, and TODOs; one of `auto` (the agent's tracked TODOs plus worktrees/branches created in this thread), `branch_prefix=<prefix>` (any worktree or branch whose name starts with `<prefix>`), or `all` (every worktree off the repo root plus every non-default local branch); optional, default: `auto`.
- `{target_branch}` — branch that session work merges into during `resolve`; optional, default: `main`.
- `{remote}` — remote name to push to in `resolve` mode; optional, default: `origin`.
- `{require_clean_target}` — whether the `{target_branch}` must have zero unpushed commits to count as PASS for the unpushed-commits gate; optional, default: `true`.
- `{categories}` — explicit subset of the six gates to evaluate; optional, default: all six (`uncommitted`, `worktrees`, `todos`, `unmerged`, `unpushed`, `in_progress_ops`).
- `{commit_message}` — commit message to use when `resolve` mode commits tracked pending changes on the current branch; required when `{mode}` is `resolve` and the uncommitted gate fails on tracked files, otherwise optional.
- `-i` / `--interactive` — flag enabling clarifying questions about ambiguous resolution actions (e.g., whether to commit untracked files, delete unmerged session branches); optional, default: absent (non-interactive — ambiguous actions are skipped and surfaced as blockers).

## Success Criteria
- [ ] The first line of the response is exactly `SHUTDOWN: READY` or `SHUTDOWN: BLOCKED` (no other text on that line), making the decision machine-parseable.
- [ ] Each of the six gates listed below is evaluated and emitted with status `PASS`, `FAIL`, or `UNKNOWN`, a one-line verdict, and (for `FAIL` / `UNKNOWN`) a concrete remediation step:
  - `uncommitted` — `git status --porcelain` in every session worktree returns no output (no staged, unstaged, or untracked entries).
  - `worktrees` — every session-scoped worktree identified by `git worktree list --porcelain` has either been removed or has its branch merged into `{target_branch}`.
  - `todos` — every TODO tracked in the current agent session is in state `completed` or `cancelled`; none remain `pending` or `in_progress`.
  - `unmerged` — every session branch identified by `{session_scope}` has been merged into `{target_branch}` (`git branch --merged {target_branch}` includes it).
  - `unpushed` — `git rev-list {remote}/{target_branch}..{target_branch}` is empty when `{require_clean_target}` is `true`; otherwise this gate PASSes vacuously and the result still records the unpushed-commit count.
  - `in_progress_ops` — none of `.git/MERGE_HEAD`, `.git/rebase-merge/`, `.git/rebase-apply/`, `.git/CHERRY_PICK_HEAD`, `.git/REVERT_HEAD`, `.git/BISECT_LOG` exist in any session worktree.
- [ ] The shutdown decision rule is `SHUTDOWN: READY` iff every requested gate in `{categories}` returns `PASS`; any `FAIL` or `UNKNOWN` yields `SHUTDOWN: BLOCKED` (UNKNOWN is treated conservatively as a blocker).
- [ ] When `{mode}` is `check`, no state-changing git commands are executed (no `commit`, `push`, `merge`, `branch -d`, `worktree remove`, `add`, `rm`, `reset`, `rebase`, `cherry-pick`, `stash`).
- [ ] When `{mode}` is `resolve`, the auto-resolution log records each attempted action with its exit code and stderr tail, and the post-resolution gate evaluation drives the final decision token.
- [ ] When `{mode}` is `resolve` and the uncommitted gate fails on tracked changes without a `{commit_message}` set, the workflow aborts before any state change with an explanatory error naming the missing parameter.
- [ ] Untracked files matching common secret patterns (`.env`, `.env.*`, `*.key`, `*.pem`, `*credentials*`, `*secret*`, `*.p12`, `*.pfx`) are never auto-committed; they are listed as blockers requiring explicit confirmation, regardless of `{mode}`.
- [ ] When `--interactive` / `-i` is absent, the workflow asks no clarifying questions; ambiguous resolution actions are skipped and surfaced as blockers in the report.
- [ ] The Final State section (when ready) lists each session worktree's terminal disposition (removed / kept), each session branch's terminal disposition (merged / kept), and the resolved SHAs for `{target_branch}` before and after resolution.
- [ ] When blocked, every blocker entry names one specific gate, one concrete artifact (path, branch, TODO id, or refspec), and one remediation step phrased as an imperative.

## Guardrails
- MUST emit the first-line decision token (`SHUTDOWN: READY` or `SHUTDOWN: BLOCKED`) before any other content; MUST NOT emit prose, fenced blocks, or leading whitespace on line one.
- MUST scope worktree, branch, and TODO inspection to the session per `{session_scope}`; MUST NOT delete, merge, or modify worktrees, branches, or commits that fall outside the resolved session scope.
- MUST NOT auto-commit files matching the secret patterns listed above; surface them as blockers instead.
- MUST NOT delete a session worktree whose branch has not been merged into `{target_branch}`.
- MUST NOT push when `{mode}` is `check`, when the merge step failed, or when `{require_clean_target}` is `false` and the user did not request a push.
- MUST NOT force-push, force-delete branches (`branch -D`), reset, rebase, or stash anything during resolution; only additive operations (commit, merge via `/merge-commit-push`, push, `worktree remove` on merged trees, `branch -d` on merged branches) are permitted.
- MUST treat an in-progress git operation (merge, rebase, cherry-pick, revert, bisect) as a hard blocker; MUST NOT attempt to auto-resolve it.
- MUST report the same decision token deterministically given the same repository state and parameters; re-running `check` mode on an unchanged repo produces identical output below the token.
- Scope: cleanup orchestration for the current agent thread. Out of scope: cleaning unrelated worktrees, deleting historical branches, force-pushing, opening or closing PRs, archiving chat history, releasing tags, garbage collection, secret rotation.

## Workflow
1. **Parse parameters.** Extract `{mode}`, `{session_scope}`, `{target_branch}`, `{remote}`, `{require_clean_target}`, `{categories}`, `{commit_message}`, and the `-i` / `--interactive` flag. Default `{mode}` to `check`, `{session_scope}` to `auto`, `{target_branch}` to `main`, `{remote}` to `origin`, `{require_clean_target}` to `true`, `{categories}` to all six gates.
2. **Resolve session scope.** Materialize three concrete lists:
   - **Session worktrees**: `git worktree list --porcelain` filtered by `{session_scope}` (when `auto`, intersect with the agent's tracked worktree paths from this thread; when `branch_prefix=<prefix>`, keep entries whose branch starts with `<prefix>`; when `all`, keep every worktree except the repo root).
   - **Session branches**: local branches matching the same filter.
   - **Session TODOs**: the agent's current TODO list for this thread.
3. **Validate `resolve` prerequisites.** If `{mode}` is `resolve`: require `{commit_message}` whenever any session worktree has tracked uncommitted changes; require `git remote get-url {remote}` to succeed when push is in play. Abort with an explanatory error on any failure — no state change yet.
4. **Evaluate the six gates** (read-only) using the checkable conditions listed in Success Criteria, producing one record per gate: `{gate, status, verdict, artifacts, remediation}`. Mark a gate `UNKNOWN` only when a probe command failed for an environmental reason (e.g., remote unreachable for `unpushed`).
5. **If `{mode}` is `check`**: skip to step 8 with the current gate results.
6. **Auto-resolve (resolve mode only), in this fixed order, halting on first non-recoverable failure and logging each step:**
   1. **In-progress ops gate first**: if any session worktree has an in-progress merge/rebase/cherry-pick/revert/bisect, stop here — this is a hard blocker even in `resolve` mode.
   2. **Uncommitted (tracked)**: in each session worktree with tracked changes and no flagged secrets, run `git add -A` (respecting the secret-pattern filter) then `git commit -m "{commit_message}"`. Skip and record a blocker if any secret-pattern file is present and `--interactive` was not passed (or the user declined).
   3. **Uncommitted (untracked, non-secret)**: in `--interactive` mode only, ask whether to add. Otherwise skip and record as a blocker.
   4. **Unmerged session branches**: for each session branch not yet merged into `{target_branch}`, invoke `/merge-commit-push` with `source_branch=<session_branch>`, `target_branch={target_branch}`, `remote={remote}`, `include_push=true` (default `--no-ff` strategy). Stop the loop on the first merge conflict or push rejection; subsequent branches are left untouched and recorded as blockers.
   5. **Unpushed commits on `{target_branch}`**: if `{require_clean_target}` is `true` and `git rev-list {remote}/{target_branch}..{target_branch}` is non-empty, run `git push {remote} {target_branch}` once. Stop on rejection.
   6. **Worktrees on merged branches**: for each session worktree whose branch is now merged, run `git worktree remove` followed by `git branch -d`. Skip and record any worktree whose branch is not yet merged.
7. **Re-evaluate the six gates** after resolution using the same checks as step 4, producing the final gate-result set.
8. **Compute the decision token**: `SHUTDOWN: READY` iff every gate in `{categories}` is `PASS`; otherwise `SHUTDOWN: BLOCKED`.
9. **Render the Output Format** below, leading with the decision token on line one.

## Output Format
The response MUST begin with the literal decision token on its own line, followed by the named sections below in order. Omit any section whose body would be empty.

```
SHUTDOWN: READY
```
or
```
SHUTDOWN: BLOCKED
```

### Session Scope
- `Mode`: `check` or `resolve`.
- `Scope rule`: resolved value of `{session_scope}`.
- `Target branch`: `{target_branch}` and its current SHA.
- `Remote`: `{remote}`.
- `Session worktrees`: 0-or-more entries, each `<path>` `<branch>`.
- `Session branches`: 0-or-more entries.
- `Session TODOs`: counts by status (`pending` / `in_progress` / `completed` / `cancelled`).

### Gate Evaluation
A table with one row per requested gate, in the canonical order `uncommitted`, `worktrees`, `todos`, `unmerged`, `unpushed`, `in_progress_ops`. Columns: `Gate`, `Status` (`PASS` / `FAIL` / `UNKNOWN`), `Verdict` (one line), `Artifacts` (paths/branches/ids triggering FAIL or UNKNOWN, comma-separated or `n/a`).

### Auto-Resolution Log
Present only when `{mode}` is `resolve`. One bullet per attempted action in execution order:
- `<step>`: `<command or sub-workflow>` → exit `<code>` (`<one-line stderr tail or "ok">`).

### Blockers
Present only when the decision token is `SHUTDOWN: BLOCKED`. One bullet per `FAIL` or `UNKNOWN` gate; for gates that affect multiple artifacts, one sub-bullet per artifact:
- **`<gate>`** — `<artifact>`: `<remediation imperative>`.

### Final State
Present only when the decision token is `SHUTDOWN: READY`. Reports the terminal disposition:
- `Worktrees`: per session worktree, `<path>` → `removed` or `kept (branch=<branch>)`.
- `Branches`: per session branch, `<branch>` → `merged into {target_branch}` or `kept`.
- `Target SHAs`: `<pre-resolution SHA>` → `<post-resolution SHA>`.
- `Remote tip`: `<remote>/<target_branch>` = `<SHA>`.
- `Outstanding TODOs`: `0` (when ready, this is always zero).

### Exit Signal
One line summarizing the next step the calling parent agent should take:
- When ready: `Thread may exit; no outstanding session state.`
- When blocked: `Stay on thread; resolve <N> blocker(s) above before re-running /soft-shutdown.`
