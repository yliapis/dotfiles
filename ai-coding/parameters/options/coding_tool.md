# `coding_tool` — tool slug for snapshot naming and transcript lookup

Tool slug substituted into `{filename_format}` and used to locate the
native transcript. Default: auto-detected — `cursor` when the session
transcript lives under `~/.cursor/projects/`, `claude-code` when under
`~/.claude/projects/`, else `agent`.

- **Used by:** trajectory-snapshot
- **Full entry:** [concerns/io.md](../concerns/io.md#artifact-specific)
