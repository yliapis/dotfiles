# Tree Shapes

This file catalogues the canonical tree topologies a command's invocation can take under the tree-shaped ontology. Every command resolves to exactly one of these shapes (or a recognized composition of them). The shape is determined by the values of the **fan-out** parameters at root: `fan_out`, `parallel`, `num_partitions`, `depth`.

Each shape lists:

- a name and short description,
- a depth count and node count formula,
- an ASCII diagram,
- the parameter binding that produces it,
- example commands that use it,
- common pitfalls.

---

## Shape 0: flat (depth-0)

A single root with **no children**. The root does all the work itself; there are no subagents and no leaves below it.

```
root
```

- **Depth:** 0.
- **Node count:** 1.
- **Parameter binding:** `root.fan_out = 1`, `root.parallel = 1`, `root.num_partitions = 1`, `root.depth = 0`.
- **Bubbled outputs:** N/A — root produces its own outputs directly into its reply.
- **Examples in this repo:** `meta-prompt.md` (no fan-out: produces a single refined prompt or HELP message).
- **When to use:** the entire task can be completed by one model in one turn, with no replication, partitioning, or sub-isolation.
- **Pitfall:** authors sometimes accidentally describe a flat command using fan-out vocabulary (`{n_candidates}`, `{parallel}`). If those parameters are *only* present to be re-bound to `1`, prefer documenting the shape as flat and removing the parameters; otherwise upgrade to fan-out.

---

## Shape 1: fan-out (depth-1)

Root spawns N **leaves** directly. There is no intermediate subagent layer. This is the simplest replication shape and the most common.

```
root
├── leaf[1]
├── leaf[2]
├── ...
└── leaf[N]
```

- **Depth:** 1.
- **Node count:** `1 + N` where `N = root.fan_out`.
- **Parameter binding:** `root.fan_out = N`, `root.parallel ∈ [1, N]`, `root.num_partitions = 1`, `root.depth = 1`.
- **Bubbled outputs:** each `leaf[i]` bubbles `status`, `result`, `findings`, `verification`, `diff`, `terminal_log`, etc. Root reduces them per `selection_mode`.
- **Examples in this repo:** `critique.md` (`num_experiments = N` independent analysis runs).
- **When to use:** N independent attempts at the same task, with selection or aggregation at root.
- **Variants:**
  - **Best-of-N** — `selection_mode = auto-best`, `ranker` set, root picks the top result.
  - **All-of-N** — `selection_mode = all`, root emits every result.
  - **Synthesize** — `selection_mode = synthesize`, `aggregator` set, root merges into one.
- **Pitfall:** confusing `parallel` with `fan_out`. `fan_out = N` says "spawn N leaves total"; `parallel = K` says "have at most K running concurrently". They are independent.

---

## Shape 2: partition fan-out (depth-2, balanced)

Root spawns P partitions; each partition is a subagent that itself has L leaves. Total leaves = `P × L`. This is the canonical depth-2 balanced shape.

```
root
├── subagent[1]                  (partition 1)
│   ├── leaf[1]
│   └── leaf[2]
├── subagent[2]                  (partition 2)
│   ├── leaf[1]
│   └── leaf[2]
└── ...
```

- **Depth:** 2.
- **Node count:** `1 + P + P*L`.
- **Parameter binding:**
  - `root.num_partitions = P`,
  - `root.fan_out = P` (one direct child per partition),
  - `root.parallelism = P*L` (or any subdivision),
  - per subagent: `subagent[i].fan_out = L`,
  - `root.depth = 2`.
- **Bubbled outputs:** leaves bubble to their subagent (which may apply per-partition selection); subagents bubble to root (which applies global selection).
- **Examples in this repo:** `worktree-task-agent.md` with `parallelism = 4`, `num_partitions = 2` (2 partitions × 2 worktrees each). Also a hypothetical `/critique --partitions=3 --num_experiments_per_partition=4` that splits criteria across partitions.
- **When to use:** when leaves cluster naturally (different partitions cover different criteria, file subsets, or model groups) and you want per-partition selection before global selection.
- **Pitfall:** the partition contract for `agent_model` shape — when `agent_model` is a list, the dispatcher must verify that `len(agent_model)` equals `parallelism` (full iteration), or `num_partitions` (one model per partition broadcast within), or is scalar. See `worktree-task-agent.md` parameter docs.

---

## Shape 3: partition fan-out (depth-2, ragged)

Same as Shape 2 but partitions need not have equal size. Common when partitions correspond to qualitative groups of unequal size (e.g. one partition per source language with different file counts).

