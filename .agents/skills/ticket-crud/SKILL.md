---
name: ticket-crud
description: "Create a new local Markdown ticket set and WORKLIST.md from an analysis, review, plan, or checklist, and update lifecycle state, definitions, or the worklist projection of an existing set. Use when the user asks to create tickets, ticketize findings, break work into ticket files, persist a local backlog, or to change ticket status, owner, reason, metadata, body, acceptance criteria, or dependencies, or to reconcile a worklist. Do not use to implement or verify ticket work, or to operate an external tracker."
license: MIT
---

# Ticket CRUD

## Activation

Use this skill for the create and update halves of the local ticket lifecycle.
It supersedes `ticket-create`, `ticket-update`, and `ticket-breakdown`.

| Letter | Operation | Mechanism |
|---|---|---|
| C | create | `{operation}=create` renders one new managed set from one source |
| R | read | `{dry_run}=true` on either operation, or `{legacy}=inspect`, reports without writing |
| U | update | `{operation}=update` applies an explicit patch to an existing set |
| D | delete | a `cancelled` transition on a native set, or `backlog task archive` on a Backlog.md set; neither destroys a ticket file |

Implementation, acceptance verification, and per-ticket commits belong to
`ticket-execute`. Do not use this skill to produce the source analysis, operate
GitHub/Jira/Linear, implement ticket scope, execute acceptance, or answer a
request that merely asks what to change.

The update operation additionally requires an existing local set whose tickets
declare `ticket-operations/ticket` schema version `1` and whose managed
`WORKLIST.md` declares `ticket-operations/worklist` schema version `1`. Do not
activate it for tracker records or unchecked prose tasks.

A Backlog.md-managed set (a directory governed by a Backlog.md `config.yml`)
is not a native set. Do not render native ticket files or a `WORKLIST.md` into
it. Apply this skill's derivation, transition, and evidence rules to such
tickets, but perform every change through the `backlog` CLI (`backlog task
create`, `backlog task edit`) per that directory's `AGENTS.md`, and never
hand-edit its task files.

## Task

**Create.** Capture one `{source}` snapshot, extract and normalize every work
item, render one versioned Markdown ticket per resulting item through
[./TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md), and generate a compatible
`WORKLIST.md` projection. Render and validate the complete set in memory before
publishing it atomically.

The same canonical source, template bytes, and semantic parameters MUST produce
the same ticket definitions, ids, filenames, ordering, and set identity. Do not
use timestamps, randomness, ambient git state, directory enumeration order, or
free-form paraphrasing in generated artifacts.

**Update.** Resolve one native set, validate it from a single snapshot, apply
an explicit patch with compare-and-swap protection, and regenerate
`WORKLIST.md` from the prospective authoritative tickets. A multi-ticket update
is one journaled transaction: publish every planned image or restore every
preimage.

Ticket frontmatter and acceptance markers hold lifecycle state. `WORKLIST.md`
is a projection and selection surface. Its marker, status, revision, or
fingerprint never overrides a ticket.

## Parameters

- `{operation}` — `create` | `update`. Optional when exactly one of `{source}`
  or `{target}` is supplied; that parameter then selects the operation.
  Supplying both, neither, or a parameter belonging to the other operation
  aborts.
- `{dry_run}` — optional boolean, default `false`. Create: complete
  resolution, rendering, validation, accounting, and collision checks, then
  write nothing. Update: resolve, validate, render, and report the complete
  prospective transaction, but acquire no lock, write no journal or file,
  request no approval, stage nothing, and create no commit.

### Create

- `{source}` — required work-item source. `{analysis}` is a compatibility
  alias; supplying both aborts. Accepts one UTF-8 Markdown file, a directory of
  `*.md` files, a reference to prior chat content, or inline items separated by
  newlines or semicolons.
- `{ticket_template}` — optional path, default: this skill's
  [./TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md). Read it on every invocation.
- `{granularity}` — `one-to-one` | `split-composites` | `theme-grouped`;
  optional, default `split-composites`.
- `{min_severity}` — `critical` | `major` | `minor` | `nit`; optional, default
  includes all. `unclassified` items always remain.
- `{id_prefix}` — optional, default `TKT`; MUST match
  `^[A-Z][A-Z0-9]{1,9}$`. IDs are `<prefix>-NNN`, expanding beyond three
  digits without truncation.
- `{output_dir}` — optional destination, default
  `.ai-coding-artifacts/tickets/<source-slug>/`, resolved from the workspace
  root. It MUST NOT equal or sit inside a source directory, be a symlink, or
  resolve to the workspace root or `.git`.
- `{on_existing}` — `reuse` | `error` | `new-set`; optional, default `reuse`.
  See `## Existing Sets and Publication`.
- `-i` / `--interactive` — optional. Show the validated plan once and require
  approval before publication.

