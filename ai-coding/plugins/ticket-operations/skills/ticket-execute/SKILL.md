---
name: ticket-execute
description: "Execute open runnable tickets from a native local Markdown ticket set, verify acceptance with runtime evidence, update authoritative lifecycle state and WORKLIST.md, and create exactly one traceable Conventional Commit per successful ticket. Use when the user asks to implement a ticket, execute the next ticket, or work through selected tickets. Do not use for ticket creation, trackers, remotes, or checkbox-only tasks."
license: MIT
---

# Ticket Execute

## Activation

Use this skill only for local tickets created under the
`ticket-operations/ticket` schema. It supersedes
`address-worklist-commit-loop` for native ticket sets.

Ticket frontmatter is lifecycle authority. `WORKLIST.md` is a validated
projection and selection surface; it never overrides a ticket.

## Task

Resolve `{target}` to one managed ticket set, validate the complete set before
side effects, and deterministically select open tickets. Process one ticket at
a time: claim it with compare-before-write lifecycle state, implement only its
scope, prove every acceptance criterion with current runtime evidence, complete
the lifecycle and worklist projection, and create exactly one Conventional
Commit containing implementation and lifecycle writeback.

## Parameters

- `{target}` — required local path inside the current Git worktree. Accepts a
  native ticket file, a managed `WORKLIST.md`, a directory containing exactly
  one managed `WORKLIST.md`, or a legacy Markdown worklist used only as the
  read-only native-ticket selector defined under Compatibility. URLs, chat,
  inline items, and tracker identifiers are rejected.
- `{select}` — `next` | `all` | a comma-separated list of exact ticket IDs;
  optional. A ticket target selects itself and rejects a conflicting value.
  Other targets default to `next`.
- `{mode}` — `interactive` | `non-interactive` | `force-approve-all`;
  optional, default `interactive`. `interactive` approves the plan and each
  final diff/commit; `non-interactive` approves the plan once;
  `force-approve-all` prompts nowhere.
- `{owner}` — non-empty provisional-claim owner; optional, default
  `ticket-execute:<git-user-email>`. Abort when no parameter or configured Git
  email supplies an owner.
- `{verify_command}` — optional additional shell command run from the worktree
  root for each attempted ticket. It supplements criterion-specific checks;
  ticket prose is never executed as a command. Export `TICKET_ID`,
  `TICKET_FILE`, `TICKET_SET`, and `TICKET_BASE_REVISION` for this command.
- `{commit_scope}` — optional Conventional Commit scope applied to every
  resulting commit. It MUST match `^[a-z0-9][a-z0-9._-]*$`; omit it when unset.
- `{on_failure}` — `abort` | `continue`; optional, default `abort`. Both first
  roll the failed ticket back completely. `continue` then considers only
  tickets whose dependencies remain satisfied.
- `{recovery}` — `abort` | `resume` | `rollback`; optional, default `abort`.
  It applies only to a valid interrupted `ticket-execute` journal in this
  worktree and never adopts an unjournaled claim.
- `{legacy_checkbox_policy}` — `reject` | `project-from-tickets`; optional,
  default `reject`. The latter explicitly treats checkbox-only state as
  advisory; it never converts a checked box into ticket completion.
- `{dry_run}` — optional boolean, default `false`. Resolve, validate, select,
  and render the complete plan, but acquire no lock, write no journal or file,
  ask no approval, run no verification command, stage nothing, and create no
  commit.

Unknown parameters or invalid values abort before side effects.

## Success Criteria

- [ ] Validate parameters, Git state, schema/version, set identity, ticket
      fingerprints, lifecycle revisions, full worklist projection, and the
      dependency graph before the first side effect.
- [ ] Select and order tickets deterministically; claim only a ticket whose
      authoritative status is `open` and whose dependencies are `done` at
      claim time.
- [ ] Perform `open@r -> in_progress@(r+1) -> done@(r+2)` with exact-content
      compare-before-write checks and crash-recoverable journaling.
- [ ] Make the smallest implementation within Scope and Out of Scope, and map
      every acceptance criterion to fresh runtime evidence.
- [ ] Check acceptance markers and update the canonical worklist only from
      authoritative final ticket state.
- [ ] Create exactly one Conventional Commit per successful ticket, containing
      implementation, final ticket state, and worklist writeback with ticket
      identity trailers.
- [ ] A failure or declined approval creates no commit and restores the exact
      pre-ticket tree/index, or stops without overwriting when safe restoration
      cannot be proved.
- [ ] A rerun skips authoritative `done` tickets and creates no duplicate
      commit regardless of legacy checkbox state.
