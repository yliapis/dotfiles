# `granularity` — snapshot detail level

Snapshot detail level: closed enum `verbatim` | `condensed` | `summary` |
`native`. Default `summary`. Security-relevant split: the rendered
granularities redact secrets to `<redacted>`; `native` copies the tool's
session transcript byte-identically and intentionally applies no
redaction.

- **Used by:** trajectory-snapshot
- **Full entry:** [concerns/io.md](../concerns/io.md#artifact-specific)
