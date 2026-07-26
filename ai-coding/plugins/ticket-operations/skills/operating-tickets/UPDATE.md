# Update Tickets Contract

Loaded by the `operating-tickets` `update` motion only for an existing local set
whose tickets declare
`ticket-operations/ticket` schema version `1` and whose managed `WORKLIST.md`
declares `ticket-operations/worklist` schema version `1`.

Route new-set requests to the create motion and implementation/verification to
the execute motion. Do not use update for tracker records, unchecked prose
tasks, implementation edits, acceptance execution, or a request that merely
asks what to change.

## Task

Resolve one native set, validate it from a single snapshot, apply an explicit
patch with compare-and-swap protection, and regenerate `WORKLIST.md` from the
prospective authoritative tickets. A multi-ticket update is one journaled
transaction: publish every planned image or restore every preimage.

Ticket frontmatter and acceptance markers hold lifecycle state.
`WORKLIST.md` is a projection and selection surface. Its marker, status,
revision, or fingerprint never overrides a ticket.

`ticket_set` is the immutable lineage identifier assigned at creation. Treat it
as opaque after creation. Definition edits recompute each affected ticket's
`fingerprint`, but never recompute or replace `ticket_set`,
`source_fingerprint`, source records, template identity, or creation
accounting. After the first definition edit, `ticket_set` remains lineage
rather than a digest of current definitions; validate agreement, not a
creation preimage that the set does not retain.

## Parameters

- `{target}`: required path inside the current Git worktree. Accept a native
  ticket, its managed `WORKLIST.md`, or a directory containing exactly that
  file. Reject URLs, tracker identifiers, chat references, inline tickets, and
  recursive directory guessing.
- `{patch}`: a strict YAML or JSON mapping supplied inline or by a read-only
  file inside the worktree. Optional only for projection-only reconciliation,
  legacy inspection, or recovery. See `## Patch Contract`.
- `{projection}`: `require` | `repair`; optional, default `require`.
  `require` rejects worklist drift except a checked-marker proposal explicitly
  inspected or imported through `{legacy}`. `repair` permits only the
  reconstructible projection drift defined below.
- `{legacy}`: `reject` | `inspect` | `discard` | `import`; optional, default
  `reject`.
  `inspect` reports eligible proposals without mutation. `import` converts only
  entries named by `{legacy_accept}` into native lifecycle transactions.
- `{legacy_worklist}`: optional path to one unmanaged read-only Markdown
  worklist for `legacy=inspect|import`. When omitted, those modes inspect
  checked-marker drift in the managed `WORKLIST.md` itself.
- `{legacy_accept}`: strict YAML or JSON list required for `legacy=import`.
  Each record supplies exact `id`, `expected_revision`,
  `expected_fingerprint`, `expected_owner`, and one exact evidence record per
  acceptance criterion.
- `{mode}`: `interactive` | `non-interactive`; optional, default
  `interactive`. Interactive mutation presents one complete plan and requires
  approval. Non-interactive mutation requires `{approve}`.
- `{approve}`: exact `sha256:<64-hex>` plan digest from a prior dry run;
  required only for non-interactive mutation.
- `{operation_id}`: optional identifier matching
  `^[A-Za-z0-9._-]{1,64}$`; otherwise derive the full request hash.
- `{commit}`: `none` | `audit`; optional, default `none`. `audit` creates one
  local Conventional Commit for the whole transaction under the contract
  below. It never pushes.
- `{recovery}`: `abort` | `resume` | `rollback`; optional, default `abort`.
  This applies only to a valid interrupted `ticket-update` journal for this set.
- `{dry_run}`: optional boolean, default `false`. Resolve, validate, render,
  and report the complete prospective transaction, but acquire no lock, write
  no journal or file, request no approval, stage nothing, and create no commit.

Unknown parameters, duplicate keys, invalid values, or conflicting modes abort
before side effects.

## Success Criteria

- [ ] Validate the complete schema, lineage, file manifest, current ticket
      fingerprints, lifecycle invariants, dependency graph, persistence mode,
      and current or repairable projection before the first side effect.
- [ ] Select tickets only by exact ID and process them in canonical manifest
      rank, independent of patch order or directory enumeration.
- [ ] Require the patch's `ticket_set` and every selected ticket's expected
      revision, fingerprint, and status to match before writing.