- [ ] End each committed or safely rolled-back ticket with a clean worktree and
      report its evidence and commit SHA.

## Guardrails

- MUST read and apply the live `ticket-create` version-1 schema and identity
  contracts. Fail closed on unknown schema names or versions.
- MUST require a clean tracked/untracked tree, empty index, named branch,
  configured commit identity, and no merge, rebase, cherry-pick, revert, or
  bisect in progress. Explicit recovery of this skill's valid journal is the
  sole exception.
- MUST NOT execute a ticket unless it is `open` and runnable. Never reopen
  `blocked`, `cancelled`, or `done`, or seize `in_progress`.
- MUST NOT change immutable or definition-owned fields, acceptance text,
  dependencies, fingerprints, ticket-set identity, source data, or unknown
  extension keys. This skill changes only lifecycle fields, acceptance
  markers, and their projection.
- MUST NOT infer acceptance from inspection, intention, an old result, an
  unrelated green suite, or an agent assertion. Preserve the command/action,
  result, and relevant output or artifact for each criterion.
- MUST NOT stage unrelated files or use broad `git add -A`, `git reset --hard`,
  or `git clean`. Stage and restore explicit transaction-owned paths.
- MUST NOT commit when evidence fails, a criterion remains unchecked, the
  projection is invalid, a compare-before-write check fails, or approval is
  declined.
- MUST NOT combine tickets, create a claim commit, amend, squash, rebase, or
  produce a lifecycle-only follow-up commit.
- MUST NOT call trackers or external write APIs, spawn agents/worktrees/swarms,
  switch or create branches, merge, push, open a pull request, create a tag, or
  delete a branch.

## Native Set Preflight

Reject every symlink path component before normalizing paths. The target,
managed worklist, and every ticket MUST be tracked regular files inside the
current worktree and outside `.git`. A ticket target resolves through its
sibling `WORKLIST.md`; a directory resolves only
`<directory>/WORKLIST.md`, without recursive guessing.

Parse YAML strictly, rejecting duplicate keys, aliases, custom tags, and
implicit coercion that violates the declared field type. Validate from one
read-only snapshot:

1. The worklist declares `ticket-operations/worklist` version `1` and
   `ticket-operations/ticket` version `1`. Each ticket declares
   `ticket-operations/ticket` version `1`.
2. `ticket_set` and `source_fingerprint` have full
   `sha256:<64-lowercase-hex>` form. Set identity agrees across all artifacts.
   Every ticket's `source.fingerprint` equals the worklist
   `source_fingerprint`. Treat `ticket_set` as an opaque identity: do not claim
   to recompute it because its creation preimage includes source/template
   material absent from a generated set.
3. `ticket_count`, ordered manifest records, and native ticket files are
   one-to-one. IDs and normalized relative paths are unique and safe; no native
   file claiming this set is omitted.
4. Every required ticket field, ordering, enum, body section, and acceptance
   marker is valid. `revision` is a positive integer. `owner` is non-null
   exactly for `in_progress`; `status_reason` is non-null exactly for
   `blocked` and `cancelled`; a `done` ticket has all criteria checked.
5. Recompute every ticket `fingerprint` exactly as `ticket-create` specifies:
   canonical definition data, acceptance markers normalized to unchecked, and
   lifecycle fields, `ticket_set`, and extensions excluded. It MUST match the
   ticket and manifest.
6. Reconstruct every worklist entry from authoritative tickets and require
   exact manifest status/revision and body group, marker, ID, title, `Where`,
   `Why`, `Done-when`, ticket path, fingerprint, status, and revision. Preserve
   and structurally validate Item Accounting.
7. Dependencies are unique existing same-set IDs, never self, and the complete
   graph is acyclic. Only authoritative `done` satisfies a dependency.
8. `HEAD`, branch, identity, index, worktree, submodules, and Git-operation
   state satisfy the Guardrails.

Any mismatch aborts without repair, except the single explicitly authorized
checkbox-only compatibility case below. Re-read and compare exact bytes under
the execution lock before every lifecycle write.

## Compatibility

An unmanaged legacy worklist is never authority. Read only item IDs and
`Ticket:` paths. Continue only when every selected item links to a valid native
ticket, all links resolve to one managed set, and its canonical `WORKLIST.md`
passes preflight. Items without native links are rejected rather than executed
from checkbox prose. The legacy file remains read-only.

For legacy markers, including body markers changed by
`address-worklist-commit-loop`:

- `reject` aborts when a checkbox disagrees with authoritative ticket status
  and reports both states.
