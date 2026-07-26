---
name: ticket-create
description: "Create a deterministic local Markdown ticket backlog from an analysis, review, plan, checklist, or inline recommendations. Use when the user asks to create tickets, ticketize findings, break work into ticket files, or produce a WORKLIST.md. Do not use for tracker integration, implementation, commits, lifecycle edits to existing tickets, or ad hoc note dumping."
license: MIT
---

# Ticket Create

## Activation

Use this skill when the user asks to:

- create local ticket files from an analysis, critique, review, plan, task list, or recommendations;
- split findings into independently actionable tickets;
- turn existing `ticket-breakdown` input into a durable Markdown backlog; or
- produce ticket files and a `WORKLIST.md` for later execution.

Do not use this skill when the user asks to:

- create or update GitHub Issues, Jira issues, Linear issues, or another remote tracker record;
- implement, fix, execute, commit, or push ticket work;
- change an existing ticket batch (the future `ticket-update` skill owns that);
- execute an existing backlog (the future `ticket-execute` skill owns that);
- produce the source analysis itself; or
- dump one ad hoc document without creating a ticket backlog.

## Task

Transform one declared source snapshot into a batch of local Markdown ticket files and one compatible `WORKLIST.md`. Read the configured ticket template during every invocation, normalize every source item under the rules below, render all artifacts in memory, validate the complete batch, then persist it without overwriting existing state.

The transformation boundary is pure: source snapshot, semantic parameters, template bytes, and schema revision determine every output byte. Do not use time, randomness, model wording choices, directory enumeration order, locale, environment variables, git state, or network results in ticket content, ids, filenames, ordering, or batch identity.

This skill creates backlog artifacts only. It does not implement tickets or mutate lifecycle state after creation.

## Parameters

- `{source}`: required work-item source. `{analysis}` is a compatibility alias. Supply exactly one, or supply both with byte-identical values. Accepted source kinds:
  - a readable UTF-8 Markdown file;
  - a directory, read recursively for regular `*.md` files without following symlinks;
  - a reference to a prior chat block, such as `the findings above`;
  - inline items separated by newlines or semicolons.
- `{ticket_template}`: optional template path. Default: this skill's [./TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md). Resolve relative paths against the workspace root. Read the file anew during every invocation; never use a cached or reconstructed copy.
- `{granularity}`: optional splitting policy. Default: `split-composites`. Allowed values:
  - `one-to-one`: keep one normalized candidate per source item, except exact duplicates;
  - `split-composites`: also split only the explicit composite forms listed below;
  - `theme-grouped`: apply `split-composites`, then merge candidates with the exact grouping key below.
- `{min_severity}`: optional lowest included severity under `critical > major > minor > nit`. Default: include all, represented as `none` in canonical data. Allowed explicit values: `critical`, `major`, `minor`, `nit`. Retain `unclassified` items and report `severity filter not applicable`.
- `{id_prefix}`: optional ticket-id prefix. Default: `TKT`. It MUST match `^[A-Z][A-Z0-9]{1,9}$`. Ticket ids use `<prefix>-NNN`, with at least three decimal digits and no truncation after ticket 999.
- `{output_dir}`: optional destination. Relative paths resolve against the workspace root. Default: `.ai-coding-artifacts/tickets/<source-slug>-<batch-id>/`, where `<batch-id>` is the lowercase content-derived batch id. The destination MUST NOT equal a source path or sit inside a source directory.
- `{dry_run}`: optional boolean, default `false`. Complete all read-only resolution, rendering, validation, accounting, and collision checks; report the plan and write nothing.
- `-i` / `--interactive`: optional approval flag. Present the validated plan and wait for one approval before persistence. A changed plan requires a new invocation.

Compatibility parameters from `ticket-breakdown` are narrow and explicit:

- `{persistence}=files` is accepted as a no-op. `{persistence}=chat` is rejected because this skill creates local Markdown files.
- `{emit_worklist}=true` is accepted as a no-op. `{emit_worklist}=false` is rejected because `WORKLIST.md` is part of the batch contract.
- Unknown parameters abort instead of being ignored.