- [ ] Increment each effectively patched ticket exactly once. Recompute its
      fingerprint exactly when its definition changes. Projection-only repair
      increments no ticket.
- [ ] Enforce the transition graph, owner/reason invariants, acceptance
      evidence gates, marker-reset rules, and special handling for
      `in_progress`, `done`, and `cancelled`.
- [ ] Reject missing, duplicate, self, cross-set, or cyclic dependencies in the
      complete prospective graph.
- [ ] Validate every prospective ticket and the regenerated worklist in memory,
      then publish through one locked, crash-recoverable transaction.
- [ ] Preserve tracked versus local persistence. An optional audit commit
      contains or cryptographically binds every final lifecycle artifact.
- [ ] A replay with the same operation identity and final hashes reports
      `already-applied`; an effective no-op writes nothing and changes no
      revision.

## Guardrails

- MUST read and apply [CREATE.md](./CREATE.md)'s live version-1 schema,
  fingerprint, body, lifecycle, and worklist contracts. Fail closed on unknown
  versions.
- MUST NOT change `schema`, `schema_version`, `ticket_set`, `id`, `source`, or
  `source_fingerprint`; rename ticket files; reorder manifest rank; or rewrite
  Item Accounting.
- MUST NOT infer completion from code, commits, a checked worklist marker, old
  output, or user intent. A `done` transition needs the explicit evidence
  references defined below.
- MUST NOT run acceptance commands, inspect implementation to declare a
  criterion met, implement ticket scope, or edit repository content outside
  the managed set. Lock, journal, receipt, and optional commit metadata are the
  only non-set writes.
- MUST NOT overwrite unknown concurrent state, steal a live or uncertain lock,
  adopt an unjournaled claim, or recover an execute-motion transaction.
- MUST preserve unknown `extensions` keys. Update them only through an explicit
  RFC 7396 merge patch; `null` deletes the named key.
- MUST apply only explicit replacements. Never paraphrase body text or infer
  scope, acceptance text, metadata, dependencies, or lifecycle evidence.
- MUST stage only transaction-owned paths. Never use broad add, clean, reset,
  checkout, amend, rebase, or history-rewriting commands.
- MUST NOT call a tracker or external write API; create or switch a branch or
  worktree; merge; push; open a pull request; create a tag; or spawn an agent.

## Native Set Preflight

Reject symlinks in every path component. The target, worklist, tickets, patch
file, and legacy file must be readable regular files inside the current
worktree and outside `.git`; managed files must also be writable unless the run
is read-only.

Parse YAML strictly, rejecting duplicate keys, aliases, custom tags, and type
coercions that violate the schema. From one captured snapshot:

1. Require the declared ticket and worklist schemas and versions. Require full
   lowercase `sha256:<64-hex>` lineage, source, and ticket fingerprints.
2. Require one `ticket_set` across all artifacts. Report it as
   `consistent (opaque lineage)`, never `recomputed`. Require every ticket's
   `source.fingerprint` to equal the worklist `source_fingerprint`.
3. Require the ordered manifest's IDs and safe relative file paths to map
   one-to-one to regular native ticket files. Reject duplicate IDs or paths and
   any sibling native ticket claiming the set but absent from the manifest.
4. Validate required frontmatter order and types, required body sections,
   title heading, acceptance syntax, revision positivity, owner/reason rules,
   and the rule that every `done` ticket has all criteria checked.
5. Recompute every current ticket fingerprint from its immutable and
   definition-owned fields and body with acceptance markers normalized to
   unchecked. Require equality with ticket frontmatter; compare the manifest
   copy as projection in step 7.
6. Validate dependencies against the complete set and reject self-edges and
   cycles. Only authoritative `done` satisfies a dependency. Every current
   `in_progress` or `done` ticket MUST have all direct dependencies done;
   update does not use satisfaction to infer status.
7. Reconstruct every worklist-derived field from the tickets and compare the
   manifest and body, including group, marker, ID, title, `Where`, `Why`,
   `Done-when`, path, fingerprint, status, and revision. Structurally validate
   and preserve Item Accounting as creation history.

Before treating step 7 as fatal, classify legacy proposals. Under
`legacy=inspect|discard|import`, permit only an exact `[ ] -> [x]` body-marker
difference for an entry whose manifest record and every subfield still match
the authoritative open ticket. Parse that difference as a proposal before
ordinary projection enforcement. Any additional drift follows `{projection}`
and cannot be hidden by legacy mode.

