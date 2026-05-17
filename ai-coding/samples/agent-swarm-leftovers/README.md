# Agent-Swarm SKILL Leftovers

These are historical `agent-swarm` SKILL.md variants from an earlier (pre-canonical)
swarm experiment. They are preserved here for historical reference only and are
**not** intended to update or replace the current canonical skill.

The canonical agent-swarm SKILL lives at `.cursor/skills/agent-swarm/SKILL.md` in
`main` (238 lines) and supersedes everything in this directory.

The original sample branches `agent-swarm-sample-{1,2,3,5,6,8}` have been reverted
after the cherry-pick into the root aggregator; this archive is the surviving copy
of those branch tips.

## Variants

| File | Lines | Distinguishing aspect |
| --- | --- | --- |
| `SKILL-1.md` | 140 | Variant 1: gates fan-out on a 5-row Trigger Conditions table that requires **two or more** triggers to fire before recommending a swarm. |
| `SKILL-2.md` | 162 | Variant 2: uses a 4-question "should we swarm?" gate and adds a dedicated `consensus` selection mode plus an explicit `{replacement_policy}` parameter (`off` / `replace-up-to-n` / `replace-up-to-budget`). |
| `SKILL-3.md` | 176 | Variant 3: longest and most table-driven variant — explicit Swarm Trigger Table with paired anti-triggers, a Selection Mode Decision Table, and a standalone cost-vs-latency workflow step plus a dedicated `Escalation` output section. |
| `SKILL-5.md` | 152 | Variant 5: organizes the decision around a Five Questions Gate (Q5 specifically about cross-model disagreement), treats parameters as internal design knobs rather than user inputs, and requires a "was the swarm worth it?" cost-judgment in the final report. |
| `SKILL-6.md` | 152 | Variant 6: pattern-based — a Pattern Catalog of named shapes (`sanity` / `diversity` / `consensus` / `synthesize` / `tournament`) presets `{n}`, `{model_mix}`, and `{selection_mode}` together, and uniquely supports a `tournament` selection mode. |
| `SKILL-8.md` | 146 | Variant 8: introduces an explicit `{trigger}` parameter, a `{cost_cap}` that must surface a proposed `{n}` reduction for user approval rather than silently shrinking, and a `hybrid` aggregation defined as "filter to `{test_command}` passers, then synthesize". |