## Success Criteria

- [ ] Every invocation reads `{ticket_template}` from disk before transformation. An unreadable template aborts with `cannot read ticket template: <path>`.
- [ ] All parameter, source, template, schema, accounting, destination, and collision checks finish before the first filesystem write.
- [ ] Every source item receives exactly one outcome: `ticketed(<id>)`, `split-into(<ids>)`, `merged-into(<ids>)`, `filtered(<reason>)`, or `already-done`.
- [ ] Every ticket validates against `ticket-operations/ticket-v1`, starts at `status: open`, and contains no unresolved template token or template-only comment.
- [ ] `WORKLIST.md` validates against `ticket-operations/worklist-v1`, contains one entry per ticket, persists complete item accounting, and points to every ticket by relative path.
- [ ] Ticket and worklist order follows the deterministic ordering rules. Every text field comes from source text or a fixed fallback.
- [ ] Repeating an invocation against unchanged inputs resolves to the same path and bytes. An existing byte-identical batch is a successful no-op; any difference aborts without modification.
- [ ] Output contains no timestamp, random value, host path when a workspace-relative identifier is available, or other ambient value.
- [ ] Zero extracted items reports `_No work items found._` and creates no directory.
- [ ] The skill creates no remote record and performs no implementation, branch, worktree, staging, commit, merge, or push operation.

## Guardrails

- MUST keep source files and the template read-only.
- MUST write only local Markdown artifacts under `{output_dir}`. Temporary lock and staging directories may exist beside it only during persistence and MUST be removed on success.
- MUST NOT infer facts, evidence, paths, dependencies, test commands, or completion claims absent from the source. Use the fixed fallbacks below.
- MUST NOT paraphrase source text. Normalize syntax and whitespace only as specified.
- MUST NOT overwrite, append to, merge into, delete, or auto-suffix a pre-existing destination.
- MUST NOT call a tracker API, MCP tracker tool, or network service.
- MUST NOT implement a ticket or modify project files named by a ticket.
- MUST NOT stage, commit, push, create a branch or worktree, open a pull request, or edit `.gitignore`.
- Scope: create one versioned local ticket batch from one source snapshot. Existing-batch lifecycle or specification changes belong to future ticket operation skills.

## Canonical Source Snapshot

Build the source snapshot before extracting items:

1. Decode every source as UTF-8. Remove one leading UTF-8 BOM, normalize `CRLF` and bare `CR` to `LF`, normalize Unicode to NFC, and ensure exactly one terminal newline. Invalid UTF-8 aborts.
2. Identify an in-workspace file by workspace-relative POSIX path. Identify an outside file by normalized absolute path. Never resolve an identifier through a symlink.
3. For a directory, collect regular `*.md` files recursively, reject symlinks, and sort workspace-relative POSIX paths by unsigned UTF-8 byte order. An empty collection is an empty source.
4. For a chat reference, select the nearest preceding block that satisfies it. Identify the block as `chat:sha256:<first-12-hex-of-normalized-text>`. An ambiguous or missing reference aborts.
5. For inline input, preserve supplied text after canonical text normalization and identify it as `inline:sha256:<first-12-hex-of-normalized-text>`.
6. Compute `{source_digest}` as lowercase SHA-256 over canonical JSON containing ordered `identifier` and `normalized_text` pairs, serialized as UTF-8 with sorted keys and no insignificant whitespace.
7. Derive `{source_slug}` from the file or directory basename without extension. For chat or inline input, use the first five ASCII-alphanumeric words of normalized text. Apply Unicode NFKD, drop combining marks and non-ASCII characters, lowercase, join words with `-`, and use `source` when empty.

`{source_identifier}` is the canonical file or directory path for path input and the `chat:sha256:...` or `inline:sha256:...` identifier otherwise. Directory tickets use the directory as `source.identifier` and concrete child-file refs in `source.refs`.

Do not read a live source twice. Extraction, evidence, hashing, rendering, and reporting all use the captured snapshot.

