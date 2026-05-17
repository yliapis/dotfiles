---
name: agent-swarm
description: Decide whether to fan a single coding task out across N parallel agents in isolated git worktrees, design the swarm, launch it via the existing /worktree-task-agent slash command, and aggregate the per-agent outcomes into one winner or merged artifact. Use when the user mentions agent fan-out, best-of-N, parallel agents, agent swarm, swarm orchestration, worktree fan-out, ensemble agents, candidate generation, or any request to explore several independent attempts at the same task.
---

# Agent Swarm

## Task

Decide whether to fan a single coding task out across N parallel agents in isolated git worktrees, design the swarm (size, model mix, success floor, hang watchdog, selection mode), launch it by composing with the existing `/worktree-task-agent` slash command, and aggregate the per-agent outcomes into a single recommendation or merged artifact.

Treat a swarm as a portfolio decision: it trades multiplied token cost for variance reduction and approach diversity. Apply this skill only when at least one swarm-positive signal from the Five Questions Gate holds; otherwise, prefer a single agent.

## Parameters

These are design knobs the skill chooses during the workflow, not user inputs. They are surfaced here so the launch invocation is reproducible and the cost/quality trade-off is legible.

- `{n_target}` — target number of agents to fan out. Selected in workflow step 2 from the Sizing Heuristics table; integer in `2..8` (values `> 8` require explicit cost justification).
- `{model_mix}` — model-assignment strategy: `broadcast` (one model for all), `per-agent` (one model per slot), or `per-partition` (one model per contiguous slice). Selected in step 3 from the Model-Mix Decision Table.
- `{selection_mode}` — aggregation strategy: `manual` (user picks), `auto-best` (deterministic rubric), `synthesize` (merge N into 1), or `vote` (majority-shape winner). Selected in step 4 from the Selection Strategy Matrix.
- `{min_successes}` — minimum count of agents that must report `success` before selection runs; integer in `1..n_target`. Default: `ceil(n_target / 2)`. Raise when the cost of a bad winner is high.
- `{relaunch_on_hang_after_s}` — seconds of silence before a hung agent is killed and replaced; integer. Default: `300` for code tasks, `120` for prompt-refinement tasks. At most one round of replacements per swarm.
- `{budget_cap_tokens}` — approximate ceiling on combined token spend; bounds `{n_target}` via `floor(budget / per_agent_estimate)`. Optional; default: no cap.

## Success Criteria

- [ ] The swarm-vs-single decision is recorded explicitly, citing at least one swarm-positive signal from the Five Questions Gate; if no signal holds, the skill exits early and a single agent is used.
- [ ] `{n_target}` is selected from the Sizing Heuristics table (not picked by feel) and the chosen tier name appears in the Swarm Design report.
- [ ] `{model_mix}` is named and the exact value passed for `/worktree-task-agent`'s `{agent_model}` parameter matches one of the three shapes the command accepts (scalar, list of length `{parallelism}`, or list of length `{num_partitions}`).
- [ ] The swarm is launched by composing with `/worktree-task-agent`; worktree creation, branch naming, and per-agent dispatch are NOT reimplemented inside this skill.
- [ ] A `{min_successes}` floor is enforced before aggregation; when fewer than `{min_successes}` agents report `success` after the allowed replacement round, the skill escalates to the user instead of selecting from a degraded field.
- [ ] The reply names the chosen `{selection_mode}`, the per-agent verdict (success / failed / hung / replaced), the selected winner (or `none`), and a one-line rationale grounded in the selection mode's criteria.
- [ ] Total estimated combined token spend across launched + replaced agents is reported alongside the recommendation, with a one-sentence judgment of whether the swarm was worth its cost.

## Guardrails

