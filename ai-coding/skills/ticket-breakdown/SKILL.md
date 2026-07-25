---
name: ticket-breakdown
description: "Split an analysis of work items — a critique report, code review, task list, or plan — into discrete, right-sized ticket files rendered from a parameterized ticket template, plus a WORKLIST.md index consumable by the address-worklist-commit-loop command. Use when the user asks to split an analysis into tickets, break findings into tickets, ticketize a report or review, turn action items into work-item tickets, or generate a ticket backlog from an analysis. For addressing items commit-by-commit use address-worklist-commit-loop; for producing the analysis itself use the critique command; for dumping raw session content to a file use file-dump."
license: MIT
---

# Ticket Breakdown

## Task

Split one `{analysis}` — a document containing work items: severity-grouped findings (e.g. `/critique` output), `- [ ]` checkbox task lists, numbered action items, or prose recommendations — into discrete tickets. Extract and normalize every work item, apply the `{granularity}` splitting rules, render one ticket per resulting item from the parameterized ticket template ([./TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md) by default), and persist the tickets plus a `WORKLIST.md` index in the checkbox-and-subfields format that `/address-worklist-commit-loop` consumes directly.

Deferral: producing the analysis is `/critique`'s job; addressing the tickets commit-by-commit is `/address-worklist-commit-loop`'s job; dumping arbitrary session content to a single file is the `file-dump` skill's job. This skill owns the middle motion: analysis in, ticket backlog out. It never implements, fixes, or addresses any ticket it produces.

## Parameters

- `{analysis}` — the work-item source to split; required. Accepts any of:
  - a filesystem path to a markdown file (severity-grouped findings, checkbox lists, numbered action items, or prose recommendations are all extracted);
  - a directory path; every `*.md` file inside is read and treated as one combined source, with per-file `source_ref`s;
  - a reference to prior chat content (e.g., `"the findings above"`); the agent resolves the reference to the most recent matching block and parses it with the same rules as a markdown source;
  - inline items in the invocation itself, separated by newlines or `;`.
- `{ticket_template}` — path to the ticket template rendered per ticket; optional, default: this skill's own [./TICKET_TEMPLATE.md](./TICKET_TEMPLATE.md). A custom template MAY use any subset of the token vocabulary in `## Template Contract`; a token outside the vocabulary aborts with an error listing the available tokens.
- `{granularity}` — splitting policy; optional, default: `split-composites`. Allowed values:
  - `one-to-one` — one ticket per extracted item; only exact duplicates (same location plus same concern) merge.
  - `split-composites` — `one-to-one`, plus any item naming multiple independently shippable concerns (distinct fixes in distinct locations, "and also" clauses, acceptance spanning unrelated modules) is split into one ticket per concern; fragments inherit the parent's severity, evidence, and `source_ref`.
  - `theme-grouped` — `split-composites`, then tickets forming one coherent change against the same module or theme merge into a single ticket carrying every member's `source_ref` and the highest member severity.
- `{min_severity}` — lowest severity to ticket, over the order `critical > major > minor > nit`; optional, default: include all. Items below the threshold are filtered and reported, never silently dropped. Items with no derivable severity are `unclassified`: they are always retained, and the report marks them `severity filter not applicable`.
- `{id_prefix}` — ticket id prefix; optional, default: `TKT`. MUST match `^[A-Z][A-Z0-9]{1,9}$`. Ids render as `{id_prefix}-NNN`, zero-padded to 3 digits.
- `{output_dir}` — directory the tickets and worklist are written into; optional, default: `.ai-coding-artifacts/tickets/<analysis-slug>/`, resolved against the workspace root (MAY be absolute). `<analysis-slug>` is the kebab-case of the source file's basename without extension; for chat or inline sources it is a 1–5-word kebab-case slug derived from the content; `analysis` when underivable. Rejected when `{persistence}` is `chat`.
- `{persistence}` — `files` | `chat`; optional, default: `files`. `files` writes the tickets and worklist under `{output_dir}`; `chat` renders every ticket inline in the response and writes nothing.
- `{emit_worklist}` — whether `WORKLIST.md` is written at the root of `{output_dir}`; optional, default: `true`. Meaningful only when `{persistence}` is `files`; setting it explicitly with `{persistence}` = `chat` aborts.
- `{dry_run}` — flag; when `true`, emit the ticket plan table and item accounting, then stop: no template render, no writes, no approval prompt. Takes precedence over `{persistence}`. Optional, default: `false`.
- `-i` / `--interactive` — flag. When present, ask clarifying questions about ambiguous `{analysis}` content and present the ticket plan for approval before rendering or writing; on decline, stop with the plan as the only output. When absent, ask nothing; ambiguities surface only in the report's Open Questions section. Optional. Default: absent.