Compatibility parameters are intentionally narrow:

- `{persistence}=files` and `{emit_worklist}=true` are accepted as no-ops.
- `{persistence}=chat`, `{emit_worklist}=false`, and unknown parameters abort.

### Update

- `{target}` — required path inside the current Git worktree. Accept a native
  ticket, its managed `WORKLIST.md`, or a directory containing exactly that
  file. Reject URLs, tracker identifiers, chat references, inline tickets, and
  recursive directory guessing.
- `{patch}` — a strict YAML or JSON mapping supplied inline or by a read-only
  file inside the worktree. Optional only for projection-only reconciliation,
  legacy inspection, or recovery. See `## Patch Contract`.
- `{projection}` — `require` | `repair`; optional, default `require`.
  `require` rejects worklist drift except a checked-marker proposal explicitly
  inspected or imported through `{legacy}`. `repair` permits only the
  reconstructible projection drift defined below.
- `{legacy}` — `reject` | `inspect` | `discard` | `import`; optional, default
  `reject`. `inspect` reports eligible proposals without mutation. `import`
  converts only entries named by `{legacy_accept}` into native lifecycle
  transactions.
- `{legacy_worklist}` — optional path to one unmanaged read-only Markdown
  worklist for `legacy=inspect|import`. When omitted, those modes inspect
  checked-marker drift in the managed `WORKLIST.md` itself.
- `{legacy_accept}` — strict YAML or JSON list required for `legacy=import`.
  Each record supplies exact `id`, `expected_revision`,
  `expected_fingerprint`, `expected_owner`, and one exact evidence record per
  acceptance criterion.
- `{mode}` — `interactive` | `non-interactive`; optional, default
  `interactive`. Interactive mutation presents one complete plan and requires
  approval. Non-interactive mutation requires `{approve}`.
- `{approve}` — exact `sha256:<64-hex>` plan digest from a prior dry run;
  required only for non-interactive mutation.
- `{operation_id}` — optional identifier matching
  `^[A-Za-z0-9._-]{1,64}$`; otherwise derive the full request hash.
- `{commit}` — `none` | `audit`; optional, default `none`. `audit` creates one
  local Conventional Commit for the whole transaction under the contract
  below. It never pushes.
- `{recovery}` — `abort` | `resume` | `rollback`; optional, default `abort`.
  This applies only to a valid interrupted update journal for this set.

Unknown parameters, duplicate keys, invalid values, or conflicting modes abort
before side effects.

## Success Criteria

### Create

- [ ] Validate parameters, source, template, schemas, accounting, dependencies,
      destination, and the complete write set before the first filesystem
      mutation.
- [ ] Account for every extracted source item exactly once as
      `ticketed(<id>)`, `split-into(<ids>)`, `merged-into(<ids>)`,
      `filtered(<reason>)`, or `already-done`.
- [ ] Every ticket starts with the canonical ticket schema, `status: open`,
      `owner: null`, `status_reason: null`, and `revision: 1`.
- [ ] Every ticket cites at least one source ref and contains no invented fact.
- [ ] `WORKLIST.md` validates as the projection of every rendered ticket and
      keeps the legacy `Where`, `Why`, `Done-when`, and `Ticket` fields.
- [ ] Identical definitions yield byte-identical new artifacts. A matching
      existing managed set preserves explicit lifecycle and definition updates
      rather than resetting them.
- [ ] Zero extracted items reports `_No work items found._` and writes nothing.

### Update

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

### Both operations

- [ ] Perform no implementation, tracker, branch, worktree, merge, push, or
      pull-request operation. Create additionally stages and commits nothing.

## Guardrails

### Both operations

- MUST NOT call a tracker, tracker MCP tool, or external write API; create or
  switch a branch or worktree; merge; push; open a pull request; create a tag;
  or spawn an agent.
- MUST apply this skill's version-1 schema, identity, body, lifecycle, and
  worklist contracts. Fail closed on unknown schema names or versions.
- MUST NOT implement or verify a ticket, run acceptance commands, or inspect
  implementation to declare a criterion met.
- MUST NOT infer completion from code, commits, a checked worklist marker, old
  output, or user intent.
- MUST NOT invent evidence, scope, dependencies, test commands, or completion.

### Create

- MUST keep `{source}` and `{ticket_template}` read-only.
- MUST use the fixed fallbacks below for absent values and report them under
  Open Questions.
- MUST NOT mutate an existing ticket set, including to repair its worklist.
  Repair belongs to the update operation.
- MUST NOT overwrite, append to, delete, or numerically suffix existing paths.
- MUST publish all artifacts or none; temporary paths are invocation-owned.
- Scope: one source snapshot to one new local ticket set.

### Update

- MUST NOT change `schema`, `schema_version`, `ticket_set`, `id`, `source`, or
  `source_fingerprint`; rename ticket files; reorder manifest rank; or rewrite
  Item Accounting.
