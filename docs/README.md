# Docs

Repository documentation and agent-generated analysis artifacts.

## Layout

| Path | Purpose |
|---|---|
| `reports/` | Committed critique, review, and analysis reports (for example `/critique` and `/agent-swarm` outputs). |

## Conventions

- **Reports** live under `reports/` and use the file-dump naming pattern when applicable: `{description}-{model}-{date}-{session}.md`.
- **Ad-hoc session dumps** that are not meant for the repo stay in `.ai-coding-artifacts/dumps/` (see the `file-dump` skill).
- New long-form docs that are not analysis reports may be added at this level or in new subdirectories as the repo grows.