## Success Criteria

- [ ] Parameter validation completes before any read or write: `{granularity}` / `{persistence}` take allowed values, `{id_prefix}` matches its pattern, `{min_severity}` is one of the four severities, and an explicit `{output_dir}` or explicit `{emit_worklist}` combined with `{persistence}` = `chat` is rejected. Validation failure aborts with an explanatory error naming the offending parameter and zero filesystem side effects.
- [ ] The ticket template is read from `{ticket_template}` at invocation time and used as the render contract; an unreadable path aborts with `cannot read ticket template: <path>`.
- [ ] Every ticket traces to at least one extracted work item: `{source_ref}` points into `{analysis}` (`<path>:<line-range>` or a section identifier), and `{evidence}` quotes or references the analysis. No ticket is fabricated.
- [ ] Item accounting is total: every extracted item resolves to exactly one of `ticketed (<id>)`, `split-into (<ids>)`, `merged-into (<id>)`, `filtered (below {min_severity})`, or `already-done`, and the report lists the mapping. Items the source already marks done (`- [x]`) are excluded from ticketing and counted separately.
- [ ] Rendered tickets contain no unresolved `{…}` tokens and no template remnants (frontmatter, the `<!-- TEMPLATE FILE -->` comment, italic guidance notes). A template token the skill cannot produce for an item aborts before any file is written, naming the token.
- [ ] Ticket ids are deterministic: items are ordered by severity rank (`critical`, `major`, `minor`, `nit`, `unclassified`) then by source order within rank, and ids are assigned in that order. Identical `{analysis}` content plus identical parameters yield identical ids, filenames, and section structure across runs; free-text field wording is drafted per run but its factual content does not vary. Rendered artifacts carry no timestamps.
- [ ] Ticket filenames are `<id>-<slug>.md` where `<slug>` is a 1–6-word kebab-case slug of the title. Nothing is overwritten: when the resolved `{output_dir}` already exists and is non-empty, a `-2` (then `-3`, …) suffix is appended to the directory name; within a run, two tickets resolving to the same filename get a `-2` (then `-3`, …) suffix before the extension.
- [ ] When `{emit_worklist}` is `true`, `WORKLIST.md` exists at the root of the resolved output directory and parses under `/address-worklist-commit-loop`'s rules: one `- [ ]` item per ticket with `Where:` / `Why:` / `Done-when:` / `Ticket:` subfields, grouped under severity headings `Critical` / `Major` / `Minor` / `Nit` (plus `Unclassified` for items without severity, which the loop treats as severity-less).
- [ ] When `{dry_run}` is `true`, the response contains only the plan table and item accounting; no file is created and no approval is requested.
- [ ] When `{persistence}` is `chat`, every rendered ticket appears inline in the response and no file is created.
- [ ] Zero extracted items produce a report stating `_No work items found._` and no files, not an empty ticket directory.

## Guardrails