With `{projection}=repair`, steps 1 through 6 still pass without exception.
The worklist must retain a valid schema header, lineage and source fingerprint,
an ordered unique ID/file backbone that maps one-to-one to the complete native
set, and valid complete Item Accounting. The skill may repair `ticket_count`,
manifest fingerprint/status/revision values, and projected body content. It
must abort when rank, file identity, lineage, accounting, or set completeness
would need guessing.

Classify persistence before Git safety checks:

- `tracked`: the worklist and every ticket are tracked and byte-identical to
  `HEAD` and the index at preflight.
- `local`: none of those files is tracked; capture every exact byte and mode.

Mixed persistence aborts. Every mutating run requires a stable `HEAD` and no
merge, rebase, cherry-pick, revert, or bisect in progress. `{commit}=none` may
coexist with unrelated unstaged paths but never modifies or stages them.
`{commit}=audit` additionally requires a named branch, configured identity,
empty index, and no unrelated worktree or submodule changes.

## Patch Contract

The patch root has `schema: ticket-operations/update`, `schema_version: 1`, the
exact `ticket_set`, `expected_worklist_sha256`, and a `tickets` list. Derive an
absent operation ID from canonical JSON of the normalized patch, lineage,
worklist hash, and all expected revisions and fingerprints, using sorted object
keys, ticket entries normalized to manifest rank, specified order for semantic
arrays, UTF-8, and no insignificant whitespace. With no patch, derive it from
the normalized reconciliation or legacy-import request and its expected hashes.

Each ticket entry requires `id`, `expected_revision`, `expected_fingerprint`,
`expected_status`, and a nonempty `rationale`; it also requires
`expected_owner` (`null` except when the expected status is `in_progress`).
The caller cannot set `fingerprint` directly. Duplicate IDs abort. Each entry
contains at least one operation; omitted operations preserve their current
value:

| Operation | Semantics |
|---|---|
| `definition` | Partially replace only `title`, `type`, `severity`, `estimate`, or `labels`. Derive `priority` from severity; direct priority replacement aborts. Labels become sorted unique lowercase ASCII slugs. |
| `body` | Replace complete bodies for exact keys `summary`, `context_and_evidence`, `in_scope`, `out_of_scope`, or `open_questions`. Normalize UTF-8 text to NFC and LF with one final newline. |
| `dependencies` | Supply complete `expected` and `replacement` ID arrays. Require exact IDs, reject duplicates, and render in canonical manifest rank. |
| `acceptance_criteria` | Supply complete `expected` and `replacement` text arrays. Markers are not part of these strings. |
| `acceptance_markers` | Supply equal-length complete `expected` and `replacement` boolean vectors, an `evidence` record list, and an equal-length `uncheck_reasons` list of string or null. Evidence is required for every `false -> true` index and every index when transitioning to `done`; a nonempty reason is required exactly for `true -> false`. |
| `transition` | Supply `to` and the final-state fields required below. Optional audit-only controls are `transition_note`, `reopen`, and `abandon_claim`. |
| `extensions` | Apply an RFC 7396 merge patch. Absent keys survive and explicit `null` deletes. Extensions do not enter the fingerprint. |

Reject unknown operations, line-number patches, regular expressions, fuzzy
title matching, partial list edits, and overlapping representations of the
same field. Update the rendered H1 when `title` changes. Missing operations
never mean deletion.

Evidence records use this exact common schema; criterion indexes are
one-based:

```yaml
- criterion_index: 1
  criterion_text: "<exact current criterion text>"
  ticket_fingerprint: "sha256:<current ticket fingerprint>"
  observed_tree: "<full lowercase Git tree object id>"
  kind: "commit"
  ref: "<kind-specific reference>"
  result: "<nonempty observed result>"
```

`observed_tree` MUST equal the full output of `git rev-parse HEAD^{tree}` and
match the repository's object-ID length. For `kind: commit`, `ref` is a full
commit SHA reachable from `HEAD` and no extra key is allowed. For
`kind: artifact`, `ref` is a safe in-worktree file path and the record adds
exactly `expected_sha256: "sha256:<64-hex>"`, which MUST match current bytes.
For `kind: attestation`, `ref` is a durable reference and the record adds
exactly `actor: "<nonempty identity>"`. Reject unknown keys, duplicate
criterion indexes, zero-based/out-of-range indexes, text/fingerprint/tree
mismatches, unavailable refs, and evidence for an index that neither becomes
checked nor supports a `done` transition.

