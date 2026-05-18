---
name: agent-swarm
description: Orchestrate parallel agent fan-out (best-of-N) for AI coding tasks — gate the swarm-vs-single decision, size the swarm, pick a model-mix shape (broadcast / per-agent / per-partition), dispatch siblings through /worktree-task-agent, watchdog hangs with a 5-minute default and explicit replacement policy, and aggregate by running every requested selection mode in parallel (manual, auto-best, synthesize, vote, hybrid, tournament, consensus) over the surviving members. Use when the user asks for an agent swarm, agent fan-out, best-of-N, parallel agent runs, swarm orchestration, worktree fan-out, multiple plausible approaches, or independent exploration that adds signal.
license: MIT
---

# Agent Swarm

## Task

Decide whether a coding task warrants parallel agent fan-out, design the swarm (size, concurrency, model mix, replacement policy, selection modes), dispatch through `/worktree-task-agent`, watchdog for hangs, and aggregate the per-member outcomes by running every requested selection mode in parallel over the surviving members.

This skill is the policy layer above `.cursor/commands/worktree-task-agent.md`. It owns the swarm-vs-single decision, sizing, model mix, replacement policy, watchdog, aggregation strategy, and structured event emission. It never re-implements worktree mechanics — those belong to `/worktree-task-agent`.

## Parameters

- `{num_agents}` (aliases: `{n}`, `{num}`) — total agents to spawn; required; integer `>= 2`. A "swarm" of `1` is a single agent; refuse and recommend a direct `/worktree-task-agent` invocation instead.
- `{parallel_agents}` (aliases: `{p}`, `{parallel}`) — concurrency cap on members running simultaneously; optional, default: `{num_agents}` (full parallelism). MUST be an integer in `1..{num_agents}`.
- `{model_mix}` — model-assignment shape: `broadcast` (one model to all), `per-agent` (list of length `{num_agents}`), or `per-partition` (list of length `{num_partitions}` broadcast across contiguous slices); optional, default: `broadcast` with the parent agent's model.
- `{num_partitions}` — partition count when `{model_mix} = per-partition`; optional, default: `{num_agents}`. MUST divide `{num_agents}` evenly.
- `{selection_modes}` — list (any subset) of: `manual`, `auto-best`, `synthesize`, `vote`, `hybrid`, `tournament`, `consensus`. Every listed mode runs in parallel over the surviving members and produces its own outcome block; optional, default: `auto` (every mode whose prerequisites are met given the other parameters; skipped modes are listed in the report with the missing prerequisite).
- `{test_command}` — shell verifier each member runs in its worktree; required when any of `auto-best`, `vote`, `hybrid`, `tournament` is in `{selection_modes}`.
- `{aggregator}` — prompt or shell command that produces a merged artifact from candidates; required when `synthesize` or `hybrid` is in `{selection_modes}`.
- `{min_successes}` — minimum members reaching `success` before aggregation runs; optional, default: `ceil({num_agents} / 2)`. If unmet after replacements terminate, every selection mode reports `under-floor` and no winner is auto-selected.
- `{relaunch_on_hang_after}` — wall-clock duration after which a silent member is force-aborted; optional, default: `5m`. Replacement happens per `{replacement_policy}`.
- `{replacement_policy}` — `off` | `replace-up-to-n` | `replace-up-to-budget`; optional, default: `off`. Controls whether killed members are respawned; replacements never recurse.
- `{cost_cap}` — soft cap on projected token spend or wall-clock seconds across the swarm; optional. When set, the workflow projects cost before dispatch; if projected exceeds the cap, the skill proposes a smaller `{num_agents}` and waits for user approval (does NOT silently shrink).
- `{pattern}` — optional preset shortcut; one of: `sanity`, `diversity`, `consensus`, `synthesize`, `tournament`. When set, the preset supplies defaults for `{num_agents}`, `{model_mix}`, and `{selection_modes}` from the Pattern Catalog. User-set parameters always override preset defaults.

## Success Criteria

