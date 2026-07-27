---
name: ticket-create
description: "Turn an analysis, review, plan, checklist, or inline recommendations into Backlog.md tasks through the backlog CLI, accounting for every source item exactly once. Use when the user asks to create tickets, ticketize findings, break work into tasks, or persist a backlog. Do not use for tracker integration, implementation, commits, or changes to an existing task."
license: MIT
---

# Ticket Create

## Activation

Use this skill to turn one source of proposed work into Backlog.md tasks.

Do not use it to produce the source analysis, operate GitHub/Jira/Linear, execute
task work, or revise an existing task. Execution belongs to `ticket-execute`;
later field and lifecycle changes belong to `ticket-update`.

## Task

Read one `{source}` snapshot, extract and normalize every work item, and create
one Backlog.md task per resulting item with `backlog task create`. Backlog.md
owns file naming, IDs, frontmatter, and ordinals. This skill owns the mapping
from source text to task fields and the accounting that proves no item was lost
or invented.

## Backlog.md Contract

These rules apply to every command this skill runs:

- Require `backlog` on `PATH` and an initialized project (`backlog/config.yml`,
  `.backlog/config.yml`, or `backlog.config.yml`). Missing either aborts with
  `install backlog.md (brew install backlog-md) and run backlog init`.
- Read `backlog instructions task-creation` before the first write and follow it.
- MUST NOT create, edit, move, or delete a file under the backlog directory by
  hand. Every read and write goes through the CLI.
- Read with `--plain`. Task IDs come from CLI output, never from a locally
  derived prefix or a guessed counter.
- Statuses, priorities, and task types are per-project. Read the accepted values
  from `backlog task create --help` and use only those.

## Parameters

- `{source}` — required work-item source. Accepts one UTF-8 Markdown file, a
  directory of `*.md` files, a reference to prior chat content, or inline items
  separated by newlines or semicolons.
- `{granularity}` — `one-to-one` | `split-composites` | `theme-grouped`;
  optional, default `split-composites`.
- `{min_severity}` — `critical` | `major` | `minor` | `nit`; optional, default
  includes all. `unclassified` items always remain.
- `{parent}` — optional existing task ID. Every created task becomes its
  subtask through `-p`.
- `{labels}` — optional extra labels applied to every created task.
- `{on_existing}` — `skip` | `create` | `error`; optional, default `skip`. See
  `## Duplicate Detection`.
- `{dry_run}` — optional boolean, default `false`. Complete extraction,
  accounting, and the command plan, then run no write command.
- `-i` / `--interactive` — optional. Show the validated plan once and require
  approval before the first `backlog task create`.

Unknown parameters abort before side effects.

## Success Criteria

- [ ] Validate parameters, the source, the CLI precondition, and the complete
      command plan before the first write.
- [ ] Account for every extracted source item exactly once as
      `ticketed(<id>)`, `split-into(<ids>)`, `merged-into(<ids>)`,
      `filtered(<reason>)`, `already-done`, or `skipped-existing(<id>)`.
- [ ] Every task cites at least one source ref through `--ref` and contains no
      invented fact.
- [ ] Every task carries acceptance criteria, a description, and a configured
      priority and type.
- [ ] Intra-batch dependencies resolve to real IDs returned by the CLI.
- [ ] Zero extracted items reports `_No work items found._` and creates nothing.
- [ ] The skill performs no implementation, tracker, branch, worktree, staging,
      commit, merge, push, or pull-request operation.

## Guardrails

- MUST keep `{source}` read-only.
- MUST NOT invent evidence, scope, dependencies, test commands, or completion.
  Use the fixed fallbacks below and report them under Open Questions.
- MUST NOT implement or verify a task.
- MUST NOT set a status other than the project default, check an acceptance
  criterion, or write a plan, notes, or a final summary. Creation captures
  intent; `ticket-execute` records progress.
- MUST NOT call an external tracker or tracker MCP tool.
- Scope: one source snapshot to a set of new tasks. Updating, executing, and
  remote synchronization are out of scope.

