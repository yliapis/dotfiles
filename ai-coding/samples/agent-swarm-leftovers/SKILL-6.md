---
name: agent-swarm
description: Orchestrates parallel agent fan-out and best-of-N exploration across isolated git worktrees, then selects or synthesizes a winning result. Use when the user asks for an agent swarm, agent fan-out, best-of-N, parallel agent run, swarm orchestration, or worktree fan-out; or when a task has multiple plausible approaches whose cost of being wrong outweighs the multiplied token cost of running N attempts in parallel.
---

# Agent Swarm

## Task

Decide whether parallel agent fan-out is warranted for the current task, pick a swarm pattern (size, model mix, selection mode), launch the swarm by delegating to the existing `/worktree-task-agent` command, watchdog for hangs and partial failures, then aggregate the per-worktree results into a single recommendation or synthesized artifact.

A swarm is a deliberate multiplier on tokens and coordination overhead. Treat it as the exception, not the default. This skill exists to make that exception cheap to set up, robust against partial failure, and decisive at aggregation time.

## Parameters

- `{task}` — the task each swarm member must complete, passed through verbatim to every member; required.
- `{pattern}` — named swarm pattern from the Pattern Catalog; optional, default: `diversity` for `{n} >= 4`, `sanity` for `{n} <= 3`.
- `{n}` — number of swarm members; optional, default: derived from `{pattern}`. MUST be an integer `>= 2` (a "swarm" of one is just a single agent).
- `{model_mix}` — model assignment strategy: `scalar` (one id broadcast), `per-agent` (list of `{n}` ids), or `per-partition` (list of `p` ids broadcast across contiguous slices, where `p` divides `{n}` evenly); optional, default: `scalar`.
- `{selection_mode}` — how to pick or merge the final result: `manual`, `auto-best`, `synthesize`, `vote`, or `tournament`; optional, default: `manual`.
- `{min_successes}` — minimum members that must report `success` before aggregation runs; optional, default: `max(2, ceil({n}/2))`.
- `{relaunch_on_hang_after}` — wall-clock budget after which a non-responsive member is aborted and replaced once with the same model; optional, default: `none` (no replacement).
- `{test_command}` — shell command each member runs in its worktree to produce a pass/fail signal that feeds `auto-best`, `vote`, and `tournament`; optional.

## Success Criteria

- [ ] The decision to swarm is justified against a single-agent baseline in one sentence naming which Trigger from the Decision Matrix applied; if no Trigger applied, the swarm is not launched.
- [ ] `{n}`, `{model_mix}`, and `{selection_mode}` are validated against the chosen Pattern Catalog row before any worktree is created; shape mismatches abort with no filesystem side effects.
- [ ] All members are launched via the `/worktree-task-agent` slash command (or its documented equivalent) with `{parallelism}={n}`; this skill MUST NOT hand-roll worktree creation, branching, or diff collection.
- [ ] Every member receives the identical `{task}` text; per-member variation lives only in model assignment, sampling, or seed — never in task wording.
- [ ] At least `{min_successes}` members report `success` before aggregation runs; below the floor, the workflow follows the Failure Policy's escalation row rather than picking a winner.
- [ ] The final reply contains the per-member status table, the chosen `{selection_mode}` outcome with rationale, and (for `synthesize`) the merged artifact.
- [ ] No worktree branch is merged automatically when `{selection_mode}` is `manual`, `synthesize`, or `vote`; explicit user confirmation is required.

## Guardrails

- MUST delegate worktree creation, branch naming, isolation, and diff collection to the `/worktree-task-agent` command; this skill is an orchestration layer above it, not a replacement.
- MUST validate the swarm shape (size, model mix, selection mode) before launching members; fail fast with no filesystem side effects on validation failure.
- MUST treat each member as untrusted until at least `{min_successes}` succeed; partial results below the floor trigger escalation, not a confident pick.
- MUST NOT swarm when a single agent would suffice (see Decision Matrix); multiplying token spend without a Trigger is waste.
- MUST NOT vary the task wording across members; non-determinism comes from models, temperature, or seed, never from task text drift.
- MUST NOT merge more than one worktree branch per invocation; aggregation either picks one branch or emits a synthesized artifact that the user then chooses to apply.
- MUST NOT spawn nested swarms; if a member needs its own fan-out, that is a separate invocation by the user.
- Scope: in scope — deciding to swarm, sizing, model mix, launching via `/worktree-task-agent`, watchdog, and aggregation. Out of scope — low-level worktree mechanics, pushing branches, opening PRs, and any per-member task customization.

