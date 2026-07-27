# AGENTS.md

## Backlog.md ticket set

This directory is a [Backlog.md](https://github.com/MrLesk/Backlog.md) project
and the repo's canonical work-item set: `config.yml` holds project settings
(`task_prefix: tkt`, statuses `To Do` / `In Progress` / `Done`) and `tasks/`
holds one Markdown task per item.

Every interaction with this directory and its tickets goes through the
`backlog` CLI. Never hand-edit `tasks/*.md` or `config.yml`: the CLI owns task
IDs, ordinals, frontmatter field types, and the `SECTION:DESCRIPTION` /
`AC` marker structure, and raw edits corrupt them.

`backlog --help` lists every command; each command's flags are authoritative
in its own help menu, not here:

| Intent | Help menu |
|---|---|
| Create a task | `backlog task create --help` |
| Edit fields, status, acceptance criteria | `backlog task edit --help` |
| List open work | `backlog task list --help` |
| Read one task | `backlog task view --help` |
| Search | `backlog search --help` |
| Board projection / export | `backlog board --help` |

Pass `--plain` on read commands for non-interactive, agent-friendly output
instead of the TUI.

The CLI ships as the npm package `backlog.md` and the Homebrew formula
`backlog-md` (in the repo `Brewfile`). Cloud VMs have no Homebrew; when
`backlog` is missing, install it with `npm i -g backlog.md`.

## Ticket procedure: ticket-operations skills

Before create, execute, or update work on tickets here, read the matching
skill in full:

| Intent | Skill |
|---|---|
| Ticketize findings, or edit status, definitions, metadata | `ai-coding/plugins/ticket-operations/skills/crud-tickets/SKILL.md` |
| Implement, verify, commit | `ai-coding/plugins/ticket-operations/skills/ticket-execute/SKILL.md` |

These tasks are Backlog.md-native, not `ticket-operations/ticket` schema v1,
so the skills' native-set preflights do not apply here; follow their
procedural contracts and route all reads and writes through the `backlog`
CLI. Status mapping: `To Do` = `open`, `In Progress` = `in_progress`,
`Done` = `done`. `ticket-execute` additionally composes the `minimal-diffs`
and `conventional-commits` skills from the `git-operations` plugin.

## Execution contract

- Respect frontmatter `dependencies`; claim a task only when its dependencies
  are `Done`.
- Prove every acceptance criterion with runtime evidence before moving a task
  to `Done`; a checked box alone never completes a task.
- Create exactly one Conventional Commit per completed task, referencing its
  ID (e.g. `tkt-009`).
- No external tracker APIs; this local set is the only ticket authority.