## Canonical Source

1. Decode UTF-8; remove one BOM; normalize CRLF/CR to LF. Invalid UTF-8 aborts.
2. Identify in-workspace files by workspace-relative POSIX path and outside
   files by normalized absolute path.
3. For a directory, recursively collect regular `*.md` files without following
   symlinks and sort identifiers by unsigned UTF-8 byte order.
4. For chat or inline input, use the nearest unambiguous preceding matching
   block.

Read the live source once. Extraction, evidence, and field derivation all use
that captured snapshot.

## Extraction

Walk canonical documents and lines in order. Assign source keys `SRC-001`,
`SRC-002`, ... before any transformation. Extract the first matching form:

1. critique findings shaped as `- **<criterion>** @ <location>` plus indented
   `Evidence`, `Rationale`, `Context`, `Why`, `Where`, `Done-when`,
   `Depends on`, `Severity`, `Type`, and `Estimate` fields;
2. Markdown checkbox items and their indented fields (`[x]` is `already-done`);
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
field names listed above and `:`. Remove that delimiter and all recognized
inline fields from the statement. Collapse all statement whitespace to one
ASCII space and trim it. A root source ref spans the item line through its last
indented child.

Then apply, in this order:

1. Merge exact duplicates with equal case-folded, whitespace-collapsed concern
   and sorted explicit locations. Preserve first wording; concatenate distinct
   explicit evidence, acceptance criteria, and refs in source order; keep the
   highest severity.
2. Under `split-composites` or `theme-grouped`, split only explicit independent
   child bullets, numbered child actions, or semicolon-separated action clauses
   that each carry their own location or acceptance criterion. Never split a
   bare conjunction by semantic guess. A fragment inherits the merged
   candidate's severity, context, dependencies, distinct evidence, and complete
   ordered source-ref union.
3. Under `theme-grouped`, merge only candidates with equal normalized criterion
   and complete sorted location list. Sharing a file or severity is
   insufficient.
4. Filter classified candidates below `{min_severity}`; retain `unclassified`.
5. Order by severity (`critical`, `major`, `minor`, `nit`, `unclassified`),
   source-file order, start line, fragment index, then normalized title bytes.

Every source key receives exactly one accounting outcome. Counts are over source
keys, not generated fragments. When a source key merges into a candidate that
later splits, its `merged-into(<ids>)` outcome lists every final ID descending
from that candidate. Serialize outcomes exactly as `ticketed(TKT-001)`,
`split-into(TKT-001,TKT-002)`, `merged-into(TKT-001,TKT-002)`,
`filtered(below-min-severity:<value>)`, `already-done`, or
`skipped-existing(TKT-001)`, with no spaces inside parentheses.

## Field Mapping

| Task field | CLI flag | Derivation |
|---|---|---|
| title | positional | For a critique finding, the exact criterion label; otherwise the source statement through its first `.`, `?`, or `!` that is followed by whitespace or the end of the text, so a path such as `src/util.ts` does not split the sentence. Preserve wording; truncate beyond 72 code points at the last whitespace by code point 69 and append `...`. |
| description | `-d` | Normalized source statement, then each distinct explicit `Why` or `Rationale` value, then a `### Context and Evidence` block with containing headings, explicit `Context` values, and each evidence value with its source ref, then a `### Scope` block listing in-scope locations and the out-of-scope statement. Do not paraphrase. |
| acceptance criteria | `--ac` per value | One flag per explicit `Done-when` or acceptance child in source order; fallback one criterion `Source requirement is satisfied: "<title>".` |
| priority | `--priority` | `critical`/`major` to `high`, `minor` to `medium`, `nit` to `low`, `unclassified` to `medium`. |
| type | `--type` | Explicit valid type, else first matching rule: every concrete location under `docs/` or ending `.md`/`.rst`/`.adoc` to `docs`; a location under `/test/`, `/tests/`, or a basename containing `.test.`, `.spec.`, `_test.`, or text containing `test`/`coverage` to `test`; text containing `refactor`/`restructure`/`rename`/`move` to `refactor`; text containing `fix`/`bug`/`broken`/`error`/`failure`/`incorrect`/`regression` to `fix`; a first word of `add`/`create`/`implement`/`introduce`/`support` to `feat`; otherwise `chore`. |
| labels | `-l` | Sorted unique lowercase ASCII slugs from explicit labels, the leading directory of each concrete location, the source slug, `{labels}`, and `estimate:<XS\|S\|M\|L\|XL>`. Form each slug from maximal ASCII alphanumeric runs after NFKD folding and combining-mark removal, joined with `-`. A location with no directory component contributes no label, and the criterion is not slugged because it belongs in the title. |
| references | `--ref` per value | Every source ref for the item, in source order. |
| parent | `-p` | `{parent}` when supplied. |

