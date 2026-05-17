---
name: agent-swarm
description: Orchestrates parallel agent fan-out and best-of-N exploration across isolated git worktrees, including the swarm-vs-solo decision, swarm sizing, model-mix shape, aggregation strategy (manual pick, auto-best, synthesize, vote, hybrid), and hang/timeout handling. Use when the agent considers an agent swarm, agent fan-out, best-of-N, parallel agent runs, swarm orchestration, or worktree fan-out for a task with multiple plausible approaches or an open design space.
---

# Agent Swarm

## Task

Decide whether to fan a single task out across N parallel agents in isolated git worktrees, and — when fan-out is warranted — pick the sizing, model-mix shape, selection mode, and robustness floors before delegating worktree mechanics to `.cursor/commands/worktree-task-agent.md`. After the swarm completes, aggregate the per-member results into exactly one final artifact and report the decisions that produced it.

This skill is the policy layer above `worktree-task-agent`. It chooses *whether* and *how* to swarm; `worktree-task-agent` performs the actual worktree create / launch / merge plumbing.

## Parameters

- `{task}` — the task statement each swarm member must attempt; required.
- `{n}` — number of swarm members; optional, default: `1` (no fan-out). MUST be an integer in `1..8` unless a one-line cost justification is provided.
- `{selection_mode}` — how to produce the final artifact from the swarm; one of `manual`, `auto-best`, `synthesize`, `vote`, `hybrid`; optional, default: `manual`.
- `{agent_model}` — model identifier(s); optional. Accepts a scalar (broadcast), a length-`{n}` per-agent list, or a length-`{num_partitions}` per-partition list.
- `{num_partitions}` — contiguous slice count for partitioned models; optional, default: `{n}`. MUST divide `{n}` evenly.
- `{min_successes}` — minimum members that must complete before selection runs; optional, default: `ceil({n} / 2)`. MUST be an integer in `1..{n}`.
- `{relaunch_on_hang_after}` — duration a member may stay silent before it is aborted and replaced; optional, default: `none` (no automatic replacement).
- `{test_command}` — verification command each member runs in its worktree; optional. Required when `{selection_mode}` is `auto-best` or `hybrid`.
- `{aggregator}` — command or prompt that produces a merged artifact from successful members; optional. Required when `{selection_mode}` is `synthesize`.

## Success Criteria

- [ ] A swarm-vs-solo decision is made and recorded before any worktree is created, citing at least one row of the Swarm Trigger Table; when no trigger fires, the task runs with a single agent and the workflow stops.
- [ ] `{n}` aligns with the Sizing Heuristic Table (small `2-3`, medium `4-8`, large `>8` only with explicit cost justification captured in the Swarm Decision section).
- [ ] When `{n} > 1`, worktree creation, branch naming, and merge-back are delegated to `.cursor/commands/worktree-task-agent.md`; no `git worktree add` or branch plumbing is inlined here.
- [ ] The chosen `{selection_mode}` is consistent with the Selection Mode Decision Table given the presence (or absence) of `{test_command}` and `{aggregator}`.
- [ ] The model-mix shape (scalar / per-agent / per-partition) is named explicitly in the Swarm Decision section, not left implicit.
- [ ] When fewer than `{min_successes}` members succeed before the hang-budget exhausts, the workflow escalates to the user with partial results rather than auto-selecting a sub-quorum winner.
- [ ] Exactly one final artifact is produced per invocation: one picked branch, one synthesized file, one vote winner, or an explicit `none — escalated`.
- [ ] The final report names the trigger that fired, the sizing rationale, the model-mix shape, the selection mode, the winner (or synthesized artifact), and the per-member status.

## Guardrails

- MUST consult the Swarm Trigger Table first and run the task with a single agent when no trigger fires; agent swarms are not the default.
- MUST delegate worktree creation, branch naming, and merge-back to `.cursor/commands/worktree-task-agent.md`; if that command is missing, abort with an explanatory error.
- MUST cap `{n}` at `8` unless the invocation includes a one-line written cost justification (token budget vs. latency win vs. quality threshold).
- MUST treat `{min_successes}` as a hard floor; when unmet after `{relaunch_on_hang_after}` budget exhausts, surface partial results and stop rather than auto-pick.
- MUST emit exactly one final artifact per invocation (picked branch / synthesized file / vote winner / explicit escalation); MUST NOT silently merge multiple winners or stack outputs.
- MUST NOT recursively fan out: spawned swarm members never invoke this skill themselves.
- MUST NOT re-specify worktree, branch, or merge mechanics inline; refer to `.cursor/commands/worktree-task-agent.md` instead.
- Scope: this skill decides whether and how to swarm, sets robustness parameters, and aggregates results. Out of scope: worktree plumbing, branch merge mechanics, pushing, opening PRs, and the implementation work performed by individual swarm members.

## Workflow

### 1. Swarm-vs-solo decision

Consult the Swarm Trigger Table. Fan out only if at least one trigger fires; otherwise run the task with a single agent and stop. Record the trigger row verbatim in the Swarm Decision section.

**Swarm Trigger Table**

| Trigger | Fan out? |
|---|---|
| Multiple plausible approaches with non-trivial trade-offs | Yes |
| Cost of being wrong (regression, irreversible change) is high | Yes |
| Prompt or design space is genuinely open | Yes |
| Independent exploration would surface useful disagreement signal | Yes |
| Single best answer is already obvious from the brief | No (solo) |
| Token cost dominates the latency budget | No (solo) |
| Task is mechanically deterministic (rename, format, scripted refactor) | No (solo) |