- MUST NOT edit repository content outside the managed set. Lock, journal,
  receipt, and optional commit metadata are the only non-set writes.
- MUST NOT overwrite unknown concurrent state, steal a live or uncertain lock,
  adopt an unjournaled claim, or recover a `ticket-execute` transaction.
- MUST preserve unknown `extensions` keys. Update them only through an explicit
  RFC 7396 merge patch; `null` deletes the named key.
- MUST apply only explicit replacements. Never paraphrase body text or infer
  scope, acceptance text, metadata, dependencies, or lifecycle evidence.
- MUST stage only transaction-owned paths. Never use broad add, clean, reset,
  checkout, amend, rebase, or history-rewriting commands.
- A `done` transition needs the explicit evidence references defined below.

## Ticket Schema and Lifecycle

Ticket frontmatter is authoritative. Required fields, in order:

| Field | Creation value or constraint | Ownership |
|---|---|---|
| `schema` | `ticket-operations/ticket` | immutable |
| `schema_version` | `1` | immutable |
| `ticket_set` | creation fingerprint and stable lineage | immutable |
| `id` | assigned ID | immutable |
| `fingerprint` | definition fingerprint | derived definition identity |
| `title` | derived title | definition |
| `status` | `open` | lifecycle |
| `status_reason` | `null` | lifecycle |
| `owner` | `null` | lifecycle |
| `revision` | `1` | lifecycle |
| `type` | Conventional Commits type | definition |
| `severity` | normalized severity | definition |
| `priority` | fixed mapping | definition |
| `estimate` | `XS|S|M|L|XL` | definition |
| `labels` | sorted unique list | definition |
| `source` | `kind`, `identifier`, `fingerprint`, `refs` | immutable |
| `dependencies` | same-set IDs | definition |
| `extensions` | empty mapping; preserve unknown nested keys | extension |

Body section text is definition-owned. Acceptance checkbox markers are
lifecycle-owned; their text is definition-owned. Callers cannot assign
`fingerprint`: the update operation recomputes it after an explicit definition
change, while `ticket-execute` preserves it. Extensions change only through an
explicit merge patch and remain excluded from the fingerprint.

Allowed statuses are `open`, `in_progress`, `blocked`, `done`, and
`cancelled`. Allowed status edges are:

- `open -> in_progress|blocked|cancelled`
- `in_progress -> open|blocked|done|cancelled`
- `blocked -> open|in_progress|cancelled`
- `done|cancelled -> open` only with an explicit `reopen: true`

Final state invariants are:

| Status | Owner | Status reason | Acceptance |
|---|---|---|---|
| `open` | `null` | `null` | any valid marker vector |
| `in_progress` | required nonempty string | `null` | any valid marker vector |
| `blocked` | `null` | required nonempty string | any valid marker vector |
| `done` | `null` | `null` | every marker checked |
| `cancelled` | `null` | required nonempty string | any valid marker vector |

Every native lifecycle or definition mutation compares an expected revision and
increments it by exactly one. Projection-only repair does not increment it.

Every current and prospective `in_progress` or `done` ticket requires all
direct dependencies to be authoritatively `done`. Entering either status
requires dependencies to be done in both the baseline and final snapshots; a
different ticket entry in the same update cannot satisfy that gate. Update does
not use satisfaction to infer status.

### Transition mechanics

Every transition names its destination explicitly. A transition to
`in_progress` supplies `owner`; a transition to `blocked` or `cancelled`
supplies `status_reason`. Other destinations force both fields to their table
values. Reopen, abandonment, owner reassignment, and same-status reason
replacement require a nonempty `transition_note`; this note goes to the
journal, report, and audit commit, not `status_reason`.

For an `in_progress` ticket, require top-level `expected_owner` to match.
Marker-only updates, lifecycle transitions, or explicit owner reassignment may
proceed when no live `ticket-execute` journal exists. Any definition, body,
dependency, acceptance text, or extension edit must also set
`abandon_claim: true` and transition to `open`; it resets markers.

Any fingerprint-changing edit to `done` or `cancelled` must set `reopen: true`
and transition to `open` in the same entry. Extension-only changes may retain a
terminal status. Every transition to `open` resets all markers. A same-status
operation may only reassign an `in_progress` owner or replace a `blocked` or
`cancelled` reason. Other same-status requests are no-ops or invalid field
combinations. Any automatic reset from a definition edit, abandonment, or
reopen conflicts with `acceptance_markers` in the same entry.

### Acceptance evidence

Checking a criterion is an explicit lifecycle assertion that requires evidence
bound to the exact criterion text and current fingerprint. `ticket-execute`
produces and runs fresh evidence; this skill may adopt explicit
caller-supplied evidence but labels it `caller-supplied; not executed`.

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
checked nor supports a `done` transition. The skill validates identity, shape,
and local availability, then labels the record `caller-supplied; not executed`.

