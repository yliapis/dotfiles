# `filename_format` — snapshot output path template

Output-path *template* for trajectory snapshots: rendered by substituting
`{coding_tool}` and `{datetime_timestamp}` tokens, then resolved against
the workspace root. Default:
`{coding_tool}-snapshot-{datetime_timestamp}.md`. Collisions never
overwrite — a `-2` (then `-3`, ...) suffix is appended before the
extension.

- **Used by:** trajectory-snapshot
- **Full entry:** [concerns/io.md](../concerns/io.md#artifact-specific)