## Deterministic Extraction

Walk files and lines in snapshot order. Assign source item keys `SRC-001`, `SRC-002`, and so on before merging, splitting, or filtering. Extract only:

For inline input, treat each literal semicolon as a separator before walking items, trim surrounding whitespace, drop empty segments, and preserve segment order. Use newline-separated inline input when an item itself must contain a semicolon.

1. A critique finding headed by `- **<criterion>** @ <location>`, including indented `Evidence:`, `Rationale:`, `Why:`, and `Done-when:` children.
2. A Markdown checkbox item `- [ ]` or `* [ ]`, including indented continuation text and named subfields. A matching `[x]` or `[X]` item goes directly to `already-done`.
3. A numbered item whose first non-whitespace token is an integer followed by `.` or `)`.
4. A bullet or standalone sentence whose first ASCII word is one of `add`, `align`, `avoid`, `create`, `document`, `ensure`, `fix`, `implement`, `improve`, `introduce`, `prevent`, `remove`, `replace`, `refactor`, `test`, `update`, or `validate`, or that contains `should`, `must`, `needs to`, or `recommend`. Compare ASCII case-insensitively. A sentence ends at `.`, `?`, or `!` followed by whitespace or end of paragraph. Each source bullet or sentence is one item.

Headings and unmatched prose supply context to the next extracted item in the same section; they are not separate items. Strip Markdown list markers and collapse internal whitespace for normalized scalar fields, but retain an exact normalized source quote for evidence. Record refs as `<identifier>:<start-line>-<end-line>`.

Severity comes from the item label first, then its nearest containing heading:

| Source value | Severity |
|---|---|
| `blocker`, `critical`, `sev0` | `critical` |
| `high`, `major`, `sev1` | `major` |
| `medium`, `minor`, `sev2` | `minor` |
| `low`, `trivial`, `nit`, `sev3` | `nit` |
| absent or any other value | `unclassified` |

Compare values case-insensitively. When a rule cannot decide whether text is separate, keep it with its containing item. Apply fixed field fallbacks instead of choosing alternate wording.

## Deterministic Splitting and Merging

Apply these operations in order:

1. **Exact duplicates:** normalize concern text with NFC, case-folding, whitespace collapse, and terminal-punctuation removal. Normalize locations as a sorted, deduplicated list. Items with equal `(concern, locations)` keys merge; the earliest remains primary, evidence and refs concatenate in source order, and severity becomes the highest member severity.
2. **Explicit composites:** under `split-composites` and `theme-grouped`, split only:
   - sibling sub-bullets that each begin with an action and carry their own location or acceptance criterion;
   - explicitly numbered child actions; or
   - semicolon-separated clauses that each contain an action marker and a distinct explicit location.
   Preserve child order. Each fragment inherits severity, context, evidence, and refs and appends `#part-<N>` to its internal source key. Do not split an unstructured `and` or make a semantic judgment.
3. **Exact theme grouping:** under `theme-grouped`, merge candidates only when both normalized criterion label and complete sorted location list match. The earliest remains primary and severity becomes the highest member severity. Sharing only a file, severity, or broad topic is insufficient.
4. **Severity filter:** filter classified candidates below `{min_severity}`. Retain `unclassified`.

Assign each root source item after filtering. A checked item is `already-done`. A split root with one or more surviving fragments is `split-into(<ordered-ids>)`; one with none is `filtered`. An unsplit source item in a surviving merge is `ticketed(<id>)` when primary and `merged-into(<ordered-ids>)` otherwise. Any source item whose complete result was filtered is `filtered`. These precedence rules prevent dangling ids and keep one outcome per `SRC-NNN`.

## Field Derivation

Derive fields with fixed rules:

- `title`: use explicit item title, or text through the first sentence boundary. Remove Markdown emphasis, collapse whitespace, and remove terminal `.`, `:`, or `;`. If it exceeds 72 Unicode code points, cut at the last whitespace at or before 69 code points and append `...`; if no whitespace exists, use the first 69 code points plus `...`. Preserve wording and capitalization.
- `summary`: use complete normalized concern followed by explicit `Why:` or `Rationale:` text in source order. If neither exists, use the concern alone.
- `context`: join containing headings and explicit context continuation in source order. If absent, use `No additional context was supplied.`
- `evidence`: emit source evidence verbatim. If absent, quote the item's exact normalized source text. Every bullet ends with its source ref.
- `where`: use, in order, the finding's `@ <location>`, `Where:` values, then backticked path or symbol references. Preserve first appearance and deduplicate exact values. If absent, emit `Not specified in source.`
- `done_when`: use explicit `Done-when:` or acceptance-criteria children verbatim. If absent, emit `Complete the source request: <title>`.
- `out_of_scope`: use explicit text. If absent, use `Changes outside the listed scope and acceptance criteria.`
- `severity` and `priority`: use `critical -> P0`, `major -> P1`, `minor -> P2`, `nit -> P3`, and `unclassified -> P2`.
- `type`: accept an explicit `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, or `revert`. Otherwise lowercase the title plus concern and use the first match:
  1. whole word `revert` -> `revert`;
  2. every concrete location ends in `.md`, `.rst`, or `.adoc`, or starts with `docs/` -> `docs`;
  3. a location starts with `.github/workflows/`, `.circleci/`, or `ci/`, or equals `.gitlab-ci.yml` -> `ci`;
  4. a location basename is `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`, or ends in `.lock` -> `build`;
  5. every concrete location contains `/test/`, `/tests/`, `.test.`, `.spec.`, or `_test.`; or text contains whole word `test` or `coverage` -> `test`;
  6. text contains `performance`, `latency`, `throughput`, or `optimize` -> `perf`;
  7. text contains `formatting-only`, `style-only`, `whitespace`, or `lint-only` -> `style`;
  8. text contains `refactor`, `restructure`, `rename`, or `move` -> `refactor`;
  9. text contains `fix`, `bug`, `broken`, `error`, `failure`, `incorrect`, or `regression` -> `fix`;
  10. the first word is `add`, `create`, `implement`, `introduce`, or `support` -> `feat`;
  11. fallback -> `chore`.
  Match words as ASCII-alphanumeric tokens. This is advisory metadata; ticket creation creates no commit.
- `labels`: collect explicit labels, normalized criterion label, first path segment of each concrete `where` value, and `{source_slug}`. Convert to lowercase ASCII kebab-case, drop empty values, deduplicate, and sort by UTF-8 bytes. Source slug guarantees one label.
- `estimate`: consider only concrete locations; a top-level module is the first POSIX path segment. Use `XL` only when source contains `architecture`, `migration`, or `rewrite`; otherwise `L` for more than three unique locations or more than one top-level module, `M` for two or three locations, `S` for one location, and `XS` when none exists.
- `dependencies`: include only explicit dependencies that resolve to a source item or final ticket id in the same batch. Preserve source order, deduplicate, and replace source-item references with final ids. An unresolved reference, self-reference, or cycle aborts. Otherwise emit an empty list and `None.` in the body.
- `status`, `status_reason`, and `revision`: always `open`, `null`, and `1` at creation.

Order candidates by severity rank (`critical`, `major`, `minor`, `nit`, `unclassified`), then source-file order, start line, fragment number, and normalized title UTF-8 bytes. Assign ids in that order.

Create filename slugs by applying Unicode NFKD, dropping combining marks, lowercasing, replacing each non-ASCII-alphanumeric run with `-`, trimming `-`, and keeping the first six words. Use `item` when empty. Filenames are `<ticket-id>-<slug>.md`. Any duplicate filename is a validation error.

For each ticket, compute `spec_digest` as lowercase SHA-256 of canonical JSON for immutable schema fields and body-field values, excluding `batch_id`, `status`, `status_reason`, and `revision`.

## Batch Identity and Rendering

Use transformation revision `ticket-create/v1`. Normalize template line endings to `LF`, then compute `template_digest` over the full template bytes. Build canonical JSON with:

- transformation revision;
- source kind, ordered identifiers, and `{source_digest}`;
- normalized semantic parameters (`granularity`, `min_severity`, and `id_prefix`);
- `{template_digest}`;
- ordered source-item accounting records; and
- ordered final ticket records with `spec_digest`.

Serialize with sorted keys, UTF-8, and no insignificant whitespace. Hash with SHA-256. `{batch_id}` is `TC-` plus the first 16 lowercase hex characters. Exclude `output_dir`, `dry_run`, interactivity, and compatibility no-ops because they do not change artifact bytes.

Render UTF-8 with `LF` line endings and exactly one terminal newline. Preserve template line breaks. Do not reflow prose. YAML strings use JSON double-quoted string encoding.

## Ticket Schema

Every ticket MUST start with YAML frontmatter conforming to `ticket-operations/ticket-v1`:

| Field | Type and constraint | Lifecycle mutable |
|---|---|---|
| `schema` | literal `ticket-operations/ticket-v1` | no |
| `id` | unique string matching `^{id_prefix}-[0-9]{3,}$` | no |
| `title` | non-empty string, at most 72 code points | no |
| `status` | `open`, `in-progress`, `blocked`, `done`, or `cancelled` | yes |
| `status_reason` | `null` or non-empty string | yes |
| `revision` | integer `>= 1` | yes |
| `type` | Conventional Commits type listed above | no |
| `severity` | `critical`, `major`, `minor`, `nit`, or `unclassified` | no |
| `priority` | `P0`, `P1`, `P2`, or `P3` with fixed mapping | no |
| `estimate` | `XS`, `S`, `M`, `L`, or `XL` | no |
| `labels` | non-empty, sorted, unique string list | no |
| `batch_id` | current content-derived batch id | no |
| `spec_digest` | 64 lowercase hexadecimal characters | no |
| `source` | mapping with `kind`, `identifier`, `digest`, and non-empty `refs` | no |
| `dependencies` | source-ordered unique ids from the same batch | no |
| `extensions` | mapping, initially empty; consumers preserve unknown keys | no |

The body MUST contain non-empty `Summary`, `Context and Evidence`, `Scope`, `Acceptance Criteria`, and `Dependencies` sections. Acceptance Criteria contains at least one unchecked checkbox. Evidence contains at least one source ref.

V1 has no timestamp. Lifecycle tools use `revision` for concurrency instead of time.

## Lifecycle and Handoff Contract

Ticket frontmatter is the authoritative lifecycle record. `WORKLIST.md` mirrors it:

| Ticket status | Worklist marker | Meaning |
|---|---|---|
| `open` | `[ ]` | Created and not claimed |
| `in-progress` | `[/]` | Claimed by an executor |
| `blocked` | `[!]` | Waiting on a recorded impediment |
| `done` | `[x]` | Acceptance criteria completed |
| `cancelled` | `[-]` | Closed without completion |

Creation emits only `open`, `status_reason: null`, and `revision: 1`. A future `ticket-execute` or `ticket-update` implementation may change lifecycle state, but it MUST:

1. compare the expected `revision` before writing;
2. increment `revision` by exactly one per lifecycle mutation;
3. require non-empty `status_reason` for `blocked` and `cancelled`, and `null` for other statuses;
4. update ticket frontmatter plus matching worklist marker, `Status:`, and `Revision:` as one logical operation; and
5. stop on a ticket/worklist mismatch instead of choosing a value silently.

These are storage and handoff invariants, not either future skill's workflow. Immutable fields define the work contract. A tool changing one MUST recompute `spec_digest` and the worklist projection under a separately specified update operation.

`open` does not imply dependency readiness. A consumer MUST resolve every listed same-batch dependency and treat the ticket as runnable only when each dependency is `done`.

The `type` field supplies the `conventional-commits` vocabulary to a future executor. Scope, Out of scope, and Acceptance Criteria bound work performed with `minimal-diffs`. This skill invokes neither supporting skill because it performs no implementation or commit.

## Template Contract

Read `{ticket_template}` in full on every invocation. The canonical template has template metadata frontmatter, then rendered ticket frontmatter after its marked comment. Remove the first metadata block and every `<!-- TICKET-CREATE TEMPLATE ... -->` comment before token discovery and rendering. Do not strip arbitrary comments or italic text.

Recognized tokens:

- scalar: `{ticket_id}`, `{status}`, `{revision}`, `{type}`, `{severity}`, `{priority}`, `{estimate}`, `{batch_id}`, `{spec_digest}`, `{source_kind}`, `{source_digest}`;
- YAML-safe scalar: `{title_yaml}`, `{status_reason_yaml}`, `{source_identifier_yaml}`;
- YAML block: `{labels_yaml}`, `{source_refs_yaml}`, `{dependency_ids_yaml}`;
- Markdown scalar or paragraph: `{title}`, `{summary}`, `{context}`, `{out_of_scope}`;
- Markdown block: `{evidence}`, `{where}`, `{done_when}`, `{dependencies}`.

YAML blocks render list items with indentation required by the enclosing key. Empty `{dependency_ids_yaml}` renders as an indented `[]`. Markdown blocks render evidence and scope as bullets, acceptance as unchecked boxes, and dependencies as ticket-id bullets or `None.`.

Custom templates use `{{` and `}}` for literal braces. Protect those pairs before token discovery and restore them after substitution. An unknown token aborts with `unknown template token: <token>`. A missing value, unresolved recognized token, malformed YAML, unknown ticket-schema key outside `extensions`, missing required field, or missing required body section aborts before any write.

A custom template may change layout, but its output MUST satisfy the complete schema and required body sections. The template remains the rendering source of truth; never fall back to a hard-coded ticket body.

## WORKLIST.md Contract

Generate `WORKLIST.md` from validated records. It starts with:

```yaml
---
schema: ticket-operations/worklist-v1
batch_id: TC-0123456789abcdef
source_digest: "<64 lowercase hex>"
template_digest: "<64 lowercase hex>"
ticket_count: 1
accounting:
  source_items: 1
  ticketed_items: 1
  split_items: 0
  merged_items: 0
  filtered_items: 0
  already_done_items: 0
