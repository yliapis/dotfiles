# Inner vs. Outer — Depth Disambiguation

A single command runs a lifecycle. Inside its `execute` stage it may launch subagents, each running *their own* lifecycle. The same parameter name (`task`, `parallel`, `criteria`, `save_path`, …) can therefore refer to two different things depending on which lifecycle you're inside. This file is the canonical disambiguation.

## Depth conventions

- **outer** — refers to the orchestrating command's lifecycle (the user-invoked one).
- **inner** — refers to one subagent's lifecycle, nested inside the outer command's `execute` stage.
- **both** — the parameter exists at both levels with related but distinct meaning; the rules below resolve which one applies.
- For commands with more than one nesting level, "inner" recurses: the inner-inner is a third lifecycle. The same rules apply at each level.

## The default inheritance rule

For every `Depth: both` parameter, the inner value defaults to the resolved outer value unless the command explicitly overrides. Overrides happen in two places:

1. **Plan stage** (the most common): the outer command emits a per-slot config that overrides one or more parameters for the inner agent (e.g. distinct `subagent_model` per slot, distinct `focus_hints[i]`).
2. **Inner input stage**: the inner agent itself re-resolves parameters from its own prompt — typically because its `subagent_prompt` carried explicit `{param} = value` directives.

Override at plan beats inheritance; explicit inner override beats both.

## The four recurring names

The user-task brief calls these out explicitly. Resolution at each lifecycle stage:

### `task`