Any change to a definition-owned frontmatter field, dependency, criterion
text, or body byte recomputes that ticket's fingerprint using CREATE.md's
algorithm. Lifecycle and extension changes preserve the
fingerprint. One entry with any effective combination of allowed changes is
one native mutation and moves `revision: r` to `r+1`. An identical replacement
is not effective.

Definition edits invalidate evidence bound to the prior fingerprint, so they
reset every acceptance marker to unchecked. Do not combine
`acceptance_criteria` or any other definition edit with marker checks in the
same entry. Regenerate the affected manifest record and all derived worklist
content. Keep `ticket_set`, `source_fingerprint`, canonical rank, filenames,
and Item Accounting unchanged.

## Lifecycle and Acceptance Rules

Allowed status edges are:

- `open -> in_progress|blocked|cancelled`
- `in_progress -> open|blocked|done|cancelled`
- `blocked -> open|in_progress|cancelled`
- `done|cancelled -> open` only with `reopen: true`

Final state invariants are:

| Status | Owner | Status reason | Acceptance |
|---|---|---|---|
| `open` | `null` | `null` | any valid marker vector |
| `in_progress` | required nonempty string | `null` | any valid marker vector |
| `blocked` | `null` | required nonempty string | any valid marker vector |
| `done` | `null` | `null` | every marker checked |
| `cancelled` | `null` | required nonempty string | any valid marker vector |

Every transition names its destination explicitly. A transition to
`in_progress` supplies `owner`; a transition to `blocked` or `cancelled`
supplies `status_reason`. Other destinations force both fields to their table
values. Reopen, abandonment, owner reassignment, and same-status reason
replacement require a nonempty `transition_note`; this note goes to the
journal, report, and audit commit, not `status_reason`.

Every current and prospective `in_progress` or `done` ticket requires all
direct dependencies to be authoritatively `done`. Entering either status
requires dependencies to be done in both the baseline and final snapshots; a
different ticket entry in the same update cannot satisfy that gate.

For an `in_progress` ticket, require top-level `expected_owner` to match.
Marker-only updates, lifecycle transitions, or explicit owner reassignment may
proceed when no live execute-motion journal exists. Any definition, body,
dependency, acceptance text, or extension edit must also set
`abandon_claim: true` and transition to `open`; it resets markers.

Any fingerprint-changing edit to `done` or `cancelled` must set `reopen: true`
and transition to `open` in the same entry. Extension-only changes may retain a
terminal status. Every transition to `open` resets all markers.
A same-status operation may only reassign an `in_progress` owner or replace a
`blocked` or `cancelled` reason. Other same-status requests are no-ops or
invalid field combinations. Any automatic reset from a definition edit,
abandonment, or reopen conflicts with `acceptance_markers` in the same entry.

Checking a criterion is an explicit lifecycle assertion. Each evidence record
contains the exact criterion index and text, current ticket fingerprint, full
observed Git tree, `kind: commit|artifact|attestation`, nonempty `ref`, and
nonempty `result`. A commit ref is a full reachable SHA; an artifact is a safe
local path plus expected SHA-256; an attestation names an actor and durable
reference. The skill validates identity, shape, and local availability, then
labels the record `caller-supplied; not executed`.

Transitioning to `done` requires evidence for every criterion, including
markers already checked, and an `acceptance_markers` operation whose final
vector is all checked. The skill never obtains, executes, or endorses this
evidence. Unchecking requires an indexed reason but no completion evidence.

## Legacy Completion Proposals

Neither a managed marker mismatch nor an unmanaged legacy worklist supplies
lifecycle authority. The proposal source is the managed `WORKLIST.md` when
`{legacy_worklist}` is omitted, otherwise the supplied unmanaged read-only
file. For `inspect|import`, parse only exact `- [x] <id>: <title>` entries with
one indented `Ticket:` path. Each path must resolve without symlinks to a ticket
in the validated managed worklist; all links must resolve to this one set.
Require exact native ID and current title. If `Fingerprint`, `Revision`, or
`Status` subfields exist, require exact current values.

