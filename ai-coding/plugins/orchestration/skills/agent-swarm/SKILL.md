---
name: agent-swarm
description: Orchestrate parallel agent fan-out (best-of-N) for AI coding tasks — gate the swarm-vs-single decision, size the swarm, shape it with a topology (parallel / partitioned / staged / pipeline), optionally preview that topology as a mermaid diagram before dispatch, pick a model-mix shape (broadcast / per-agent / per-partition), dispatch siblings through worktree-task, watchdog hangs with a 5-minute default and explicit replacement policy, and aggregate by running every requested selection mode in parallel (manual, auto-best, synthesize, vote, hybrid, tournament, consensus) over the surviving members. Use when the user asks for an agent swarm, agent fan-out, best-of-N, parallel agent runs, swarm orchestration, swarm topology, staged or pipelined agents, a preview of the swarm shape, worktree fan-out, multiple plausible approaches, or independent exploration that adds signal.
license: MIT
---

# Agent Swarm

## Task

Decide whether a coding task warrants parallel agent fan-out, design the swarm (size, topology, concurrency, model mix, replacement policy, selection modes), dispatch through `worktree-task`, watchdog for hangs, and aggregate the per-member outcomes by running every requested selection mode in parallel over the surviving members.

This skill is the policy layer above `.cursor/skills/worktree-task/SKILL.md`. It owns the swarm-vs-single decision, sizing, topology, model mix, replacement policy, watchdog, aggregation strategy, and structured event emission. It never re-implements worktree mechanics — those belong to `worktree-task`.

## Parameters

