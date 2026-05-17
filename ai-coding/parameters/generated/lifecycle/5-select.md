# Stage 5 — Select

**Position in lifecycle:** runs after **evaluate** has scored every slot. Runs before **persist**.

**Purpose:** decide **which** candidate(s), if any, advance to persist. Select is a pure decision stage — it makes the call but does not commit, merge, or write. Its three canonical modes are:
   1. **manual** — present the menu; the user picks.
   2. **auto-best** — apply `ranker` order; pick the top one(s) that pass guardrails.
   3. **synthesize** — run `aggregator` to merge multiple candidates into one new artifact.

**Flows in:** per-slot `slot_evaluation` records, the `gate_result`, the convergence record, and `selection_mode` / `ranker` / `aggregator` / `merge_count` / `tie_breaker` from input.
**Flows out:** a **selection set** — zero or more `slot_id`s flagged for persist, possibly plus a synthesized artifact when `selection_mode = synthesize`.

**Skipped when:** trivial commands with `n_candidates = 1` and no choice to make (e.g. `meta-prompt.md` in CREATE mode without `n_candidates`). Even then, select runs degenerately: "1 candidate, take it."

**Key invariant:** select never *commits* anything. It can ask the user; it can synthesize a new in-memory artifact; it can declare a winner — but persist is the only stage that touches the user's repo, save path, or remote.

---

## Parameters whose primary semantic lives in select

### `tie_breaker`

**Aliases:** `tiebreaker`, `tie_break_rule`
**Definition:** Rule for resolving ties when `ranker` produces equal scores in `auto-best` mode.
**Stages:** select (applied).
**Depth:** outer.
**Type:** enum `lowest-index | random | seed-deterministic | none`.
   - `lowest-index`: pick the lowest-numbered slot (matches `worktree-task-agent.md`'s "prefer the lowest-index branch").
   - `random`: uniform random pick.
   - `seed-deterministic`: hash of `seed` + tied slot ids.
   - `none`: surface the tie back to the user and fall back to `manual`.
**Default:** `lowest-index`.

**Example:**

```
{tie_breaker} = lowest-index   # worktree-task-agent.md auto mode
{tie_breaker} = none           # force user disambiguation on ties
```

From `worktree-task-agent.md`:

> "In `auto` merge mode, … if more than one is eligible, prefer the lowest-index branch."

---

## Parameters consumed in select (canonical homes elsewhere)

| Parameter           | Home    | What select does with it                                              |
| ------------------- | ------- | --------------------------------------------------------------------- |
| `selection_mode`    | input   | the master switch: manual / auto-best / synthesize                   |
| `ranker`            | input   | the score producer; select consumes its ordering                     |
| `aggregator`        | input   | invoked when `selection_mode = synthesize`                            |
| `merge_count`       | input   | upper bound on the size of the selection set (`one`, `all-passing`, `user-pick-multi`, or `int_range[>= 0]`) |
| `merge_mode`        | input   | `interactive` → present a menu; `auto` → apply the ranker silently   |
| `auto_save_winner`  | input   | if true and a unique winner emerges, mark the selection set as persist-bound without confirmation |
| `min_successes`     | plan    | gate already applied at evaluate; select consumes `gate_result`     |
| `compare_against`   | input   | already consumed at evaluate; select sees the resulting score deltas |
| `slot_evaluation`   | evaluate| the per-slot judgments — the *input data* of select                 |
| `gate_result`       | evaluate| if false, select short-circuits to an empty selection set and a fail-report |
| `convergence_record`| evaluate| informs ranking heuristics ("convergent findings are more reliable") |

---

## Stage outputs (what select produces for persist / report)

### `selection_set`

**Definition:** Ordered list of `slot_id`s flagged for persist. May be empty (nothing worth persisting), singleton (typical), or multi (when `merge_count = all-passing` or `user-pick-multi`).
**Type:** list of slot ids.
**Producer:** select.
**Consumer:** persist (acts on each id), report (renders the selection rationale).

### `synthesized_artifact`

**Definition:** When `selection_mode = synthesize`, the merged artifact `aggregator` produced from multiple candidate outputs.
**Type:** depends on command — diff bundle, markdown report, generated file.
**Producer:** select.
**Consumer:** persist (writes it), report (renders or links it).

### `selection_rationale`

**Definition:** Human-readable explanation of why the selection set was chosen.
**Type:** text. Includes ranker scores, tie-break invocations, gate failures, user choices.
**Producer:** select.
**Consumer:** report (rendered as the "Merge Recommendation" / "Selection" section).

From `worktree-task-agent.md`'s required Output Format:

> "### Merge Recommendation — The recommended worktree branch to merge (or `none`) and a one-line rationale."

That section is *produced* by select, rendered by report.

---

## Selection modes — operational detail

### `manual` mode

Present the menu; user picks. Examples: `worktree-task-agent.md`'s default (`interactive`).

The menu shape is governed by report (`require_diff`, `verbosity`); the *decision* still belongs to select — it just delegates to the user.

### `auto-best` mode

Apply `ranker` to the surviving (`pass == true`) candidates; pick the top `merge_count`. Tie-broken by `tie_breaker`. Skipped when `gate_result = false`.

Per `trajectory.md`:

> "Define a selection rubric so `auto-best` selection mode has a concrete contract."

The rubric is `ranker` + `tie_breaker` + `merge_count` together. This stage is where the rubric is *invoked* — its components live in input.

### `synthesize` mode

Invoke `aggregator` over the candidate set; emit `synthesized_artifact`. `merge_count` is implicitly `one` (one synthesized output). `auto_save_winner` semantics apply to the synthesized artifact, not the originals.

Per `trajectory.md`'s open question:

> "Should 'best-of-N prompt refinement' be a new dedicated command … or expressed by composing the two?"

Either way, `synthesize` is the canonical selection mode that supports it; the aggregator command / prompt is the substitutable piece.

---

## Cross-stage notes

- **Select is the natural seam between "what happened" and "what we keep."** Evaluate produces judgments without policy; persist applies policy without judgment; select bridges them.
- **`merge_count > 1` reshapes downstream stages.** Multi-merge invocations require persist to handle multiple sequential merges (per `worktree-task-agent.md`'s current guardrail "MUST NOT merge more than one worktree branch per invocation", `merge_count = one` is hardcoded; the future-state is to lift that to `merge_count`).
- **Select can short-circuit.** If `gate_result = false` (insufficient successes), select produces an empty `selection_set` and a `selection_rationale` of "gate failed". Persist becomes a no-op; report renders the failure.
- **Select is the only stage allowed to pause for user input** in `interactive` modes. Plan / execute / evaluate / persist / report all run non-interactively given a resolved decision.