- `project-from-tickets` ignores markers for selection and reports every
  disagreement. In a managed worklist, tolerate only body-marker drift for
  which in-memory projection from ticket statuses is otherwise byte-valid.
  Validate that canonical in-memory projection before any write. Include that
  projection-only repair in the first successful ticket commit; it increments
  no ticket revision. If no ticket succeeds, write no repair.

Manifest lifecycle drift, changed projected text, missing links, mixed sets,
or other ambiguity always aborts. `[x]` beside an `open` ticket is a legacy
completion proposal, not evidence that the ticket is done.

## Selection and Ordering

Use the worklist frontmatter `tickets` order as canonical rank, never directory
enumeration or legacy body order.

- `next` selects the lowest-ranked currently `open` ticket whose dependencies
  are all `done`.
- `all` selects every `open` ticket in the target universe.
- An ID list rejects empty, duplicate, or unknown IDs; execution still
  tie-breaks by canonical rank.

For `all` or IDs, repeatedly schedule the lowest-ranked selected `open` ticket
whose dependencies are already `done` or scheduled earlier. This is a stable
topological order. Report terminal, blocked, claimed, and unsatisfied tickets
without mutation. Revalidate the complete set and actual dependency statuses
before every claim; a failed dependency leaves dependents unattempted.

Before approval, derive a minimal path plan, criterion-specific verification
plan, and commit message for each scheduled ticket. Use its validated `type`,
optional `{commit_scope}`, and a faithful lowercase imperative description
with no trailing period and fewer than 50 characters. The complete subject MUST
satisfy Conventional Commits and never exceed 72 characters. If truthful
conversion is ambiguous, stop before side effects.

## Lifecycle Transaction

Claims are provisional working-tree transactions, not commits. After plan
approval, acquire an exclusive set lock beneath this worktree's Git
administrative directory and rerun preflight. Never auto-break a stale lock.

For each ticket at revision `r`:

1. Create and sync an atomic write-ahead journal at
   `$GIT_DIR/ticket-execute/<set-hex>/<ticket-id>.json`. Record baseline `HEAD`,
   exact ticket/worklist bytes and hashes, expected revision/owner, planned
   before/after hashes, phase, index state, commit message, and every path
   before its first mutation. Locks and journals are never staged.
2. **Claim CAS.** Require exact preflight bytes, `open`, null owner/reason,
   revision `r`, unchanged fingerprint, and all dependencies `done`. Prepare
   both images in memory. Compare again immediately before atomically replacing
   the ticket with `in_progress`, `{owner}`, null reason, revision `r+1`, then
   the worklist with `[>]`, `in_progress`, and `r+1`. Advance the write-ahead
   journal around each replacement so a torn pair is recognizable.
3. **Implement.** Before editing a path, journal its baseline object/mode/hash
   or absence. Apply only the smallest coherent ticket change, following
   `minimal-diffs`. After every tool or command, inspect and register produced
   paths; unexplained or out-of-scope changes fail the ticket.
4. **Verify.** Exercise changed behavior with the narrowest existing
   repository-native tests or end-to-end actions, then run `{verify_command}`
   when supplied. Map every criterion to a fresh command/action, exit/result,
   relevant output/artifact, and conclusion. Static inspection alone is
   insufficient for behavioral acceptance. Documentation and configuration
   criteria need a parser, renderer, link check, example run, or consuming
   command. An unproved criterion fails.
5. **Complete CAS.** Require the exact claim images, revision `r+1`, matching
   owner, unchanged fingerprint and baseline `HEAD`, and dependencies still
   `done`. In memory, check every evidenced criterion, set `done`, null
   owner/reason, revision `r+2`, and project `[x]`, `done`, `r+2` to the
   worklist. Validate the complete prospective set, journal it, compare before
   each atomic replacement, then replace ticket first and worklist second.
6. Review the complete diff and evidence. In `interactive` mode obtain
   per-ticket approval; decline triggers rollback. Stage only journaled
   implementation paths, ticket, and worklist. Require no unstaged or
   unexpected change and no staged journal, definition edit, or unchecked
   criterion.
7. Create one normal commit whose sole parent is the journaled baseline.
   Verify exactly one commit was added, its tree/message match approval, both
   final images are present, and the tree/index are clean. Only then remove the
   journal and release the lock (or continue under it to the next ticket).

The committed ticket moves visibly from `r` to `r+2` because the transaction
contains two valid compare-before-write lifecycle mutations. Restoring `r`
during rollback discards an unpublished transaction; it is not a reverse
lifecycle transition.

## Commit Contract

The single commit follows Conventional Commits 1.0.0:

```text
<ticket.type>[(<commit_scope>)]: <imperative description>

Acceptance:
- <criterion>: <evidence summary>

Verification:
- `<command or action>`: <result>

Ticket-Id: <id>
Ticket-Set: <ticket_set>
Ticket-Fingerprint: <fingerprint>
Ticket-File: <workspace-relative path>
Ticket-Revision: <r> -> <r+2>
```

Wrap body text at 72 characters and retain all identity trailers. Run Git hooks
normally. If `git commit` reports failure but `HEAD` moved, inspect it: accept
success only when the sole new commit exactly matches the journaled
transaction; otherwise stop for recovery without resetting or committing
again.

## Failure, Recovery, and Idempotency

Before `HEAD` advances, any implementation error, failed evidence/CAS/hook,
approval decline, or definite commit failure invokes rollback. Roll back only
when `HEAD` equals the baseline and all states match journaled hashes or
transaction-owned deltas. Restore explicit tracked paths and index entries from
the baseline and delete only individually recorded new paths. Restore ticket
and worklist byte-for-byte, then validate either an exact native set or the same
authorized checkbox-only compatibility state captured at preflight. Confirm a
clean Git tree before removing journal and lock. Never overwrite an unknown
hash or unregistered path; preserve state and report `recovery-required`.

After proven rollback, `abort` stops and `continue` revalidates before the next
independent ticket. A failed ticket remains `open@r`, produces no commit, and
cannot satisfy a dependent.

On startup, handle a valid interrupted journal according to `{recovery}`:

- `abort` reports phase, owner, baseline, and safe choices without mutation.
- `rollback` acquires the lock and performs the guarded exact restoration.
- `resume` requires the same baseline, owner, known phase, registered paths,
  and recognized preimage/claim/final states. Repair only a journaled torn
  ticket/worklist pair, revalidate dependencies, and rerun all verification.
  Never claim twice or increment the claim revision twice.

If `HEAD` is exactly one child of the baseline, contains the journaled final
tree and identity trailers, and has no unknown index/worktree residue, clean up
and report recovered success without another commit. An exact commit with
unexpected hook residue remains successful, but execution stops and preserves
the journal until the residue is resolved. Explicit recovery may reclaim only
the stale lock named by that validated journal. Unknown journals, dirty
unjournaled claims, and committed `in_progress` tickets are never adopted.

Ordinary reruns select current ticket frontmatter. `done` is reported
`already-done` with no verifier, write, stage, or commit.

## Workflow

1. Validate parameters; resolve the local target, compatibility state, and
   canonical managed set.
2. Detect and validate recovery before applying ordinary dirty-tree safety.
3. Snapshot and validate the complete native set, projection, dependency
   graph, and Git state.
4. Resolve selection, stable order, deferrals, path/evidence plans, and commit
   messages.
5. Render the plan. Stop for `{dry_run}` or declined plan approval.
6. Lock, revalidate, and process scheduled tickets sequentially through
   journal, claim, minimal implementation, evidence, completion, approval, and
   one commit.
7. Roll back failures before applying `{on_failure}`; recalculate dependency
   readiness before continuing.
8. Revalidate final set, projection, commit chain, and cleanliness; report
   without remote side effects.

## Output Format

Return these sections in order, omitting only empty optional sections:

### Run Summary

Target and canonical worklist; ticket-set identity; selector/order; mode;
owner; baseline/final `HEAD`; outcome (`completed`, `partial`, `no-runnable`,
`already-done`, `dry-run`, `declined`, `failed`, or `recovery-required`); and
counts for selected, scheduled, committed, already-done, deferred, failed, and
declined.

### Validation

Schema versions; ticket/file count; set identity (`consistent`, not
`recomputed`); fingerprint, projection, dependency, and Git-safety results;
and every compatibility or recovery discrepancy.

### Plan

One row per selected ticket: canonical/execution order, ID, status/revision,
dependencies, runnability, scope paths, verification summary, proposed commit
subject, and disposition. For dry run, stop here and state that no side effect
occurred.

### Ticket Results

One row per selected ticket: ID, outcome, starting/final lifecycle revisions,
commit SHA or `none`, final status, and one-line note.

### Runtime Evidence

For every committed ticket, map each criterion to the exact command/manual
action, exit/result, relevant output tail or artifact path, and conclusion.
Redact secrets from captured output.

### Failures and Recovery

For every non-committed scheduled ticket, report phase, root cause, rollback
result, retained journal path when applicable, and deferred dependents.

### Handoff

List local commits in order, remaining open/deferred IDs, and final worktree
status. State that no tracker, branch/worktree creation or switch, swarm,
merge, push, pull request, tag, or remote write occurred.