tickets:
  - id: TKT-001
    file: ./TKT-001-example.md
    spec_digest: "<64 lowercase hex>"
---
```

All fields are required. `tickets` follows final order and has one entry per ticket. Paths are relative, use `/`, and cannot escape the batch directory.

The body uses severity headings in `Critical`, `Major`, `Minor`, `Nit`, `Unclassified` order and omits empty headings:

```markdown
# Worklist: <source-slug>

Generated by ticket-create from `<source-identifier>`.

## Critical

- [ ] TKT-001: <title>
  - Status: open
  - Revision: 1
  - Where: <semicolon-joined scope values>
  - Why: <first sentence of summary>
  - Done-when: <semicolon-joined acceptance criteria>
  - Ticket: ./TKT-001-<slug>.md
```

Keep each subfield on one physical line; replace line breaks with one space. Escape literal backslashes and line-breaking Markdown characters without changing words. Keep final ticket order within headings.

After ticket groups, persist complete accounting:

```markdown
## Item Accounting

| Source item | Source ref | Normalized title | Outcome | Final ticket ids |
|---|---|---|---|---|
| SRC-001 | source.md:4-7 | Add validation | ticketed(TKT-001) | TKT-001 |
```

Escape `|` and line breaks inside cells. Include every source item in source order.

The initial `[ ]` item and `Where:`, `Why:`, and `Done-when:` subfields remain ingestible by `address-worklist-commit-loop`; `Status:`, `Revision:`, and `Ticket:` are additive. That legacy command can read the initial open list, but its checkbox-only writeback does not update ticket-v1 frontmatter and therefore does not satisfy the lifecycle handoff contract.

## Total Item Accounting

Keep one row for every `SRC-NNN`, including direct tickets. The outcome uses exactly one of the five Success Criteria outcomes. Report and persist:

`source_items = ticketed_items + split_items + merged_items + filtered_items + already_done_items`

Report `tickets_rendered` separately. Before persistence, verify the equation, every final id appears in at least one row, and every non-filtered, non-done source item reaches a final ticket. Any failure aborts.

## Collision and Idempotency Policy

Resolve the expected set before writing: `WORKLIST.md` plus one file per ticket.

- A missing `{output_dir}` is eligible for creation.
- A symlink, non-directory, unreadable directory, or directory containing a symlink aborts.
- A directory whose immediate regular-file set and every byte match the expected set reports `existing-identical` and causes no write.
- Any absent expected file, differing byte, additional file, or subdirectory aborts with `output collision: <path>` and a difference list. This includes lifecycle changes; creation never rolls them back.

Do not choose a numeric suffix. A changed source, template, or semantic parameter produces a different default batch path. An explicit `{output_dir}` pins the location.

After approval, create missing parents and acquire exclusive sibling lock `<output-dir>.ticket-create.lock`. Recheck the destination. Write validated bytes to new sibling staging directory `<output-dir>.ticket-create.tmp` with exclusive file creation. Refuse pre-existing lock or staging paths. Rename staging to `{output_dir}` only while destination remains absent. On handled failure, remove only lock, staging, and empty parents created by this invocation. Remove the lock after success. Never alter a pre-existing path during cleanup.

## Workflow

1. **Activation check:** confirm ticket creation, not analysis, execution, updating, tracker integration, or file dumping.
2. **Parameter validation:** resolve aliases and content-independent defaults; reject unknown or incompatible parameters.
3. **Template read:** read the template, validate its envelope and tokens, and compute `template_digest`.
4. **Source snapshot:** resolve source once and build canonical snapshot and `source_digest`.
5. **Extract and account:** assign source keys, classify already-done items, and initialize all accounting rows.
6. **Normalize:** merge, split, group, filter, derive fields, order, assign ids and filenames, validate dependencies, and compute `spec_digest`.
7. **Render in memory:** compute `batch_id` and default path, render tickets through the template, generate `WORKLIST.md`, and normalize bytes.
8. **Validate in memory:** validate schemas, sections, token exhaustion, references, dependency graph, filenames, artifact set, and accounting.
9. **Collision preflight:** inspect destination. Return a no-op for an identical batch; abort on other existing state.
10. **Plan gate:** render plan and accounting. Stop for `{dry_run}`. Under `--interactive`, wait for approval and stop unchanged on decline.
11. **Persist:** use lock and staging, then reread every final file and byte-compare with validated memory.
12. **Report:** use the sections below. Do not imply any ticket was implemented.

## Output Format

Return one Markdown response with these sections in order. Omit a section only when empty.

### Run Summary

- `Source`: identifier and kind (`file`, `directory`, `chat`, or `inline`).
- `Source digest`, `Template`, `Template digest`, `Transformation revision`, `Batch id`.
- `Granularity`, `Min severity`, `Id prefix`, `Output dir`, `Dry run`.
- `Disposition`: `created`, `existing-identical`, `dry-run`, `declined`, or `no-items`.
- `Counts`: source items / ticketed / split / merged / filtered / already done / tickets rendered.

### Ticket Plan

| Id | Title | Status | Severity | Priority | Type | Estimate | Source refs | File |
|---|---|---|---|---|---|---|---|---|

### Item Accounting

Render the complete accounting table, one row per source item. Never omit direct mappings.

### Files

List every absolute final path with `created`, `existing-identical`, or `not written (dry-run|declined)`.

### Open Questions

List deterministic fallbacks that reduced specificity, such as unclassified severity, missing location, fixed acceptance fallback, or an item retained unsplit. These are reports, not prompts.

### Handoff

- Name `WORKLIST.md` as the batch entry point.
- State that every ticket remains `open` at `revision: 1`.
- State that no ticket was implemented and no git or remote operation occurred.