- MUST compose with `/worktree-task-agent` for all worktree creation, branch management, and per-agent dispatch; MUST NOT shell out to `git worktree add` directly from this skill.
- MUST NOT swarm when none of the Five Questions Gate answers is yes; a single agent is the default.
- MUST NOT exceed `{budget_cap_tokens}` when it is set; reduce `{n_target}` to fit the cap instead.
- MUST NOT merge more than one worktree branch back into the base branch per swarm invocation; when multiple outputs should be combined, use `selection_mode = synthesize` and merge them as files, not branches.
- MUST NOT raise `{n_target}` above 8 without recording an explicit cost justification (token budget, latency requirement, or diversity argument) in the launch summary.
- MUST escalate to the user when `{min_successes}` is not met after one round of replacements; never silently pick a winner from a thin field.
- MUST stay inside the worktree(s) `/worktree-task-agent` creates; agents MUST NOT read, write, or run commands against the calling working tree or any sibling worktree.
- Scope: deciding whether to fan out, sizing the swarm, picking the model mix, launching via the existing command, and aggregating outcomes. Out of scope: implementing worktree mechanics, opening PRs, pushing branches, training models, or persisting cross-invocation history.

## Workflow

1. **Apply the Five Questions Gate.** Answer each question below before designing anything. A swarm is justified only when at least one answer is yes; if all are no, exit this skill and run a single agent.
   - **Q1: Multiple plausible approaches?** Are there ≥2 reasonable designs (recursive vs iterative, library A vs B, monolith vs split) where the right one is non-obvious without trying both?
   - **Q2: High cost of being wrong?** Would a wrong-first-pass result (subtle bug, bad API choice, security regression) be expensive to detect or roll back?
   - **Q3: Independent exploration valuable?** Will seeing several attempts surface trade-offs you can't predict from one (diff size, test breakage, performance shape)?
   - **Q4: Open prompt/design space?** Is the task itself under-specified, so different agents will reasonably interpret it differently and that variance is informative?
   - **Q5: Cross-model disagreement informative?** Would running the same task on different models (Sonnet vs Opus vs GPT-class) teach you something even on a well-specified task?
   - Record which questions answered yes; cite at least one in the launch summary.

2. **Choose `{n_target}` from the Sizing Heuristics table.** Pick the lowest tier that still answers the Five Questions Gate. If `{budget_cap_tokens}` is set, cap at `floor(budget / per_agent_estimate)`.

   | Tier | `{n_target}` | When to use | Cost mindset |
   |------|---|---|---|
   | Sanity | 2–3 | Verifying a single agent's answer; cheap disagreement detection | ≈3× single-agent cost; minimal latency hit |
   | Diversity | 4–6 | Multiple plausible approaches; open design space; comparing diffs | ≈5× cost; parallelizes well |
   | Wide search | 7–8 | Refining a prompt/architecture where variance matters; multi-model experiment | ≈8× cost; requires explicit justification |
   | Extra-wide | >8 | Avoid unless you have both a budget argument and a strong selection rubric | Cost grows linearly; aggregation quality degrades |

3. **Choose `{model_mix}` from the Model-Mix Decision Table.** Default to `broadcast` when the parent agent's model is already strong for this task class; switch to `per-agent` or `per-partition` only when cross-model signal (Q5) is itself one of the yes-answers.

   | Strategy | When to use | Maps to `/worktree-task-agent` `{agent_model}` |
   |---|---|---|
   | `broadcast` | Variance comes from sampling, not model; baseline default | scalar id (e.g., `"sonnet"`) |
   | `per-agent` | Maximize approach diversity at small N (≤4); each slot a distinct model | list of length `{n_target}` (e.g., `["sonnet","opus","haiku","sonnet"]`) |
   | `per-partition` | Want both within-model variance and cross-model comparison; group agents into 2–3 contiguous slices, one model per slice | list of length `{num_partitions}` paired with `{num_partitions}` (e.g., 4 agents, 2 partitions, `["sonnet","opus"]`) |

4. **Choose `{selection_mode}` from the Selection Strategy Matrix.** If unsure, default to `manual` when `n_target ≤ 4` and `auto-best` when `n_target ≥ 5` and `{test_command}` is meaningful.

   | Mode | Picks | When | Aggregator artifact |
   |---|---|---|---|
   | `manual` | User chooses from the per-worktree report | Stakes are high or the rubric is implicit | The `/worktree-task-agent` interactive prompt |
   | `auto-best` | Highest-ranked agent by deterministic rubric: test exit code, then summary length, then diff size | `{test_command}` is set and is a meaningful pass/fail | A short rubric documented in the launch summary |
   | `synthesize` | A single new artifact merged from N candidates | Outputs are additive (prompt variants, doc sections), not mutually exclusive | A merge prompt or shell command run on the N outputs |
   | `vote` | Most-common-shape winner (e.g., semantically equivalent diffs) | `n_target ≥ 5` and outputs are structurally comparable | A signature function (test exit code + diff shape hash) |

