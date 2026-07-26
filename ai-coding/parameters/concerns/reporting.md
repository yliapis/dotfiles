# Reporting

What a run shows its reader, independent of what the run does. Most artifacts
fix their Output Format section instead of parameterizing it; the two knobs
below are the exceptions — one sets how much detail a rendered snapshot
carries, the other adds a diagram of the plan a swarm is about to dispatch.
[future.md](../future.md) held this concern open until a second artifact
shipped an output-shape knob; agent-swarm's `--preview-swarm-topology` is that
second knob. The two parameters share no concept, so this file has no cards.

## trajectory-snapshot

- `{granularity}` — snapshot detail level: closed enum `verbatim` |
  `condensed` | `summary` | `native`. Default `summary`. `native` requires a
  locatable native transcript (no lossy reconstruction; the run aborts without
  one) and swaps the `.md` extension in
  [`{filename_format}`](io.md#artifact-specific) for the native transcript's
  extension. Security-relevant split: the rendered granularities (`verbatim`,
  `condensed`, `summary`) redact secrets to `<redacted>`; `native` copies the
  tool's session transcript byte-identically and intentionally applies no
  redaction, so sensitive transcript bytes are preserved.

## agent-swarm

- `--preview-swarm-topology[=<format>]` — flag; renders the resolved
  [`{topology}`](replication.md#artifact-specific) as a diagram in the reply's
  `### Topology Preview` section before the first worktree is created.
  `<format>` is `mermaid` (default — one fenced mermaid block), `ascii`, or
  `both`; the bare flag means `mermaid`. Render-only: the preview reads
  resolved values (slot count, per-slot model, group / wave / stage
  boundaries, base branches, selection modes), never gates dispatch, and never
  substitutes for the `{cost_cap}` projection. Setting it also emits a
  `swarm.topology_previewed` event.
