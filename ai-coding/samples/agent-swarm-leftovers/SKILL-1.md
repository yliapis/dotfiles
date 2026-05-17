---
name: agent-swarm
description: Decide whether to fan out into a parallel agent swarm vs run a single agent, then orchestrate best-of-N candidate generation by composing the existing /worktree-task-agent command for isolated worktree execution. Use when the user asks for agent fan-out, best-of-N, a parallel agent run, an agent swarm, swarm orchestration, worktree fan-out, exploring multiple plausible approaches in parallel, or picking a winner across N candidate diffs.
---

# Agent Swarm

## Task

Decide whether the current task warrants parallel agent fan-out (a "swarm") and, when it does, orchestrate a best-of-N run by composing the `/worktree-task-agent` command for the low-level worktree mechanics. This skill owns the decision, sizing, model-mix, robustness floor, aggregation strategy, and final report; it never reimplements worktree creation, branch naming, diff capture, or merge logic.

## Parameters

- `{swarm_size}` — number of parallel agents to launch; required when fanning out. MUST be an integer `>= 2`.
- `{agent_model}` — model assignment: scalar (broadcast to all), list-by-agent of length `{swarm_size}`, or list-by-partition of length `{num_partitions}`; optional, default: scalar = parent agent's model.
- `{num_partitions}` — contiguous slices that share one model when `{agent_model}` is list-by-partition; optional, default: `{swarm_size}` (one model per agent). MUST divide `{swarm_size}` evenly.
- `{selection_mode}` — how a winner is chosen: `manual` | `auto-best` | `synthesize` | `vote` | `hybrid`; required.
- `{test_command}` — shell command each candidate runs to feed `auto-best` ranking; required when `{selection_mode}` is `auto-best` or `hybrid`.
- `{min_successes}` — minimum candidates that must terminate with status `success` before selection runs; optional, default: `ceil({swarm_size} / 2)`.
- `{relaunch_on_hang_after}` — duration (seconds) after which a stalled agent is aborted and replaced; optional, default: unset (no replacement).
- `{cost_ceiling}` — soft cap on total tokens or wall-clock minutes for the swarm; optional, default: unset.

## Success Criteria

- [ ] Before any side effect, the skill emits a one-paragraph swarm decision that names which Trigger Conditions matched and why a single agent would not suffice.
- [ ] When the decision is `single agent`, no worktrees are created and the skill stops with that recommendation.
- [ ] When the decision is `swarm`, fan-out is delegated entirely to `/worktree-task-agent` with `{parallelism} = {swarm_size}` and the resolved `{agent_model}` / `{num_partitions}` shape; no ad-hoc `git worktree` calls live in this skill.
- [ ] At least `{min_successes}` candidates terminate with status `success` before selection runs; otherwise the skill escalates to the user instead of picking.
- [ ] Selection runs exactly once per invocation under the rule defined by `{selection_mode}`, and the chosen candidate is named explicitly with a one-line rationale.
- [ ] Hangs are surfaced: any agent exceeding `{relaunch_on_hang_after}` is reported as `incomplete` with elapsed wait; replacement only happens when `{relaunch_on_hang_after}` is set.
- [ ] At most one worktree branch is merged per invocation, regardless of `{selection_mode}`.

## Guardrails

- MUST compose with `/worktree-task-agent` for every worktree side effect (create, run, diff, merge, delete). MUST NOT re-specify or re-implement worktree mechanics.
- MUST run the swarm decision before any side effect; a swarm with `{swarm_size} < 2` is a contradiction and aborts.
- MUST keep each agent isolated to its own worktree — never share scratch files, environment state, or chat memory across siblings.
- MUST NOT recursively spawn swarms: agents launched by this skill receive a single-agent task, never another swarm directive.
- MUST NOT collapse `synthesize` into `manual` silently: if synthesis is requested but no aggregator exists, abort and ask.
- MUST NOT exceed `{cost_ceiling}` when set; abort the run with a partial report if the ceiling is hit.
- Scope: in scope — deciding to swarm, sizing it, mixing models, defining selection, reporting results. Out of scope — branch publishing, multi-merge, cross-repo fan-out, agent training, prompt synthesis (that belongs to `/meta-prompt`).

## Workflow

1. **Decide swarm vs single.** Walk the Trigger Conditions table below. Recommend `swarm` only when two or more conditions match; otherwise recommend `single agent` and stop.
2. **Size the swarm.** Pick `{swarm_size}` from the Sizing Heuristics table. Justify the choice in one sentence (e.g., "4 candidates: open design space, moderate cost").
3. **Choose the model mix.** Pick a shape from Model-Mix Strategies and resolve `{agent_model}` and `{num_partitions}` accordingly. Validate that list lengths match the chosen shape before delegating.
4. **Pick a selection mode.** Choose from Selection Modes, then ensure its prerequisites are present (`{test_command}` for `auto-best`, an aggregator prompt for `synthesize`, etc.). If a prerequisite is missing, abort.
5. **Set the robustness floor.** Resolve `{min_successes}` (default = `ceil({swarm_size} / 2)`) and `{relaunch_on_hang_after}` when hangs are expected.
6. **Delegate to `/worktree-task-agent`.** Invoke it with `{parallelism} = {swarm_size}`, the resolved model shape, the same `{task}` for every agent, and `{merge_mode} = interactive` unless `{selection_mode}` is `auto-best` and the Guardrails for an auto merge are all met.
7. **Wait, watch, replace.** Track per-agent elapsed time. When `{relaunch_on_hang_after}` is set and any agent exceeds it, abort that one and re-dispatch a replacement on the same model.
8. **Verify the floor.** When all agents settle, count `success`. If fewer than `{min_successes}` succeeded, do not select — escalate to the user with the per-agent report.
9. **Select the winner.** Apply the rule for `{selection_mode}` from Selection Modes. Record the rationale verbatim.
10. **Report and merge.** Produce the Output Format report. Hand the chosen candidate's branch back to `/worktree-task-agent` for the merge step; leave non-winning worktrees in place unless the user opts in to cleanup.

