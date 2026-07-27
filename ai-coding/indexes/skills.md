# Skills Index

Canonical census of live skills under `ai-coding/plugins/*/skills/`. Generated
by `make skills-index`; edit the skill and regenerate rather than editing this
file. `make skills-index-check` fails when it has drifted.

- **Source root:** `ai-coding/plugins/*/skills/`
- **Count:** 15

## Parameter surface

Pass a `slug` (or full `path`) from this index to a command's `{artifact}` /
`{artifacts}` parameter, such as applying
[`stop-slop`](../plugins/writing/skills/stop-slop/SKILL.md) across every skill.
Enumerate every row when no filter is given. Descriptions are cut to 100
characters at a word boundary.

| # | slug | path | has_parameters | description |
|---:|---|---|---|---|
| 1 | `agent-swarm` | `ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md` | yes | Orchestrate parallel agent fan-out (best-of-N) for AI coding tasks — gate the swarm-vs-single... |
| 2 | `conventional-commits` | `ai-coding/plugins/git-operations/skills/conventional-commits/SKILL.md` | no | Format git commit messages following Conventional Commits 1.0.0 specification. Use when the user... |
| 3 | `declarative-design` | `ai-coding/plugins/design-suite/skills/declarative-design/SKILL.md` | no | Design a YAML DSL schema for a user-named domain — modeling entities, attributes, types,... |
| 4 | `design-skill` | `ai-coding/plugins/design-suite/skills/design-skill/SKILL.md` | no | Manually-invoked meta-skill that authors a new &lt;trait&gt;-design/SKILL.md against... |
| 5 | `designer-controller` | `ai-coding/plugins/design-suite/skills/designer-controller/SKILL.md` | no | Manually-invoked design controller that orchestrates one or more &lt;trait&gt;-design skills against a... |
| 6 | `deterministic-design` | `ai-coding/plugins/design-suite/skills/deterministic-design/SKILL.md` | no | Drive a systematic effort to enumerate and eliminate every source of non-determinism in a target... |
| 7 | `file-dump` | `ai-coding/plugins/session-state/skills/file-dump/SKILL.md` | yes | Dump ad-hoc content from the current session — an analysis, review, report, comparison, plan,... |
| 8 | `minimal-diffs` | `ai-coding/plugins/git-operations/skills/minimal-diffs/SKILL.md` | no | Apply minimal, surgical changes when creating, editing, modifying, refactoring, or fixing any... |
| 9 | `prompt-template-library` | `ai-coding/plugins/writing/skills/prompt-template-library/SKILL.md` | yes | Pick a starting skeleton from the prompt template library when an agent is drafting a new... |
| 10 | `stop-slop` | `ai-coding/plugins/writing/skills/stop-slop/SKILL.md` | no | Remove AI writing patterns from prose. Use when drafting, editing, or reviewing text to... |
| 11 | `ticket-create` | `ai-coding/plugins/ticket-operations/skills/ticket-create/SKILL.md` | yes | Turn an analysis, review, plan, checklist, or inline recommendations into Backlog.md tasks... |
| 12 | `ticket-execute` | `ai-coding/plugins/ticket-operations/skills/ticket-execute/SKILL.md` | yes | Work Backlog.md tasks to Done through the backlog CLI: plan, implement, prove every acceptance... |
| 13 | `ticket-update` | `ai-coding/plugins/ticket-operations/skills/ticket-update/SKILL.md` | yes | Change fields or status on existing Backlog.md tasks through the backlog CLI, applying only what... |
| 14 | `trajectory-snapshot` | `ai-coding/plugins/session-state/skills/trajectory-snapshot/SKILL.md` | yes | Snapshot the current agent session's trajectory into a file at a chosen granularity — verbatim... |
| 15 | `worktree-task` | `ai-coding/plugins/orchestration/skills/worktree-task/SKILL.md` | yes | Launch agents in isolated git worktrees to execute a task end-to-end, then present per-worktree... |

## Slug list

Comma-separated slugs for command parameters:

```text
agent-swarm, conventional-commits, declarative-design, design-skill, designer-controller, deterministic-design, file-dump, minimal-diffs, prompt-template-library, stop-slop, ticket-create, ticket-execute, ticket-update, trajectory-snapshot, worktree-task
```

## Path list

```text
ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md
ai-coding/plugins/git-operations/skills/conventional-commits/SKILL.md
ai-coding/plugins/design-suite/skills/declarative-design/SKILL.md
ai-coding/plugins/design-suite/skills/design-skill/SKILL.md
ai-coding/plugins/design-suite/skills/designer-controller/SKILL.md
ai-coding/plugins/design-suite/skills/deterministic-design/SKILL.md
ai-coding/plugins/session-state/skills/file-dump/SKILL.md
ai-coding/plugins/git-operations/skills/minimal-diffs/SKILL.md
ai-coding/plugins/writing/skills/prompt-template-library/SKILL.md
ai-coding/plugins/writing/skills/stop-slop/SKILL.md
ai-coding/plugins/ticket-operations/skills/ticket-create/SKILL.md
ai-coding/plugins/ticket-operations/skills/ticket-execute/SKILL.md
ai-coding/plugins/ticket-operations/skills/ticket-update/SKILL.md
ai-coding/plugins/session-state/skills/trajectory-snapshot/SKILL.md
ai-coding/plugins/orchestration/skills/worktree-task/SKILL.md
```
