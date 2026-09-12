# Skills Index

Canonical census of live skills under `ai-coding/plugins/*/skills/`. Generated
by `make skills-index`; edit the skill and regenerate rather than editing this
file. `make skills-index-check` fails when it has drifted.

- **Source root:** `ai-coding/plugins/*/skills/`
- **Count:** 17

## Parameter surface

Pass a `slug` (or full `path`) from this index to a command's `{artifact}` /
`{artifacts}` parameter, such as applying
[`stop-slop`](../plugins/writing/skills/stop-slop/SKILL.md) across every skill.
Enumerate every row when no filter is given. Descriptions are cut to 100
characters at a word boundary.

| # | slug | path | has_parameters | description |
|---:|---|---|---|---|
| 1 | `agent-swarm` | `ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md` | yes | Orchestrate parallel agent fan-out (best-of-N) for AI coding tasks — gate the swarm-vs-single... |
| 2 | `artifact-researcher` | `ai-coding/plugins/artifact-researcher/skills/artifact-researcher/SKILL.md` | no | Route an analysis type across one or more artifacts — a single repo, a repo collection, or a... |
| 3 | `conventional-commits` | `ai-coding/plugins/git-operations/skills/conventional-commits/SKILL.md` | no | Format git commit messages following Conventional Commits 1.0.0 specification. Use when the user... |
| 4 | `design-skill` | `ai-coding/plugins/design-suite/skills/design-skill/SKILL.md` | no | Manually-invoked meta-skill that authors a new designer trait card against... |
| 5 | `designer` | `ai-coding/plugins/design-suite/skills/designer/SKILL.md` | no | Manually-invoked design controller that applies one or more design traits — declarative (YAML... |
| 6 | `excalidraw-diagrams` | `ai-coding/plugins/excalidraw/skills/excalidraw-diagrams/SKILL.md` | no | Generate hand-drawn Excalidraw diagrams (architecture, flowcharts, sequence diagrams, sketches)... |
| 7 | `file-dump` | `ai-coding/plugins/session-state/skills/file-dump/SKILL.md` | yes | Dump ad-hoc content from the current session — an analysis, review, report, comparison, plan,... |
| 8 | `flint-chart-author` | `ai-coding/plugins/flint-chart/skills/flint-chart-author/SKILL.md` | no | Use when: the user asks to make or render charts with flint-chart, visualize tabular data,... |
| 9 | `manage-packages` | `ai-coding/plugins/dotfiles-dev/skills/manage-packages/SKILL.md` | yes | Add, delete, or update packages in this dotfiles repo's Brewfile, mas.Brewfile, snap installs,... |
| 10 | `minimal-diffs` | `ai-coding/plugins/git-operations/skills/minimal-diffs/SKILL.md` | no | Apply minimal, surgical changes when creating, editing, modifying, refactoring, or fixing any... |
| 11 | `prompt-template-library` | `ai-coding/plugins/writing/skills/prompt-template-library/SKILL.md` | yes | Pick a starting skeleton from the prompt template library when an agent is drafting a new... |
| 12 | `simple-english` | `ai-coding/plugins/writing/skills/simple-english/SKILL.md` | no | Write or rewrite technical text with the rules of ASD-STE100 Simplified Technical English so it... |
| 13 | `stop-slop` | `ai-coding/plugins/writing/skills/stop-slop/SKILL.md` | no | Remove AI writing patterns from prose. Use when drafting, editing, or reviewing text to... |
| 14 | `ticket-crud` | `ai-coding/plugins/ticket-operations/skills/ticket-crud/SKILL.md` | yes | Create a new local Markdown ticket set and WORKLIST.md from an analysis, review, plan, or... |
| 15 | `ticket-execute` | `ai-coding/plugins/ticket-operations/skills/ticket-execute/SKILL.md` | yes | Execute open runnable tickets from a native local Markdown ticket set, verify acceptance with... |
| 16 | `trajectory-snapshot` | `ai-coding/plugins/session-state/skills/trajectory-snapshot/SKILL.md` | yes | Snapshot the current agent session's trajectory into a file at a chosen granularity — verbatim... |
| 17 | `worktree-task` | `ai-coding/plugins/orchestration/skills/worktree-task/SKILL.md` | yes | Launch agents in isolated git worktrees to execute a task end-to-end, then present per-worktree... |

## Slug list

Comma-separated slugs for command parameters:

```text
agent-swarm, artifact-researcher, conventional-commits, design-skill, designer, excalidraw-diagrams, file-dump, flint-chart-author, manage-packages, minimal-diffs, prompt-template-library, simple-english, stop-slop, ticket-crud, ticket-execute, trajectory-snapshot, worktree-task
```

## Path list

```text
ai-coding/plugins/orchestration/skills/agent-swarm/SKILL.md
ai-coding/plugins/artifact-researcher/skills/artifact-researcher/SKILL.md
ai-coding/plugins/git-operations/skills/conventional-commits/SKILL.md
ai-coding/plugins/design-suite/skills/design-skill/SKILL.md
ai-coding/plugins/design-suite/skills/designer/SKILL.md
ai-coding/plugins/excalidraw/skills/excalidraw-diagrams/SKILL.md
ai-coding/plugins/session-state/skills/file-dump/SKILL.md
ai-coding/plugins/flint-chart/skills/flint-chart-author/SKILL.md
ai-coding/plugins/dotfiles-dev/skills/manage-packages/SKILL.md
ai-coding/plugins/git-operations/skills/minimal-diffs/SKILL.md
ai-coding/plugins/writing/skills/prompt-template-library/SKILL.md
ai-coding/plugins/writing/skills/simple-english/SKILL.md
ai-coding/plugins/writing/skills/stop-slop/SKILL.md
ai-coding/plugins/ticket-operations/skills/ticket-crud/SKILL.md
ai-coding/plugins/ticket-operations/skills/ticket-execute/SKILL.md
ai-coding/plugins/session-state/skills/trajectory-snapshot/SKILL.md
ai-coding/plugins/orchestration/skills/worktree-task/SKILL.md
```
