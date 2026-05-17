---
name: agent-swarm
description: Orchestrate an agent swarm via parallel agent fan-out (best-of-N) for AI coding tasks — size the swarm, pick a model-mix pattern (broadcast / per-agent / per-partition), dispatch sibling agents through /worktree-task-agent for worktree fan-out, handle hangs with a watchdog and replacement policy, and aggregate candidates via manual-pick, auto-best, synthesize, vote, or hybrid. Use this swarm orchestration skill when deciding whether to swarm vs run a single agent, when multiple plausible approaches exist, when mitigating model variance, when comparing models head-to-head, or when exploring an open prompt or design space.
---

# Agent Swarm

## Task

Decide whether a task warrants parallel agent fan-out (a "swarm"), size and shape the swarm, dispatch it through the existing `/worktree-task-agent` slash command, and aggregate the per-agent results into one deliverable.

This skill is the *policy layer* on top of `/worktree-task-agent`. That command already handles the mechanics of creating sibling worktrees, dispatching agents, capturing per-worktree diffs, and offering merge prompts. This skill decides *whether* to fan out, *how* to configure the fan-out, and *what to do with the candidates that come back*. It does not re-implement worktree mechanics.

## Parameters

- `{trigger}` — the user request or internal decision that motivates fan-out; required so the swarm's existence can be justified in the reply.
- `{n}` — swarm size (number of sibling agents); required; integer `>= 2`. A "swarm of 1" is just a single agent — abort and dispatch one regular agent instead.
- `{min_successes}` — minimum agents that must reach terminal `success` before aggregation runs; optional, default: `ceil(n / 2)`.
- `{model_mix}` — assignment of models across slots; optional, default: scalar broadcast of the calling agent's model. Shapes: `scalar` (one model for all `{n}` slots), `per-agent` (list of length `{n}`, positional), `per-partition` (list of length `{num_partitions}` paired with a `{num_partitions}` that evenly divides `{n}`).
- `{num_partitions}` — required when `{model_mix}` is `per-partition`; integer in `1..{n}` that evenly divides `{n}`; otherwise omitted.
- `{aggregation}` — how candidates collapse into one deliverable; optional, default: `manual-pick`. Values: `manual-pick`, `auto-best`, `synthesize`, `vote`, `hybrid`.
- `{test_command}` — shell command run inside each worktree before aggregation; required when `{aggregation}` is `auto-best`, `vote`, or `hybrid`; optional otherwise.
- `{relaunch_on_hang_after}` — duration after which a non-responsive agent is aborted and one replacement is launched; optional, default: do not relaunch (hung agents end as `incomplete`).
- `{cost_cap}` — soft budget (tokens, dollars, or seconds) the swarm should not exceed; optional. Used to propose a smaller `{n}` for user approval before dispatch.

## Success Criteria

- [ ] Before any worktree is created, the reply documents (a) the trigger row from "When to Swarm" that applies, (b) the chosen `{n}` with sizing-bucket rationale, (c) the chosen `{model_mix}` and `{aggregation}`, (d) the projected cost multiplier vs a single agent.
- [ ] Dispatch happens through `/worktree-task-agent` with `{parallelism} = {n}` and the resolved `{agent_model}` / `{num_partitions}` shape; this skill never hand-rolls worktree creation, branch naming, or merge mechanics.
- [ ] At least `{min_successes}` agents reach terminal `success` before aggregation runs; if fewer succeed, the reply is labeled `under-floor`, the partial results are listed, and no winner is named.
- [ ] When `{relaunch_on_hang_after}` is set and an agent exceeds the threshold without progress, the agent is aborted and exactly one replacement is launched per slot.
- [ ] Aggregation honors the chosen mode: `manual-pick` defers to the user, `auto-best` ranks by `{test_command}` exit then summary heuristics, `synthesize` produces one merged artifact, `vote` picks by majority of comparable outputs with a documented tie-break, `hybrid` synthesizes over only the passing subset.
- [ ] At most one worktree branch is merged back per swarm invocation; remaining worktrees are reported as held or deleted per the user's choice.
- [ ] The reply ends with a per-slot row (model, status, test result, change summary) and a single named aggregation outcome.

## Guardrails

