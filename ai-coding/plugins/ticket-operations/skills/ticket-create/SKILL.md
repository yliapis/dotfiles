---
name: ticket-create
description: "Create a deterministic local Markdown ticket set and compatible WORKLIST.md from a critique, review, plan, checklist, or inline work items. Use when the user asks to create tickets, ticketize findings, split an analysis into tickets, or build a local backlog. Do not use to implement or execute tickets, change an existing ticket's lifecycle state, create issues in an external tracker, or dump arbitrary prose."
license: MIT
---

# Ticket Create

## Task

Transform one `{source}` into a local ticket set: one rich Markdown file per
resulting item and one `WORKLIST.md`. Account for every source item, derive every
output byte through fixed rules, and make the worklist the durable lifecycle
authority for future `ticket-execute` and `ticket-update` skills.

This skill creates backlog artifacts only. It does not implement ticket work,
change existing lifecycle state, or call a tracker.

## Activation

Use this skill to create or ticketize local work items from a critique, review,
plan, report, checklist, prior chat block, or inline list.

Do not use it to execute, fix, test, or commit tickets; update an existing ticket
set; create remote tracker records; produce the source analysis; or dump one
undivided document. For a mixed request, create the backlog only when the user
clearly asks for it and defer the other operation.

## Parameters

- `{source}`: required. `{analysis}` is a compatibility alias; supplying both
  with different values aborts. Accept a Markdown file, a directory of Markdown
  files, a prior-chat reference, or inline items separated by newlines or
  unescaped semicolons (`\;` means a literal semicolon).
- `{ticket_template}`: optional; default
  [./TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md). Read it during every invocation,
  including dry runs and idempotent reruns.
- `{granularity}`: `one-to-one`, `split-composites` (default), or
  `theme-grouped`. One-to-one keeps each root after exact duplicate merging.
  Split-composites splits only two-or-more child bullets under `Subtasks:` or
  `Separate tickets:`. Theme-grouped also merges equal non-empty explicit
  `Theme:` values.
- `{min_severity}`: `none` (default), `critical`, `major`, `minor`, or `nit`
  under `critical > major > minor > nit`. `unclassified` remains included.
- `{id_prefix}`: default `TKT`; MUST match `^[A-Z][A-Z0-9]{1,9}$`. IDs use
  `<prefix>-NNN`, with no truncation above 999.
- `{output_dir}`: default `.ai-coding-artifacts/tickets/<source-slug>/` from the
  workspace root. Absolute paths are allowed. The path MUST NOT equal or sit
  inside a source directory.
- `{on_existing}`: `reuse` (default) or `error`. Reuse validates a managed set;
  it never repairs or overwrites.
- `{dry_run}`: boolean, default `false`. Complete all read-only transformation,
  rendering, accounting, and validation, then write nothing.
- `-i` / `--interactive`: optional approval gate after validation and before
  persistence.
- `{persistence}`: compatibility parameter. Omitted and `files` are accepted;
  `chat` and other values abort.
- `{emit_worklist}`: compatibility parameter. Omitted and `true` are accepted;
  `false` aborts because the worklist owns lifecycle state.

Unknown parameters abort.

## Success Criteria

- [ ] Parameter, input, render, schema, accounting, path, and collision checks
  finish before the first filesystem mutation.
- [ ] The selected template is read at invocation. An unreadable path aborts
  with `cannot read ticket template: <path>`.
- [ ] Every ticket cites immutable source item IDs, source references, and exact
  source evidence.
- [ ] Every root item receives exactly one disposition: `ticketed`,
  `split-into`, `merged-into`, `filtered`, `already-done`, or
  `already-managed`.
- [ ] Identical normalized sources, template bytes, and shaping parameters yield
  byte-identical initial tickets and worklist. Output has no timestamp,
  randomness, model-drafted prose, or in-workspace absolute path.
- [ ] Tickets and worklist validate against their v1 schemas; every discovered
  template occurrence is replaced and template-only guidance is removed.
- [ ] Open entries retain the legacy `- [ ]`, `Where:`, `Why:`, `Done-when:`,
  and `Ticket:` shape.