- [ ] Before any worktree is created, the response records the swarm-gate verdict, the trigger ID(s) that fired, and (when `{pattern}` is used) the preset chosen.
- [ ] Parameters are validated before dispatch: `{num_agents} >= 2`, `{parallel_agents} <= {num_agents}`, `{model_mix}` shape matches `{num_agents}` / `{num_partitions}`, `{num_partitions}` divides `{num_agents}` evenly, and required parameters for each entry in `{selection_modes}` are present.
- [ ] Worktree creation, branch naming, agent dispatch, and per-worktree diff capture are delegated to `/worktree-task-agent`; this skill emits no `git worktree` calls.
- [ ] When `{cost_cap}` is set, a cost projection is run before dispatch; if `projected > {cost_cap}`, the skill proposes a smaller `{num_agents}` and waits for user approval.
- [ ] When `{relaunch_on_hang_after}` expires for a member, that member is force-aborted; replacement happens iff `{replacement_policy}` allows; replacements never recurse.
- [ ] When `successes < {min_successes}` after the run terminates (including replacements), every selection mode reports `under-floor`; no winner is auto-selected.
- [ ] Every entry in the resolved `{selection_modes}` runs over the surviving members and produces its own outcome block in the Aggregation section.
- [ ] Structured JSON Lines events are emitted in the dedicated `### Events` section of the reply, in chronological order, covering the swarm-gate verdict, dispatch, member lifecycle, replacements, per-mode selection results, and run completion.
- [ ] At most one worktree branch is merged back per invocation, regardless of how many selection modes converged on the same winner.

## Guardrails

- MUST run the Swarm Gate before any side effect. At least one trigger MUST fire AND its identifier MUST appear in the response; otherwise abort and recommend a single agent.
- MUST compose with `/worktree-task-agent` for every worktree side effect (create, run, diff, merge prompt). MUST NOT re-specify or re-implement worktree mechanics.
- MUST validate parameters before dispatch; fail fast with no filesystem side effects on validation failure.
- MUST keep each member isolated to its assigned worktree; members MUST NOT read, write, or run commands against the calling worktree or any sibling worktree.
- MUST treat `{relaunch_on_hang_after}` as a hard kill, not a polite request.
- MUST NOT chain replacements; a replaced member that itself hangs ends as `incomplete`.
- MUST NOT silently shrink `{num_agents}` to fit `{cost_cap}`; surface the proposed size and wait for the user's approval.
- MUST NOT recursively spawn swarms; every member runs as a single agent.
- MUST NOT merge more than one worktree branch per invocation, even when several selection modes converge on it.
- MUST emit events in chronological order in the dedicated `### Events` section; MUST NOT inline events outside that section.
- Scope: orchestration policy (gate, sizing, mix, dispatch shape, watchdog, aggregation, events). Out of scope: low-level worktree mechanics (delegated to `/worktree-task-agent`), pushing branches, opening PRs, cross-repo coordination, persistent scheduling.

## Swarm Gate

Run a swarm only when at least one trigger fires. Record the trigger ID(s) in the Swarm Decision section.

| ID | Trigger | When it fires |
|---|---|---|
| T1 | Multiple plausible approaches | Two or more designs are reasonable; the right one is non-obvious without trying both |
| T2 | High cost of being wrong | Irreversible changes, security-sensitive logic, public API design, expensive-to-detect failures |
| T3 | Open prompt or design space | Spec is loose; agents will reasonably interpret it differently and that variance is informative |
| T4 | Independent exploration adds signal | Disagreement detection, model-variance smoothing, or refactor-consensus is itself the goal |
| T5 | Cross-model comparison is the question | "Does Opus beat Sonnet on this task class?" or similar head-to-head |
| T6 | User explicitly requested fan-out | The user said "swarm", "best of N", "fan out", "parallel agents", or named the agent-swarm skill |

Counter-triggers (skip the swarm even if a trigger fires):

- Mechanically-correct task with one obvious shape (rename, format, scripted refactor).
- Token budget is the binding constraint and a single agent's quality is already adequate.
- The work depends on serial conversational context (interactive debugging, iterative log reading).

## Pattern Catalog

`{pattern}` is an optional shortcut that supplies defaults for `{num_agents}`, `{model_mix}`, and `{selection_modes}`. User-set parameters always override the preset.

| Pattern | `{num_agents}` | `{model_mix}` | `{selection_modes}` | When to use |
|---|---|---|---|---|
| `sanity` | 3 | `broadcast` | `[vote, manual]` | Cheap second-opinion check; surface obvious disagreement before committing |
| `diversity` | 6 | `per-partition` | `[manual, auto-best, synthesize]` | Open design space; want a comparable spread of styles |
| `consensus` | 5 | `broadcast` | `[vote, consensus]` | Verify a fragile fix is robust to seed and temperature noise |
| `synthesize` | 4 | `per-partition` | `[synthesize]` | Members explore complementary facets; merge into one artifact |
| `tournament` | 8 | `per-agent` | `[tournament, auto-best]` | Strong selection signal exists; want the best of several head-to-head |

## Sizing Heuristics

Pick `{num_agents}` from the lowest tier that still answers the trigger that fired.