```
root
├── subagent[1]                  (partition 1, 3 leaves)
│   ├── leaf[1]
│   ├── leaf[2]
│   └── leaf[3]
├── subagent[2]                  (partition 2, 1 leaf)
│   └── leaf[1]
└── subagent[3]                  (partition 3, 5 leaves)
    ├── leaf[1]
    └── ...
```

- **Depth:** 2.
- **Node count:** `1 + P + Σ L_i`.
- **Parameter binding:**
  - `root.num_partitions = P`,
  - per subagent: `subagent[i].fan_out = L_i` (declared per partition),
  - `root.depth = 2`.
- **Bubbled outputs:** as Shape 2.
- **When to use:** asymmetric workloads where partitions own genuinely different child counts.
- **Pitfall:** list-shaped SHADOW parameters (`agent_model`, `focus_hints`) become ambiguous at root. Either:
  1. declare them inside each subagent (RESET at subagent scope), or
  2. provide them as a *flat* list of length `Σ L_i` at root and document the slicing rule.

---

## Shape 4: recursive (depth-N)

A subagent itself spawns subagents that themselves spawn subagents, etc. Used for hierarchical decomposition where the same orchestration logic applies at every level.

```
root
├── subagent[1]
│   ├── subagent[1]
│   │   ├── leaf[1]
│   │   └── leaf[2]
│   └── subagent[2]
│       ├── leaf[1]
│       └── leaf[2]
└── subagent[2]
    └── ...
```

- **Depth:** `N` where `N >= 3`.
- **Node count:** depends on per-level fan_out; for uniform fan-out `B` and depth `N`, total leaves = `B^N`.
- **Parameter binding:**
  - `root.depth = N`,
  - per scope: `subagent.fan_out` re-bound (RESET) at each level,
  - `subagent.depth = parent.depth - 1` (decrement; spawn rejected when `depth == 0`).
- **Bubbled outputs:** every level applies its own selection/aggregation; values bubble up incrementally.
- **Examples:** a hypothetical `/refine-best-of-n --depth=3 --fan_out=2` that produces 2 refined prompts at level 1, each refined into 2 more at level 2, each independently coded into 2 attempts at level 3 (8 leaves).
- **When to use:** when the same fan-out + select pattern needs to compose multi-level (refine → refine → implement). Rare in practice.
- **Pitfall:**
  - exponential blow-up of leaves; the dispatcher should enforce `B^N <= max_leaves` at root.
  - reasoning about effective model assignments becomes hard — strongly prefer per-scope `subagent_model` declarations over a flat root-level list.

---

## Shape 5: serial pipeline (degenerate fan-out)

Each subagent has exactly one child; the tree is a chain. Equivalent to a multi-stage pipeline (each stage feeds the next). Implemented as a tree because each stage has its own scope, model, guardrails, and bubbled outputs even though there's no fan-out.

```
root
└── subagent[1]
    └── subagent[2]
        └── leaf[1]
```

- **Depth:** N (= chain length).
- **Node count:** `N + 1` (where N is chain length excluding root).
- **Parameter binding:**
  - `root.fan_out = 1`, every `subagent.fan_out = 1`,
  - each scope declares its own `task`, `model`, `subagent_prompt`,
  - `root.depth = N`.
- **Bubbled outputs:** the leaf's `result` bubbles up through every intermediate subagent; ancestors may transform but typically pass through.
- **When to use:** explicit multi-stage decomposition where each stage is genuinely a different agent (e.g. "planner → coder → reviewer" pipeline).
- **Pitfall:** for two-stage cases with no model change and no scope change, prefer flat (Shape 0) instead of serial pipeline — pipelines are heavyweight. Use a chain only when stages have distinct guardrails / models / prompts.

---

## Shape 6: heterogeneous (mixed depths)

Different children of the same parent have **different shapes** below them. For example: subagent[1] is a leaf (depth-0 below itself), while subagent[2] has its own children (depth-1 below itself).

```
root
├── leaf[1]                   (direct leaf — depth 1 below root)
└── subagent[2]               (intermediate)
    ├── leaf[1]               (depth 2 below root)
    └── leaf[2]
```

- **Depth:** `max` over branches.
- **Node count:** depends.
- **Parameter binding:** mixed; `root.fan_out = 2` but only `subagent[2]` has `subagent[2].fan_out > 1`.
- **Bubbled outputs:** ancestors must handle non-uniform child shapes — typically by treating each direct child's bubbled output as opaque.
- **When to use:** rare; usually arises when one branch needs replication (analysis) and a sibling does not (synthesis). Often a sign that the work should be re-modeled as two separate commands.
- **Pitfall:** list-shaped SHADOW parameters at root (`agent_model`, `focus_hints`) are hard to interpret because the leaf-counts differ across branches. Strongly prefer per-branch declaration.