Transitioning to `done` requires evidence for every criterion, including
markers already checked, and an `acceptance_markers` operation whose final
vector is all checked. The skill never obtains, executes, or endorses this
evidence. Unchecking requires an indexed reason but no completion evidence.

## Identity

For every identity payload in this skill, canonical JSON means RFC 8259 JSON
with object keys sorted by UTF-8 byte order at every depth, array order
preserved, strings encoded as UTF-8 without ASCII escaping, no insignificant
whitespace, and no trailing newline. Hash those exact bytes with SHA-256 and
prefix lowercase hex with `sha256:`.

Compute each `fingerprint` from this exact payload:

```json
{
  "body": "<exact rendered Markdown after frontmatter, with every acceptance marker normalized to [ ]>",
  "dependencies": ["TKT-000"],
  "estimate": "S",
  "id": "TKT-001",
  "labels": ["label"],
  "priority": "P1",
  "schema": "ticket-operations/ticket-definition",
  "schema_version": 1,
  "severity": "major",
  "source": {
    "fingerprint": "sha256:<hex>",
    "identifier": "<source identifier>",
    "kind": "file",
    "refs": ["<source ref>"]
  },
  "title": "<title>",
  "type": "fix"
}
```

`body` begins at the rendered H1 and ends with exactly one LF. Normalize only
acceptance marker bytes; preserve every other body byte. Exclude `ticket_set`,
the stored `fingerprint`, lifecycle fields, and extensions.

Compute `ticket_set` from this exact payload:

```json
{
  "accounting": [
    {
      "final_ids": ["TKT-001"],
      "outcome": "ticketed(TKT-001)",
      "source_key": "SRC-001",
      "source_refs": ["<source ref>"]
    }
  ],
  "contract_revision": "ticket-create/v1",
  "parameters": {
    "granularity": "split-composites",
    "id_prefix": "TKT",
    "min_severity": null
  },
  "source": {
    "fingerprint": "sha256:<hex>",
    "records": [
      {"identifier": "<identifier>", "normalized_text": "<text>"}
    ]
  },
  "template_sha256": "sha256:<hash of exact template bytes as read>",
  "tickets": [
    {"fingerprint": "sha256:<hex>", "id": "TKT-001"}
  ]
}
```

The `contract_revision` string is a frozen hash input, not a name to update
when this skill is renamed. Changing it would give every set a different
lineage than the one its existing tickets carry.

Use JSON `null` when `{min_severity}` is omitted. Accounting and tickets retain
their documented order. Compute `ticket_set` once at creation. Thereafter it is
an opaque, stable lineage identifier: definition updates change affected ticket
fingerprints and projections but never recompute `ticket_set`,
`source_fingerprint`, source records, template identity, or creation
accounting. After the first definition edit, `ticket_set` remains lineage
rather than a digest of current definitions; validate agreement, not a creation
preimage that the set does not retain.

Any change to a definition-owned frontmatter field, dependency, criterion text,
or body byte recomputes that ticket's fingerprint by this algorithm. Lifecycle
and extension changes preserve the fingerprint.

## Canonical Source

This section governs the create operation.

1. Decode UTF-8; remove one BOM; normalize CRLF/CR to LF, Unicode to NFC, and
   exactly one final newline. Invalid UTF-8 aborts.
2. Identify in-workspace files by workspace-relative POSIX path and outside
   files by normalized absolute path.
3. For a directory, recursively collect regular `*.md` files without following
   symlinks and sort identifiers by unsigned UTF-8 byte order.
4. For chat, use the nearest unambiguous preceding matching block and identify
   it as `chat:sha256:<first-12-hex>` of the normalized text bytes. For inline
   input, use `inline:sha256:<first-12-hex>` by the same rule.
5. Obtain the source fingerprint by hashing this exact canonical JSON shape:

   ```json
   {
     "records": [
       {"identifier": "<identifier>", "normalized_text": "<text>"}
     ],
     "schema": "ticket-operations/source-snapshot",
     "schema_version": 1
   }
   ```

   Records remain in canonical source order.
6. Derive `<source-slug>` from the basename or first five source words:
   NFKD-normalize, remove combining marks, tokenize maximal ASCII
   `[A-Za-z0-9]+` runs, lowercase, join with `-`, and use `source` when empty.

Read the live source once. Extraction, evidence, identity, and rendering all use
that captured snapshot.

## Transformation

### Extract

Walk canonical documents and lines in order. Assign source keys `SRC-001`,
`SRC-002`, ... before any transformation. Extract the first matching form:

1. critique findings shaped as `- **<criterion>** @ <location>` plus indented
   `Evidence`, `Rationale`, `Context`, `Why`, `Where`, `Done-when`,
   `Depends on`, `Severity`, `Type`, and `Estimate` fields;
2. Markdown checkbox items and their indented fields (`[x]` is
   `already-done`);
3. numbered action items;
4. bullets under `Recommendations`, `Action Items`, `Actions`, `Findings`,
   `Next Steps`, or `Tasks`; or
5. imperative sentences beginning with `add`, `create`, `document`, `ensure`,
   `fix`, `implement`, `improve`, `introduce`, `prevent`, `remove`, `replace`,
   `refactor`, `test`, `update`, or `validate`.

Capture source refs as `<identifier>:<start-line>-<end-line>`. Unmatched prose
is context, not a fabricated item. Normalize severity aliases:
`blocker/high/medium/low` map to `critical/major/minor/nit`; absent or unknown
severity is `unclassified`. Resolve severity from an explicit item field or
label first, then the nearest containing heading whose complete trimmed,
case-insensitive text is `Critical`, `Major`, `Minor`, or `Nit`.

An item's source statement is its first physical item line after removing the
list/checkbox/number marker and Markdown emphasis around a finding label.
Recognize inline named fields only after a literal `; ` followed by one of the
field names listed in extraction and `:`. Remove that delimiter and all
recognized inline fields from the statement; parse their values as if they
were indented fields. Collapse all statement whitespace to one ASCII space and
trim it. A root source ref spans the item line through its last indented child.

### Merge, split, group, and filter

Apply in this order:

1. Merge exact duplicates with equal case-folded, whitespace-collapsed concern
   and sorted explicit locations. Preserve first wording; concatenate distinct
   explicit evidence, acceptance criteria, and refs in source order; preserve
   the primary's other fields; keep the highest severity.
2. Under `split-composites` or `theme-grouped`, split only explicit independent
   child bullets, numbered child actions, or semicolon-separated action clauses
   that each carry their own location or acceptance criterion. Never split a
   bare conjunction by semantic guess. A fragment takes its statement, title,
   inline/child scope, and inline/child acceptance from that child or clause.
   It inherits the merged candidate's severity, context, out-of-scope text,
   dependencies, distinct explicit evidence, and complete ordered source-ref
   union. Its evidence starts with its exact fragment statement, followed by
   inherited distinct evidence in source order. When a fragment omits scope or
   acceptance, inherit the primary candidate's value before using a fallback.
3. Under `theme-grouped`, merge only candidates with equal normalized criterion
   and complete sorted location list. Sharing a file or severity is
   insufficient.
4. Filter classified candidates below `{min_severity}`; retain
   `unclassified`.
5. Order by severity (`critical`, `major`, `minor`, `nit`, `unclassified`),
   source-file order, start line, fragment index, then normalized title bytes.
   Assign IDs in that order.

Every source key receives exactly one accounting outcome. Counts are over source
keys, not generated fragments. When a source key merges into a surviving
candidate that later splits, its `merged-into(<ids>)` outcome contains every
ordered final ID descending from that candidate; the surviving primary source
key is `split-into(<ids>)`. Never collapse that merged source to an arbitrary
single fragment.

Serialize outcomes exactly as `ticketed(TKT-001)`,
`split-into(TKT-001,TKT-002)`, `merged-into(TKT-001,TKT-002)`,
`filtered(below-min-severity:<value>)`, or `already-done`, with final IDs in
ticket order and no spaces inside parentheses.

## Field Derivation

- `title` — for a critique finding, the exact criterion label; otherwise the
  source statement through its first `.`, `?`, or `!` sentence boundary.
  Preserve wording. Truncate beyond 72 code points at the last whitespace by
  code point 69 and append `...`.
- `summary` — normalized source statement followed by each distinct explicit
  `Why` or `Rationale` value in source order, joined with `; `. Do not
  paraphrase.
- `context` — non-severity containing heading texts followed by explicit
  `Context` values, each whitespace-collapsed and joined with `; ` in source
  order; fallback `No additional context was supplied.`
- `evidence` — each distinct explicit `Evidence` value with its originating
  root source ref; when absent, the exact source statement with that ref.
  Preserve source order.
- `scope` — explicit finding location, then each `Where` value split on literal
  commas, then backticked paths/symbols in the statement, trimmed and
  deduplicated in source order; fallback `Not specified in source.`
- `acceptance_criteria` — one value per explicit `Done-when` or acceptance
  child in source order, whitespace-collapsed; fallback
  `Source requirement is satisfied: "<title>".`
- `out_of_scope` — explicit value; fallback
  `Changes outside the listed scope and acceptance criteria.`