| Tier | `{num_agents}` | Use for | Cost shape |
|---|---|---|---|
| Sanity | 2-3 | Disagreement detection, second opinion, A/B between two models | `~3×` single-agent cost |
| Diversity | 4-8 | Real best-of-N exploration; default range when a trigger fires | `~n×` cost; default range |
| Search | >8 | Only with `{cost_cap}` justification recorded in the response | Cost grows linearly; aggregation difficulty grows super-linearly |

Doubling the swarm rarely doubles the signal. Prefer raising selection rigor over raising `{num_agents}`.

## Model-Mix Strategies

Three shapes, dispatched through `/worktree-task-agent`'s `{agent_model}` parameter:

- **`broadcast`** — one model identifier broadcast to every member. Variance from sampling alone. Default.
- **`per-agent`** — list of length `{num_agents}`, one model per slot positionally. Use for explicit head-to-head model comparison.
- **`per-partition`** — list of length `{num_partitions}`, broadcast across `{num_agents} / {num_partitions}` contiguous slots. Use for "k samples per model" comparisons.

Validation: list-by-agent length MUST equal `{num_agents}`; list-by-partition length MUST equal `{num_partitions}`, and `{num_partitions}` MUST divide `{num_agents}` evenly.

## Selection Modes (run in parallel)

All modes listed in the resolved `{selection_modes}` run independently over the surviving members; each emits its own outcome block. Each mode is a read-only pass over the same data, so running several is cheap and gives the caller a side-by-side comparison.

| Mode | Decision rule | Requires |
|---|---|---|
| `manual` | Present per-member report; user picks zero or one branch | nothing extra |
| `auto-best` | Rank by `{test_command}` exit (0 wins); break ties on smaller diff, fewer files touched, lower-index slot | `{test_command}` |
| `synthesize` | Run `{aggregator}` over surviving members; emit one merged artifact (no branch is merged) | `{aggregator}` |
| `vote` | Group members by output equivalence (test result + structural diff hash); pick largest group; tie-break on lower-index | `{test_command}` or comparable signature |
| `hybrid` | Filter to members passing `{test_command}`, then run `{aggregator}` over the filtered subset (or fall back to manual pick if synthesis is inappropriate for the artifact type) | `{test_command}` AND `{aggregator}` |
| `tournament` | Pairwise comparisons reduce `2^k` members to `1`; requires comparison cost to be cheap relative to member cost | `{test_command}`; `{num_agents}` MUST be a power of 2 |
| `consensus` | Strict per-hunk overlap across members; emit only the agreed subset as a unified diff plus a list of contested hunks | comparable diffs |

When `{selection_modes} = auto` (the default), the skill includes every mode whose prerequisites are met. Skipped modes appear in the Aggregation section as `skipped: <missing prerequisite>` so the omission is auditable.

## Replacement Policy

`{replacement_policy}` controls hang recovery. Replacements multiply spend, so opt-in is required.

- **`off`** (default) — killed members end as `incomplete`; no replacement is launched.
- **`replace-up-to-n`** — each slot may respawn at most once. Total replacement budget is `{num_agents}`. A replacement that itself hangs ends as `incomplete`.
- **`replace-up-to-budget`** — replacements continue while `{cost_cap}` projection still allows; pending replacements are cancelled when the cap is crossed. Requires `{cost_cap}` to be set.

A replacement counts toward `{min_successes}` only if the replacement itself reports `success`.

## Cost Cap and Projection

When `{cost_cap}` is set, the workflow runs a cost projection before dispatch:

```
projected = ({num_agents} + projected_replacements) × per_agent_estimate
```

If `projected > {cost_cap}`, propose the largest `{num_agents}` value that fits the cap and wait for user approval. NEVER silently shrink. Without `{cost_cap}`, no pre-launch gate runs and cost is reported only via emitted events and the post-run report.

## Events

The skill emits structured events in a dedicated `### Events` section of the reply. Events are JSON Lines (one JSON object per line) so external tooling can grep the section and compute cost on the fly without re-parsing the markdown report. Schema:

```json
{ "ts": "2026-05-17T01:30:00Z", "type": "<event_type>", "payload": { ... } }
```