---

## Shape 7: empty (depth-0, read-only)

Root produces an answer without consuming any explicit context, fan-out, or children — the simplest possible shape. Distinct from Shape 0 (flat) because Shape 7 has neither inputs to slice nor outputs to bubble.

```
root
```

- **Depth:** 0.
- **Node count:** 1.
- **Parameter binding:** all replication / fan-out / partition parameters absent or default; `root.context` may also be absent.
- **Examples:** `meta-prompt help` (HELP mode emits a fixed help message).
- **When to use:** documentation, help, status output.

---

## Shape selection cheat sheet

```
                                         ┌──── flat (Shape 0): single root, no children
                                         │
                                         │       ┌──── depth-1 (Shape 1): root → leaves
              ┌──── replication needed? ──┤───────┤
              │                            │       │       ┌──── balanced (Shape 2)
              │                            │       └── partitioned ──┤
              │                            │               │       └──── ragged (Shape 3)
              │                            │
              │                            └── recursive (Shape 4): nested fan-out
   start ─────┤
              │
              └──── pipeline / staged? ──── serial pipeline (Shape 5): chain
                              │
                              └── mixed? ── heterogeneous (Shape 6)
```

In words:

1. **No replication, just one model doing one task** → Shape 0 (or Shape 7 if no input either).
2. **N independent attempts, same task** → Shape 1 (depth-1 fan-out).
3. **N attempts in `P` groups** → Shape 2 (balanced) or Shape 3 (ragged).
4. **Hierarchical decomposition with the same orchestration at every level** → Shape 4.
5. **Multi-stage pipeline with distinct per-stage agents** → Shape 5.
6. **Mixed shapes per branch** → Shape 6 (rare; usually wants splitting into two commands).

---

## Validation per shape

For each shape, the dispatcher MUST validate the following before any side effects (creating worktrees, spawning agents):

| Shape | Validation |
|---|---|
| 0, 7 | `fan_out == 1`, `parallel == 1`, `num_partitions == 1`, `depth == 0`. |
| 1 | `fan_out >= 1`, `parallel ∈ [1, fan_out]`, `num_partitions == 1`, `depth == 1`. List-shaped SHADOW params (`agent_model`, `focus_hints`) length matches `fan_out` (or are scalar / null). |
| 2 | `num_partitions >= 1`, `fan_out == num_partitions`, every subagent's `fan_out == fan_out_total / num_partitions` (integer divides), `depth == 2`. List-shaped SHADOW params length matches one of `{1, num_partitions, fan_out_total}`. |
| 3 | per-subagent `fan_out` declared explicitly; root-level list-shaped SHADOW params either of length `Σ subagent.fan_out` (flat slicing) or declared per subagent. |
| 4 | `depth == N`, every level's `fan_out` declared; total leaves `<= max_leaves`. |
| 5 | every scope has `fan_out == 1`; each scope declares its own `subagent_type` / `subagent_prompt`. |
| 6 | per-branch validation: each child subtree validated independently; root-level list-shaped SHADOW params declared per branch (NOT flat). |

Validation failure aborts with no filesystem side effects (mirrors `worktree-task-agent.md`'s existing fail-fast contract).

---

## Anti-patterns

- **Shape mismatch:** declaring `num_partitions = 2` with `parallelism = 3` (3 not divisible by 2). Resolution: change one of the parameters before launch.
- **Hidden depth:** a subagent silently spawning grandchildren when `depth = 1` (which permits only one level below root). Resolution: dispatcher rejects `subagent.fan_out > 1` when `depth == 0`.
- **Bubbling broken by reduction:** root applying `selection_mode = synthesize` without an `aggregator`. Resolution: reject at validation.
- **List length mismatch:** `agent_model` list of length 3 with `fan_out = 4`. Resolution: reject at validation; `worktree-task-agent.md` already does this.
- **Recursive without `depth`:** a subagent inheriting a non-default `fan_out` from its parent (would cause runaway recursion). Resolution: `fan_out` is RESET at every level (see `inheritance.md#reset`).

---

## Cross-references

- Per-scope parameter docs: `0-root.md`, `1-subagent.md`, `2-leaf.md`.
- Inheritance / shadow / reset / bubble rules: `inheritance.md`.
- The repo's command files demonstrating these shapes: `ai-coding/plugins/ai-coding/commands/critique.md` (Shape 1), `ai-coding/plugins/ai-coding/commands/worktree-task-agent.md` (Shape 1 or Shape 2 depending on `num_partitions`), `ai-coding/plugins/ai-coding/commands/meta-prompt.md` (Shape 0 / 7).
