---
name: ticket-execute
description: "Work Backlog.md tasks to Done through the backlog CLI: plan, implement, prove every acceptance criterion with runtime evidence, and create exactly one Conventional Commit per finished task. Use when the user asks to implement a ticket, execute the next task, or work through selected tasks. Do not use for task creation, trackers, or remotes."
license: MIT
---

# Ticket Execute

## Activation

Use this skill to implement tasks that already exist in a Backlog.md project.

Backlog.md holds task state. This skill adds what its guides leave to the
project: one Conventional Commit per finished task, an evidence gate before any
acceptance criterion is checked, and rollback of the working tree when a task
fails.

Execution composes the `minimal-diffs` and `conventional-commits` skills from
the `git-operations` plugin. Require both before implementation; if either is
unavailable, stop before starting a task and report the missing plugin.

## Task

Select runnable tasks deterministically, then process one at a time: move it to
the active status, record a researched plan, implement only its scope, prove
every acceptance criterion with current runtime evidence, finalize it, and
create exactly one commit containing the implementation.

## Backlog.md Contract

These rules apply to every command this skill runs:

- Require `backlog` on `PATH` and an initialized project (`backlog/config.yml`,
  `.backlog/config.yml`, or `backlog.config.yml`). Missing either aborts with
  `install backlog.md (brew install backlog-md) and run backlog init`.
- Read `backlog instructions task-execution` before the first edit and
  `backlog instructions task-finalization` before checking any criterion.
- MUST NOT create, edit, move, or delete a file under the backlog directory by
  hand. Every read and write goes through the CLI.
- Read with `backlog task view <id> --plain` and `backlog task list --plain`.
- Statuses are per-project. Read the accepted values from
  `backlog task edit --help` and use the configured active and terminal
  statuses rather than assuming `In Progress` and `Done`.

## Parameters

- `{target}` — `next` | `all` | a comma-separated list of exact task IDs;
  optional, default `next`.
- `{mode}` — `interactive` | `non-interactive` | `force-approve-all`;
  optional, default `interactive`. `interactive` approves the plan and each
  final diff and commit; `non-interactive` approves the plan once;
  `force-approve-all` prompts nowhere.
- `{verify_command}` — optional additional shell command run from the worktree
  root for each attempted task. It supplements criterion-specific checks; task
  prose is never executed as a command. Export `TASK_ID` and `TASK_TITLE` for
  it.
- `{commit_scope}` — optional Conventional Commit scope applied to every
  resulting commit. It MUST match `^[a-z0-9][a-z0-9._-]*$`; omit it when unset.
- `{on_failure}` — `abort` | `continue`; optional, default `abort`. Both first
  roll the failed task back completely. `continue` then considers only tasks
  whose dependencies remain satisfied.
- `{dry_run}` — optional boolean, default `false`. Resolve, select, and render
  the complete plan, but edit no task, run no verification command, stage
  nothing, and create no commit.

Unknown parameters or invalid values abort before side effects.

## Success Criteria

- [ ] Validate parameters, the Backlog.md contract, Git state, and the
      dependency graph before the first side effect.
- [ ] Start only a task whose status is not terminal and whose dependencies are
      all at the terminal status.
- [ ] Record a researched plan in the task before implementing it.
- [ ] Make the smallest implementation within the task's scope, and map every
      acceptance criterion to fresh runtime evidence before `--check-ac`.
- [ ] Create exactly one Conventional Commit per finished task, containing the
      implementation, the task trailers, and the backlog file when it is
      tracked.
- [ ] A failure or declined approval creates no commit and restores the exact
      pre-task tree and index, and returns the task to its starting status.
- [ ] A rerun skips tasks already at the terminal status and creates no
      duplicate commit.

## Guardrails

- MUST require a clean starting baseline: an empty index, a named branch,
  configured commit identity, and no merge, rebase, cherry-pick, revert, or
  bisect in progress.
- MUST NOT start a task that is already at the terminal status or assigned to
  another owner, and MUST NOT reopen a finished task.
- MUST NOT change a task's title, description, acceptance criterion text,
  dependencies, type, priority, or labels. Those are `ticket-update` edits.
  This skill changes status, assignee, plan, notes, criterion checkmarks, and
  the final summary.
- MUST NOT infer acceptance from inspection, intention, an old result, an
  unrelated green suite, or an agent assertion. Preserve the command or action,
  the result, and the relevant output for each criterion.
- MUST NOT stage unrelated files or use broad `git add -A`, `git reset --hard`,
  or `git clean`. Stage explicit task-owned paths.
- MUST NOT commit when evidence fails, a criterion remains unchecked, or
  approval is declined.
- MUST NOT combine tasks in one commit, amend, squash, or rebase.
- MUST NOT call trackers or external write APIs, spawn agents, worktrees, or
  swarms, switch or create branches, merge, push, open a pull request, create a
  tag, or delete a branch.

## Selection

Read the candidate universe with
`backlog task list --exclude-status "<terminal status>" --sort priority --plain`,
and read each selected task in full with `backlog task view <id> --plain`.

- `next` selects the highest-priority non-terminal task whose dependencies are
  all terminal, breaking ties by ascending task ID.
- `all` selects every non-terminal task for classification.
- An ID list rejects empty, duplicate, or unknown IDs.