### 2. Size the swarm

Pick `{n}` from the Sizing Heuristic Table. Default to the lower end of each band; only widen when the trigger that fired specifically argues for more diversity.

**Sizing Heuristic Table**

| Band | `{n}` | Use for |
|---|---|---|
| Small | `2-3` | Sanity check, disagreement detection, cheap second opinion |
| Medium | `4-8` | Best-of-N quality, diverse approaches, prompt refinement |
| Large | `>8` | Only with explicit cost justification recorded in Swarm Decision |

### 3. Choose the model-mix shape

Name one shape explicitly. Semantics mirror `.cursor/commands/worktree-task-agent.md`; do not redefine them here.

| Shape | When |
|---|---|
| Scalar broadcast | Same model for every member — diversity from sampling alone |
| Per-agent list (length `{n}`) | Heterogeneous models, one slot per agent |
| Per-partition list (length `{num_partitions}`) | Grouped diversity: contiguous slices share a model |

### 4. Pick the selection mode

Use the Selection Mode Decision Table. The mode determines what "winning" means and which auxiliary parameters are required before launch.

**Selection Mode Decision Table**

| `{selection_mode}` | When | Requires |
|---|---|---|
| `manual` | High-stakes or irreversible changes; human review essential | nothing extra |
| `auto-best` | A clear pass/fail signal exists for the task | `{test_command}` |
| `synthesize` | Each member contributes partial insight; merge yields better than any one | `{aggregator}` |
| `vote` | Diversity is the point; majority answer is meaningful | `{n} >= 3` |
| `hybrid` | Auto-filter to passing members, then human picks from the filtered set | `{test_command}` |

### 5. Set robustness floors

- Choose `{min_successes}`; default to `ceil({n} / 2)`.
- Set `{relaunch_on_hang_after}` only when the task is long-running or known to hang; otherwise leave unset and accept that hangs require manual intervention.
- A relaunched member counts toward `{min_successes}` only if it itself succeeds.

### 6. Cost-vs-latency check

Before launch, confirm the swarm is worth the multiplied cost. If the situation does not justify it, downgrade to solo and stop.

| Situation | Pick |
|---|---|
| Latency-bound, budget available | Fan out (parallelism wins the wall clock) |
| Token-bound, deterministic task | Solo (avoid the fan-out tax) |
| Quality-bound, single try too risky | Fan out (best-of-N) |
| Exploratory, individual runs are cheap | Fan out at small `{n}` |
| One agent already produces a verifiable correct result | Solo |

### 7. Hand off to `/worktree-task-agent`

Invoke `.cursor/commands/worktree-task-agent.md` with the resolved parameters:

- `{task}` — from this invocation
- `{parallelism}` — equal to `{n}`
- `{agent_model}` — chosen shape (scalar / per-agent / per-partition)
- `{num_partitions}` — when applicable
- `{test_command}` — when applicable

Do not inline worktree mechanics. Wait for the swarm to settle: either all members report terminal status, or `{min_successes}` is met and the hang budget expires for the rest.

### 8. Aggregate per `{selection_mode}`

- `manual` — present the per-member roster; ask the user to pick one branch.
- `auto-best` — among members where `{test_command}` exited `0`, pick the lowest-index one; tie-break by terminal status `success` over `incomplete`.
- `synthesize` — run `{aggregator}` over the successful members' diffs or outputs; emit one merged artifact.
- `vote` — group members by output equivalence; pick the largest group; tie-break by lowest-index.
- `hybrid` — filter to members passing `{test_command}`, then ask the user to pick from the filtered set.

If fewer than `{min_successes}` members succeeded, do not aggregate; escalate instead.

### 9. Report

Emit the Output Format below. Never silently emit a sub-quorum winner; escalate.

## Output Format

Reply with these sections, in this order. Omit `Escalation` when `min_successes` was met and a winner was selected.

### Swarm Decision
- Trigger fired: `<row from Swarm Trigger Table, or "none — running solo">`
- `{n}`: `<integer>`; sizing band: `small` | `medium` | `large`; rationale: `<one line>`
- Model mix: `scalar` | `per-agent` | `per-partition`
- `{selection_mode}`: `<mode>`; rationale: `<one line>`
- Robustness: `{min_successes}` = `<int>`, `{relaunch_on_hang_after}` = `<duration or none>`
- Cost-vs-latency: `<one line tying the choice to a row of the cost-vs-latency table>`

### Fan-Out Hand-Off
Delegated to `.cursor/commands/worktree-task-agent.md` with the parameters above. Record the shared `WORKTREE_ID` and each `WORKTREE_PATH` reported back by that command.

### Member Roster
One block per member, in launch order:
- `Index`: 1-based
- `Status`: `success` | `failed` | `incomplete` | `replaced`
- `Model`: `<identifier>`
- `Summary`: 1–3 bullets describing what the member produced
- `Verification`: `{test_command}` exit code, or `n/a`

### Aggregation
- Mode: `<selection mode>`
- Successes / total: `<count> / {n}`
- Final artifact: `<picked branch + path>` | `<synthesized file path>` | `<vote winner index>` | `none — escalated`
- Rationale: one paragraph tying the artifact back to the trigger that fired and the selection mode.

### Escalation
Present only when `{min_successes}` was not met or no winner could be selected. List partial results per member and ask the user how to proceed (relax the floor, re-run with a different model mix, accept partial output, or abort). Do not auto-select.