## Decision Matrix

Swarm only when at least one Trigger fires and no Anti-Trigger fires.

| Trigger (swarm) | Anti-Trigger (single agent) |
|---|---|
| Multiple plausible approaches exist; "best" is unknown a priori. | Mechanical task with one correct shape (rename, format, add comment). |
| Cost of a wrong answer is high (security fix, migration, public API design). | Cheap to redo if wrong; iteration is faster than parallel try. |
| Prompt or design space is genuinely open. | Spec is tight; only one design satisfies it. |
| Independent exploration adds signal (disagreement is informative). | Agents will produce near-identical diffs; fan-out is wasted spend. |
| Latency matters more than token cost. | Token cost dominates; serial single-agent is cheaper for the same outcome. |

## Pattern Catalog

Pick exactly one. Each row sets defaults for `{n}`, `{model_mix}`, and `{selection_mode}`. Deviate only with a stated reason.

| Pattern | `{n}` | `{model_mix}` | `{selection_mode}` | When to use |
|---|---|---|---|---|
| `sanity` | 2–3 | `scalar` | `vote` or `manual` | Second-opinion check on a load-bearing change; detect obvious disagreement. |
| `diversity` | 4–8 | `per-partition` (2 models × 2–4 members each) | `manual` or `auto-best` | Open design space; want a spread of styles and approaches. |
| `consensus` | 3 or 5 (odd) | `scalar` | `vote` | Verify a fragile fix is robust to seed and temperature noise. |
| `synthesize` | 3–5 | `per-partition` | `synthesize` | Each member explores a facet; an aggregator merges them into one artifact. |
| `tournament` | 4 or 8 (power of 2) | `per-agent` | `tournament` | Strong selection signal exists (e.g., a meaningful `{test_command}` plus benchmarks). |

### Sizing heuristics

- **Small (2–3):** sanity checks, disagreement detection, second opinions. Cheap, fast, usually enough.
- **Medium (4–8):** real diversity exploration. Default range when a Trigger fires.
- **Large (>8):** rarely warranted. Require an explicit cost justification (e.g., critical migration, public API surface design). Cost scales linearly with `{n}`; coordination and aggregation difficulty scale super-linearly.

### Model-mix strategies

- **scalar** — one model id broadcast to all members. Variance comes from sampling alone (temperature, seed).
- **per-agent** — list of length `{n}`, one id per member positionally. Use when you want fine-grained control over which member tries which model.
- **per-partition** — list of length `p` where `p` divides `{n}` evenly; each id is broadcast to a contiguous slice of `{n}/p` members. Use to compare model families with replicates per family. Validation: `{n} % p == 0`; otherwise abort.

## Selection Modes

| Mode | Decision rule | Notes |
|---|---|---|
| `manual` | User chooses after reading the per-member report. | Default. Safest. Required for high-stakes changes. |
| `auto-best` | Rank by `{test_command}` exit `0` first; break ties with summary heuristics (diff size, lint clean, file count). | Requires a meaningful `{test_command}` or the ranking is noise. |
| `vote` | Strict majority on a discrete output (same file changed, same constant value, same chosen library). | Requires odd `{n}` or an explicit tie-breaker rule. |
| `synthesize` | Aggregator pass (a separate prompt over the surviving members) emits one merged artifact. | Use when members were assigned overlapping facets, not the whole task. |
| `tournament` | Pairwise comparisons reduce 2k members to 1. | Reserve for when comparisons are cheap and the selection signal is strong. |