- `{num_agents}` (aliases: `{n}`, `{num}`) — total agents to spawn; required; integer `>= 2`. A "swarm" of `1` is a single agent; refuse and recommend a direct `worktree-task` invocation instead.
- `{topology}` — how the `{num_agents}` members are arranged: `parallel` (one wave of independent members), `partitioned` (independent groups), `staged` (sequential waves, each informed by the previous one), or `pipeline` (a chain of single-member stages, each forking from its predecessor's branch); optional, default: `parallel`. See the Topology Catalog for per-topology dispatch, validation, and selection rules.
- `--preview-swarm-topology[=<format>]` — flag; when present, render the resolved topology as a diagram in the `### Topology Preview` section before the first worktree is created. `<format>` is `mermaid` (default — one fenced ` ```mermaid ` block), `ascii`, or `both`; the bare flag means `mermaid`. Render-only: it never gates dispatch and never changes the plan.
- `{parallel_agents}` (aliases: `{p}`, `{parallel}`) — concurrency cap on members running simultaneously; optional, default: `{num_agents}` (full parallelism). MUST be an integer in `1..{num_agents}`. Maps to worktree-task's `{concurrency}` at dispatch; the total member count `{num_agents}` maps to its `{parallelism}`. Under `{topology} = staged` the cap applies within a wave; under `{topology} = pipeline` it resolves to `1`, and an invocation that names it with a value above `1` is a validation error.
- `{model_mix}` — model-assignment shape: `broadcast` (one model to all), `per-agent` (list of length `{num_agents}`), or `per-partition` (list of length `{num_partitions}` broadcast across contiguous slices); optional, default: `broadcast` with the parent agent's model.
- `{num_partitions}` — contiguous grouping of member slots, serving both per-partition model assignment and the `partitioned` / `staged` topologies from one value; optional with default `{num_agents}` when only `{model_mix} = per-partition` needs it, required with no default when `{topology}` is `partitioned` or `staged` (then MUST be an integer in `2..{num_agents}`). MUST divide `{num_agents}` evenly.
- `{selection_modes}` — list (any subset) of: `manual`, `auto-best`, `synthesize`, `vote`, `hybrid`, `tournament`, `consensus`. Every listed mode runs in parallel over the surviving members and produces its own outcome block; optional, default: `auto` (every mode whose prerequisites are met given the other parameters and whose rule the resolved `{topology}` supports; skipped modes are listed in the report with the missing prerequisite or the topology reason).
- `{test_command}` — shell verifier each member runs in its worktree; required when any of `auto-best`, `vote`, `hybrid`, `tournament` is in `{selection_modes}`.
- `{aggregator}` — prompt or shell command that produces a merged artifact from candidates; required when `synthesize` or `hybrid` is in `{selection_modes}`.
- `{min_successes}` — minimum members reaching `success` before aggregation runs; optional, default: `ceil({num_agents} / 2)`, or `1` under `{topology} = pipeline` where stages are cumulative rather than independent. If unmet after replacements terminate, every selection mode reports `under-floor` and no winner is auto-selected.
- `{relaunch_on_hang_after}` — wall-clock duration after which a silent member is force-aborted; optional, default: `5m`. Replacement happens per `{replacement_policy}`.
- `{replacement_policy}` — `off` | `replace-up-to-n` | `replace-up-to-budget`; optional, default: `off`. Controls whether killed members are respawned; replacements never recurse.
- `{cost_cap}` — soft cap on projected token spend or wall-clock seconds across the swarm; optional. When set, the workflow projects cost before dispatch; if projected exceeds the cap, the skill proposes a smaller `{num_agents}` and waits for user approval (does NOT silently shrink).
- `{pattern}` — optional preset shortcut; one of: `sanity`, `diversity`, `consensus`, `synthesize`, `tournament`, `refine`. When set, the preset supplies defaults for `{num_agents}`, `{topology}`, `{model_mix}`, and `{selection_modes}` from the Pattern Catalog. User-set parameters always override preset defaults.

## Success Criteria

- [ ] Before any worktree is created, the response records the swarm-gate verdict, the trigger ID(s) that fired, and (when `{pattern}` is used) the preset chosen.
- [ ] Parameters are validated before dispatch: `{num_agents} >= 2`, `{parallel_agents} <= {num_agents}`, `{topology}` is one of the four catalog values, `{num_partitions}` is present and in `2..{num_agents}` when `{topology}` is `partitioned` or `staged`, `{model_mix}` shape matches `{num_agents}` / `{num_partitions}`, `{num_partitions}` divides `{num_agents}` evenly, and required parameters for each entry in `{selection_modes}` are present.
- [ ] The dispatch shape matches the resolved `{topology}`: one `worktree-task` invocation for `parallel` and `partitioned`, one per wave for `staged`, one per stage for `pipeline` with each stage forking from its predecessor's branch.
- [ ] Selection modes that the resolved `{topology}` cannot support report `skipped: <reason>` in the Aggregation section instead of running.
- [ ] When `--preview-swarm-topology` is set, the `### Topology Preview` section renders the resolved topology (mermaid by default) after validation and before the first worktree, and the run then proceeds unchanged.
- [ ] Worktree creation, branch naming, agent dispatch, and per-worktree diff capture are delegated to `worktree-task`; this skill emits no `git worktree` calls.
- [ ] When `{cost_cap}` is set, a cost projection is run before dispatch; if `projected > {cost_cap}`, the skill proposes a smaller `{num_agents}` and waits for user approval.
- [ ] When `{relaunch_on_hang_after}` expires for a member, that member is force-aborted; replacement happens iff `{replacement_policy}` allows; replacements never recurse.
- [ ] When `successes < {min_successes}` after the run terminates (including replacements), every selection mode reports `under-floor`; no winner is auto-selected.
- [ ] Every entry in the resolved `{selection_modes}` either runs over the surviving members or reports `skipped: <reason>`, and each produces its own outcome block in the Aggregation section.
- [ ] Structured JSON Lines events are emitted in the dedicated `### Events` section of the reply, in chronological order, covering the swarm-gate verdict, dispatch, member lifecycle, replacements, per-mode selection results, and run completion.
- [ ] At most one worktree branch is merged back per invocation, regardless of how many selection modes converged on the same winner.

## Guardrails

- MUST run the Swarm Gate before any side effect. At least one trigger MUST fire AND its identifier MUST appear in the response; otherwise abort and recommend a single agent.
- MUST compose with `worktree-task` for every worktree side effect (create, run, diff, merge prompt). MUST NOT re-specify or re-implement worktree mechanics.
- MUST validate parameters before dispatch; fail fast with no filesystem side effects on validation failure.
- MUST keep each member isolated to its assigned worktree; members MUST NOT read, write, or run commands against the calling worktree or any sibling worktree. Upstream context under `staged` / `pipeline` reaches a member as text in its task, never as filesystem access to another member's worktree.
- MUST NOT nest a topology: members never spawn members, so hierarchical, recursive, and dynamically-grown shapes stay out of the catalog. `staged` and `pipeline` order the swarm's own slots; they do not create new ones.
- MUST treat `--preview-swarm-topology` as render-only; it MUST NOT gate dispatch, alter the resolved plan, or stand in for the `{cost_cap}` projection.
- MUST treat `{relaunch_on_hang_after}` as a hard kill, not a polite request.
- MUST NOT chain replacements; a replaced member that itself hangs ends as `incomplete`.
- MUST NOT silently shrink `{num_agents}` to fit `{cost_cap}`; surface the proposed size and wait for the user's approval.
- MUST NOT recursively spawn swarms; every member runs as a single agent.
- MUST NOT merge more than one worktree branch per invocation, even when several selection modes converge on it.
- MUST emit events in chronological order in the dedicated `### Events` section; MUST NOT inline events outside that section.
- Scope: orchestration policy (gate, sizing, topology, mix, dispatch shape, watchdog, aggregation, events). Out of scope: low-level worktree mechanics (delegated to `worktree-task`), pushing branches, opening PRs, cross-repo coordination, persistent scheduling.

## Swarm Gate

Run a swarm only when at least one trigger fires. Record the trigger ID(s) in the Swarm Decision section.

| ID | Trigger | When it fires |
|---|---|---|
| T1 | Multiple plausible approaches | Two or more designs are reasonable; the right one is non-obvious without trying both |
| T2 | High cost of being wrong | Irreversible changes, security-sensitive logic, public API design, expensive-to-detect failures |
| T3 | Open prompt or design space | Spec is loose; agents will reasonably interpret it differently and that variance is informative |
| T4 | Independent exploration adds signal | Disagreement detection, model-variance smoothing, or refactor-consensus is itself the goal |
| T5 | Cross-model comparison is the question | "Does Opus beat Sonnet on this task class?" or similar head-to-head |
| T6 | User explicitly requested fan-out | The user said "swarm", "best of N", "fan out", "parallel agents", or named the agent-swarm skill |

Counter-triggers (skip the swarm even if a trigger fires):

- Mechanically-correct task with one obvious shape (rename, format, scripted refactor).
- Token budget is the binding constraint and a single agent's quality is already adequate.
- The work depends on serial conversational context (interactive debugging, iterative log reading).

## Pattern Catalog

`{pattern}` is an optional shortcut that supplies defaults for `{num_agents}`, `{topology}`, `{model_mix}`, and `{selection_modes}`. User-set parameters always override the preset.

| Pattern | `{num_agents}` | `{topology}` | `{model_mix}` | `{selection_modes}` | When to use |
|---|---|---|---|---|---|
| `sanity` | 3 | `parallel` | `broadcast` | `[vote, manual]` | Cheap second-opinion check; surface obvious disagreement before committing |
| `diversity` | 6 | `parallel` | `per-partition` | `[manual, auto-best, synthesize]` | Open design space; want a comparable spread of styles |
| `consensus` | 5 | `parallel` | `broadcast` | `[vote, consensus]` | Verify a fragile fix is robust to seed and temperature noise |
| `synthesize` | 4 | `parallel` | `per-partition` | `[synthesize]` | Members explore complementary facets; merge into one artifact |
| `tournament` | 8 | `parallel` | `per-agent` | `[tournament, auto-best]` | Strong selection signal exists; want the best of several head-to-head |
| `refine` | 3 | `pipeline` | `broadcast` | `[auto-best, manual]` | One approach that rewards iteration; each stage sharpens the previous stage's branch |

## Sizing Heuristics

Pick `{num_agents}` from the lowest tier that still answers the trigger that fired.

| Tier | `{num_agents}` | Use for | Cost shape |
|---|---|---|---|
| Sanity | 2-3 | Disagreement detection, second opinion, A/B between two models | `~3×` single-agent cost |
| Diversity | 4-8 | Real best-of-N exploration; default range when a trigger fires | `~n×` cost; default range |
| Search | >8 | Only with `{cost_cap}` justification recorded in the response | Cost grows linearly; aggregation difficulty grows super-linearly |

Doubling the swarm rarely doubles the signal. Prefer raising selection rigor over raising `{num_agents}`.

## Topology Catalog

Sizing picks how many members run; `{topology}` picks how they are arranged — what each member forks from, which members run together, and what flows between them.

| Topology | Shape | Members fork from | Flow between members | Effective concurrency |
|---|---|---|---|---|
| `parallel` (default) | one wave of `{num_agents}` independent members | `{base_branch}` | none | `{parallel_agents}` |
| `partitioned` | `{num_partitions}` groups of `{num_agents} / {num_partitions}` members; the grouping drives model assignment, report layout, and a per-group selection pass rather than scheduling | `{base_branch}` | none across groups; each group gets its own selection pass before the global one | `{parallel_agents}`, shared across groups |
| `staged` | `{num_partitions}` sequential waves of `{num_agents} / {num_partitions}` members | `{base_branch}` | wave `j + 1` receives wave `j`'s member summaries as upstream context | `min({parallel_agents}, wave size)`; waves never overlap |
| `pipeline` | a chain of `{num_agents}` single-member stages | stage `1` from `{base_branch}`; stage `i` from stage `i - 1`'s branch | stage `i` receives stage `i - 1`'s summary and builds on its branch | `1` |

Slots keep the numbering `1..{num_agents}` in dispatch order under every topology. Group `g` and wave `g` both own the contiguous slice of `{num_agents} / {num_partitions}` slots starting at `((g - 1) × {num_agents} / {num_partitions}) + 1`; stage `i` is slot `i`.

`pipeline` and `staged` spend the same tokens as `parallel` for the same `{num_agents}`, but their wall clock scales with the number of stages or waves. Keep chains short (2-4 stages); reach for `staged` when a second look at the problem is worth more than a second independent attempt.

### Dispatch shape

Every topology resolves to one or more `worktree-task` invocations, and the skill still emits no worktree mechanics of its own.

| Topology | worktree-task invocations | Per-invocation parameters |
|---|---|---|
| `parallel` | 1 | `{parallelism} = {num_agents}`, `{concurrency} = {parallel_agents}` |
| `partitioned` | 1 | `{parallelism} = {num_agents}`, `{concurrency} = {parallel_agents}`; `{num_partitions}` is forwarded only when `{model_mix} = per-partition`, since the grouping otherwise serves the swarm's own reporting and selection |
| `staged` | one per wave, in wave order | `{parallelism} = {num_agents} / {num_partitions}`, `{concurrency} = min({parallel_agents}, wave size)`, `{base_branch}` unchanged, `{worktree_name} = <slug>-w<j>`; `{num_partitions}` is never forwarded, because each wave's slots already carry their resolved models |
| `pipeline` | one per stage, in stage order | `{parallelism} = 1`, `{concurrency} = 1`, `{base_branch}` = previous stage's branch, `{worktree_name} = <slug>-s<i>` |

A wave or stage launches only after the previous one terminates. Under `pipeline`, a stage that ends non-`success` stops the chain: the stages never launched are recorded as `incomplete` and selection runs over the stages that did complete. Under `staged`, a wave in which every member ends non-`success` stops the run the same way. `{relaunch_on_hang_after}` and `{replacement_policy}` apply per member and resolve before its wave or stage counts as terminated.

Branch names stay unique because every wave and stage carries its own `{worktree_name}`. Any `-<i>` suffix the child adds is local to that invocation, so a global slot in wave `j` lands on `<slug>-w<j>-<local index>`, and a single-member wave or stage keeps the bare name; the swarm's report and events keep the global slot number either way.

### Validation

- `{topology}` MUST be one of `parallel`, `partitioned`, `staged`, `pipeline`.
- `partitioned` and `staged` MUST carry an explicit `{num_partitions}` in `2..{num_agents}` that divides `{num_agents}` evenly.
- `pipeline` resolves `{parallel_agents}` to `1` when the invocation leaves it out; an invocation that names `{parallel_agents}` with a value above `1` is a validation error rather than a silent serialization. `staged` takes the same value without complaint: a cap wider than a wave simply never binds, the way `{parallel_agents} = {num_agents}` never binds under `parallel`, whereas a `pipeline` cap above `1` contradicts the topology itself.
- `--preview-swarm-topology` accepts `mermaid`, `ascii`, or `both`; any other `<format>` value is a validation error.
- `{model_mix} = per-partition` and the `partitioned` / `staged` topologies share the one `{num_partitions}`; there is no second partition count to reconcile.
- A mode the topology skips does not carry its prerequisite: `{test_command}` and `{aggregator}` are required only for the modes that actually run.

### Selection compatibility

| Topology | Modes that run | Modes reported as `skipped` |
|---|---|---|
| `parallel` | every resolved mode, over the surviving members | — |
| `partitioned` | every resolved mode, once within each partition and then once globally over the partition outcomes | — |
| `staged` | every resolved mode, over the surviving members of every wave | — |
| `pipeline` | `manual` and `auto-best`, ranking stage branches with the deepest passing stage winning ties — that tie-break replaces the mode's diff-size one, because a later stage's branch contains every earlier stage | `synthesize`, `vote`, `hybrid`, `tournament`, `consensus` — `skipped: pipeline stages are cumulative, not independent candidates` |

`{min_successes}` stays a swarm-wide floor under every topology. A `partitioned` group with no survivors reports `under-floor` in its own partition block while the other groups still report their outcomes.

### Upstream context

Members in a `staged` wave after the first, and in every `pipeline` stage after the first, receive the verbatim `{task}` plus a delimited `## Upstream Context` block carrying the previous wave's or stage's per-member summaries, branch names, and test results. That block is text the swarm writes into the member's task; members still never read a sibling worktree. `parallel` and `partitioned` members receive the verbatim `{task}` and nothing else.

## Topology Preview

`--preview-swarm-topology` renders the resolved plan as a diagram so the caller sees the shape before paying for it. The preview reads resolved values only — slot count, per-slot model, group / wave / stage boundaries, base branches, and the resolved selection modes — so it renders after validation and after the cost projection settles, and before the first worktree.

- `mermaid` (default) emits one fenced ` ```mermaid ` block; `ascii` emits one fenced plain block; `both` emits the mermaid block followed by the ascii block. Both formats carry the same labels and obey the same rules below.
- The root node states the topology, `{num_agents}`, the concurrency actually in effect (the Topology Catalog's effective-concurrency column, so `min({parallel_agents}, wave size)` under `staged`), the grouping count when the topology has one, and `{base_branch}` when every member forks from it. Only `pipeline` puts a base branch on each node, because only there do they differ.
- Every slot node carries its own resolved model, which keeps a `per-agent` mix readable and gives the collapse rule a uniform label to fold; group nodes carry only their own label.
- Once a diagram would draw more than 12 slot nodes, fold each run of identically-configured adjacent slots into one node (one line, in `ascii`) labeled with its slot range and count (`slots 3-12 · sonnet ×10`). A run never crosses a group, wave, or stage boundary. When no run is longer than one slot — a `per-agent` mix, for instance — nothing folds and every slot is drawn.
- When the `{cost_cap}` projection blocks the run, the preview waits for the user's answer and then renders the plan that will actually dispatch: the approved smaller swarm, or nothing at all if the user declines.
- Skipped selection modes stay out of the diagram; the Aggregation section reports them.

Templates, one per topology, with resolved values substituted into the labels:

`parallel`, `{num_agents} = 4`:

```mermaid
flowchart TD
  S["swarm · parallel · n=4 · concurrency=4<br/>base main"]
  S --> A1["slot 1 · sonnet"]
  S --> A2["slot 2 · sonnet"]
  S --> A3["slot 3 · sonnet"]
  S --> A4["slot 4 · sonnet"]
  A1 --> SEL{{"selection · auto-best, vote"}}
  A2 --> SEL
  A3 --> SEL
  A4 --> SEL
```

`partitioned`, `{num_agents} = 6`, `{num_partitions} = 3`:

```mermaid
flowchart TD
  S["swarm · partitioned · n=6 · concurrency=6 · partitions=3<br/>base main"]
  subgraph P1["partition 1"]
    A1["slot 1 · opus"]
    A2["slot 2 · opus"]
  end
  subgraph P2["partition 2"]
    A3["slot 3 · sonnet"]
    A4["slot 4 · sonnet"]
  end
  subgraph P3["partition 3"]
    A5["slot 5 · haiku"]
    A6["slot 6 · haiku"]
  end
  S --> P1
  S --> P2
  S --> P3
  P1 --> SEL{{"partition pass, then global · auto-best"}}
  P2 --> SEL
  P3 --> SEL
```

`staged`, `{num_agents} = 6`, `{num_partitions} = 3` waves:

```mermaid
flowchart TD
  S["swarm · staged · n=6 · concurrency=2 · waves=3<br/>base main"]
  subgraph W1["wave 1"]
    A1["slot 1 · sonnet"]
    A2["slot 2 · sonnet"]
  end
  subgraph W2["wave 2"]
    A3["slot 3 · sonnet"]
    A4["slot 4 · sonnet"]
  end
  subgraph W3["wave 3"]
    A5["slot 5 · opus"]
    A6["slot 6 · opus"]
  end
  S --> W1
  W1 -. "upstream context" .-> W2
  W2 -. "upstream context" .-> W3
  W1 --> SEL{{"selection · synthesize"}}
  W2 --> SEL
  W3 --> SEL
```

`pipeline`, `{num_agents} = 3`:

```mermaid
flowchart TD
  S["swarm · pipeline · n=3 · concurrency=1"] --> T1["stage 1 · sonnet<br/>base main"]
  T1 -->|"branch + summary"| T2["stage 2 · opus<br/>base stage-1 branch"]
  T2 -->|"branch + summary"| T3["stage 3 · opus<br/>base stage-2 branch"]
  T3 --> SEL{{"selection · auto-best, manual"}}
```

The `ascii` format carries the same labels as an indented tree: the root line as above; one line per group, wave, or stage; one line per slot beneath it; and a trailing line naming the resolved selection modes.

```
swarm · staged · n=6 · concurrency=2 · waves=3
├── wave 1
│   ├── slot 1 · sonnet
│   └── slot 2 · sonnet
│   ↓ upstream context
├── wave 2
│   ├── slot 3 · sonnet
│   └── slot 4 · sonnet
│   ↓ upstream context
└── wave 3
    ├── slot 5 · opus
    └── slot 6 · opus
selection · synthesize
```

## Model-Mix Strategies

Three shapes, dispatched through `worktree-task`'s `{agent_model}` parameter:

- **`broadcast`** — one model identifier broadcast to every member. Variance from sampling alone. Default.
- **`per-agent`** — list of length `{num_agents}`, one model per slot positionally. Use for explicit head-to-head model comparison.
- **`per-partition`** — list of length `{num_partitions}`, broadcast across `{num_agents} / {num_partitions}` contiguous slots. Use for "k samples per model" comparisons.

Validation: list-by-agent length MUST equal `{num_agents}`; list-by-partition length MUST equal `{num_partitions}`, and `{num_partitions}` MUST divide `{num_agents}` evenly. Those lengths describe the caller's input. The swarm resolves it once into a per-slot assignment over the global slots `1..{num_agents}` — expanding a `per-partition` list across its slices — and then hands each `worktree-task` invocation the slots it owns: all `{num_agents}` of them under `parallel` and `partitioned`, the wave's slice under `staged`, the stage's single identifier under `pipeline`. Each invocation therefore receives a scalar when its slots share one model, or a list whose length equals that invocation's `{parallelism}`, which is exactly the child's check (see Workflow step 7). Expanding before dispatch keeps the child from having to choose between its two accepted list shapes.

## Selection Modes (run in parallel)

All modes listed in the resolved `{selection_modes}` run independently over the surviving members; each emits its own outcome block. Each mode is a read-only pass over the same data, so running several is cheap and gives the caller a side-by-side comparison.

| Mode | Decision rule | Requires |
|---|---|---|
| `manual` | Present per-member report; user picks zero or one branch | nothing extra |
| `auto-best` | Rank by `{test_command}` exit (0 wins); break ties on smaller diff, fewer files touched, lower-index slot | `{test_command}` |
| `synthesize` | Run `{aggregator}` over surviving members; emit one merged artifact (no branch is merged) | `{aggregator}` |
| `vote` | Group members by output equivalence (test result + structural diff hash); pick largest group; tie-break on lower-index | `{test_command}` or comparable signature |
| `hybrid` | Filter to members passing `{test_command}`, then run `{aggregator}` over the filtered subset (or fall back to manual pick if synthesis is inappropriate for the artifact type) | `{test_command}` AND `{aggregator}` |
| `tournament` | Pairwise comparisons reduce `2^k` members to `1`; requires comparison cost to be cheap relative to member cost | `{test_command}`; `{num_agents}` MUST be a power of 2 |
| `consensus` | Strict per-hunk overlap across members; emit only the agreed subset as a unified diff plus a list of contested hunks | comparable diffs |

When `{selection_modes} = auto` (the default), the skill includes every mode whose prerequisites are met and whose rule the resolved `{topology}` supports (see Selection compatibility). Skipped modes appear in the Aggregation section as `skipped: <missing prerequisite>` or `skipped: <topology reason>` so the omission is auditable.

## Replacement Policy

`{replacement_policy}` controls hang recovery. Replacements multiply spend, so opt-in is required.

- **`off`** (default) — killed members end as `incomplete`; no replacement is launched.
- **`replace-up-to-n`** — each slot may respawn at most once. Total replacement budget is `{num_agents}`. A replacement that itself hangs ends as `incomplete`.
- **`replace-up-to-budget`** — replacements continue while `{cost_cap}` projection still allows; pending replacements are cancelled when the cap is crossed. Requires `{cost_cap}` to be set.

A replacement counts toward `{min_successes}` only if the replacement itself reports `success`.

## Cost Cap and Projection

When `{cost_cap}` is set, the workflow runs a cost projection before dispatch:

```
projected = ({num_agents} + projected_replacements) × per_agent_estimate
```

If `projected > {cost_cap}`, propose the largest `{num_agents}` value that fits the cap and wait for user approval. NEVER silently shrink. Without `{cost_cap}`, no pre-launch gate runs and cost is reported only via emitted events and the post-run report.

Token spend follows `{num_agents}` under every topology. A wall-clock `{cost_cap}` MUST instead be projected against serial depth: `{num_agents}` stages under `pipeline`, `{num_partitions}` waves under `staged`, and `ceil({num_agents} / {parallel_agents})` batches under `parallel` and `partitioned`.

## Events

The skill emits structured events in a dedicated `### Events` section of the reply. Events are JSON Lines (one JSON object per line) so external tooling can grep the section and compute cost on the fly without re-parsing the markdown report. Schema:

```json
{ "ts": "2026-05-17T01:30:00Z", "type": "<event_type>", "payload": { ... } }
```

| Type | Payload fields | Emitted when |
|---|---|---|
| `swarm.gate_decided` | `verdict`, `triggers_fired`, `pattern` | After the Swarm Gate runs |
| `swarm.topology_previewed` | `topology`, `format`, `slot_count` | After the preview renders (only when `--preview-swarm-topology` is set) |
| `swarm.dispatched` | `num_agents`, `parallel_agents`, `topology`, `model_mix`, `selection_modes` | After `worktree-task` is launched |
| `swarm.stage_started` | `kind` (`wave` / `stage`), `index`, `slots`, `base_branch` | Before each wave or stage launches under `staged` / `pipeline` |
| `member.started` | `slot`, `model`, `worktree_path` | When a member begins |
| `member.progress` | `slot`, `last_activity_ms` | Heartbeat (per `worktree-task`'s reporting cadence) |
| `member.completed` | `slot`, `status`, `test_exit`, `diff_lines` | When a member terminates (success / failed / incomplete) |
| `member.replaced` | `slot`, `reason`, `replacement_model` | When a hung member is killed and respawned |
| `selection.completed` | `mode`, `result`, `rationale` | Once per resolved entry in `{selection_modes}` |
| `swarm.done` | `successes`, `failures`, `replacements`, `wall_clock_s`, `floor_met` | At end of run |

Events MUST appear in chronological order. Do NOT inline events outside the dedicated section.

## Workflow

1. **Swarm gate.** Walk the Swarm Gate table and any counter-triggers. If no trigger fires (or a counter-trigger applies), recommend a single agent and stop. Emit `swarm.gate_decided`.
2. **Apply pattern (if `{pattern}` is set).** Populate defaults for `{num_agents}`, `{topology}`, `{model_mix}`, and `{selection_modes}` from the Pattern Catalog row. User-set parameters override.
3. **Resolve `{selection_modes}`.** When the value is `auto`, include every mode whose prerequisites are met given the other parameters and whose rule the resolved `{topology}` supports. Every catalog mode outside the resolved list is a skipped mode: record each one with its reason (the missing prerequisite, or the topology rule that excludes it) so the Aggregation section can report it.
4. **Validate parameters.** Confirm sizing, topology (catalog value, partition count where required, `{parallel_agents}` under `pipeline`), mix shape, partition divisibility, and selection-mode prerequisites. Fail fast on any mismatch (no filesystem side effects).
5. **Cost projection (when `{cost_cap}` is set).** Compute projected cost against `{num_agents}` for tokens and against the topology's serial depth for wall clock. If `projected > {cost_cap}`, propose the largest `{num_agents}` that fits and wait for user approval.
6. **Preview the topology (when `--preview-swarm-topology` is set).** Render the resolved topology per the Topology Preview section into the `### Topology Preview` section and emit `swarm.topology_previewed`. Continue to dispatch; the preview gates nothing.
7. **Dispatch via `worktree-task`.** Follow the Dispatch shape table for the resolved `{topology}`: one invocation for `parallel` and `partitioned`, one per wave for `staged`, one per stage for `pipeline`. Every invocation carries the slice of the resolved `{agent_model}` assignment belonging to its slots, the `{task}` (verbatim, plus the `## Upstream Context` block for `staged` waves and `pipeline` stages after the first), `{test_command}` (when set), and `{merge_mode} = interactive`. Emit `swarm.dispatched` once for the plan and `swarm.stage_started` before each wave or stage. Do not re-implement worktree mechanics.
8. **Watchdog.** Track each member's last activity. Emit `member.started`, `member.progress`, `member.completed` events as they fire. When `{relaunch_on_hang_after}` expires for a member, force-abort it; respawn per `{replacement_policy}` and emit `member.replaced`. Under `staged` and `pipeline`, the next wave or stage waits for the current one to terminate, replacements included.
9. **Floor check.** When all live members terminate, count `success`. If below `{min_successes}`, every selection mode reports `under-floor`; skip aggregation and emit `swarm.done` with `floor_met=false`.
10. **Run all resolved selection modes in parallel.** For each entry in the resolved `{selection_modes}`, apply its rule over the surviving members and emit `selection.completed`. Under `partitioned`, run each mode within every partition first, then globally over the partition outcomes. Each mode produces its own outcome block.
11. **Report and merge handoff.** Render the Output Format. Hand the chosen branch (if any) back through `worktree-task`'s merge prompt. Emit `swarm.done`. At most one branch is merged per invocation, even if several modes converge on it.

## Output Format

Reply with the following named sections, in this order. Omit sections whose body is legitimately empty.

### Swarm Decision

- `Verdict`: `swarm` or `single-agent`.
- `Triggers fired`: `T1`-`T6` IDs.
- `Pattern`: preset name or `none`.
- `Rationale`: one sentence tying verdict to triggers.

If `Verdict = single-agent`, stop here.

### Swarm Plan

- `num_agents` / `parallel_agents`: e.g., `8 (parallel: 4)`.
- `topology`: value plus the resolved layout — partitions, waves, or stages with their base branches.
- `model_mix`: shape and resolved per-slot assignment.
- `selection_modes`: resolved list; skipped modes with reasons.
- `min_successes`: floor.
- `relaunch_on_hang_after`: duration.
- `replacement_policy`: value.
- `cost_cap`: value or `unset`. Include the projection (and any user-approved downsize) when set.

### Topology Preview

Present this section only when `--preview-swarm-topology` is set, and render it before dispatch. One fenced ` ```mermaid ` block by default, a fenced plain block for `ascii`, or both for `both`, following the templates in the Topology Preview section.

### Per-Member Report

Defer to `worktree-task`'s Worktree Results section verbatim; do not duplicate the schema. Group the member blocks by partition, wave, or stage when the resolved `{topology}` is not `parallel`.

### Aggregation

One block per resolved entry in `{selection_modes}`, in the order listed:

#### `<mode>`

- `Outcome`: chosen branch, synthesized artifact path, `under-floor`, `no-consensus`, or `skipped: <reason>`. Under `partitioned`, list the per-partition outcomes first, then the global one.
- `Rationale`: one line tying the outcome to the mode's rule.

### Events

Fenced JSON Lines block in chronological order:

```jsonl
{"ts": "...", "type": "swarm.gate_decided", "payload": {...}}
{"ts": "...", "type": "swarm.dispatched", "payload": {...}}
...
{"ts": "...", "type": "swarm.done", "payload": {...}}
```

### Recommendation

- `Action`: one of `merge <branch>`, `apply synthesized artifact`, `await user pick`, `retry single-agent`, or `widen swarm`.
- `Mode convergence`: which selection modes agreed on which outcome (e.g., `auto-best and vote both pick member 3; synthesize emitted a separate artifact; manual defers`).
- `Confidence`: `high` / `medium` / `low` with a one-line reason.

### Handoff

- `Merge`: hand the chosen branch (if any) back to `worktree-task`'s merge prompt; do not merge inline.
- `Cleanup`: ask the user which non-winning worktrees to delete; leave them in place by default.