Treat `[ ]` as no proposal. Never use it to reopen a ticket. Reject malformed
or duplicate entries and status-like `[>]`, `[!]`, or `[-]` markers rather
than interpreting them.

`legacy=inspect` reports only. `legacy=discard` is patchless projection repair:
restore each managed marker from authoritative ticket state. `legacy=import`
requires interactive, digest-bound approval and an exact `{legacy_accept}`
record for each ID. It also requires a reachable legacy commit whose diff
contains the marker flip and a non-projection change, with matching
`Worklist-Item-Id` and `Worklist-Source` trailers. Supply the complete evidence
record for every criterion.

A checked entry whose ticket is `done` is `already-reflected`. For
`in_progress`, import one evidence-backed edge to `done` and increment revision
once. For `open`, journal two legal edges through a derived temporary owner and
finish at `done`, incrementing revision twice. Reject `blocked` and `cancelled`
proposals. A checked box never bypasses the transition graph or evidence gate.

Reject an imported ID that also appears in `{patch}`. `inspect` forbids patch,
repair, legacy acceptance, and audit commit but may inspect the narrowly
classified managed-marker drift above. `discard` requires
`projection=repair` and forbids patch and commit. Never modify an unmanaged
legacy file.

## Projection and Transaction

Render all prospective tickets and the complete worklist in memory. Preserve
unaffected ticket bytes. The worklist keeps its lineage, source fingerprint,
rank, filenames, and Item Accounting, while its manifest and body project the
prospective authoritative tickets. Validate the entire prospective set,
fingerprints, graph, and exact projection before approval. Hash canonical JSON
of the request, baseline hashes, and prospective hashes as the plan digest.
Interactive mode approves that exact digest; non-interactive mutation requires
the same value in `{approve}`.

Before ordinary projection validation, detect unresolved execute- and
update-motion journals and direct recovery to their owning motion. After
approval, derive a set key from canonical JSON containing the real
worktree path, set-root path, and `ticket_set`. Acquire the same OS-released
per-set mutation lock used by ticket execution at
`$(git rev-parse --git-path ticket-execute)/<set-key>/lock`. Never steal a live
or uncertain lock. Re-read every managed byte and repeat schema, graph, CAS,
`HEAD`, index, and plan-digest checks under the lock.

Before writing, atomically create and fsync a write-ahead journal under
`$(git rev-parse --git-path ticket-update)/<set-key>/<operation-id>.journal.json`.
Record request hash, approval digest, evidence, baseline `HEAD` and index,
persistence and modes, all expected revisions, exact preimages and prospective
images with hashes, write order, and commit plan. Advance phases through
`prepared`, each file replacement, `files-written`, `staged`, `committing`,
and `completed` via sibling temporary file, fsync, and atomic rename.

For each effective ticket in canonical rank, compare its exact current bytes to
the journaled preimage immediately before an atomic file replacement. Replace
the worklist last. On a detected mismatch or ordinary failure before commit,
restore every replaced path in reverse order only when its hash is a known
transaction image. Revalidate exact preimages. Unknown state stops as
`recovery-required`; never overwrite it. A crash may expose an incomplete
sequence, but the skill never reports success or starts another update until
the journal is resumed or rolled back.

Projection-only repair replaces only `WORKLIST.md`; it changes no ticket
fingerprint or revision. A combined ticket update and repair produces one
regenerated worklist and one transaction.

## Audit Commit

With `{commit}=none`, leave tracked results unstaged and local results local.
Create no Git object.

With `{commit}=audit`, create exactly one commit after all files validate:

- For `tracked`, stage only changed managed tickets and `WORKLIST.md`.
- For `local`, prove no managed path is staged and use `--allow-empty`; the
  commit binds the exact local bytes by hash.

Use `chore(tickets): update <id>` for one ticket,
`chore(tickets): update <n> tickets` for several, or
`chore(tickets): reconcile worklist` for projection-only repair. Include
transition notes and caller-supplied evidence references, then trailers for
`Ticket-Update-Id`, `Ticket-Set`, and `Ticket-Persistence`; repeat
`Ticket-Revision: <id> <r>..<r+1>` and
`Ticket-State-SHA256: <id> sha256:<hash>` for every ticket in canonical rank;
finish with `Worklist-State-SHA256: sha256:<hash>`.

