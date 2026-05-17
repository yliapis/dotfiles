# Wrap Up

## Task
Survey the current agent thread's worktrees, categorize their content, archive each category under `{archive_root}<category>-leftovers/` (or roll substantive changes into the matching canonical file when warranted), commit + merge + push the consolidated archive, delete the wrapped worktrees and branches, and emit a structured JSONL event log throughout. Interactive mode optionally saves a session trajectory log and a learnings note before exit.

This command generalizes the ad-hoc worktree cleanup pattern (commit outstanding samples → aggregate per category → optional rollup into canonical → merge → push → delete) into a single auditable workflow with machine-readable progress events.

## Parameters

- `{base_branch}` — branch to merge the archive into; optional, default: `main`.
- `{remote}` — remote to push `{base_branch}` to after merge; optional, default: `origin`.
- `{archive_root}` — root directory for category archives; optional, default: `samples/`.
- `{rollup}` — rollup mode for substantive variant content; optional, default: `interactive` when `-i` is set, else `off`. Allowed values: `interactive`, `auto`, `off`.
- `{rollup_threshold}` — minimum distinct new lines per variant vs. its canonical to qualify as substantive; optional, default: `30`.
- `{include_categories}` — only wrap up worktrees whose name begins with one of these category prefixes; optional, default: every non-base, non-calling worktree.
- `{exclude_categories}` — skip worktrees whose name begins with one of these category prefixes; optional, default: empty.
- `{delete_after_merge}` — whether to delete wrapped worktrees + branches after the archive is merged; optional, default: `true` when `-i` is absent, prompts per worktree when `-i` is set.
- `{event_log_path}` — path where the JSONL event log is persisted; optional, default: `.ai-coding-artifacts/wrap-up/<utc-iso-timestamp>.jsonl`. The same events are always emitted inline in the report.
- `{trajectory_path}` — path for the session trajectory log; optional, default: `.ai-coding-artifacts/trajectories/<utc-iso-timestamp>.jsonl`.
- `{learnings_path}` — path for the session learnings note; optional, default: `.ai-coding-artifacts/learnings/<utc-iso-timestamp>.md`.
- `{save_trajectory}` — whether to write the trajectory + learnings files; optional, default: `interactive` (prompt at end when `-i` is set), `false` otherwise.
- `-i` / `--interactive` — enable interactive prompts for rollup decisions, ambiguous categorization, deletion confirmation, and trajectory save. Optional. Default: absent. When absent, no clarifying questions are asked, `{rollup}` defaults to `off`, and `{save_trajectory}` defaults to `false`.

## Success Criteria

