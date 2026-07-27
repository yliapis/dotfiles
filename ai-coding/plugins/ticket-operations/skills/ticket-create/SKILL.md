---
name: ticket-create
description: "Create a deterministic local Markdown ticket set and WORKLIST.md from an analysis, review, plan, checklist, or inline recommendations. Use when the user asks to create tickets, ticketize findings, break work into ticket files, or persist a local backlog. Do not use for tracker integration, implementation, commits, or changes to an existing ticket."
license: MIT
---

# Ticket Create

## Activation

Use this skill to turn one source of proposed work into local ticket files and a
`WORKLIST.md`. It supersedes `ticket-breakdown`.

Do not use it to produce the source analysis, operate GitHub/Jira/Linear, execute
ticket work, or revise an existing ticket. Execution belongs to
`ticket-execute`; lifecycle and definition changes belong to `ticket-update`.

A Backlog.md-managed set (a directory governed by a Backlog.md `config.yml`)
is not a native set. Do not render native ticket files or a `WORKLIST.md`
into it; create each task through the `backlog` CLI (`backlog task create`)
per that directory's `AGENTS.md`, and never hand-edit its task files.

## Task

Capture one `{source}` snapshot, extract and normalize every work item, render
one versioned Markdown ticket per resulting item through
[./TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md), and generate a compatible
`WORKLIST.md` projection. Render and validate the complete set in memory before
publishing it atomically.

The same canonical source, template bytes, and semantic parameters MUST produce
the same ticket definitions, ids, filenames, ordering, and set identity. Do not
use timestamps, randomness, ambient git state, directory enumeration order, or
free-form paraphrasing in generated artifacts.

## Parameters

- `{source}` — required work-item source. `{analysis}` is a compatibility alias;
  supplying both aborts. Accepts one UTF-8 Markdown file, a directory of
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
- `{dry_run}` — optional boolean, default `false`. Complete resolution,
  rendering, validation, accounting, and collision checks, then write nothing.
- `-i` / `--interactive` — optional. Show the validated plan once and require
  approval before publication.

Compatibility parameters are intentionally narrow:

- `{persistence}=files` and `{emit_worklist}=true` are accepted as no-ops.
- `{persistence}=chat`, `{emit_worklist}=false`, and unknown parameters abort.

## Success Criteria

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
- [ ] The skill performs no implementation, tracker, branch, worktree, staging,
      commit, merge, push, or pull-request operation.

## Guardrails

- MUST keep `{source}` and `{ticket_template}` read-only.
- MUST NOT invent evidence, scope, dependencies, test commands, or completion.
  Use the fixed fallbacks below and report them under Open Questions.
- MUST NOT implement or verify a ticket.
- MUST NOT mutate an existing ticket set, including to repair its worklist.
- MUST NOT call an external tracker or tracker MCP tool.
- MUST NOT overwrite, append to, delete, or numerically suffix existing paths.
- MUST publish all artifacts or none; temporary paths are invocation-owned.
- Scope: one source snapshot to one new local ticket set. Updating, executing,
  importing legacy writeback, and remote synchronization are out of scope.

## Canonical Source

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

For every identity payload in this skill, canonical JSON means RFC 8259 JSON
with object keys sorted by UTF-8 byte order at every depth, array order
preserved, strings encoded as UTF-8 without ASCII escaping, no insignificant
whitespace, and no trailing newline. Hash those exact bytes with SHA-256 and
prefix lowercase hex with `sha256:`.

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
`fingerprint`: `ticket-update` recomputes it after an explicit definition
change, while `ticket-execute` preserves it. Extensions change only through an
explicit merge patch and remain excluded from the fingerprint.

Allowed statuses are `open`, `in_progress`, `blocked`, `done`, and `cancelled`.
Creation defines this transition graph for downstream skills:

- `open -> in_progress|blocked|cancelled`
- `in_progress -> open|blocked|done|cancelled`
- `blocked -> open|in_progress|cancelled`
- `done|cancelled -> open` only through explicit reopen

`owner` is non-null exactly for `in_progress`. `status_reason` is non-null
exactly for `blocked` and `cancelled`. Every native lifecycle or definition
mutation compares an expected revision and increments it by exactly one.
Projection-only repair does not increment it.

Every `in_progress` or `done` ticket requires all direct dependencies to be
authoritatively `done`. Checking acceptance requires evidence bound to the
exact criterion text and current fingerprint. `ticket-execute` produces and
runs fresh evidence; `ticket-update` may adopt explicit caller-supplied evidence
but labels it `caller-supplied; not executed`.

## Identity

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

Use JSON `null` when `{min_severity}` is omitted. Accounting and tickets retain
their documented order. Compute `ticket_set` once at creation. Thereafter it is
an opaque, stable lineage identifier: definition updates change affected
ticket fingerprints and projections but never recompute `ticket_set`.

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

Generated by ticket-create from `<source-identifier>`.
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

## Existing Sets and Publication

Inspect the complete expected set before writing:

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

## Workflow

1. Check activation and validate scalar parameters.
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

## Output Format

Return these sections in order:

### Run Summary

Source identifier/kind/fingerprint; template; ticket-set fingerprint; resolved
parameters; outcome (`created`, `unchanged`, `existing-preserved`, `dry-run`,
`existing-diverged`, `declined`, or `no-items`); and all accounting counts.

### Ticket Plan

| ID | Title | Status | Severity | Priority | Type | Estimate | Source refs | File |
|---|---|---|---|---|---|---|---|---|

### Item Accounting

One row per source key, including direct mappings and the evaluated accounting
equality.

### Files

Every final path and disposition, or `None (<outcome>)`.

### Open Questions

Every deterministic fallback or retained ambiguity; `_None._` when empty.

### Handoff

Name `WORKLIST.md`, state that ticket frontmatter is lifecycle authority, all
tickets start open at revision 1, and no implementation, git history, or remote
record changed.