Derive the estimate from an explicit `XS|S|M|L|XL`, else `XS` without a concrete
location, `S` for one location, `M` for two or three in one module, `L` for more
or cross-module work, and `XL` only for an explicit architecture or migration.

When a derived type is not among the project's configured types, omit `--type`
and add the derived value as a label instead. Never pass a value the project
rejects.

Emit these Open Questions notes, in this order, whenever their fallback applies:
`Severity is unclassified; assign a severity before prioritization.`,
`Scope location is unspecified; identify the path, symbol, or module.`,
`Acceptance criteria were not supplied; review the generated fallback.` Use
`_None._` when none applies.

## Duplicate Detection

Before creating anything, run `backlog search "<title>" --plain` for each
candidate and read any close match with `backlog task view <id> --plain`. A
match is a task whose title, after case folding and whitespace collapse, equals
the candidate title.

- `{on_existing}=skip` records `skipped-existing(<id>)` and creates nothing for
  that candidate.
- `{on_existing}=create` creates the task anyway and reports the duplicate.
- `{on_existing}=error` aborts the whole run before the first write.

## Creation

Create tasks in the order assigned above, one `backlog task create ... --plain`
per task, and read the assigned ID from each command's output. Quote every
argument; use single quotes for any value containing a literal backtick so the
shell does not substitute it. Pass multi-line description text as real newlines
inside one quoted argument.

Dependencies come second, because an ID exists only after its task is created.
Once every task is created, map each explicit same-set dependency to its final
ID and apply them with one `backlog task edit <id> --dep <ids> --plain` per
dependent task. Resolve a dependency by exact source key, final ID, or unique
full title; an unresolved, self, or cyclic dependency aborts the dependency pass
and is reported. Never infer a dependency that the source does not state.

A failing create aborts the run. Report the tasks already created; they are real
and are not rolled back.

## Workflow

1. Check activation, validate parameters, and verify the Backlog.md contract.
2. Capture the source snapshot and extract items with total accounting.
3. Merge, split, filter, order, and derive fields.
4. Read configured statuses, priorities, and types from `backlog task create --help`.
5. Search for duplicates and apply `{on_existing}`.
6. Render the command plan. Stop for `{dry_run}` or declined approval.
7. Create tasks, then apply intra-batch dependencies.
8. Re-read the result with `backlog task list --plain` and report.

## Output Format

Return these sections in order:

### Run Summary

Source identifier and kind; resolved parameters; outcome (`created`,
`dry-run`, `declined`, `no-items`, or `failed`); and all accounting counts.

### Task Plan

| ID | Title | Priority | Type | Labels | Dependencies | Source refs |
|---|---|---|---|---|---|---|

### Item Accounting

One row per source key with its refs, statement, outcome, and final IDs.

### Open Questions

Every deterministic fallback or retained ambiguity; `_None._` when empty.

### Handoff

Name the backlog directory, state that all tasks were created at the project
default status with no acceptance criteria checked, and state that no
implementation, git history, or remote record changed.
