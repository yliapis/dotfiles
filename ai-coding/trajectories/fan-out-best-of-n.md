# Trajectory: Fan-Out Best-of-N Prompt Refinement

Working notes for evolving `meta-prompt.md` and `worktree-task-agent.md` toward a clean composition for fan-out, parallel best-of-N prompt and code refinement.

## Why this exists
`meta-prompt.md` produces a single refined prompt; with `{n} > 1` it fans out into parallel candidates and writes each variant to disk. `worktree-task-agent.md` runs one or more agents against a single task and merges at most one branch. Fan-out plumbing is now first-class in both commands; what still requires manual orchestration is **selection / synthesis across variants** (picking a winner or merging across `n` candidates) and **robustness under partial failure** (hung agents, cross-invocation collisions). This file captures the remaining gaps, the parameter ideas still in flight, and the open questions for closing the loop.

## Observations from recent runs
- Prose-with-explicit-constraints (integer `>= 1`, list length matches parallelism, scalar broadcasts) survived re-readings of `{agent_model}` and `{parallelism}` better than Python-typed signatures; the lesson is that constraint prose travels through agents more reliably than type annotations. *(behavior addressed by `worktree-task-agent.md`)*
- `{parallelism} > 1` contradicted the original "one worktree, one resulting branch" scope; the reconciliation kept multiple worktrees as candidates while capping merges at one per invocation. *(addressed by `worktree-task-agent.md` Guardrails)*
- `{num_partitions}` was added to express grouping of agents/models: a partition is a contiguous slice of `{parallelism} / {num_partitions}` agents that share one `{agent_model}` (default `1` puts every agent in a single partition; `{num_partitions}` must divide `{parallelism}` evenly). The three supported `{agent_model}` shapes, illustrated for `{parallelism}=4, {num_partitions}=2` (2 agents per partition): scalar — `"sonnet"` broadcasts to all 4 agents; list-by-agent of length `{parallelism}` — `["sonnet", "sonnet", "opus", "opus"]` assigns one model per agent positionally; list-by-partition of length `{num_partitions}` — `["sonnet", "opus"]` assigns one model per partition, broadcast to its 2 agents (so agents 1-2 get sonnet, agents 3-4 get opus). *(partially addressed by `worktree-task-agent.md` — gap: the worked examples above are not yet reflected in `worktree-task-agent.md` itself)*
- Hung subagents (2 of 8 in one batch) returned no diff and required interrupt + relaunch; there is no built-in "minimum success count" or replacement policy.
- `{worktree_name}` collisions within an invocation are avoided with a 1-based `-{i}` suffix. *(partially addressed by `worktree-task-agent.md` — gap: cross-invocation collisions on a re-run of the same task name are not yet handled)*

## Parameter ideas to consider

### For `worktree-task-agent.md`
- `{min_successes}` — minimum number of agents that must complete successfully before synthesis or selection is attempted; default `1`.
- `{relaunch_on_hang_after}` — duration in seconds after which a hung agent is auto-aborted and replaced; no default (required when enabled).
- `{selection_mode}` — `manual` (interactive pick) | `auto-best` (rank by `{test_command}` exit plus an explicit rubric — see Open Questions) | `synthesize` (merge outputs into a single result rather than picking one). *(partially addressed by `worktree-task-agent.md` `{merge_mode}` — gap: `auto` lacks a ranking rubric; `synthesize` mode is not implemented)*
- `{candidate_aggregator}` — optional, either an `{aggregator_command}` (shell command run against the per-worktree results) or an `{aggregator_prompt}` (LLM prompt with the per-worktree results inlined); pick one form or split into two parameters so the contract is unambiguous. Depends on `{selection_mode} = synthesize`.
- `{merge_count}` — explicit values: `one` | `all-passing` | `user-pick-multi` (user picks a subset of passing branches, capped at `{parallelism}`). *(partially addressed by `worktree-task-agent.md` — gap: only `one` is currently enforced; `all-passing` and `user-pick-multi` are not selectable)*
- `{worktree_root}` — directory under which to create worktrees, for layout control.

### For `meta-prompt.md`
- `{focus_hints}` — list of refinement angles, one per candidate (e.g., `tighten guardrails`, `clarify parameters`, `improve workflow steps`); makes the `{n} > 1` fan-out produce deliberately distinct candidates rather than i.i.d. ones.
- `{compare_against}` — for REFINE, optionally provide a baseline + comparison rubric so candidates can be ranked.
- `{require_diff}` — emit a diff against the original alongside each candidate.
- `{auto_save_winner}` — if `{n} > 1` and a clear winner is selected, persist it to `{save_path}` automatically. Depends on `{selection_mode} ∈ {auto-best, synthesize}` having a defined "winner" contract (see the `auto-best` rubric experiment below).

## Open design questions
- How should non-determinism be controlled across parallel agents — distinct `{agent_model}` per slot, varied temperature, or distinct `{focus_hints}`? *(partially addressed by `worktree-task-agent.md` `{agent_model}` shapes — gap: temperature variation and `{focus_hints}` are not available)*
- Where does ranking / selection logic live — inside `worktree-task-agent.md` (generic, parameterized by a rubric) or inside the calling command (e.g., `meta-prompt.md`)? *(partially addressed: `worktree-task-agent.md` handles merge selection, `critique.md` provides the rubric framework, but no concrete cross-variant ranking is wired up)*
- Should agent hangs be a first-class concern with a retry policy, or stay manual?
- When the inputs to a fan-out are themselves diffs (best-of-N code refinement), how should worktrees be presented — as named candidates with shared context, or as competing branches like today? *(partially addressed: `worktree-task-agent.md` uses competing branches; the named-candidates-with-shared-context alternative is unexplored)*

## Next experiments
- [ ] Copy the three `{num_partitions}` worked examples (scalar / list-by-agent / list-by-partition) from this file into `worktree-task-agent.md`. *Done when:* each shape has one inline example in `worktree-task-agent.md`, and the Observation above no longer carries a gap annotation.
- [ ] Add `{focus_hints}` to `meta-prompt.md`. *Done when:* the spec lists the parameter and shows one worked example of per-variant hint dispatch under `{n} > 1`.
- [ ] Pilot `{min_successes}` in `worktree-task-agent.md`. *Done when:* a `{parallelism}=4, {min_successes}=2` run with 2 deliberate failures completes selection rather than aborting.
- [ ] Pilot `{relaunch_on_hang_after}` in `worktree-task-agent.md`. *Done when:* a deliberately-hung subagent is auto-aborted and replaced once within the configured duration.
- [ ] Define a concrete `auto-best` selection rubric (inputs, scoring, tie-breakers). *Done when:* the rubric is documented in `worktree-task-agent.md` with at least one named tie-breaker, and `{auto_save_winner}` cites it as its "clear winner" contract.