- [ ] The Header section restates every resolved parameter (`{base_branch}`, `{remote}`, `{archive_root}`, `{rollup}`, `{rollup_threshold}`, `{include_categories}`, `{exclude_categories}`, `{delete_after_merge}`, `{event_log_path}`, `{trajectory_path}`, `{learnings_path}`, `{save_trajectory}`, and interactive mode) plus the calling repository root and pre-run HEAD SHA so the run is reproducible from the report alone.
- [ ] Every worktree in scope is surveyed, categorized by leading kebab-case prefix shared across siblings, and recorded in the Survey section with its absolute path, branch (or detached SHA), HEAD SHA, dirty/clean state, file-count diff vs. `{base_branch}`, and assigned category.
- [ ] Each category produces an Aggregation block describing the archive path under `{archive_root}<category>-leftovers/`, the variant count, the per-variant filename mapping, and the aggregator commit SHA.
- [ ] For every category, a rollup decision is recorded as exactly one of `applied` (canonical updated, commit SHA cited), `declined` (proposal rejected by user or `{rollup}=off`), `under-threshold` (no variant met `{rollup_threshold}`), or `no-canonical` (no matching `.cursor/skills/<category>/SKILL.md` or `.cursor/commands/<category>.md` exists in `{base_branch}`).
- [ ] When `{rollup}` is `interactive`, the user is explicitly asked per proposal before any canonical file is edited; without `-i`, `{rollup}` defaults to `off` and the canonical files in `{base_branch}` remain unchanged.
- [ ] The Events section is a fenced JSONL block in chronological order containing at minimum: `wrapup.started`, every `category.identified`, every `aggregator.dispatched` and `aggregator.completed`, every `rollup.proposed` and (`rollup.applied` or `rollup.declined`), `archive.committed`, `merge.completed`, `push.completed`, every `worktree.deleted` and `branch.deleted` when cleanup ran, optional `trajectory.saved` and `learnings.saved`, and `wrapup.done`.
- [ ] Each event is a JSON object with exactly the keys `ts`, `event_name`, `event_type`, `payload`. `ts` is an ISO-8601 UTC timestamp with millisecond precision. `event_name` is kebab-case (e.g., `wrapup.started`, `tool-call-git-worktree-list`, `rollup.proposed`). `event_type` is exactly one of `phase`, `tool_call`, `decision`, `side_effect`, `error`, `progress`.
- [ ] The JSONL block in the Events section is byte-identical to the file written at `{event_log_path}` when the path is enabled.
- [ ] When `{save_trajectory}` resolves to `true` (explicit `true` or interactive confirmation), `{trajectory_path}` and `{learnings_path}` both exist on disk and are non-empty; the report's Trajectory and Learnings section records each absolute path and its line count.
- [ ] When `{delete_after_merge}` resolves to `true` and the merge plus push both succeeded, every wrapped worktree is removed via `git worktree remove` and every wrapped branch deleted via `git branch -d` (or `-D` after a sample+revert pair makes the branch net-no-op); the Cleanup section lists every removed entry.
- [ ] On any failing step (merge conflict, push rejection, rollup application failure), the workflow stops at that step, emits an `error` event with `event_type: "error"` whose payload includes the failing command and stderr tail, leaves the repository in an inspectable state, and emits `wrapup.done` with `payload.outcome = "partial"`.
- [ ] When `-i` / `--interactive` is absent, the workflow makes no clarifying prompts; ambiguous categorization, missing canonicals, and rollup candidacy are recorded directly in the report without user interaction.

## Guardrails

- MUST emit a `wrapup.started` event before any side effect and a `wrapup.done` event as the last event, regardless of outcome.
- MUST emit every event in chronological order in the dedicated `### Events` section; MUST NOT inline events outside that section.
- MUST NOT delete a worktree or branch before its content is archived and the archive merged into `{base_branch}`; `{delete_after_merge}` controls deletion only after merge plus push succeed.
- MUST NOT modify a canonical file under `.cursor/skills/` or `.cursor/commands/` when `{rollup}` is `off`; MUST NOT silently apply a rollup when `{rollup}` is `interactive` without explicit per-proposal user confirmation.
- MUST cite the literal shell command and a verbatim slice of its captured output in every `tool_call` event's payload; MUST NOT paraphrase, summarize, or fabricate git or filesystem state inside event payloads.
- MUST stop at the first error, emit an `error` event, and skip all later phases except `wrapup.done`; MUST NOT auto-retry, auto-abort merges, or push with `--force` or `--force-with-lease`.
- MUST NOT ask clarifying questions unless `-i` / `--interactive` is set; without the flag, every parameter falls back to its non-interactive default.
- MUST refuse the workflow if `{base_branch}` is not a local branch or `{remote}` is not configured; abort with the failing check named before any side effect.
- Scope: wrap up the current agent thread's worktree work — survey, archive per category, optional rollup into canonical, merge, push, delete, optional trajectory and learnings save. Out of scope: opening PRs, force pushes, rebasing pre-existing branches, garbage-collecting unrelated branches, killing the agent process, sending notifications outside the local repository.

## Workflow