- [ ] A matching managed destination is a write-free success; any other existing
  state aborts without overwrite.
- [ ] Publication exposes the complete set or no set.
- [ ] Zero actionable items reports `_No actionable work items found._`, keeps
  total accounting, and creates no directory.

## Guardrails

- MUST keep sources and templates read-only and MUST NOT substitute a fallback
  for an invalid template.
- MUST NOT invent evidence, paths, commands, dependencies, completion claims,
  estimates, or facts. Use source values and fixed fallbacks below.
- MUST NOT overwrite, append to, repair, delete, or auto-suffix an existing set.
- MUST NOT mutate lifecycle state. New tickets start open; reused sets remain
  unchanged.
- MUST NOT implement, test, stage, commit, or otherwise address ticket content.
- MUST NOT commit, push, branch, create worktrees, open pull requests, edit
  `.gitignore`, or write outside `{output_dir}` except to owned sibling lock and
  staging paths during publication.
- MUST NOT call tracker tools, MCP tracker endpoints, web APIs, or remote stores.
- Scope: create one local Markdown ticket set. Future `ticket-update` and
  `ticket-execute` skills own mutation and execution.

## Canonical Source Snapshot

Resolve existing filesystem paths before chat or inline interpretation:

1. A file becomes one record.
2. A directory contributes regular `*.md` files recursively without following
   symlinks. Reject encountered symlinks and sort normalized POSIX identifiers
   by unsigned UTF-8 bytes.
3. A chat reference selects the most recent unambiguous matching block; missing
   or ambiguous references abort.
4. Inline input converts unescaped semicolons to line breaks and restores `\;`.

Decode UTF-8; reject invalid input and NUL. Remove one leading BOM, normalize
`CRLF` and bare `CR` to `LF`, and preserve every other character. Identify an
in-workspace file by workspace-relative POSIX path and an explicitly external
file by normalized absolute path. Identify chat and inline records as
`chat:<first-12-content-hash>` and `inline:<first-12-content-hash>`.

Canonical JSON uses UTF-8, JSON escaping, unsigned-byte-sorted object keys,
array order, and no insignificant whitespace. `source_fingerprint` is
`sha256:<lowercase-hex>` over canonical JSON for ordered
`{identifier, content}` records. Capture the snapshot once.

Derive `source_slug` from a file stem or directory basename. For chat and inline
content, take the first five ASCII-alphanumeric words. Lowercase, replace runs
outside `[a-z0-9]` with `-`, trim dashes, and use `analysis` when empty.

## Deterministic Extraction

Walk records and lines in order. Apply the first matching recognizer and never
reconsider consumed lines:

1. critique finding `- **<criterion>** @ <location>`;
2. Markdown checkbox `- [ ]`, `* [ ]`, or `+ [ ]`;
3. ordered item beginning with an integer plus `.` or `)`;
4. unordered item under an `Action Item(s)`, `Recommendation(s)`, `Next Steps`,
   `Todo(s)`, or `Task(s)` heading; or
5. standalone paragraph beginning with `add`, `align`, `avoid`, `create`,
   `document`, `ensure`, `fix`, `implement`, `improve`, `introduce`, `prevent`,
   `remove`, `replace`, `refactor`, `test`, `update`, or `validate`.

Capture contiguous indented fields named `Title`, `Where`, `Why`, `Evidence`,
`Rationale`, `Done-when`, `Acceptance`, `Severity`, `Type`, `Labels`,
`Estimate`, `Dependencies`, `Theme`, `Out of scope`, or `Open questions`.
`Subtasks:` and `Separate tickets:` own their immediate child bullets.

Assign root IDs `SRC-001`, `SRC-002`, and so on before transformation. A
reference is `<record-id>:<start-line>-<end-line>`. Preserve the normalized
source block for fallback evidence. Hash canonical JSON of reference, text,
fields, heading path, and fragments as the source item fingerprint.

Treat `[x]` and `[X]` as `already-done`. Treat `[>]`, `[!]`, and `[-]` as
`already-managed (in_progress|blocked|cancelled)`. They precede filters and
never produce tickets.

Derive severity from explicit `Severity:`, nearest ancestor heading, then a
leading severity word:

| Inputs | Result |
|---|---|
| `blocker`, `critical`, `sev0` | `critical` |
| `high`, `major`, `sev1` | `major` |
| `medium`, `minor`, `sev2` | `minor` |
| `low`, `trivial`, `nit`, `sev3` | `nit` |
| anything else | `unclassified` |

## Transformation and Accounting

Apply in order:

1. **Exact duplicates.** Lowercase and collapse concern whitespace, remove one
   terminal punctuation mark, and compare it with lowercase, deduplicated,
   sorted `Where` values. Earliest input represents an equal key.
2. **Explicit split.** In split modes, split only a two-or-more child list under
   `Subtasks:` or `Separate tickets:`. Preserve order and inherit parent fields.
   Never infer a split from prose, conjunctions, punctuation, or paths.
3. **Explicit theme grouping.** In `theme-grouped`, merge only equal non-empty
   lowercase, whitespace-collapsed `Theme:` values. Keep earliest position,
   highest severity, and ordered unions of provenance and criteria.
4. **Severity filter.** Filter classified candidates below the threshold;
   retain `unclassified` with `severity filter not applicable`.
5. **Disposition.** Record `ticketed (<id>)`; `split-into` with every fragment's
   ticket or filter outcome; `merged-into (<id-list>)`; `filtered (<reason>)`;
   `already-done`; or `already-managed (<status>)`. If a merge representative
   is filtered, use `merged-into (<source-id>; filtered: <reason>)`.

Persist one row per root item in source order. Every fragment maps to one ticket
or filter outcome, and every ticket has an accounting back-pointer.

## Deterministic Ticket Fields

Sort candidates by severity rank (`critical`, `major`, `minor`, `nit`,
`unclassified`), earliest source position, then item fingerprint. Assign IDs in
that order.