- `type` — explicit valid Conventional Commits type, otherwise first matching
  rule: word `revert` -> `revert`; every concrete location is under `docs/` or
  ends `.md|.rst|.adoc` -> `docs`; a location is under `.github/workflows/`,
  `.circleci/`, or `ci/` -> `ci`; a location basename is `package.json`,
  `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`, or ends `.lock` ->
  `build`; a location contains `/test/` or `/tests/`, or its basename contains
  `.test.`, `.spec.`, or `_test.`, or text contains `test|coverage` -> `test`;
  text contains `performance|latency|throughput|optimize` -> `perf`;
  text contains `formatting-only|style-only|whitespace|lint-only` -> `style`;
  text contains `refactor|restructure|rename|move` -> `refactor`; text contains
  `fix|bug|broken|error|failure|incorrect|regression` -> `fix`; the first word
  is `add|create|implement|introduce|support` -> `feat`; otherwise `chore`.
  Text words are lowercase maximal ASCII alphanumeric runs.
- `priority` — `critical=P0`, `major=P1`, `minor=P2`, `nit=P3`,
  `unclassified=P2`.
- `labels` — sorted unique lowercase ASCII slugs from explicit labels,
  criterion, first path segment, and source slug. Form each slug from maximal
  ASCII alphanumeric runs after NFKD folding and combining-mark removal,
  joined with `-`; drop empty slugs.
- `estimate` — explicit `XS|S|M|L|XL`, else `XS` without a concrete location,
  `S` for one location, `M` for two or three in one module, `L` for more or
  cross-module work, and `XL` only for an explicit architecture/migration.
- `dependencies` — explicit same-set dependencies only. Resolve exact source
  key, final ID, or unique full title. Unresolved, self, or cyclic dependencies
  abort; never infer dependencies.
- `open_questions` — emit applicable notes in this exact order:
  `Severity is unclassified; assign a severity before prioritization.`,
  `Scope location is unspecified; identify the path, symbol, or module.`,
  `Acceptance criteria were not supplied; review the generated fallback.`,
  `Composite scope was ambiguous; the item was retained as one ticket.` Use
  the first three exactly when their corresponding fallback is used. Use the
  fourth only when source text contains ASCII case-insensitive whole phrase
  `and also` but does not meet the explicit split rule. Use `_None._` when none
  applies.

Filenames are `<id>-<first-six-title-words>.md` using lowercase ASCII
kebab-case. Words are maximal ASCII alphanumeric runs after NFKD folding and
combining-mark removal. Use `ticket` when empty. A duplicate filename aborts.

## Template Contract

Read the template at invocation. Remove only its template-metadata frontmatter
and immediately following comment beginning `TEMPLATE FILE`. The rendered
template MUST contain `{ticket_frontmatter}` exactly once; for compatibility, a
custom legacy template that omits it receives the generated frontmatter before
its first body line.

Recognized tokens:

- generated block: `{ticket_frontmatter}`;
- scalars: `{ticket_id}`, `{title}`, `{type}`, `{severity}`, `{priority}`,
  `{labels}`, `{estimate}`, `{source}`, `{source_ref}`, `{out_of_scope}`;
- paragraphs: `{summary}`, `{context}`;
- blocks: `{evidence}`, `{scope}`, `{acceptance_criteria}`, `{dependencies}`,
  `{open_questions}`;
- aliases: `{where}` for `{scope}`, `{done_when}` for
  `{acceptance_criteria}`.

`{ticket_frontmatter}` renders exactly this shape and field order. Encode every
string with JSON double-quoted string syntax (valid YAML); render arrays as
`[]` when empty or one `  - <encoded-string>` line per value:

```yaml
---
schema: "ticket-operations/ticket"
schema_version: 1
ticket_set: "sha256:<hex>"
id: "TKT-001"
fingerprint: "sha256:<hex>"
title: "<title>"
status: "open"
status_reason: null
owner: null
revision: 1
type: "fix"
severity: "major"
priority: "P1"
estimate: "S"
labels:
  - "<label>"
source:
  kind: "inline"
  identifier: "<identifier>"
  fingerprint: "sha256:<hex>"
  refs:
    - "<source ref>"
dependencies: []
extensions: {}
---
```

The token value has no trailing LF; the template supplies line endings around
it. Render Markdown values as follows after collapsing internal line breaks and
whitespace to one ASCII space:

- `{evidence}`: one `- <evidence> (<source-ref>)` line per distinct evidence
  value, preserving source order and its originating ref;
- `{scope}`: one `- <scope-value>` line per value;
- `{acceptance_criteria}`: one `- [ ] <criterion>` line per value;
- `{dependencies}`: one `- <ticket-id>` line per ID, or `None.` when empty;
- `{open_questions}`: one `- <fixed-note>` line per note, or `_None._`;
- `{labels}`: labels joined with `, `; `{source_ref}`: the first source ref;
- paragraph/scalar tokens: the normalized scalar value without added quoting.

