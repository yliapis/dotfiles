---
name: agent-swarm
description: "Decides whether and how to fan an AI coding task out to multiple sibling agents working in isolated git worktrees, then aggregates their results into a single chosen or synthesized outcome. Use when the user asks for an agent swarm, agent fan-out, best-of-N, parallel agent runs, swarm orchestration, or worktree fan-out; or when the underlying task has multiple plausible approaches, a high cost of being wrong, or genuinely benefits from independent exploration. Composes with the `/worktree-task-agent` slash command for the low-level worktree mechanics."
---

# Agent Swarm

## Task

Decide whether a coding task warrants parallel fan-out, configure the swarm (size, model mix, aggregation, robustness floors), dispatch it through `/worktree-task-agent`, and aggregate the per-member results into a single chosen or synthesized outcome.

A "swarm" here is `N ≥ 2` sibling agents working the same task in independent git worktrees, with results joined downstream. The mechanics of creating worktrees, dispatching agents, and producing per-worktree diffs are owned by `.cursor/commands/worktree-task-agent.md`; this skill owns the decisions around it — should we swarm at all, how big, which models, how to aggregate, how to survive hangs.

## Parameters

- `{task}` — the underlying coding task each member will attempt. Required.
- `{n}` — number of swarm members; required, integer `≥ 2`. A 1-member "swarm" is a single agent; do not invoke this skill for it.
- `{model_mix}` — how `{agent_model}` is shaped on the downstream `/worktree-task-agent` call: `scalar` (one model broadcast to all `n`), `per-agent` (list of length `n`, one model per slot), or `per-partition` (list of length `num_partitions`, where each contiguous slice of `n / num_partitions` agents shares a model). Optional; default `scalar` using the parent agent's model.
- `{selection_mode}` — how a single answer is extracted from `n` members: `manual` | `auto-best` | `synthesize` | `consensus`. Optional; default `manual`.
- `{test_command}` — shell command each member runs as the objective signal for `auto-best` / `consensus`. Optional, but required when `{selection_mode}` is `auto-best` or `consensus`.
- `{min_successes}` — minimum number of members that must terminate cleanly before aggregation may run. Optional; default `ceil(n/2)`.
- `{relaunch_on_hang_after}` — seconds of no member progress after which the member is killed and marked `incomplete`. Optional; default `1800` (30 min).
- `{replacement_policy}` — `off` | `replace-up-to-n` | `replace-up-to-budget`. Whether killed members are replaced. Optional; default `off` (replacements multiply spend silently).
- `{budget_ceiling}` — soft cap on total tokens or wall-clock seconds across the swarm; aborts new launches once exceeded. Optional; no default.

## Success Criteria

- [ ] Before any worktree is created, the response records the answers to the four "should we swarm?" checks in Workflow step 1 and a one-line verdict (`swarm` or `single-agent`).
- [ ] `{n}` is justified against the sizing tiers in Workflow step 2; any value `> 8` carries an explicit cost note in the response.
- [ ] Worktree creation, agent dispatch, and per-worktree diff reporting are delegated to `/worktree-task-agent`; the response does not inline `git worktree add` invocations.
- [ ] If `{selection_mode}` is `auto-best` or `consensus`, `{test_command}` is set; otherwise the workflow aborts before dispatch.
- [ ] The run terminates when either all `n` members report, or `{min_successes}` succeed and every remaining member has either reported or been killed for exceeding `{relaunch_on_hang_after}`.
- [ ] When `successes < min_successes`, the response does not auto-pick or synthesize; it escalates explicitly with the partial results and a recommended next step.
- [ ] At most one worktree branch is merged back per invocation, and only when `{selection_mode}` is not `synthesize`.
- [ ] The response includes a one-line cost summary: members launched, succeeded, killed, replacements, model mix, elapsed.

## Guardrails