| Stage     | Outer meaning                                          | Inner meaning                                                       |
| --------- | ------------------------------------------------------ | ------------------------------------------------------------------- |
| input     | the command's overall task statement                   | the per-slot prompt the outer plan handed down (`subagent_prompt`) |
| plan      | decomposed into `subagent_prompt` for each slot        | (typically degenerate — inner usually doesn't re-decompose)        |
| execute   | "orchestrate slots until selection completes"          | "implement the slice in the assigned slot's sandbox"                |
| evaluate  | "did the invocation meet its overall goal?"            | "did this slot complete its slice?"                                |
| select    | "which slots advance to persist?"                      | (typically degenerate)                                              |
| persist   | "merge / save the selection set"                       | "write whatever the slice produced into the slot's sandbox"        |
| report    | the user-facing aggregated report                      | the per-slot artifact the outer report aggregates                  |

**Rule:** inner `task` = `subagent_prompt[i]`, which is derived from outer `task` + `focus_hints[i]` + slot context. They are related but not equal. The outer task statement is rarely passed verbatim to inner slots; the plan stage decides the slicing.

### `parallel`

| Stage   | Outer meaning                                            | Inner meaning                                              |
| ------- | -------------------------------------------------------- | ---------------------------------------------------------- |
| plan    | how many sibling subagents the outer command fans out    | how many sub-subagents each inner agent may itself launch  |
| execute | the wall-clock width of the outer fan-out                | the wall-clock width *inside* an inner agent's own work    |

**Rule:** outer `parallel` × inner `parallel` is the worst-case wall-clock concurrency. Default inheritance is **broken** here: inner `parallel` defaults to `1`, not to outer `parallel`. (Otherwise a `parallel = 8` outer would by default fan out to 8 × 8 = 64 leaf agents, which is rarely intended.) Inner `parallel > 1` requires explicit opt-in via `subagent_constraints` or a recursive command design.

### `criteria`

| Stage    | Outer meaning                                                       | Inner meaning                                                         |
| -------- | ------------------------------------------------------------------- | --------------------------------------------------------------------- |
| input    | the command-wide rubric the user supplied                          | the rubric each subagent judges its own slice against                 |
| evaluate | applied across all slot evaluations (e.g. to filter or rank)        | applied per slot during inner evaluate                                |

**Rule:** inner `criteria` defaults to outer `criteria` verbatim. The override case is rare and almost always *additive* (`subagent_constraints` layered on top, not replacing). Critique-style commands where outer rubric = inner rubric are the typical case; multi-rubric fan-out commands are an open design area (per `trajectory.md`).

### `save_path`

| Stage   | Outer meaning                                          | Inner meaning                                                                   |
| ------- | ------------------------------------------------------ | ------------------------------------------------------------------------------- |
| input   | the user-facing destination for the final artifact     | usually unset — inner agents write to sandbox temp paths, not user paths      |
| persist | written: the file the user opens at the end           | the per-slot artifact path inside `worktree_root/<slot>` (or analogous sandbox) |

**Rule:** inner `save_path` is **not** inherited from outer. Inner agents write inside their isolation boundary; the *outer* persist stage is what moves the winning slot's artifact to outer `save_path`. If you set inner `save_path` explicitly, you are deliberately bypassing isolation — typically only correct for read-only inner stages.

## Full disambiguation table

Every "Depth: both" parameter in this ontology, with its outer-to-inner relationship:

| Parameter             | Outer scope                       | Inner scope                          | Inheritance default                       |
| --------------------- | --------------------------------- | ------------------------------------ | ----------------------------------------- |
| `task`                | command's task                    | slot's slice (`subagent_prompt[i]`)  | derived (not equal); plan controls       |
| `context`             | full context                      | per-slot scope                       | sliced (per-partition); plan controls    |
| `file` / `directory` / `glob` / `url` / `inline` | source forms for outer `context` | source forms for inner sub-context | sliced |
| `format`              | format of outer `context`         | format of inner scope                | inherit                                   |
| `criteria`            | command-wide rubric               | per-slot rubric                      | inherit verbatim                          |
| `guardrails`          | command-wide MUST/MUST-NOT        | per-slot rules                       | inherit + additive (`subagent_constraints`) |
| `stop_condition`      | outer halt predicate              | per-slot halt predicate              | inherit                                   |
| `save_path`           | final user-facing destination     | sandbox temp path                    | NOT inherited (isolation boundary)        |
| `verbosity`           | outer report verbosity            | per-slot output verbosity            | inherit                                   |
| `parallel`            | outer fan-out width               | inner fan-out width                  | NOT inherited (defaults to 1)             |
| `n_candidates`        | total outer slot count            | per-slot child count                 | NOT inherited (defaults to 1)             |
| `num_partitions`      | outer partitioning                | inner partitioning                   | NOT inherited (defaults to 1)             |
| `depth`               | max nesting from outer            | decremented per level                | decremented (not inherited verbatim)      |
| `fan_out`             | outer branching                   | inner branching                      | NOT inherited (defaults to 1)             |
| `subagent_type`       | (n/a — outer is the orchestrator) | role tag for the slot                | per-slot                                  |
| `subagent_prompt`     | (n/a)                             | full prompt the slot receives        | derived from outer                        |
| `subagent_model`      | (n/a — outer uses `model`)        | per-slot model                       | inherit outer `model` if unset            |
| `subagent_constraints`| (n/a)                             | per-slot guardrails                  | inherit outer `guardrails` + additive    |
| `focus_hints`         | the *list*                        | the *scalar* `focus_hints[i]`        | distributed positionally                  |
| `seed`                | broadcast seed                    | per-slot seed                        | inherit, or per-slot derivation (`seed + i`) |
| `temperature`         | broadcast temp                    | per-slot temp                        | inherit or per-slot list                  |
| `min_successes`       | outer threshold                   | (typically n/a)                      | not propagated                            |
| `timeout`             | outer wall-clock                  | per-slot wall-clock                  | inherit                                   |
| `relaunch_on_hang_after` | outer                          | per-slot                             | inherit                                   |
| `retry_policy`        | outer                             | per-slot                             | inherit                                   |
| `hang_policy`         | outer                             | per-slot                             | inherit                                   |
| `model`               | outer orchestrator model          | per-slot via `subagent_model`        | inherit if `subagent_model` unset         |
| `test_command`        | meta-test (rare)                  | per-slot test                        | typically inner-only                      |

Parameters not in this table are outer-only (e.g. `selection_mode`, `aggregator`, `merge_mode`, `merge_strategy`, `cleanup_policy`, `worktree_root`, `output_format`, `report_template`, `report_destination`). Inner agents have no analog because they don't drive selection / merging / cleanup themselves.

## Worked example: a 2-level invocation

User runs:

```
/critique
  context = directory:./src
  criteria = file:./rubric.md
  parallel = 4
  num_experiments = 8
  model = claude-opus-4
  verbosity = full
  save_path = .ai-coding-artifacts/critique-2025.md
```

Outer lifecycle:

- input: `context, criteria, parallel=4, num_experiments=8, model, verbosity=full, save_path` resolved.
- plan: emits 8 slots, fan-out width 4, each slot gets `subagent_prompt` = "critique `./src` against `rubric.md`", `subagent_model = "claude-opus-4"`, `subagent_constraints` inherits outer guardrails. `focus_hints` unset → all slots same.
- execute: 8 critique subagents launched (4 at a time). Each runs its **inner lifecycle**:
   - inner input: `subagent_prompt` becomes inner `task`. `context` and `criteria` inherit verbatim. Inner `parallel = 1` (default, NOT 4). Inner `save_path` UNSET (NOT outer's save_path).
   - inner plan: trivial (1 slot).
   - inner execute: the actual critique run, producing `findings`.
   - inner evaluate: self-check against the rubric.
   - inner select / persist: degenerate.
   - inner report: emits structured `findings` to the outer.
- evaluate (outer): aggregates findings across 8 runs; computes convergence; checks `min_successes` (default 1).
- select (outer): `selection_mode = manual` default → would normally prompt; for `critique.md` it's `aggregate` (synthesize a single report from N runs).
- persist (outer): writes the aggregated report to outer `save_path`.
- report (outer): renders, with `verbosity = full` (per-slot, per-finding, convergence-tagged).

The disambiguation is crisp: every "8" or "4" or "verbosity" question has exactly one resolved value at exactly one level.
