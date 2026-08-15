# Skill auto-attach verification

How to confirm that a coding-agent client lists all 15 skills this repository
ships, plus a log of recorded observations.

`docs/reports/skill-auto-attach-2026-07-26.md` found a cloud agent that read
`AGENTS.md` yet was offered zero skills, because every mirror entry was a
symlink and at least one discovery implementation drops a symlinked entry.
TKT-001 replaced the mirrors with real directories. That report left one gap
open: no client was ever observed listing the skills, only the filesystem was
inspected. This procedure closes that gap and records the check so a future
layout change can be re-verified instead of re-argued.

## The 15 skills

The source of truth is `ai-coding/plugins/*/skills/`. Regenerate the expected
list any time:

```sh
find ai-coding/plugins/*/skills -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort
```

| Skill | Plugin |
|---|---|
| agent-swarm | orchestration |
| conventional-commits | git-operations |
| design-skill | design-suite |
| designer | design-suite |
| excalidraw-diagrams | excalidraw |
| file-dump | session-state |
| flint-chart-author | flint-chart |
| minimal-diffs | git-operations |
| prompt-template-library | writing |
| simple-english | writing |
| stop-slop | writing |
| ticket-crud | ticket-operations |
| ticket-execute | ticket-operations |
| trajectory-snapshot | session-state |
| worktree-task | orchestration |

## Precondition: mirrors must be real directories

Each client reads project skills from its own mirror root — `.claude/skills/`,
`.cursor/skills/`, `.opencode/skills/` — a flattened copy of the source tree. A
symlinked mirror entry is skipped by at least one discovery implementation,
which is what produced the zero-skills run. Confirm no mirror entry is a
symlink and that the mirrors still match the source before testing a client:

```sh
find .cursor .claude .opencode -maxdepth 2 -type l   # prints nothing
make mirrors-check                                    # exits 0 when mirrors match source
```

## Procedure per client

A pass lists every name from [The 15 skills](#the-15-skills); a miss is any
name absent from the client's own list.

- **Claude Code (web or cloud).** Claude Code loads project skills from
  `.claude/skills/`. Open a session with this repository as the working
  directory; a Claude Code on the web session provisions it through the
  `SessionStart` hook. The session's available-skills list — shown to the agent
  in its context and to you in the skills UI — must contain all 15 names. A
  fresh cloud run reports the list in its own context, so recording those 15
  names is the observation.
- **Cursor.** Open the repository in Cursor and view the Skills panel. Confirm
  15 project skills sourced from `.cursor/skills/`. The `cursor-agent` CLI
  cannot enumerate skills without authentication (`CURSOR_API_KEY`, or
  `agent login`), so on an unauthenticated cloud VM the panel is the only
  confirmation surface.
- **OpenCode.** Open the repository in OpenCode and confirm the 15 skills from
  `.opencode/skills/` appear in its skill list.

## Observations

### 2026-08-15 — Claude Code cloud agent — all 15 listed

- Client: Claude Code, cloud agent run (`CLAUDE_CODE_REMOTE=true`).
- Repo state: branch `claude/session-start-d6yapu` at `66bbd65`.
- Precondition: `find .cursor .claude .opencode -maxdepth 2 -type l` printed
  nothing, and `make mirrors-check` exited 0 — the mirrors are real directories
  matching the source (TKT-001 fix in place).
- Result: the session's available-skills list included all 15 project skills —
  agent-swarm, conventional-commits, design-skill, designer,
  excalidraw-diagrams, file-dump, flint-chart-author, minimal-diffs,
  prompt-template-library, simple-english, stop-slop, ticket-crud,
  ticket-execute, trajectory-snapshot, worktree-task.
- Significance: the first recorded case of a live client, rather than
  filesystem inspection, offering the full set. It confirms the
  symlink-to-real-directory fix reaches a real Claude Code client.