Do not otherwise escape or reflow Markdown-token punctuation. Render UTF-8 with
LF line endings and exactly one final LF.

Protect `{{name}}` as a literal brace escape before token discovery. Discover
template token occurrences before substitution and never rescan inserted source
text. Unknown tokens, missing values, malformed YAML, duplicate keys, invalid
fields, unresolved template occurrences, or missing required sections abort.

Required body sections are `Summary`, `Context and Evidence`, `Scope` with
`In Scope` and `Out of Scope`, `Acceptance Criteria`, `Dependencies`, and
`Open Questions`.

## WORKLIST.md Contract

`WORKLIST.md` is a validated projection, never lifecycle authority. Render its
frontmatter in this exact field order, using the ticket frontmatter's JSON
string/list encoding rules:

```yaml
---
schema: "ticket-operations/worklist"
schema_version: 1
ticket_schema: "ticket-operations/ticket"
ticket_schema_version: 1
ticket_set: "sha256:<hex>"
source_fingerprint: "sha256:<hex>"
ticket_count: 1
tickets:
  - id: "TKT-001"
    file: "./TKT-001-example.md"
    fingerprint: "sha256:<hex>"
    status: "open"
    revision: 1
---
```

After frontmatter, render one blank line and:

```markdown
# Worklist: <source-slug>

Generated by ticket-crud from `<source-identifier>`.
```

Group entries under `Critical`, `Major`, `Minor`, `Nit`, and `Unclassified` in
that order, omitting empty groups. Put one blank line before and after each
heading. Entry shape and subfield order:

```markdown
- [ ] TKT-001: <title>
  - Where: <semicolon-joined scope>
  - Why: <first summary sentence>
  - Done-when: <semicolon-joined acceptance text>
  - Ticket: ./TKT-001-example.md
  - Fingerprint: sha256:<hex>
  - Status: open
  - Revision: 1
```

For `Where` and `Done-when`, join normalized values with `; `. `Why` is the
summary through the first `.`, `?`, or `!` followed by whitespace or end of
text, or the full summary when no boundary exists. Keep every subfield on one
physical line and collapse whitespace; do not otherwise escape punctuation.

Marker projection is `open=[ ]`, `in_progress=[>]`, `blocked=[!]`, `done=[x]`,
and `cancelled=[-]`. The initial four subfields remain readable by
`address-worklist-commit-loop`; its checkbox-only writeback is a legacy
completion proposal, not authoritative lifecycle state.

Append this exact table, one row per source key in source order:

```markdown
## Item Accounting

| Source key | Source refs | Title | Outcome | Final IDs |
|---|---|---|---|---|
| SRC-001 | <refs joined by ; > | <source statement> | ticketed(TKT-001) | TKT-001 |
```

Join nonempty Final IDs with literal `, ` and use `—` when empty. In table
cells, collapse whitespace, replace each existing `\` with `\\`, then each `|`
with `\|`. End `WORKLIST.md` with exactly one LF.

An existing worklist keeps the `Generated by` line it was published with; the
update operation regenerates projected content, never creation provenance.

## Existing Sets and Publication

This section governs the create operation. Inspect the complete expected set
before writing:

- Missing destination: publish there.
- `{on_existing}=error`: any existing destination aborts.
- `{on_existing}=reuse`: require a managed set with matching `ticket_set`;
  validate schemas, expected files, immutable fields, fingerprints, and
  projection. Compare definitions while normalizing lifecycle fields and
  acceptance markers.
  Return `unchanged` when exact or `existing-preserved` when only lifecycle
  state differs. When current definitions differ but the set is internally
  self-consistent, has unchanged lineage/membership/provenance, and every
  current fingerprint and projection validates, return `existing-diverged`
  without writing. Worklist-only drift or inconsistent definition drift aborts
  without repair. Never try to reproduce `ticket_set` from current definitions.
- `{on_existing}=new-set`: use
  `<output-dir>-<first-12-ticket-set-hex>`. Reuse an identical managed target;
  otherwise abort on collision. Never append a numeric suffix.

After approval, acquire an exclusive sibling lock, write the validated set to a
fingerprint-named sibling staging directory, revalidate staged bytes, recheck
destination absence, and atomically rename without replacement. Cleanup may
remove only invocation-owned lock, staging, and empty parent paths.

## Native Set Preflight

This section governs the update operation.

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
   `in_progress` or `done` ticket MUST have all direct dependencies done.
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
| `transition` | Supply `to` and the final-state fields required by `## Ticket Schema and Lifecycle`. Optional audit-only controls are `transition_note`, `reopen`, and `abandon_claim`. |
| `extensions` | Apply an RFC 7396 merge patch. Absent keys survive and explicit `null` deletes. Extensions do not enter the fingerprint. |

