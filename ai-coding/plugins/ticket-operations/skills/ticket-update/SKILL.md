---
name: ticket-update
description: "Change fields or status on existing Backlog.md tasks through the backlog CLI, applying only what was explicitly requested. Use for task status, assignee, labels, priority, type, title, description, acceptance criteria, or dependency changes. Do not use to create tasks, implement work, verify acceptance, or operate a tracker."
license: MIT
---

# Ticket Update

## Activation

Use this skill to change tasks that already exist in a Backlog.md project.

Use `ticket-create` for new tasks and `ticket-execute` to implement or verify
one. Do not activate this skill for tracker records, implementation edits, or a
request that merely asks what to change.

## Task

Resolve the named tasks, read each one before mutating it, and apply exactly the
requested changes with `backlog task edit`. The CLI owns file naming,
frontmatter, timestamps, and section structure; this skill owns the guardrail
that nothing beyond the request changes.

## Backlog.md Contract

These rules apply to every command this skill runs:

- Require `backlog` on `PATH` and an initialized project (`backlog/config.yml`,
  `.backlog/config.yml`, or `backlog.config.yml`). Missing either aborts with
  `install backlog.md (brew install backlog-md) and run backlog init`.
- MUST NOT create, edit, move, or delete a file under the backlog directory by
  hand. Every read and write goes through the CLI.
- Read each target with `backlog task view <id> --plain` before and after the
  edit.
- Statuses, priorities, and task types are per-project. Read the accepted values
  from `backlog task edit --help` and reject a request that names anything else.

## Parameters

- `{target}` — required. One task ID or a comma-separated list of exact IDs.
  Reject URLs, tracker identifiers, titles, and unknown IDs.
- `{patch}` — required for a mutation. A mapping of field to new value, applied
  through the flags in `## Field Mapping`. It may name several fields and
  several tasks; a field absent from the patch is left alone.
- `{mode}` — `interactive` | `non-interactive`; optional, default
  `interactive`. Interactive presents one complete plan and requires approval.
- `{commit}` — `none` | `audit`; optional, default `none`. `audit` creates one
  local Conventional Commit for the whole transaction. It never pushes.
- `{dry_run}` — optional boolean, default `false`. Resolve, validate, and
  report the complete prospective change, but edit nothing and commit nothing.

Unknown parameters, duplicate IDs, or values the project rejects abort before
side effects.

## Success Criteria

- [ ] Validate parameters, the Backlog.md contract, every target ID, and every
      requested value before the first edit.
- [ ] Read each target before mutating it and report its current values.
- [ ] Apply only the requested fields; every other field is byte-identical
      afterwards.
- [ ] Reject a status transition into the terminal status unless every
      acceptance criterion is checked.
- [ ] Check an acceptance criterion only against explicit caller-supplied
      evidence, labelled `caller-supplied; not executed`.
- [ ] Keep the dependency graph acyclic and free of self-edges and unknown IDs.
- [ ] An effective no-op reports `unchanged` and runs no write command.

## Guardrails

- MUST NOT infer completion from code, commits, or user intent. A move to the
  terminal status needs the evidence described below.
- MUST NOT run acceptance commands, inspect the implementation to declare a
  criterion met, or implement task scope. Use `ticket-execute` for that.
- MUST NOT paraphrase text the caller supplied, or edit a field the patch does
  not name.
- MUST NOT edit repository content outside the backlog directory. The optional
  audit commit is the only other write.
- MUST NOT stage unrelated paths, or use broad add, clean, reset, checkout,
  amend, rebase, or any history-rewriting command.
- MUST NOT call a tracker or external write API; create or switch a branch or
  worktree; merge; push; open a pull request; create a tag; or spawn an agent.

## Field Mapping