- MUST consult the "When to Swarm" decision section before dispatching; if no row applies, run a single agent instead.
- MUST validate `{n}`, `{model_mix}` shape, and `{num_partitions}` divisibility before any worktree is created; fail fast and produce no filesystem side effects on validation failure.
- MUST delegate worktree mechanics to `/worktree-task-agent`; do NOT call `git worktree add`, manage per-slot branches, or write diff capture logic directly.
- MUST NOT swarm with `{n} > 8` unless the user has explicitly approved the cost; for `{n}` in `4..8` surface the cost multiplier in the dispatch report; for `{n}` in `2..3` no explicit approval is needed.
- MUST NOT merge more than one worktree branch per swarm invocation.
- MUST NOT silently shrink `{n}` to fit `{cost_cap}`; surface the proposed reduction and wait for the user instead.
- MUST NOT chain hang replacements: at most one replacement per original slot. After that the slot stays `incomplete` and the swarm proceeds without it.
- Scope: orchestration policy for parallel sibling agents in independent worktrees — when to fan out, how to size, how to mix models, how to aggregate, how to handle hangs. Out of scope: low-level worktree mechanics (delegated to `/worktree-task-agent`), pushing branches, opening PRs, cross-repo coordination, persistent scheduling across invocations.

## When to Swarm

Consult this table BEFORE dispatching. If no row applies, abort the swarm and run a single agent.

| Trigger | Why a swarm helps |
| --- | --- |
| Multiple plausible approaches with significant trade-offs (architecture A vs B). | Each slot commits to one approach; diffs make the trade-off concrete and comparable. |
| High cost of being wrong (security-sensitive refactor, irreversible migration, data-loss-prone change). | Independent attempts reduce the chance of a single agent's blind spot landing. |
| Open prompt or design space (draft an API surface, propose UI copy, refine a meta-prompt). | Diversity of phrasing or design surfaces options the user can rank. |
| Known model variance on this task class. | Best-of-N with the same model averages out non-determinism. |
| Explicit model comparison (sonnet vs opus on the same task). | Per-agent or per-partition model mix produces a head-to-head diff. |
| Task is short (< ~1 min per agent) and cost is negligible. | Fan-out adds latency floor only, not multiplied wallclock; safe to gain coverage. |

Counter-triggers — DO NOT swarm when:

- The task has one obviously-correct mechanical implementation.
- Token cost is the binding constraint and single-agent quality is already adequate.
- The work product depends on serial conversation context (e.g., debugging via interactive log reading).
- The user requested a specific approach; a swarm would produce variations they did not ask for.

## Sizing Heuristics

- **Small (`{n}` = 2–3)** — sanity check, disagreement detection, A/B between two models. Lowest cost multiplier; safest default when in doubt.
- **Medium (`{n}` = 4–8)** — diversity-driven exploration, best-of-N for variance-prone tasks, partition-based model comparison. Surface the cost multiplier in the dispatch report.
- **Large (`{n}` > 8)** — reserve for explicit user approval with cost justification, or for cheap/short tasks where the multiplier is truly acceptable.

Cost-latency rough model (planning, not enforcement):

- Token / dollar cost scales roughly linearly with `{n}`: budget `n × single_agent_cost`.
- Wallclock latency floor is the slowest agent, not the sum: parallel `{n}` does not multiply latency.
- Aggregation adds a tail: human time for `manual-pick`; one extra agent run for `auto-best` / `synthesize` / `vote`.

## Model-Mix Patterns

Three shapes, all dispatched through `/worktree-task-agent`'s `{agent_model}` parameter:

- **Broadcast** — a single model identifier. Same model in every slot. Best for variance-only fan-out where you want `{n}` samples from one distribution.
- **Per-agent** — a list of length `{n}`, positional. Best for explicit head-to-head model comparison where every slot is a distinct model.
- **Per-partition** — a list of length `{num_partitions}` with `{num_partitions}` evenly dividing `{n}`; each model broadcasts to its contiguous slice. Best for "k samples per model" comparisons (e.g., two sonnets vs two opuses on the same task).

Default to broadcast when the user does not specify.

## Aggregation Modes