## Trigger Conditions

Use a swarm when **two or more** of these are true:

| # | Condition | Example |
|---|---|---|
| T1 | Multiple plausible approaches exist with no clear winner | "Redis vs in-memory vs file-based caching" |
| T2 | Cost of being wrong is high | irreversible refactor, public API change, infra migration |
| T3 | Independent exploration adds genuine value | prompt refinement, algorithm tuning, UX variants |
| T4 | Prompt or design space is genuinely open | "make this faster" with no profile in hand |
| T5 | Disagreement detection is itself the goal | sanity-checking a tricky bug fix, validating a heuristic |

Stop and use a single agent when **none or one** match — the multiplied token cost is not justified.

## Sizing Heuristics

| Size | Use for | Cost shape |
|---|---|---|
| 2–3 (small) | sanity / disagreement detection; pairwise diffing | low; serial fallback is feasible |
| 4–8 (medium) | diversity across approaches or model families | quadratic in review time, linear in tokens |
| > 8 (large) | only with explicit `{cost_ceiling}` justification | requires aggressive `auto-best`; manual review does not scale |

Default: pick the smallest size that still captures the disagreement you want to see. Doubling the swarm rarely doubles the signal.

## Model-Mix Strategies

Three shapes, illustrated for `{swarm_size} = 4`:

- **Broadcast (scalar):** `"sonnet"` — every agent runs on the same model. Use when you want diversity from sampling alone.
- **Per-agent (list-by-agent of length `{swarm_size}`):** `["sonnet", "sonnet", "opus", "opus"]` — explicit model per slot. Use when you want named slots (`baseline-1`, `baseline-2`, `experimental-1`, `experimental-2`).
- **Per-partition (list-by-partition of length `{num_partitions}`):** with `{num_partitions} = 2` and `["sonnet", "opus"]` — a contiguous slice shares one model. Use for head-to-head: N agents on model A vs N agents on model B.

Validate shape before delegation: list-by-agent length must equal `{swarm_size}`; list-by-partition length must equal `{num_partitions}` and `{num_partitions}` must divide `{swarm_size}` evenly.

## Selection Modes

| Mode | Rule | Prerequisites |
|---|---|---|
| `manual` | Present per-candidate diffs; user picks one or none | none |
| `auto-best` | Rank by `{test_command}` exit (`0` wins; ties broken by smaller diff, fewer files touched, no skipped tests) | `{test_command}` set |
| `synthesize` | Merge candidate outputs into a single new artifact via an aggregator prompt; no candidate is selected verbatim | aggregator prompt or command |
| `vote` | Each agent reviews the others; majority winner is selected | extra review pass; cost ~2x |
| `hybrid` | `auto-best` on test signal, manual tiebreak when ranks tie | `{test_command}` set |

## Cost vs Latency Tradeoffs

- **Cost-bounded** (token budget tight, latency tolerant): use a single agent or `{swarm_size} = 2` with broadcast model.
- **Latency-bounded** (wall-clock matters more than tokens): swarm with `{swarm_size} >= 4` in parallel; pay multiplied tokens to halve elapsed time.
- **Quality-bounded** (correctness is the binding constraint): swarm with mixed-model partitions and `auto-best` or `hybrid` selection; budget for the review pass.

A serial single agent is the right answer when any of these is true: the task has a known correct shape, there is no disagreement to surface, or the token budget cannot absorb the multiplier.

## Output Format

Return a single response with these sections, in order:

### Swarm Decision

- `Recommendation`: `swarm` or `single agent`.
- `Triggers matched`: list of T-codes from Trigger Conditions.
- `Rationale`: one sentence.

If the recommendation is `single agent`, stop here.

### Swarm Plan

- `Swarm size`: `{swarm_size}`.
- `Model mix`: shape and resolved assignment.
- `Selection mode`: `{selection_mode}`.
- `Robustness floor`: `{min_successes}` of `{swarm_size}` must succeed; hang watchdog: `{relaunch_on_hang_after}` or `none`.
- `Cost ceiling`: `{cost_ceiling}` or `unset`.

### Per-Agent Results

Defer to `/worktree-task-agent`'s `### Worktree Results` section verbatim. Do not duplicate.

### Selection

- `Winner`: branch name or `none`.
- `Reason`: one-line rationale referencing the rule from Selection Modes.
- `Floor met`: `yes` (succeeded count) or `no` (escalated to user).

### Next Step

- Final merge or cleanup instruction, delegated to `/worktree-task-agent` (use `/apply-worktree` for merge, `/delete-worktree` for cleanup). Never embed merge commands here.