| Requested change | Flags |
|---|---|
| title | `-t` |
| description | `-d` |
| status | `-s` |
| assignee | `-a` |
| priority | `--priority` |
| type | `--type` |
| labels (replace all) | `-l` |
| labels (add or remove) | `--add-label`, `--remove-label`, `--clear-labels` |
| acceptance criteria (add) | `--ac` per value |
| acceptance criteria (replace all) | `--acceptance-criteria` per value |
| acceptance criteria (remove) | `--remove-ac <index>` |
| acceptance markers | `--check-ac <index>`, `--uncheck-ac <index>` |
| definition of done | `--dod`, `--remove-dod <index>`, `--check-dod <index>`, `--uncheck-dod <index>` |
| plan | `--plan` |
| notes | `--notes` (replace), `--append-notes` (extend) |
| final summary | `--final-summary`, `--append-final-summary`, `--clear-final-summary` |
| comment | `--comment` with `--comment-author` |
| dependencies | `--dep` with the complete replacement list |
| references | `--ref` per value |
| milestone | `-m`, `--clear-milestone` |
| ordinal | `--ordinal` |

Criterion indexes are 1-based and refer to the numbering shown by
`backlog task view <id> --plain`. Re-read the task after any change that
renumbers criteria, and never combine `--remove-ac` with an index-based check in
the same call. `--dep` and `-l` replace the whole list, so supply every value
that should survive.

Apply one `backlog task edit <id> ... --plain` per task, batching that task's
flags into a single call. Quote every argument; use single quotes for any value
containing a literal backtick, and pass multi-line text as real newlines inside
one quoted argument.

## Evidence and Transitions

Checking a criterion or moving a task to the terminal status is an assertion
about the world, and this skill never runs the check itself. Both require the
caller to supply, per criterion, the command or artifact reference and the
observed result. Validate that the reference exists locally, then label it
`caller-supplied; not executed` in the plan, the report, and any audit commit.

A move to the terminal status additionally requires that every acceptance
criterion ends the transaction checked, and that every dependency is already
terminal. Without evidence for a criterion, the transition is rejected; run
`ticket-execute` instead, which produces its own evidence.

Unchecking a criterion requires a stated reason but no evidence.

## Audit Commit

With `{commit}=none`, leave the changed task files unstaged.

With `{commit}=audit`, and only after every edit succeeds and re-reads clean,
stage only the changed task files and create exactly one commit:

```text
chore(tickets): update <id>

<one line per task naming the changed fields>

Task-Id: <id>
```

Use `chore(tickets): update <n> tasks` for several. Repeat `Task-Id` per task in
target order. Require an empty index and a clean worktree beforehand, require
the commit to be the sole child of the baseline, and never amend or follow up.
When the backlog directory is untracked or ignored, report that and create no
commit.

## Failure

Edits apply one task at a time and are not transactional across tasks. Validate
everything up front so a mid-run failure is unlikely; if one happens, stop
immediately, re-read every target, and report which tasks changed and which did
not. Do not attempt to reverse an applied edit unless the caller asks, and never
hand-edit a file to undo one.

## Workflow

1. Validate parameters and the Backlog.md contract.
2. Read every target with `backlog task view <id> --plain` and capture current
   values.
3. Validate every requested value against the configured statuses, priorities,
   and types, and validate the prospective dependency graph.
4. Validate evidence for every criterion check and terminal transition.
5. Render the plan with before and after values. Stop for `{dry_run}` or a
   declined approval.
6. Apply one `backlog task edit` per task in target order.
7. Re-read every target, create the optional audit commit, and report.

## Output Format

Return these sections in order, omitting empty optional sections:

### Run Summary

Backlog directory; target IDs; mode; commit mode; outcome (`updated`,
`unchanged`, `dry-run`, `declined`, or `failed`); and changed and skipped
counts.

### Plan

One row per task: ID, field, current value, new value, and the exact flag used.

### Evidence

For each criterion check or terminal transition: the criterion, the supplied
reference, the observed result, the validation disposition, and the
`caller-supplied; not executed` label.

### Result

One row per task: ID, applied fields, and final status.

### Commit

Commit SHA, subject, and staged paths; or `none`.

### Handoff

Final status for each changed task and whether the backlog files are unstaged or
committed. State that the skill performed no implementation or acceptance
execution and made no tracker, branch, worktree, merge, push, pull-request, tag,
or other remote change.
