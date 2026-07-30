# Ticket List

## Task
List tickets in a local set and report them to the user. Strictly read-only:
no writes to ticket files, worklists, or config.

## Parameters
- `{target}` — optional path. Default: repo `backlog/` when it has
  Backlog.md `config.yml`; else abort. Accept a Backlog.md project dir, a
  native managed `WORKLIST.md`, a native ticket, or a dir with exactly one
  managed `WORKLIST.md`.
- `{status}` — optional status filter. Backlog.md: CLI status string
  (case-insensitive). Native: `open` | `in_progress` | `done` | `cancelled`.
- `{limit}` — optional positive integer; omit = no limit.
- `{sort}` — optional. Backlog.md: `priority` | `id` | `ordinal`. Native:
  `id` | `status`. Default: set's natural order.
- Extra `key=value` tokens abort as unknown.

## Success Criteria
- [ ] Output lists every matching ticket once: id, status, title; optional
      priority/type when the set provides them.
- [ ] Empty match → `_No tickets._` (exit success).
- [ ] Unknown `{target}` / invalid knobs → abort with one explanatory error
      and no partial list.
- [ ] When Backlog.md listing falls back to scraping `tasks/`, the report
      opens with a one-line warning naming why `backlog` failed.

## Guardrails
- Strictly read-only: report the list to the user; write nothing.
- Prefer `backlog task list --plain` for Backlog.md sets (plus forwarded
  filters). If the CLI is missing or fails, fall back to reading
  `tasks/*.md` and warn the user with the failure reason.
- MUST treat native `WORKLIST.md` as projection only; authoritative status
  is ticket frontmatter when they disagree.
- Scope: list. Out of scope: create, update, execute, search beyond
  `{status}`/`{limit}`/`{sort}`, remote trackers.

## Workflow
1. Resolve `{target}` and set kind (Backlog.md vs native). Abort if neither.
2. Validate knobs for that kind; abort on unknown or inapplicable values.
3. Backlog.md: run `backlog task list --plain` with mapped filters; emit CLI
   plain text unchanged (prepend a one-line header naming `{target}`). On
   CLI missing/failure, warn with the reason, then list from `tasks/*.md`
   (id, status, title; apply `{status}`/`{sort}`/`{limit}`).
4. Native: snapshot tickets + managed `WORKLIST.md`; list from frontmatter
   (id, status, title), apply `{status}`/`{sort}`/`{limit}`; on worklist
   drift, list tickets and note drift in one footer line.