## Failure Policy

| Condition | Action |
|---|---|
| Member reports `success` within `{relaunch_on_hang_after}`. | Count toward `{min_successes}`. |
| Member exceeds `{relaunch_on_hang_after}` with no progress signal. | Abort that member; if budget allows, relaunch once with the same model. Do not relaunch a second time. |
| Member reports `failed` or `incomplete`. | Exclude from aggregation; do not relaunch. |
| Successful members `< {min_successes}` after all replacements. | Escalate: present the partial results, do not auto-pick a winner, recommend either single-agent retry or a wider re-swarm. |
| All members produce near-identical diffs. | Surface as "swarm collapsed"; recommend a single agent for the next iteration to save tokens. |

## Cost vs Latency Tradeoffs

- Fan-out multiplies token cost by `{n}` but caps wall-clock at one member's runtime (modulo coordination overhead). Swarm when latency dominates or when a wrong answer is expensive to roll back.
- Serial single-agent with a self-critique pass is often cheaper than `{n}=3` for tasks where the agent can grade its own work. Prefer it when the budget is tight and disagreement detection is not the goal.
- `tournament` and `synthesize` add an aggregator pass on top of `{n}` member passes; budget for the extra round.

## Workflow

1. **Check the Decision Matrix.** Identify which Trigger applies. If none does, or any Anti-Trigger fires, recommend a single agent and stop.
2. **Pick a Pattern** from the Pattern Catalog; let it set defaults for `{n}`, `{model_mix}`, and `{selection_mode}`. Adjust only with a stated reason.
3. **Validate shape.** Confirm `{n} >= 2`, the model-mix list length matches the chosen `{model_mix}` rule (and for `per-partition`, `{n} % p == 0`), and `{selection_mode}` is supported for the chosen pattern. Fail fast on mismatch.
4. **Launch via `/worktree-task-agent`.** Invoke that command with `{task}`, `{parallelism}={n}`, the resolved `{agent_model}` shape (scalar or list of the right length), and `{test_command}` when provided. Do not create worktrees by hand.
5. **Watchdog.** When `{relaunch_on_hang_after}` is set, monitor each member; abort and replace any member that exceeds the budget with no progress signal. Do not replace `failed` or `incomplete` members.
6. **Floor check.** After all members terminate or are aborted, count `success`. If below `{min_successes}`, jump to the Failure Policy's escalation row.
7. **Aggregate** per `{selection_mode}`:
   - `manual` — present the per-member report and ask which branch (if any) to apply.
   - `auto-best` — rank by `{test_command}` then heuristics; present the rationale before any action.
   - `vote` — tally on the agreed-upon discrete output; require a strict majority.
   - `synthesize` — run the aggregator pass over the surviving members; emit one merged artifact alongside the source members.
   - `tournament` — run pairwise rounds; present the bracket and the winner.
8. **Report** using the Output Format below. Do not merge any branch automatically except when `{selection_mode} == auto-best` and the user has pre-approved auto-merge for this invocation.

## Output Format

Reply with these sections in order:

### Swarm Decision

- `Trigger`: which row from the Decision Matrix applied.
- `Pattern`: chosen pattern from the catalog.
- `Shape`: `n=<n> model_mix=<mix> selection_mode=<mode> min_successes=<floor> relaunch_on_hang_after=<budget>`.

### Member Report

A table with one row per swarm member, in launch order:

| `#` | Branch | Model | Status | Test | Summary |
|-----|--------|-------|--------|------|---------|

Followed by the per-member diff section as produced by `/worktree-task-agent` — reference its output, do not duplicate it.

### Aggregation

- `Mode`: the `{selection_mode}` used.
- `Outcome`: the picked branch, the synthesized artifact path, or the escalation reason.
- `Rationale`: one paragraph explaining the choice or the escalation.

### Recommendation

- `Action`: one of `merge <branch>`, `apply synthesized artifact`, `retry single-agent`, or `widen swarm`.
- `Confidence`: `high`, `medium`, or `low`, with a one-line reason.