- MUST NOT modify `{analysis}` or any file outside the resolved `{output_dir}`; the analysis is read-only input.
- MUST NOT fabricate work items: every ticket cites evidence quoted or referenced from `{analysis}`; unknown field values render as their documented defaults (`{dependencies}` `None.`, `{labels}` derived, `{estimate}` judged), never invented facts.
- MUST read `{ticket_template}` at invocation time and render against it; MUST NOT inline, paraphrase, or hard-code the template body into this skill's own instructions, and MUST NOT substitute a built-in skeleton when the template is unreadable.
- MUST NOT overwrite any existing file or directory; resolve collisions with numeric suffixes as documented.
- MUST NOT implement, fix, or address any ticket; the deliverable is the backlog, not the changes it describes.
- MUST NOT export tickets to external trackers (GitHub Issues, Jira, Linear, MCP endpoints); tickets are markdown files. Importing them anywhere is the user's call.
- MUST NOT commit, push, open PRs, create branches or worktrees, or edit `.gitignore` (the default `{output_dir}` root is already ignored; an explicit tracked `{output_dir}` is the user's decision to commit or not).
- Scope: split one `{analysis}` into ticket files plus a worklist index. Out of scope: producing the analysis, addressing tickets, tracker integration, authoring new templates beyond rendering the configured one.

## Splitting Rules

One ticket is one independently shippable concern: a change one focused commit (or one tightly scoped change set) can deliver and verify. Apply the rules in this order under every `{granularity}`:

1. **Extract.** Capture each finding (`- **<criterion>** @ <location>` blocks under severity headings), checkbox item (with `Where:` / `Why:` / `Done-when:` subfields when present), numbered action item, or imperative recommendation as one work item with `{title, severity, where, evidence, done_when, source_ref}`. Severity comes from the item's severity heading or label; foreign scales normalize (`blocker` → `critical`; `high` → `major`; `medium` → `minor`; `low` / `trivial` → `nit`); underivable severity is `unclassified`.
2. **Merge exact duplicates.** Items with the same location and the same concern merge into one item whose evidence concatenates both, regardless of `{granularity}`.
3. **Split composites** (`split-composites`, `theme-grouped`). An item is composite when it names concerns that ship independently: distinct fixes at distinct locations, conjunctions joining unrelated changes, or acceptance criteria spanning unrelated modules. Each fragment becomes its own item inheriting the parent's severity, evidence, and `source_ref`; the accounting records `split-into`.
4. **Group by theme** (`theme-grouped` only). Items that form one coherent change against the same module or theme merge: acceptance criteria concatenate, `source_ref`s accumulate, severity is the highest member's. Items merely sharing a file do not merge unless the change is genuinely one unit of work.
5. **Filter.** Drop items strictly below `{min_severity}` into `filtered`; retain `unclassified` items with a `severity filter not applicable` note.

## Field Derivation

Per-ticket fields are derived from the normalized item, deterministically where a rule can decide:

- `{ticket_id}` — `{id_prefix}-NNN` in severity-rank-then-source order.
- `{title}` — imperative mood, `<= 72` characters, specific enough to stand alone in a backlog listing (matches the commit-subject derivation `/address-worklist-commit-loop` applies to item titles).
- `{type}` — the Conventional Commits type the fix would carry, chosen with the `conventional-commits` skill's decision framework (`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`); `chore` when ambiguous.
- `{severity}` / `{priority}` — fixed mapping: `critical` → `P0`, `major` → `P1`, `minor` → `P2`, `nit` → `P3`, `unclassified` → `P2`.
- `{labels}` — comma-separated lowercase tags derived from the item's criterion (e.g. `robustness`, `determinism`), module or path slug, and the analysis-source slug.
- `{estimate}` — advisory t-shirt size: `XS` single-file one-liner; `S` single-file, localized; `M` multi-file within one module; `L` cross-module; `XL` architectural.
- `{where}` — affected paths, symbols, or modules, from the item's location and `Where:` subfield.
- `{done_when}` — checkbox list of observable acceptance criteria: the item's `Done-when:` text verbatim when present, otherwise synthesized as concrete checks grounded in the evidence (a command that passes, a behavior that reproduces no longer, a document section that exists).
- `{dependencies}` — ticket ids whose completion this ticket's acceptance requires (typically ordering among split fragments); `None.` otherwise.

## Template Contract

The template is read at invocation and rendered once per ticket. Rendering strips the template's frontmatter, its `<!-- TEMPLATE FILE -->` HTML comment, and every italic *guidance note*, then substitutes every token below. Single-line tokens: `{ticket_id}`, `{title}`, `{type}`, `{severity}`, `{priority}`, `{labels}`, `{estimate}`, `{source}` (the resolved analysis identifier: path, `chat:<anchor>`, or `inline`), `{source_ref}`, `{out_of_scope}`. Paragraph tokens: `{summary}` (1–3 sentences), `{context}` (background a reader needs before the evidence). Block tokens, rendered as markdown lists: `{evidence}` (quote bullets citing `{analysis}`), `{where}` (path/module bullets), `{done_when}` (`- [ ]` checkboxes), `{dependencies}` (ticket-id bullets or `None.`).

A custom `{ticket_template}` MAY reference any subset of these tokens; tokens outside the vocabulary abort with `unknown template token: <token>; available tokens: <list>`.

## Worklist Format

When `{emit_worklist}` is `true`, write `WORKLIST.md` at the root of the resolved output directory:

````markdown
# Worklist: <analysis-slug>

Generated by the ticket-breakdown skill from `<source>`. One `- [ ]` item per
ticket; consumable by /address-worklist-commit-loop. Ticket files sit beside
this index.

## Critical

- [ ] TKT-001: <title>
  - Where: <comma-joined {where}>
  - Why: <first sentence of {summary}>
  - Done-when: <semicolon-joined {done_when} criteria>
  - Ticket: ./TKT-001-<slug>.md

## Major

- [ ] TKT-002: ...
````

Severity headings appear in the order `Critical`, `Major`, `Minor`, `Nit`, `Unclassified`; empty sections are omitted. The `Where:` / `Why:` / `Done-when:` subfields are the loop's captured subfields; `Ticket:` is a back-pointer the loop ignores but humans and agents follow for the full ticket.

## Workflow

1. **Parse and validate.** Extract every parameter, apply defaults, and run every check named in Success Criteria. Abort on the first failure with an explanatory error and zero filesystem side effects.
2. **Resolve `{analysis}`.** Read the file, directory (every `*.md` inside), chat reference, or inline items; record what was loaded and what was skipped or unreachable. An empty or unresolvable source stops here with `_No work items found._` or an explanatory error.
3. **Resolve the template.** Read `{ticket_template}` in full; enumerate the tokens its body references and confirm each is in the vocabulary.
4. **Extract and normalize.** Apply Splitting Rules step 1; exclude `- [x]` items into `already-done`.
5. **Split, merge, filter.** Apply Splitting Rules steps 2–5 per `{granularity}` and `{min_severity}`; build the total accounting map.
6. **Derive fields and ids.** Order items by severity rank then source order; assign `{id_prefix}-NNN`; derive every field per Field Derivation.
7. **Plan gate.** Render the plan table. When `{dry_run}` is `true`, emit the plan and accounting and stop. When `-i` / `--interactive` is present, present the plan and wait for approval; on decline, stop with the plan as the only output.
8. **Render.** For each ticket, render the template with the ticket's fields; verify no unresolved tokens remain.
9. **Persist.** `files`: resolve the output directory (append `-2`, `-3`, … when it exists non-empty), create it, write each ticket file (file-level collision suffix within the run), and write `WORKLIST.md` when `{emit_worklist}` is `true`. `chat`: emit every rendered ticket inline instead.
10. **Report** per Output Format.

## Output Format

A single markdown response with these sections, in order; omit any section whose body would be empty.

### Run Summary

- `Analysis`: resolved identifier and kind (`file` / `directory` / `chat` / `inline`).
- `Template`: resolved `{ticket_template}` path.
- `Granularity`, `Min severity`, `Persistence`, `Output dir` (resolved absolute path, or `chat`), `Worklist` (`written` / `skipped` / `n/a`), `Dry run`.
- `Counts`: items extracted / already-done / merged / split / filtered / tickets rendered.

### Ticket Plan

| Id | Title | Severity | Priority | Type | Estimate | Source ref | Derivation |
|---|---|---|---|---|---|---|---|

`Derivation` is `1:1`, `split from <item>`, or `merged (<n> items)`. This table is the entire body in `{dry_run}` mode and the approval artifact in interactive mode.

### Item Accounting

One bullet per extracted item that did not map `1:1`: its source ref and its resolution (`split-into`, `merged-into`, `filtered`, `already-done`).

### Files Written

One bullet per file with its path, or `none (persistence=chat)` / `none (dry run)`.

### Open Questions

Ambiguities in `{analysis}` that forced a judgment call (unlabeled severity, unclear scope boundaries, items that read as observations rather than work).

### Next Steps

- How to address the backlog: `/address-worklist-commit-loop {worklist}=<output-dir>/WORKLIST.md` when the worklist was written.
- A reminder that nothing was committed and the analysis was not modified.

## Worked Example

Invocation: `ticket-breakdown {analysis}=critique-report.md` (defaults: `split-composites`, `files`, worklist on). One critical finding in the source:

```markdown
### Critical
- **Determinism / idempotency** @ `install.sh:123-128`
  - Evidence: the re-run guard greps for a marker written with zsh-only `print`;
    under bash the marker is never written and three consecutive runs appended
    three duplicate source lines to the profile.
  - Rationale: bash is an explicitly supported shell, so for any bash user
    `~/.bashrc` grows one duplicate block per re-run.
```

Rendered `TKT-001-write-shell-extras-marker-portably.md` (excerpt):

```markdown
# TKT-001: write the shell-extras marker portably so re-runs stay idempotent

- **Type:** fix
- **Severity:** critical
- **Priority:** P0
- **Labels:** determinism, idempotency, install
- **Estimate:** S
- **Source:** critique-report.md
- **Source ref:** critique-report.md:46-57

## Summary

The install script's re-run guard greps for a marker line that is written with
zsh-only `print`, so bash users never get the marker and every re-run appends
a duplicate shell-extras block to `~/.bashrc`.

...

## Acceptance Criteria

- [ ] The marker line is written with a shell-portable command (`printf` or `echo`).
- [ ] Running the install twice under bash leaves exactly one shell-extras block in the profile.
```

And the matching `WORKLIST.md` entry under `## Critical`:

```markdown
- [ ] TKT-001: write the shell-extras marker portably so re-runs stay idempotent
  - Where: install.sh:123-128
  - Why: bash users never get the re-run marker, so every install re-run appends a duplicate block.
  - Done-when: marker written portably; double install under bash leaves one shell-extras block
  - Ticket: ./TKT-001-write-shell-extras-marker-portably.md
```

## Composition

Upstream, `/critique`'s severity-grouped findings report is a first-class `{analysis}` input; this skill's extraction rules match that report's finding shape (`- **<criterion>** @ <location>` with Evidence and Rationale sub-bullets). Downstream, the emitted `WORKLIST.md` satisfies `/address-worklist-commit-loop`'s markdown source contract (checkbox items, `Where:` / `Why:` / `Done-when:` subfields, severity headings), so `critique → ticket-breakdown → address-worklist-commit-loop` is a complete find-plan-fix pipeline with tickets as the durable middle artifact. The default output root `.ai-coding-artifacts/` follows the `file-dump` skill's artifact-directory convention and is gitignored in this repo.