1. **Parse and validate.** Extract `-i` / `--interactive` and remove it from the input. Resolve every parameter to its explicit or default value. Validate that `{base_branch}` is a local branch, `{remote}` is configured, `{rollup}` is one of `interactive` / `auto` / `off`, and `{rollup_threshold}` is a non-negative integer. Emit `wrapup.started` with the resolved parameter set in the payload.
2. **Survey.** Run `git worktree list --porcelain` and `git branch --list`. For each worktree other than the calling worktree, capture path, branch (or detached HEAD SHA), dirty state, file-count diff vs. `{base_branch}`, and the assigned category. The category is the longest leading kebab-case prefix shared with one or more sibling worktrees; singletons get their own category named after the full worktree slug. Apply `{include_categories}` and `{exclude_categories}` filters. Emit one `category.identified` event per category and one `survey.completed` event.
3. **Commit outstanding samples.** For each dirty worktree, create a branch at its current HEAD (when detached) named `<category>-sample-<N>` where `<N>` is the variant index within the category. Stage and commit the outstanding content with a conventional message. Emit a `sample.committed` event per commit including the new branch name and commit SHA.
4. **Aggregate per category.** Create an isolated aggregate worktree off `{base_branch}` per category named `<category>-leftovers`. Copy each variant's tracked content into `{archive_root}<category>-leftovers/<filename>` preserving the original sample number or worktree slug, write a `README.md` describing the archive, and commit. Emit `aggregator.dispatched` and `aggregator.completed` events per category with the worktree path and commit SHA.
5. **Assess rollup eligibility.** For each category, attempt to locate a canonical file in `{base_branch}` at `.cursor/skills/<category>/SKILL.md` or `.cursor/commands/<category>.md`. When found, compute each variant's distinct new lines vs. the canonical via `git diff --stat` and a line-by-line diff. Variants whose distinct new content meets or exceeds `{rollup_threshold}` are proposed for rollup. When no canonical exists, record the category as `no-canonical` and skip rollup. Emit one `rollup.proposed` event per candidate with target path, distinct-new-lines count, and a one-line rationale.
6. **Apply rollups.** When `{rollup}` is `interactive`, ask the user per proposal before editing any canonical file; on confirmation, edit the canonical to incorporate the variant's distinct new content and commit with `feat(<scope>): roll up <variant> into <canonical>`. When `{rollup}` is `auto`, apply every proposal whose patch applies cleanly against `{base_branch}`; on conflict, downgrade to `declined`. When `{rollup}` is `off`, decline every proposal. Emit `rollup.applied` (with commit SHA) or `rollup.declined` (with reason) per proposal.
7. **Cherry-pick and revert.** Create a single root aggregate worktree `wrap-up-aggregate` off `{base_branch}`. Cherry-pick the per-category aggregator commits (and any rollup commits) into it. For each sample-commit branch created in step 3, add a revert commit (`git revert HEAD --no-edit`) so the source branch is net-no-op. Emit `aggregate.cherry_picked` and `sample.reverted` events.
8. **Merge and push.** Switch to `{base_branch}`, run `git merge --no-ff wrap-up-aggregate` with a descriptive message, then run `git push {remote} {base_branch}`. On conflict or push rejection, emit an `error` event with the failing command and stderr tail and stop. On success, emit `merge.completed` (with merge SHA) and `push.completed` (with refspec).
9. **Cleanup.** When `{delete_after_merge}` resolves to `true`, remove every wrapped worktree via `git worktree remove` (use `--force` when the branch is sample+revert net-no-op) and delete every wrapped branch via `git branch -d` (or `-D` after the revert pair). Emit one `worktree.deleted` and one `branch.deleted` event per cleanup.
10. **Save trajectory and learnings (optional).** When `{save_trajectory}` is `true` (explicit, or interactive confirmation when `-i` is set), write the chronological JSONL event log to `{trajectory_path}` and a markdown summary of decisions made, surprises encountered, and patterns discovered to `{learnings_path}`. Create parent directories as needed. Emit `trajectory.saved` and `learnings.saved` events with absolute paths and line counts.
11. **Persist the event log and emit `wrapup.done`.** Write the JSONL event log to `{event_log_path}` (creating parent directories). Emit a terminal `wrapup.done` event whose payload records archives count, rollups count, deletions count, the final repository SHA, and `payload.outcome = "success"` (or `"partial"` if step 8 or earlier emitted an `error`).

## Output Format

