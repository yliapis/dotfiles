---
name: operating-git
description: "Operate Git and Git-bound code changes: keep edits minimal, create Conventional Commits, and safely merge or push branches. Use when the user's primary request is a code change, commit, branch integration, or push. Do not use as the primary skill for creating, executing, or updating tickets; ticket execution composes this skill under operating-tickets."
license: MIT
---

# Operating Git

## Task

Route one Git-oriented request to the smallest applicable motion:

| Motion | Use when | Canonical contract |
|---|---|---|
| `change` | Editing, fixing, refactoring, or adding code/files | [DIFFS.md](./DIFFS.md) |
| `commit` | Staging and committing an existing or requested change | [DIFFS.md](./DIFFS.md) and [COMMITS.md](./COMMITS.md) |
| `integrate` | Merging a branch and optionally pushing the result | [MERGE_PUSH.md](./MERGE_PUSH.md); also [COMMITS.md](./COMMITS.md) for squash commits |

The primary object decides the skill. A ticket remains owned by
`operating-tickets`, even though its execute motion uses `operating-git` to make
the implementation minimal and create the ticket commit.

## Parameters

- `{operation}` — `change` | `commit` | `integrate`; optional when the request
  clearly selects one motion.
- The integrate motion accepts `{source_branch}`, `{target_branch}`,
  `{merge_strategy}`, `{remote}`, `{commit_message}`, and `{include_push}` as
  defined in [MERGE_PUSH.md](./MERGE_PUSH.md).
- Change and commit intent comes from the user's requested diff and current Git
  state. Reject integrate-only parameters for another motion.

## Success Criteria

- [ ] Select and report exactly one primary motion before side effects.
- [ ] Read every canonical contract named by that motion in full.
- [ ] Every edit is the smallest coherent change that satisfies the request and
      excludes unrelated cleanup.
- [ ] Every created commit follows Conventional Commits, accurately describes
      the staged diff, and preserves required ticket footers when composed by
      `operating-tickets`.
- [ ] Every merge/push validates clean state, branch existence, strategy, and
      remote preconditions before changing Git state.
- [ ] Return the selected contract's report prefixed with
      `Git operation: <change|commit|integrate>`.

## Guardrails

- MUST NOT duplicate the detailed diff, commit, or merge/push procedures in
  this router; the linked files are canonical.
- MUST NOT broaden a requested diff with drive-by formatting, refactoring,
  comments, logging, or defensive code.
- MUST NOT stage unrelated files or hide a dirty tree.
- MUST NOT amend, rebase, squash, force-push, or rewrite history unless the
  user explicitly requests an operation whose canonical contract permits it.
- MUST NOT infer ticket completion, update ticket status, or repair a ticket
  worklist. Those mutations belong to `operating-tickets`.
- MUST NOT implement worktree fan-out; use `agent-swarm` or `worktree-task`.

## Workflow

1. **Classify.** Resolve `{operation}` from the explicit value or the primary
   Git object/action. Ask one focused question only when motion choice changes
   side effects materially.
2. **Load.** Read `DIFFS.md` for change/commit, `COMMITS.md` for commit and
   squash integration, and `MERGE_PUSH.md` for integration.
3. **Validate.** Inspect relevant files and Git state, then apply every
   selected contract's fail-fast checks.
4. **Operate.** Make the minimal change, commit it, or integrate it according
   to the selected motion. When called by ticket execution, return control
   before any merge or push so the ticket transaction can finalize.
5. **Report.** Prefix and preserve the canonical motion report, including diff
   scope, commit SHA/message, branch SHAs, merge strategy, push result, and any
   inspectable failure state.

## Deferrals

- Ticket creation, execution, lifecycle, metadata, or projection:
  `operating-tickets`.
- Parallel isolated attempts or worktree orchestration: `agent-swarm` or
  `worktree-task`.
- Pull-request creation/review and remote issue trackers: their dedicated
  tooling, only when explicitly requested.