Reject unknown operations, line-number patches, regular expressions, fuzzy
title matching, partial list edits, and overlapping representations of the
same field. Update the rendered H1 when `title` changes. Missing operations
never mean deletion. Evidence records follow the schema in
`## Ticket Schema and Lifecycle`.

One entry with any effective combination of allowed changes is one native
mutation and moves `revision: r` to `r+1`. An identical replacement is not
effective.

Definition edits invalidate evidence bound to the prior fingerprint, so they
reset every acceptance marker to unchecked. Do not combine
`acceptance_criteria` or any other definition edit with marker checks in the
same entry. Regenerate the affected manifest record and all derived worklist
content. Keep `ticket_set`, `source_fingerprint`, canonical rank, filenames,
and Item Accounting unchanged.

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

Before ordinary projection validation, detect unresolved `ticket-execute` and
update journals and direct recovery to their owning skill. After approval,
derive a set key from canonical JSON containing the real worktree path,
set-root path, and `ticket_set`. Acquire the same OS-released per-set mutation
lock used by ticket execution at
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

Both Git path literals above are frozen on-disk locations, not names to update
when this skill is renamed: the lock is shared with `ticket-execute`, and the
journal directory must stay discoverable for journals written by earlier
versions.

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

### Create

1. Check activation, resolve `{operation}`, and validate scalar parameters.
2. Read and validate the template.
3. Capture and canonicalize the source snapshot.
4. Extract source items and initialize total accounting.
5. merge, split, group, filter, derive, order, assign IDs, and resolve
   dependencies.
6. Compute fingerprints; render all tickets and `WORKLIST.md` in memory.
7. Validate schemas, sections, tokens, references, dependency graph,
   projection, filenames, and accounting.
8. Apply existing-set policy. Return for `unchanged`, `existing-preserved`, or
   `existing-diverged`.
9. Render the plan. Stop for `{dry_run}` or declined interactive approval.
10. Publish atomically and byte-compare every final file with validated memory.
11. Report without implying that ticket work was implemented.

### Update

1. Check activation, resolve `{operation}`, validate parameters, and resolve
   the target without following symlinks.
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

Every report names the resolved `{operation}` first, then returns that
operation's sections in order, omitting empty optional sections.

### Create

**Run Summary.** Source identifier/kind/fingerprint; template; ticket-set
fingerprint; resolved parameters; outcome (`created`, `unchanged`,
`existing-preserved`, `dry-run`, `existing-diverged`, `declined`, or
`no-items`); and all accounting counts.

**Ticket Plan.**

| ID | Title | Status | Severity | Priority | Type | Estimate | Source refs | File |
|---|---|---|---|---|---|---|---|---|

**Item Accounting.** One row per source key, including direct mappings and the
evaluated accounting equality.

**Files.** Every final path and disposition, or `None (<outcome>)`.

**Open Questions.** Every deterministic fallback or retained ambiguity;
`_None._` when empty.

**Handoff.** Name `WORKLIST.md`, state that ticket frontmatter is lifecycle
authority, all tickets start open at revision 1, and no implementation, git
history, or remote record changed.

### Update

**Run Summary.** Target and canonical worklist; opaque ticket-set identity;
operation ID; projection, legacy, interaction, persistence, commit, and
recovery modes; approval digest; outcome (`updated`, `reconciled`,
`updated-and-reconciled`, `unchanged`, `already-applied`, `inspected`,
`dry-run`, `declined`, or `recovery-required`); and selected/changed/repaired
counts.

**Validation.** Schema versions; ticket/file count; lineage consistency;
current and prospective fingerprint results; projection result or exact repair
class; dependency and cycle results; lifecycle invariants; persistence and Git
safety.

**Plan.** One row per selected ticket: rank, ID, expected and prospective
status/revision/fingerprint, edit classes, transition, acceptance reset or
evidence disposition, and final dependencies. Include a projection-only row
when applicable.

**Legacy Proposals.** One row per checked legacy entry: native link, current
state, eligibility, explicit acceptance, and disposition. Label every evidence
reference `caller-supplied; not executed`.

**Lifecycle Evidence.** For each marker check or completion transition, list
criterion, fingerprint, observed tree, evidence kind/ref/result, validation
disposition, and the `caller-supplied; not executed` label.

**Transaction.** Approval result; lock and journal/receipt location; changed
managed paths and before/after hashes; rollback or recovery state; final
full-set validation.

**Commit.** Commit SHA and subject, staged managed paths or local state hashes,
and revision ranges; or `none`.

**Recovery.** When applicable, report phase, recognized hashes, action, result,
retained journal/receipt, and safe next operation.

**Handoff.** List final status/revision/fingerprint for each changed ticket and
whether the tracked set is unstaged or committed. State that the skill
performed no ticket implementation or acceptance execution and made no tracker,
branch, worktree, merge, push, pull-request, tag, or other remote change.