Run hooks normally. Require the commit to be the sole child of the journaled
baseline, to match the approved tree and message, and to leave no unexpected
index or worktree residue. If commit fails while `HEAD` remains at baseline,
restore files and index from exact preimages. If `HEAD` moved, accept only the
exact planned child; otherwise retain the journal and report
`recovery-required`. Never amend or create a follow-up commit.

## Recovery and Idempotency

Check for a journal before ordinary projection and dirty-tree validation:

- `abort` reports its operation ID, phase, baseline, known hashes, and safe
  choices without mutation.
- `rollback` acquires the lock, requires baseline `HEAD`, and restores exact
  preimages only from recognized transaction states. It refuses to rewrite an
  expected commit.
- `resume` acquires the lock and continues without another revision increment,
  approval, or commit. Require the recorded patch, approval, write images,
  current hashes, and `HEAD` to match a known phase. If the exact planned commit
  already exists, validate it and finalize.

After final validation, convert the journal to an immutable completion receipt
containing patch, preimage, final-state, and optional commit hashes. A rerun
with the same operation ID and canonical patch hash returns `already-applied`
only when every current hash and optional commit still match the receipt.
Reusing an operation ID with different input aborts. A matching receipt whose
current state later diverged reports `previously-applied; current state
differs` and fails normal CAS. Without a matching receipt, stale expected
revisions abort rather than guessing that another update was this operation.

If all requested values and the projection already match at the expected
revision, report `unchanged`; write no journal or file and create no commit.

## Workflow

1. Validate parameters and resolve the target without following symlinks.
2. Detect and validate any recovery journal.
3. Snapshot and preflight schemas, lineage, tickets, dependencies, persistence,
   Git state, and the exact class of every projection difference.
4. Parse optional legacy proposals before enforcing projection policy; then
   parse the patch and resolve exact selected IDs in canonical rank.
5. Apply deterministic patch and lifecycle rules in memory. Recompute affected
   fingerprints, increment effective ticket revisions once, and reject cycles.
6. Regenerate the manifest and worklist projection while preserving lineage
   and creation accounting. Validate the complete prospective set.
7. Render the plan and full managed-file diff. Stop for dry run or declined
   approval.
8. Lock, revalidate exact bytes and CAS fields, create the journal, and replace
   every planned file as one recoverable transaction.
9. Create the optional audit commit, validate final files, projection, Git
   state, and hashes, then finalize the receipt.
10. Report administrative changes without implying implementation or verified
    acceptance.

## Output Format

Return these sections in order, omitting empty optional sections:

### Run Summary

Target and canonical worklist; opaque ticket-set identity; operation ID;
projection, legacy, interaction, persistence, commit, and recovery modes;
approval digest; outcome
(`updated`, `reconciled`, `updated-and-reconciled`, `unchanged`,
`already-applied`, `inspected`, `dry-run`, `declined`, or
`recovery-required`); and selected/changed/repaired counts.

### Validation

Schema versions; ticket/file count; lineage consistency; current and
prospective fingerprint results; projection result or exact repair class;
dependency and cycle results; lifecycle invariants; persistence and Git safety.

### Plan

One row per selected ticket: rank, ID, expected and prospective
status/revision/fingerprint, edit classes, transition, acceptance reset or
evidence disposition, and final dependencies. Include a projection-only row
when applicable.

### Legacy Proposals

One row per checked legacy entry: native link, current state, eligibility,
explicit acceptance, and disposition. Label every evidence reference
`caller-supplied; not executed`.

### Lifecycle Evidence

For each marker check or completion transition, list criterion, fingerprint,
observed tree, evidence kind/ref/result, validation disposition, and the
`caller-supplied; not executed` label.

### Transaction

Approval result; lock and journal/receipt location; changed managed paths and
before/after hashes; rollback or recovery state; final full-set validation.

### Commit

Commit SHA and subject, staged managed paths or local state hashes, and
revision ranges; or `none`.

### Recovery

When applicable, report phase, recognized hashes, action, result, retained
journal/receipt, and safe next operation.

### Handoff

List final status/revision/fingerprint for each changed ticket and whether the
tracked set is unstaged or committed. State that the skill performed no ticket
implementation or acceptance execution and made no tracker, branch, worktree,
merge, push, pull-request, tag, or other remote change.