| Type | Payload fields | Emitted when |
|---|---|---|
| `swarm.gate_decided` | `verdict`, `triggers_fired`, `pattern` | After the Swarm Gate runs |
| `swarm.dispatched` | `num_agents`, `parallel_agents`, `model_mix`, `selection_modes` | After `/worktree-task-agent` is launched |
| `member.started` | `slot`, `model`, `worktree_path` | When a member begins |
| `member.progress` | `slot`, `last_activity_ms` | Heartbeat (per `/worktree-task-agent`'s reporting cadence) |
| `member.completed` | `slot`, `status`, `test_exit`, `diff_lines` | When a member terminates (success / failed / incomplete) |
| `member.replaced` | `slot`, `reason`, `replacement_model` | When a hung member is killed and respawned |
| `selection.completed` | `mode`, `result`, `rationale` | Once per resolved entry in `{selection_modes}` |
| `swarm.done` | `successes`, `failures`, `replacements`, `wall_clock_s`, `floor_met` | At end of run |

Events MUST appear in chronological order. Do NOT inline events outside the dedicated section.

## Workflow

1. **Swarm gate.** Walk the Swarm Gate table and any counter-triggers. If no trigger fires (or a counter-trigger applies), recommend a single agent and stop. Emit `swarm.gate_decided`.
2. **Apply pattern (if `{pattern}` is set).** Populate defaults for `{num_agents}`, `{model_mix}`, and `{selection_modes}` from the Pattern Catalog row. User-set parameters override.
3. **Resolve `{selection_modes}`.** When the value is `auto`, include every mode whose prerequisites are met given the other parameters. Record which modes were resolved and which were skipped (with the missing prerequisite) for the report.
4. **Validate parameters.** Confirm sizing, mix shape, partition divisibility, and selection-mode prerequisites. Fail fast on any mismatch (no filesystem side effects).
5. **Cost projection (when `{cost_cap}` is set).** Compute projected cost. If `projected > {cost_cap}`, propose the largest `{num_agents}` that fits and wait for user approval.
6. **Dispatch via `/worktree-task-agent`.** Invoke that command with `{parallelism} = {parallel_agents}`, the resolved `{agent_model}` shape, the verbatim `{task}` for every member, `{test_command}` (when set), and `{merge_mode} = interactive`. Emit `swarm.dispatched`. Do not re-implement worktree mechanics.
7. **Watchdog.** Track each member's last activity. Emit `member.started`, `member.progress`, `member.completed` events as they fire. When `{relaunch_on_hang_after}` expires for a member, force-abort it; respawn per `{replacement_policy}` and emit `member.replaced`.
8. **Floor check.** When all live members terminate, count `success`. If below `{min_successes}`, every selection mode reports `under-floor`; skip aggregation and emit `swarm.done` with `floor_met=false`.
9. **Run all resolved selection modes in parallel.** For each entry in the resolved `{selection_modes}`, apply its rule over the surviving members and emit `selection.completed`. Each mode produces its own outcome block.
10. **Report and merge handoff.** Render the Output Format. Hand the chosen branch (if any) back through `/worktree-task-agent`'s merge prompt. Emit `swarm.done`. At most one branch is merged per invocation, even if several modes converge on it.

## Output Format

Reply with the following named sections, in this order. Omit sections whose body is legitimately empty.

### Swarm Decision

- `Verdict`: `swarm` or `single-agent`.
- `Triggers fired`: `T1`-`T6` IDs.
- `Pattern`: preset name or `none`.
- `Rationale`: one sentence tying verdict to triggers.

If `Verdict = single-agent`, stop here.

### Swarm Plan

- `num_agents` / `parallel_agents`: e.g., `8 (parallel: 4)`.
- `model_mix`: shape and resolved per-slot assignment.
- `selection_modes`: resolved list; skipped modes with reasons.
- `min_successes`: floor.
- `relaunch_on_hang_after`: duration.
- `replacement_policy`: value.
- `cost_cap`: value or `unset`. Include the projection (and any user-approved downsize) when set.

### Per-Member Report

Defer to `/worktree-task-agent`'s Worktree Results section verbatim; do not duplicate the schema.

### Aggregation

One block per resolved entry in `{selection_modes}`, in the order listed:

#### `<mode>`

- `Outcome`: chosen branch, synthesized artifact path, `under-floor`, `no-consensus`, or `skipped: <reason>`.
- `Rationale`: one line tying the outcome to the mode's rule.

### Events

Fenced JSON Lines block in chronological order:

```jsonl
{"ts": "...", "type": "swarm.gate_decided", "payload": {...}}
{"ts": "...", "type": "swarm.dispatched", "payload": {...}}
...
{"ts": "...", "type": "swarm.done", "payload": {...}}
```

### Recommendation

- `Action`: one of `merge <branch>`, `apply synthesized artifact`, `await user pick`, `retry single-agent`, or `widen swarm`.
- `Mode convergence`: which selection modes agreed on which outcome (e.g., `auto-best and vote both pick member 3; synthesize emitted a separate artifact; manual defers`).
- `Confidence`: `high` / `medium` / `low` with a one-line reason.

### Handoff

- `Merge`: hand the chosen branch (if any) back to `/worktree-task-agent`'s merge prompt; do not merge inline.
- `Cleanup`: ask the user which non-winning worktrees to delete; leave them in place by default.