A single response with the named sections below, in order. Omit a section only when its body is legitimately empty after the run (e.g., Cleanup when `{delete_after_merge}` is `false`).

### Header
- `Repository`: absolute repository root.
- `Pre-run HEAD`: SHA of `{base_branch}` before the workflow ran.
- `Base branch`: resolved `{base_branch}` and its post-run HEAD SHA.
- `Remote`: resolved `{remote}`.
- `Archive root`: resolved `{archive_root}`.
- `Rollup mode`: `interactive` / `auto` / `off` and the resolved `{rollup_threshold}`.
- `Include / exclude`: resolved category filters.
- `Delete after merge`: `true` / `false`.
- `Event log path`: resolved `{event_log_path}`.
- `Trajectory / learnings paths`: resolved `{trajectory_path}` and `{learnings_path}` (or `(not saved)`).
- `Interactive`: `true` / `false`.

### Survey
A table, one row per worktree in scope: `Path | Branch | HEAD | Dirty | Files vs base | Category`. Below the table, a one-line summary per category with its worktree count.

### Aggregation
One block per category, in survey order:
- `Category`: name.
- `Archive path`: absolute path under `{archive_root}`.
- `Variants`: count and per-variant filename mapping.
- `Aggregator commit`: SHA.

### Rollup
One block per category that had at least one proposal, plus a summary line per category (`Outcome: applied | declined | under-threshold | no-canonical`). When zero proposals were considered, the section body is `_None._`. Per-proposal block:
- `Category`: name.
- `Canonical`: target path.
- `Variant`: variant identifier.
- `Distinct new lines`: count.
- `Outcome`: `applied` (with commit SHA) / `declined` (with reason) / `under-threshold`.
- `Rationale`: one line.

### Merge and Push
- `Merge`: literal `git merge` invocation, result (`success` / `conflict` / `aborted`), and post-merge SHA.
- `Push`: literal `git push` invocation, result (`success` / `rejected` / `skipped`), and the pushed remote refspec.

### Cleanup
A list, one entry per removed worktree, with `Path → removed` and `Branch → deleted`. Renders as `_None._` when `{delete_after_merge}` is `false` or no worktree was removed.

### Trajectory and Learnings
Present only when `{save_trajectory}` resolved to `true`:
- `Trajectory file`: absolute path, line count.
- `Learnings file`: absolute path, line count.

### Events
A fenced JSONL block in chronological order. Every line is a JSON object with exactly the keys `ts`, `event_name`, `event_type`, `payload`. Example:

```jsonl
{"ts":"2026-05-17T06:44:01.123Z","event_name":"wrapup.started","event_type":"phase","payload":{"interactive":true,"base_branch":"main","rollup":"interactive"}}
{"ts":"2026-05-17T06:44:02.456Z","event_name":"tool-call-git-worktree-list","event_type":"tool_call","payload":{"command":"git worktree list --porcelain","exit":0,"output_tail":"worktree /Users/.../dotfiles\nHEAD c382812\nbranch refs/heads/main\n..."}}
{"ts":"2026-05-17T06:44:03.789Z","event_name":"category.identified","event_type":"decision","payload":{"category":"agent-swarm","worktrees":6}}
{"ts":"2026-05-17T06:44:30.001Z","event_name":"rollup.proposed","event_type":"decision","payload":{"category":"agent-swarm","canonical":".cursor/skills/agent-swarm/SKILL.md","distinct_new_lines":42,"rationale":"variant adds pattern-catalog presets absent from canonical"}}
{"ts":"2026-05-17T06:45:01.002Z","event_name":"merge.completed","event_type":"side_effect","payload":{"merge_sha":"abc1234","base_branch":"main"}}
{"ts":"2026-05-17T06:45:30.000Z","event_name":"wrapup.done","event_type":"phase","payload":{"archives":4,"rollups":1,"deleted":21,"outcome":"success","final_sha":"def5678"}}
```

### Outcome
One sentence summarizing what landed in `{base_branch}` (archives, rollups), how many worktrees were deleted, and whether trajectory and learnings were saved.
