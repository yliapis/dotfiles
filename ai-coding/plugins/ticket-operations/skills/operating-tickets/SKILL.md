---
name: operating-tickets
description: "Operate local Markdown tickets across their full lifecycle: create ticket sets from analyses, execute open tickets with evidence and commits, or update existing ticket definitions, lifecycle state, and worklist projections. Use whenever the user's primary object is a ticket or ticket set. Do not use for generic code edits, commits, branches, merges, or pushes that are not driven by a ticket."
license: MIT
---

# Operating Tickets

## Task

Route one ticket request to the correct lifecycle motion, load that motion's
contract in full, and execute it without blending responsibilities:

| Motion | Use when | Canonical contract |
|---|---|---|
| `create` | The user has an analysis, review, plan, checklist, or recommendations and wants new tickets | [CREATE.md](./CREATE.md) and [TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md) |
| `execute` | The user wants an existing open ticket implemented, verified, completed, and committed | [EXECUTE.md](./EXECUTE.md), plus the `operating-git` change and commit motions |
| `update` | The user wants existing ticket fields, status, acceptance, dependencies, or worklist projection changed without implementation | [UPDATE.md](./UPDATE.md) |

The primary object decides the skill. “Implement this ticket and commit it” is
`operating-tickets`/`execute`, which composes `operating-git`; it is not a
generic Git request. “Commit these changes” or “merge this branch” is
`operating-git`.

## Parameters

- `{operation}` — `create` | `execute` | `update`; optional when exactly one
  motion is clear from the request. An explicit value wins over verb inference
  but MUST match the supplied input shape.
- All other parameters belong to the selected motion and are defined only in
  its canonical contract. Reject a parameter that belongs exclusively to a
  different motion instead of silently ignoring it.

Input routing:

- A work-item source that is not yet a native ticket set implies `create`.
- A native ticket, managed `WORKLIST.md`, or native set plus an implementation
  request implies `execute`.
- A native set plus an explicit lifecycle, definition, acceptance, dependency,
  or projection mutation implies `update`.
- An external tracker identifier does not imply any motion; tracker integration
  is outside this skill.

## Success Criteria

- [ ] Select exactly one primary motion before any side effect and name it in
      the plan/report.
- [ ] Read the selected contract in full at invocation time; for `create`, also
      read the template, and for `execute`, load `operating-git`.
- [ ] Validate only the selected motion's parameters and all of its
      preconditions before mutation.
- [ ] Preserve ticket frontmatter as lifecycle authority and `WORKLIST.md` as
      its validated projection in every motion.
- [ ] Preserve schema, fingerprint, lineage, revision, lock, journal, evidence,
      and atomicity rules from the selected contract without summarizing them
      into weaker router behavior.
- [ ] Return the selected contract's complete output, prefixed with
      `Ticket operation: <create|execute|update>`.

## Guardrails

- MUST NOT maintain an alternate create, execute, or update procedure in this
  router. The linked motion file is canonical.
- MUST NOT load all motion contracts by default; load only the selected motion
  and its declared dependencies.
- MUST NOT turn a ticket metadata/status request into implementation.
- MUST NOT implement a ticket through the update motion or mark it complete
  without the selected contract's evidence rules.
- MUST NOT let `operating-git` mutate ticket lifecycle independently; the
  execute motion owns the combined transaction.
- MUST NOT call GitHub Issues, Jira, Linear, or another external tracker.
- MUST NOT push, merge, or open a pull request unless a user separately invokes
  the applicable `operating-git` motion after ticket execution.

## Workflow

1. **Classify.** Resolve `{operation}` or infer one motion from the primary
   object and requested state change. If create/execute/update remain genuinely
   ambiguous, ask one focused question before reading or writing artifacts.
2. **Load.** Read the selected canonical contract in full. For `create`, read
   `TICKET_TEMPLATE.md`; for `execute`, read `../operating-git/SKILL.md` and
   the Git contracts it routes to.
3. **Validate.** Apply the selected contract's parameter, schema, filesystem,
   Git, lifecycle, and recovery checks before its first side effect.
4. **Operate.** Run the selected motion exactly. A request that explicitly
   sequences motions (for example, create then execute) completes and
   revalidates each motion boundary before starting the next.
5. **Report.** Prefix the canonical motion report with the selected operation,
   then preserve all evidence, hashes, revisions, commits, failures, and
   handoff details required by that contract.

## Deferrals

- Generic file changes, commits, branches, worktrees, merges, and pushes:
  `operating-git`.
- Parallel agent/worktree orchestration: `agent-swarm` or `worktree-task`.
- Producing the upstream critique or analysis: the relevant analysis command.
- External issue-tracker synchronization: unsupported.