For `all` or an ID list, repeatedly schedule the highest-priority selected task
whose dependencies are already terminal or scheduled earlier. This is a stable
topological order. Report unrunnable, blocked, and already-assigned tasks
without mutating them. A cycle aborts before side effects.

Before approval, derive a minimal path plan, a criterion-specific verification
plan, and a commit message for each scheduled task. Use the task's configured
type as the Conventional Commit type, the optional `{commit_scope}`, and a
faithful lowercase imperative description with no trailing period and fewer than
50 characters. The complete subject MUST satisfy Conventional Commits and never
exceed 72 characters. When the task carries no type, derive one from its content
and say so in the plan. If truthful conversion is ambiguous, stop before side
effects.

## Per-Task Loop

For each scheduled task, in order:

1. **Re-read.** `backlog task view <id> --plain`. Confirm the status, the
   acceptance criteria, and that every dependency is terminal. Any drift since
   selection re-plans or skips the task.
2. **Claim.** `backlog task edit <id> -s "<active status>" -a @<agent> --plain`.
3. **Plan.** Research the current code, then record the plan with
   `backlog task edit <id> --plan "<steps>" --plain`. Do not carry over an
   approach proposed at creation time without checking it against the code.
4. **Implement.** Record the baseline of every path before editing it. Apply
   only the smallest coherent change for this task, following `minimal-diffs`.
   After every tool or command, inspect the produced paths; an unexplained or
   out-of-scope change fails the task.
5. **Verify.** Exercise the changed behavior with the narrowest existing
   repository-native tests or end-to-end actions, then run `{verify_command}`
   when supplied. Map every acceptance criterion to a fresh command or action,
   its exit status or result, and the relevant output. Static inspection alone
   is not acceptance. Documentation and configuration criteria need a parser,
   renderer, link check, example run, or consuming command. An unproved
   criterion fails the task.
6. **Finalize.** Record progress and completion in one call:
   `backlog task edit <id> --append-notes "<what changed and how it was
   verified>" --check-ac <n> ... --final-summary "<summary naming the
   evidence>" -s "<terminal status>" --plain`. Check only the criteria the
   evidence proves. Check Definition of Done items with `--check-dod` when the
   project defines them.
7. **Commit.** Review the prospective diff and evidence; in `interactive` mode
   obtain approval, and a decline triggers rollback. Stage only the
   implementation paths, plus the task file when the backlog directory is
   tracked. Create one commit. Verify exactly one commit was added and its tree
   and message match the approval.

## Commit Contract

The single commit follows Conventional Commits 1.0.0:

```text
<task type>[(<commit_scope>)]: <imperative description>

Acceptance:
- <criterion>: <evidence summary>

Verification:
- `<command or action>`: <result>

Task-Id: <id>
Task-Title: <title>
```

Wrap body text at 72 characters and retain both trailers. Run Git hooks
normally. If `git commit` reports failure but `HEAD` moved, inspect it: accept
success only when the sole new commit matches the approved tree and message;
otherwise stop for recovery without resetting or committing again.

## Failure and Rerun

Before `HEAD` advances, any implementation error, failed evidence, failed hook,
declined approval, or definite commit failure rolls the task back. Restore the
recorded implementation paths and index entries, delete only individually
recorded new paths, and return the task to its starting status and assignee with
`backlog task edit`. Uncheck any criterion this run checked. Never overwrite an
unrecognized change; preserve it and report `recovery-required`.

After a proven rollback, `abort` stops and `continue` re-reads the board before
the next independent task. A failed task produces no commit and cannot satisfy a
dependent.

On rerun, a task already at the terminal status is reported `already-done` with
no verifier, edit, or commit.

## Workflow

1. Validate parameters, the Backlog.md contract, and the composed Git skills.
2. Validate Git baseline safety.
3. Read the board and the selected tasks; resolve selection, stable order,
   deferrals, path and evidence plans, and commit messages.
4. Render the plan. Stop for `{dry_run}` or a declined plan approval.
5. Run the per-task loop sequentially.
6. Roll back failures before applying `{on_failure}`; recalculate dependency
   readiness before continuing.
7. Re-read the board and report without remote side effects.

## Output Format

Return these sections in order, omitting only empty optional sections:

### Run Summary

Backlog directory; selector and order; mode; assignee; baseline and final
`HEAD`; outcome (`completed`, `partial`, `no-runnable`, `already-done`,
`dry-run`, `declined`, `failed`, or `recovery-required`); and counts for
selected, scheduled, committed, already-done, deferred, failed, and declined.

### Plan

One row per selected task: execution order, ID, status, dependencies,
runnability, scope paths, verification summary, proposed commit subject, and
disposition. For a dry run, stop here and state that no side effect occurred.

### Task Results

One row per selected task: ID, outcome, starting and final status, commit SHA
or `none`, and a one-line note.

### Acceptance Evidence

For every finished task, map each criterion to the exact command or manual
action, its exit status or result, the relevant output tail or artifact path,
and the conclusion. Redact secrets from captured output.

### Commits

Each full commit SHA, subject, and task ID.

### Failures and Recovery

For every non-committed scheduled task, report the phase, root cause, rollback
result, and deferred dependents.

### Handoff

List local commits in order, the remaining non-terminal task IDs, and the final
worktree status. State that no tracker, branch or worktree creation or switch,
swarm, merge, push, pull request, tag, or remote write occurred.