- MUST run the "should we swarm?" check before invoking `/worktree-task-agent`. If two or more of the four checks fail, abort and recommend a single-agent run with a brief rationale.
- MUST delegate all worktree mechanics to `/worktree-task-agent`. MUST NOT re-specify `git worktree add`, branch naming, or per-worktree diff formatting in this skill's output.
- MUST NOT pick a winner via `auto-best` or `consensus` without an objective signal (`{test_command}` exit code, lint pass, or a named heuristic from `{test_command}`'s output). "The diff looks cleanest" is not an objective signal.
- MUST treat `{relaunch_on_hang_after}` as a hard kill, not a polite request; mark the member `incomplete` and continue once `{min_successes}` are in.
- MUST NOT launch replacements when `{replacement_policy}` is `off`, even if members hang.
- MUST NOT exceed `{budget_ceiling}` when set; cancel pending launches and replacements once the running total crosses the ceiling.
- MUST NOT merge any branch when `{selection_mode}` is `synthesize`; the synthesized artifact is a new file or diff written into the calling worktree by the calling agent.
- MUST NOT recursively swarm: a member agent of this swarm MUST NOT invoke `agent-swarm` itself.
- Scope: orchestration of a single swarm for a single `{task}`. Out of scope: bundling unrelated tasks, recursive swarms, leasing models across separate invocations, opening PRs, pushing branches.

## Workflow

### 1. Decide whether to swarm

Answer all four:

1. **Multiple plausible approaches.** Do real alternatives exist (library choice, architecture, tone, algorithm)? If the spec pins down one answer, do not swarm.
2. **Cost of wrong > cost of N.** Is the downside of choosing wrong materially higher than the token / time cost of running `n` parallel attempts? Cheap reversible edits don't earn a swarm.
3. **Non-redundant exploration.** Will independent attempts produce different artifacts? Tasks dominated by mechanical translation usually won't.
4. **Self-contained per-member.** Can a single agent complete the task end-to-end inside one worktree without coordinating subtasks?

If **two or more** answers are "no", abort and run a single agent instead. Record all four answers and the verdict in the response.

### 2. Size the swarm

| Tier | `n` | When to use |
|---|---|---|
| **Sanity** | 2–3 | Cheap "do independent attempts converge?" check; surface disagreement before committing to a direction. |
| **Diversity** | 4–8 | Default range for genuine best-of-N. Token cost roughly `n×` a single agent run. |
| **Search** | >8 | Only with explicit cost justification (security-critical change, expensive-to-undo migration, high-uncertainty refactor). Annotate the response. |

Record the tier alongside `{n}`.

### 3. Choose the model mix

- **`scalar`** — same model across all `n` members. Variation comes from sampling alone. Cheapest, simplest. Default.
- **`per-agent`** — list of length `n`, one model per slot. Use for explicit head-to-head ("does opus beat sonnet on this kind of task?"). Most expensive to reason about.
- **`per-partition`** — list of length `num_partitions`, each model broadcast to `n / num_partitions` contiguous slots. Use when you want diversity *and* duplication for noise control (e.g., `["sonnet", "opus"]` with `n=4` → two sonnet runs, two opus runs).

Resolve the list at this step and carry it into the `/worktree-task-agent` call as `{agent_model}`. Validate length matches the chosen shape; abort on mismatch.

### 4. Choose the aggregation strategy

| Mode | What it does | When to use | Requires |
|---|---|---|---|
| `manual` | Present all member diffs to user; user picks (or skips). | Default; high-stakes, hard to mechanize. | — |
| `auto-best` | Rank by `{test_command}` exit, then secondary heuristics (diff size, lint pass). | Tasks with a clean objective signal (tests, build, types). | `{test_command}` |
| `synthesize` | Calling agent reads all member outputs and writes one unified artifact into the calling worktree. No branch is merged. | When members agree on direction but split on details. | — |
| `consensus` | Accept only the change agreed on by `≥ ceil(n/2) + 1` members (e.g., same hunks at same locations). | High-confidence small edits where noise is the risk. | `{test_command}` |

### 5. Set robustness floors

- `{min_successes}` — default `ceil(n/2)`. Aggregation runs once this many members complete cleanly, even if others are still running or killed.
- `{relaunch_on_hang_after}` — default 30 min. Hard kill on expiry.
- `{replacement_policy}` — default `off`. Replacements multiply spend, so leave off unless you have a clear budget.
- `{budget_ceiling}` — set if total spend is bounded; cancel pending launches and replacements when exceeded.

### 6. Dispatch via `/worktree-task-agent`

Invoke that command with: `{task}`, `parallelism=n`, the resolved `{agent_model}` from step 3, `{test_command}`, and `merge_mode=interactive` (this skill controls merging through aggregation, not through `/worktree-task-agent`'s auto-merge path). Do not duplicate any worktree mechanics here.

### 7. Monitor for hangs

While `/worktree-task-agent` is running, watch for members exceeding `{relaunch_on_hang_after}`. On expiry: kill the member, mark its terminal status `incomplete`, and apply `{replacement_policy}`. Stop launching anything new once `{budget_ceiling}` is crossed.

### 8. Aggregate

Apply `{selection_mode}`:

- **`manual`** — present `/worktree-task-agent`'s per-worktree report verbatim with the swarm rationale prepended; ask which (if any) to merge.
- **`auto-best`** — rank members: first by `{test_command}` exit (`0` beats non-zero), then by a stated secondary rule (e.g., smaller diff, fewer touched files); request the merge of the top member.
- **`synthesize`** — read each member's diff and per-member summary, draft a single unified artifact, write it into the calling worktree (never into a member worktree), present the path. No branch is merged.
- **`consensus`** — compute per-hunk overlap across members; emit the agreed subset as a single artifact and a list of contested hunks for human resolution.

### 9. Escalate when too few succeed

If `successes < min_successes`, do **not** auto-pick or synthesize. Report the partial results and recommend one of: a smaller re-swarm with a tightened task, a single-agent debug run on the failing path, or splitting the task before retrying.

## Output Format

Return a single response with these sections in order. Omit any whose body is legitimately empty (e.g., `Aggregation` is empty before dispatch returns).

### Swarm Decision

- **Verdict:** `swarm` or `single-agent`.
- **Checks:** four bullets answering Workflow step 1.
- **Rationale:** one sentence tying the verdict to the checks.

### Configuration

- `n`: <value> (tier: sanity | diversity | search)
- `model_mix`: <scalar | per-agent | per-partition> → resolved list
- `selection_mode`: <manual | auto-best | synthesize | consensus>
- `test_command`: <command | none>
- `min_successes`: <value>
- `relaunch_on_hang_after`: <seconds>
- `replacement_policy`: <off | replace-up-to-n | replace-up-to-budget>
- `budget_ceiling`: <value | unset>

### Dispatch

The exact `/worktree-task-agent` invocation the skill made or proposes to make, so the user can audit what was kicked off.

### Per-Member Results

Verbatim from `/worktree-task-agent`'s Run Summary + Worktree Results; do not re-flow.

### Aggregation

Per `{selection_mode}`:

- `manual`: "Awaiting user pick." plus the per-worktree merge prompt.
- `auto-best`: ranked list with scores, the chosen winner, and the merge action taken or recommended.
- `synthesize`: the synthesized artifact (fenced diff or file content) and the path it was written to.
- `consensus`: agreed-on hunks (as a unified diff) and a list of contested hunks with the members on each side.

### Cost Summary

One line: `n=<n> succeeded=<k> killed=<j> replacements=<r> models=<list> elapsed=<duration>`.

### Next Steps

- If `successes ≥ min_successes`: the action taken or asked of the user.
- If `successes < min_successes`: explicit escalation (smaller re-swarm with tightened task, single-agent debug run, or split before retry).