- **`manual-pick`** — present candidates, defer choice to the user. Safe default when criteria are hard to encode.
- **`auto-best`** — rank by `{test_command}` exit code first, then by summary heuristics (lines changed, files touched, presence of test edits, diff cleanliness). Requires `{test_command}`. Pick the top-ranked passing candidate.
- **`synthesize`** — pass passing candidates to an aggregator agent that produces one merged artifact. Do not pick any single candidate as the winner. Good for prompt-refinement style fan-out where the best result is a blend.
- **`vote`** — when candidates produce comparable outputs (an answer string, numeric result, passing/failing test), pick by majority. Tie-break with summary heuristics. Requires `{test_command}` or some comparable per-agent output.
- **`hybrid`** — filter to candidates that pass `{test_command}`, then `synthesize` over the passing subset (or fall back to `manual-pick` if synthesis is not appropriate for the artifact type).

## Hang and Failure Handling

- **`{min_successes}` floor.** Never aggregate below this. If the floor is missed, report `under-floor` with the partial results; let the user decide whether to relaunch.
- **Watchdog.** When `{relaunch_on_hang_after}` is set, treat any agent with no output / no status update past the threshold as hung. Abort it via the worktree's terminal control and launch one replacement agent in a fresh slot.
- **Replacement budget.** At most one replacement per original slot. A hung replacement ends as `incomplete`; the swarm does not chain replacements.
- **Partial-failure escalation.** If more than half of slots end up `incomplete` or `failed`, surface this prominently and recommend `manual-pick` regardless of the configured `{aggregation}` mode.

## Workflow

1. **Detect trigger.** Match the task against a row in "When to Swarm". If no row applies, abort the swarm and dispatch a single agent instead.
2. **Size and shape.** Choose `{n}` from the sizing buckets. Choose `{model_mix}` (and `{num_partitions}` when per-partition). Choose `{aggregation}`. Project the cost multiplier vs a single agent.
3. **Validate.** Confirm `{n} >= 2`, `{model_mix}` shape is internally consistent, `{num_partitions}` evenly divides `{n}`, `{test_command}` is present when the chosen `{aggregation}` requires it. Fail fast — no worktree side effects.
4. **Cost gate.** If `{n} > 8` without explicit approval, ask before dispatching. If `{cost_cap}` is set and the projected cost exceeds it, propose a downsized `{n}` and wait for user approval rather than silently shrinking.
5. **Dispatch.** Invoke `/worktree-task-agent` with `{parallelism} = {n}`, the resolved `{agent_model}` and `{num_partitions}`, the user's `{task}`, and `{test_command}` when set. Do NOT re-implement what that command already does.
6. **Watchdog (when configured).** Monitor each slot's status output. If an agent exceeds `{relaunch_on_hang_after}` without progress, abort it and launch one replacement in a fresh worktree slot. Track which slots were replaced.
7. **Floor check.** When all slots terminate, count `success` rows. If below `{min_successes}`, report `under-floor` and skip aggregation.
8. **Aggregate.** Apply the chosen `{aggregation}` over the candidates that pass `{test_command}` (when one is set) or all `success` candidates (otherwise).
9. **Merge prompt.** At most one branch is offered for merge. The remaining worktrees are listed as held; ask the user which (if any) to delete.

## Output Format

Reply with these named sections in this order:

### Swarm Plan
- `Trigger`: which "When to Swarm" row applies and why.
- `Size`: chosen `{n}` and bucket (small / medium / large).
- `Model mix`: shape (broadcast / per-agent / per-partition) and resolved per-slot models.
- `Aggregation`: chosen mode and why.
- `Cost note`: projected multiplier vs single agent; any `{cost_cap}` interaction.

### Dispatch
- The `/worktree-task-agent` invocation used — parameters only, not a re-render of its workflow.
- Watchdog settings (when configured).

### Per-Agent Results
A table with one row per slot:

| Slot | Model | Status | Test exit | Change summary |
| --- | --- | --- | --- | --- |
| 1 | `<model>` | `success` / `failed` / `incomplete` / `replaced` | `0` / `<n>` / `n/a` | one-line summary |

### Aggregation
- `manual-pick`: present the candidates as a choice prompt.
- `auto-best`: name the winner slot and the ranking rationale.
- `synthesize` / `hybrid`: present the merged artifact (inline or as a path) and name the source slots.
- `vote`: name the winning vote, the tally, and the tie-break (if any).
- `under-floor`: state the missing-success count and the recommended next step; do NOT name a winner.

### Merge Recommendation
- The single recommended branch to merge (or `none`) with a one-line rationale, plus per-slot delete recommendations.