5. **Set the success floor and the hang watchdog.**
   - `{min_successes}` defaults to `ceil(n_target / 2)`. Raise to `n_target − 1` when Q2 answered yes (high cost of being wrong). Never lower below 1.
   - `{relaunch_on_hang_after_s}` defaults to `300` for code tasks, `120` for prompt-refinement tasks. Replacement policy: kill the silent worktree, recreate it with the same model assignment, and count replacements toward `{min_successes}`. Allow at most one round per swarm.

6. **Compose the launch invocation.** Map every chosen knob onto `/worktree-task-agent`'s parameters:
   - `{task}` ← the original task statement, verbatim.
   - `{parallelism}` ← `{n_target}`.
   - `{agent_model}` ← the value from step 3 (scalar or list).
   - `{num_partitions}` ← set only when `{model_mix}` is `per-partition`.
   - `{test_command}` ← present iff `{selection_mode}` is `auto-best` or `vote`.
   - `{merge_mode}` ← `interactive` when `{selection_mode}` is `manual` or `synthesize`; `auto` only when `{selection_mode}` is `auto-best` AND `{min_successes}` was met by clean `success` results.
   - Do not pass worktree paths or branch names manually; let the slash command derive them.

7. **Monitor, replace, aggregate.**
   - Watch per-agent terminal status as `/worktree-task-agent` reports back. When an agent produces no output for `{relaunch_on_hang_after_s}`, kill and recreate it (single round only).
   - When all agents have terminated (or the replacement round is exhausted), count `success` results. If `< {min_successes}`, stop and escalate to the user with the partial report; do NOT pick a winner.
   - When `≥ {min_successes}` clean results are in, run the selection-mode aggregator from step 4 and produce one recommendation.

8. **Report using the Output Format below.** Always include the cost estimate and a one-sentence judgment of whether the swarm was worth its multiplied cost.

## Output Format

Return a single message with these named sections in this order. Omit sections that legitimately have no body (e.g., no replacements occurred, no escalation needed).

### Swarm Decision

- `Verdict`: `swarm` or `single`. When `single`, the rest of the message is the Five Questions answers and a one-line rationale; remaining sections are omitted.
- `Signals`: which of the Five Questions answered yes (e.g., `Q1: multiple approaches; Q3: independent exploration`).
- `Anti-signals`: which conditions made fan-out borderline (token cost, simple task, narrow design space).

### Swarm Design

- `n_target`: chosen size and its tier name from the Sizing Heuristics table.
- `model_mix`: strategy + the exact value passed for `/worktree-task-agent`'s `{agent_model}` parameter.
- `selection_mode`: chosen mode and the aggregator artifact (rubric text, merge prompt, or signature function).
- `min_successes`: floor value and the reasoning.
- `relaunch_on_hang_after_s`: watchdog value and the reasoning.
- `budget_cap_tokens`: cap value (or `none`) and the implied per-agent budget.

### Launch Invocation

A copy-pasteable invocation of `/worktree-task-agent` with every parameter resolved, in a fenced code block. Example shape:

```
/worktree-task-agent task="<verbatim task>" parallelism=4 agent_model="sonnet" test_command="pytest -q" merge_mode=interactive
```

### Outcomes

A table with one row per agent (including replacements):

| Index | Model | Status | Hung? | Replaced? | Diff size | Test result | Notes |
|---|---|---|---|---|---|---|---|

Followed by:

- `successes / target`: e.g., `5 / 6`.
- `floor met`: `yes` or `no`.

### Recommendation

- `Winner`: branch name, or `none` when `{min_successes}` was unmet.
- `Rationale`: one line grounded in the selection mode's criteria.
- `Synthesis artifact`: present only when `{selection_mode}` is `synthesize`; describe or link the merged result.
- `Escalation`: present only when the floor was unmet; explain what the user must decide.

### Cost Estimate

- `Agents launched (including replacements)`: integer count.
- `Approximate combined token spend`: figure with units.
- `Was the swarm worth it?`: one sentence comparing the recommendation's quality to the multiplied cost.
