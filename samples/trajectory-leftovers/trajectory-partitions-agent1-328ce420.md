# Trajectory: Fan-Out Best-of-N Prompt Refinement

Working notes for evolving `meta-prompt.md` and `worktree-task-agent.md` toward a clean composition for fan-out, parallel best-of-N prompt and code refinement.

## Why this exists
`meta-prompt.md` produces a single refined prompt. `worktree-task-agent.md` runs one or more agents against a single task. The combination — "produce N refined candidates of the same prompt (or N code attempts at the same task) in parallel, then pick the best" — currently requires manual orchestration. This file captures the gaps, parameter ideas, and open questions for making that composition first-class.

## Observations from recent runs
- `{agent_model}` and `{parallelism}` were originally added with Python-typed signatures; normalized to prose with explicit constraints (integer `>= 1`, list length matches parallelism, scalar broadcasts).
- `{parallelism} > 1` contradicts the original scope guardrail ("one worktree, one resulting branch"); the synthesized version restricts merges to "at most one per invocation" but keeps multiple worktrees as candidates.
- `{num_partitions}` groups the `{parallelism}` agents into that many contiguous blocks of `{parallelism} / {num_partitions}` agents each; a partition is the unit that shares whatever varies at the partition level (currently the `{agent_model}` slot). Supported `{agent_model}` shapes (illustrated with `{parallelism} = 4`, `{num_partitions} = 2`): a scalar like `claude-opus-4` broadcasts one model to every agent (independent of `{parallelism}` and `{num_partitions}`); a list-by-agent of length `{parallelism}` (so 4 entries here, one model per agent positionally); a list-by-partition of length `{num_partitions}` (so 2 entries here, one model per partition, broadcast to the 2 agents in that partition). Whether `{parallelism}` must be divisible by `{num_partitions}` is still under design.
- Hung subagents (2 of 8 in one batch) returned no diff and required interrupt + relaunch; there is no built-in "minimum success count" or replacement policy.
- `{worktree_name}` collisions are avoided with a 1-based `-{i}` suffix, but cross-invocation collisions (same task name re-run) are not yet addressed.

## Parameter ideas to consider

### For `worktree-task-agent.md`
- `{min_successes}` — minimum number of agents that must complete successfully before synthesis or selection is attempted; default `1`.
- `{relaunch_on_hang_after}` — duration after which a hung agent is auto-aborted and replaced.
- `{selection_mode}` — `manual` (interactive pick) | `auto-best` (rank by `{test_command}` exit + summary heuristics) | `synthesize` (merge outputs into a single result rather than picking one).
- `{candidate_aggregator}` — optional command or prompt that produces a final synthesized artifact from the per-worktree results.
- `{merge_count}` — currently implicitly capped at one; consider explicit values (`one` | `all-passing` | `user-pick-multi`).
- `{worktree_root}` — directory under which to create worktrees, for layout control.

### For `meta-prompt.md`
- `{n_candidates}` — produce N candidate prompts in one invocation (CREATE + REFINE) and present them side by side.
- `{focus_hints}` — list of refinement angles, one per candidate (e.g., `tighten guardrails`, `clarify parameters`, `improve workflow steps`).
- `{compare_against}` — for REFINE, optionally provide a baseline + comparison rubric so candidates can be ranked.
- `{require_diff}` — emit a diff against the original alongside each candidate.
- `{auto_save_winner}` — if `{n_candidates}` > 1 and a clear winner is selected, persist it to `{save_path}` automatically.

## Open design questions
- Should "best-of-N prompt refinement" be a new dedicated command (e.g., `/refine-best-of-n`) that wires `meta-prompt` and `worktree-task-agent` together, or expressed by composing the two?
- How should non-determinism be controlled across parallel agents — distinct `{agent_model}` per slot, varied temperature, or distinct `{focus_hints}`?
- Where does ranking / selection logic live — inside `worktree-task-agent` (generic) or inside a future `refine-best-of-n` command (domain-specific)?
- Should agent hangs be a first-class concern with a retry policy, or stay manual?
- When the inputs to a fan-out are themselves diffs (best-of-N code refinement), how should worktrees be presented — as named candidates with shared context, or as competing branches like today?

## Next experiments
- [ ] Resolve `{num_partitions}` semantics in `worktree-task-agent.md` with at least one worked example per shape.
- [ ] Add `{n_candidates}` + `{focus_hints}` to `meta-prompt.md` and have it itself fan out via `worktree-task-agent.md`.
- [ ] Pilot `{min_successes}` and `{relaunch_on_hang_after}` in `worktree-task-agent.md` to make fan-out robust to hangs.
- [ ] Prototype a `/refine-best-of-n` command that ties `meta-prompt.md` and `worktree-task-agent.md` together end-to-end.
- [ ] Define a selection rubric so `auto-best` selection mode has a concrete contract.