- `title`: explicit `Title:` or primary text. Remove `` ` ``, `*`, `_`, `~`, the
  recognized critique location suffix, collapsed whitespace, and one final
  punctuation mark. Prefix `Address ` unless the first word is in the extraction
  verb list. Over 72 code points, cut at the last space at or before 69 (or at
  69) and append `...`.
- Filename slug: lowercase title; replace non-`[a-z0-9]` runs with `-`; trim;
  keep six words; fallback `ticket`. Filename is `<id>-<slug>.md`.
- `type`: accept explicit `feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`.
  Otherwise tokenize lowercase ASCII words and take the first match: first word
  `revert`; a path under `.github/workflows/`, `.circleci/`, or `ci/`, or named
  `.gitlab-ci.yml`; a basename in `package.json`, `package-lock.json`,
  `pnpm-lock.yaml`, `yarn.lock`, `Cargo.toml`, `Cargo.lock`, `go.mod`, `go.sum`,
  `requirements.txt`, `pyproject.toml`, `Makefile`, or `Dockerfile`; every path
  under `docs/` or ending `.md|.mdx|.rst|.txt`; every path under
  `test|tests|spec|specs` or containing `.test.|.spec.`; a word
  `performance|latency|throughput`; first word `refactor|restructure|rename|move`;
  first word `format|reformat`; a word
  `bug|defect|broken|crash|error|incorrect|regression|failure`; first word
  `add|create|implement|introduce|support|enable`; fallback `chore`. A scope
  value is a path only if it contains `/` or its final segment contains `.`.
- `priority`: `critical=P0`, `major=P1`, `minor=P2`, `nit=P3`,
  `unclassified=P2`.
- `labels`: explicit lowercase slugs, deduplicated and bytewise sorted. Without
  them, use source slug and first scope-value slug.
- `estimate`: explicit `XS|S|M|L|XL`; otherwise `XS` for one location plus
  `one-line|typo`, `S` for one, `M` for two or three, `L` for four or more, and
  `M` for none. Never infer `XL`.
- `summary`: normalized primary text verbatim.
- `context`: `Source context: <heading path>.` or
  `No additional source context was provided.`
- `evidence`: `Evidence`, `Why`, then `Rationale` as
  `- <value> (source: <ref>)`; otherwise the source block with line breaks
  collapsed in that format.
- `scope` / `where`: ordered unique `Where` and critique locations as bullets;
  fallback `- Not specified by source.`
- `out_of_scope`: explicit value or
  `Changes not stated in the source item or its acceptance criteria.`
- `acceptance_criteria` / `done_when`: explicit values as unchecked items, or
  exactly `The requested work in the Summary is complete for every In Scope
  entry.` and `Relevant existing checks for the In Scope entries pass, or the
  ticket records why no check applies.`
- `dependencies`: only exact ticket IDs, source IDs, or unique normalized titles
  explicitly named. Map to final IDs, preserve order, and deduplicate. Move
  unresolved/self references to open questions. Abort on a resolved cycle.
- `open_questions`: explicit questions, then applicable fixed notes
  `Source did not classify severity.`, `Source did not identify an affected
  location.`, `Source did not provide acceptance criteria; fixed defaults were
  used.`, and `Unresolved dependency: <value>.`; fallback `None.`

`ticket_fingerprint` is `sha256:<lowercase-hex>` over canonical JSON containing
ordered source item fingerprints and immutable derived fields except ID and
filename.

## Generation and Template Contract

Decode the template as UTF-8, reject NUL, remove one BOM, normalize line endings
to LF, and preserve other bytes. `generation_fingerprint` is
`sha256:<lowercase-hex>` over canonical JSON containing contract
`ticket-create/v1`, source records, template content, granularity, minimum
severity, ID prefix, and both schema versions. Persistence parameters do not
enter it.

Remove top YAML metadata, comments containing `TICKET-CREATE TEMPLATE` or legacy
`TEMPLATE FILE`, and legacy italic guidance paragraphs containing recognized
tokens. Recognized tokens:

- `{ticket_frontmatter}`;
- `{ticket_id}`, `{title}`, `{type}`, `{severity}`, `{priority}`, `{labels}`,
  `{estimate}`, `{source}`, `{source_ref}`, `{out_of_scope}`;
- `{summary}`, `{context}`; and
- `{evidence}`, `{scope}`, `{where}`, `{acceptance_criteria}`, `{done_when}`,
  `{dependencies}`, `{open_questions}`.

`{where}` aliases `{scope}`; `{done_when}` aliases `{acceptance_criteria}`.
Custom templates require ID, title, summary, evidence, one scope alias, and one
acceptance alias. Permit `{ticket_frontmatter}` once; prepend it when absent.
Escape literal token-shaped braces as `{{name}}`. Unknown tokens abort with the
name and sorted vocabulary.

Discover occurrences before inserting values, replace each occurrence, and
verify none remains. Do not rescan inserted source text.

## Ticket Schema v1

`{ticket_frontmatter}` renders in this exact YAML field order, using
JSON-double-quoted strings and JSON flow arrays:

```yaml
---
schema: "ticket-operations/ticket"
schema_version: 1
id: "<ticket-id>"
fingerprint: "sha256:<ticket-fingerprint>"
generation_fingerprint: "sha256:<generation-fingerprint>"
title: "<title>"
lifecycle_ref: "./WORKLIST.md::<ticket-id>"
type: "<type>"
severity: "<severity>"
priority: "<priority>"
estimate: "<estimate>"
labels: ["<label>"]
source_items: ["SRC-001"]
source_refs: ["<record-id>:<line-range>"]
dependencies: ["<ticket-id>"]
---
```

All fields are required; arrays may be empty. IDs are unique. Fingerprints and
lifecycle reference are immutable. The ticket does not duplicate mutable
status. Its body has non-empty Summary, Context and Evidence, Scope, Acceptance
Criteria, and Dependencies sections; acceptance has an unchecked item and
evidence has a source ref.

## Worklist Schema v1 and Lifecycle

The worklist starts with this exact YAML field order:

```yaml
---
schema: "ticket-operations/worklist"
schema_version: 1
generation_fingerprint: "sha256:<generation-fingerprint>"
source_fingerprint: "sha256:<source-fingerprint>"
source: "<source-display-identifier>"
ticket_count: <integer>
---
```

Then render `# Worklist: <source-slug>`, severity groups in
Critical/Major/Minor/Nit/Unclassified order, one entry per ticket, and complete
accounting:

```markdown
- [ ] TKT-001: <title>
  - Where: <comma-joined scope>
  - Why: <summary>
  - Done-when: <semicolon-joined criteria>
  - Ticket: ./TKT-001-<slug>.md
  - Fingerprint: sha256:<ticket-fingerprint>

## Source Item Accounting

| Source item | Source ref | Resolution |
|---|---|---|
```

Collapse subfield line breaks and escape accounting-cell pipes/newlines. The
entry marker is the sole lifecycle authority:

| Marker | Status |
|---|---|
| `[ ]` | `open` |
| `[>]` | `in_progress` |
| `[!]` | `blocked` |
| `[x]` / `[X]` | `done` |
| `[-]` | `cancelled` |

Future writers may add `Status-reason:` for blocked/cancelled and
`Completion-ref:` for done while preserving ID, `Ticket:`, and `Fingerprint:`.
Allowed transitions are open to in-progress/blocked/cancelled; in-progress to
open/blocked/done/cancelled; blocked to open/in-progress/cancelled; and explicit
reopen from done/cancelled to open.

This is a handoff contract, not future workflow. Consumers stop on duplicate
IDs, unknown markers, missing tickets, fingerprint mismatches, or identity
disagreement. `ticket-execute` can claim only `[ ]`; `ticket-update` can apply
valid transitions.

Legacy `address-worklist-commit-loop` consumes initial entries because its
checkbox and `Where:`, `Why:`, and `Done-when:` fields remain compatible. Its
successful `[ ]` to `[x]` writeback updates the sole status authority.

## Existing Output and Publication

Before writes, classify an absent destination as new. Under `error`, any existing
destination aborts. Under `reuse`, require matching worklist schema and
generation fingerprint, one unique entry per expected ID, and linked regular
tickets whose schema, IDs, fingerprints, and lifecycle refs match. Accept all
recognized current markers unchanged. Any missing, duplicate, malformed, or
mismatched record aborts as `existing ticket set conflict`.

Do not compare current markers with initial open state. Never suffix or
overwrite. An identical rerun is a no-op; later lifecycle changes survive; a
changed source, template, or shape at the same path conflicts.

Validate every parameter, path, input, token, byte, schema, ID, dependency,
link, and accounting total before creating anything. Dry run stops; interactive
mode waits for approval. For a validated new set:

1. create destination parents;
2. acquire exclusive sibling `<output-dir>.ticket-create.lock`;
3. write pre-rendered tickets by ID and `WORKLIST.md` last into a new sibling
   staging directory tied to the generation fingerprint;
4. reread and validate staged bytes;
5. recheck destination absence and atomically rename without replacement; and
6. remove the lock. On failure, remove only owned staging, lock, and newly
   created empty parents.

Use UTF-8, LF, fixed spacing, and one terminal newline.

## Workflow

1. Check activation; resolve and validate parameters.
2. Read the template and capture the canonical source snapshot.
3. Extract, transform, derive, order, assign IDs, and complete accounting.
4. Compute fingerprints and render all artifacts in memory.
5. Validate tokens, schemas, links, dependencies, totals, and destination.
6. Return the plan for dry run; otherwise obtain interactive approval when set.
7. Reuse a matching set or publish a new one atomically.
8. Report using the contract below.

## Output Format

Return these sections in order, omitting empty ones:

### Run Summary

Source identifier/kind; template; source and generation fingerprints; resolved
parameters; disposition (`planned`, `written`, `reused`, `declined`, `no-items`,
or `conflict`); and counts for source items, tickets, split roots, merged roots,
filtered, already-done, and already-managed.

### Ticket Plan

| ID | Title | Severity | Priority | Type | Estimate | Source items | Filename |
|---|---|---|---|---|---|---|---|

### Item Accounting

| Source item | Source ref | Resolution |
|---|---|---|

Include every root item in source order.

### Files

List absolute paths with `written`, `reused`, or `none (dry run)`.

### Open Questions

Group deterministic notes by ticket ID.

### Handoff

Name `WORKLIST.md` as lifecycle authority, report marker-derived status counts,
and state that no ticket was implemented and no git or remote operation ran.
