# Ticket List

## Task
List tickets in a local set. Read-only. Prefer the set's own list surface;
never hand-edit ticket files.

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
- [ ] Unknown `{target}` / missing CLI / invalid knobs → abort with one
      explanatory error and no partial list.
- [ ] No ticket file, worklist, or config is written.

## Guardrails
- MUST NOT hand-edit `tasks/*.md`, native tickets, `WORKLIST.md`, or
  `config.yml`.
- MUST NOT call create/edit/archive/execute skills.
- MUST use `backlog task list --plain` for Backlog.md sets (plus forwarded
  filters); MUST NOT scrape `tasks/` as a substitute.
- MUST treat native `WORKLIST.md` as projection only; authoritative status
  is ticket frontmatter when they disagree.
- Scope: list. Out of scope: create, update, execute, search beyond
  `{status}`/`{limit}`/`{sort}`, remote trackers.

## Workflow
1. Resolve `{target}` and set kind (Backlog.md vs native). Abort if neither.
2. Validate knobs for that kind; abort on unknown or inapplicable values.
3. Backlog.md: run `backlog task list --plain` with mapped filters; emit CLI
   plain text unchanged (prepend a one-line header naming `{target}`).
4. Native: snapshot tickets + managed `WORKLIST.md`; list from frontmatter
   (id, status, title), apply `{status}`/`{sort}`/`{limit}`; on worklist
   drift, list tickets and note drift in one footer line.
5. Stop.
