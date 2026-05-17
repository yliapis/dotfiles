# Parameter Ontology — Layered / Contextual Namespaces

This directory defines a reusable parameter ontology for the `ai-coding` plugin. The angle is **layered / contextual namespaces**: every parameter lives in a *named layer* identified by a prefix (`command.*`, `subagent.*`, `skill.*`, `shared.*`). The same root name (`task`, `parallel`, `criteria`, `model`, …) can — and is encouraged to — appear in multiple layers with different semantics. Disambiguation is done by layer prefix, **never by rename**.

## Why this angle

The natural names already in use across commands and skills (`task`, `parallel`, `criteria`, `model`, `save_path`, `context`, …) are linguistically right but semantically overloaded. The "obvious" fix — rename them to disambiguate (`outer_parallel` vs `inner_parallel`, `top_task` vs `slot_task`) — works, but it discards the very thing that makes the names readable in the first place: they are the words real users type. The layered approach keeps the words and pushes the disambiguation into a prefix that prompts and code can render or strip at will:

- `task` stays `task` in every file the user touches; the prefix `command.task` / `subagent.task` / `skill.task` is metadata used by the resolver and dropped from user-facing rendering.
- Cross-layer relationships (inheritance, broadcasting, shadowing) live in **one** place (`cross-layer.md`), so the per-layer files stay focused on "what this parameter MEANS in this layer".
- New layers are cheap (add a `<layer>.md` + entries in `cross-layer.md`); new root names are cheap (add a row to the relevant layer file).

The cost: callers MUST always know which layer they are in. That cost is paid by the orchestrator and is invisible to the user — which is the point.

## The layers

| Layer | Plane | Role |
| --- | --- | --- |
| `shared.*` | value | Primitive value types and addressing forms reused everywhere. No orchestration semantics on their own. |
| `command.*` | orchestration | Parameters of a top-level slash-command invocation. The orchestrator reads them. |
| `subagent.*` | execution | Parameters of a single subagent slot. The subagent reads them; the orchestrator computes them. |
| `skill.*` | activation | Parameters of a skill (declared, not invoked). Activated skills contribute to the orchestrator's or subagent's effective set. |

> **There is no `command_or_subagent.*` mega-layer.** When a root name applies at both layers, it appears under both — and the wiring between them lives in `cross-layer.md`.

## Files

| File | Purpose | Parameters defined |
| --- | --- | --- |
| `shared.md` | Primitive value types (`int_range`, `addressable`, `duration`, …) and addressing forms (`file`, `directory`, `glob`, `url`, `inline`). The vocabulary every other layer composes with. | 25 |
| `command.md` | Every parameter in the `command.*` namespace, grouped by category (intent, constraints, fan-out, isolation, lifecycle, robustness, reporting). | 46 |
| `subagent.md` | Every parameter in the `subagent.*` namespace, including outbound (reporting) parameters the subagent produces. | 22 |
| `skill.md` | Every parameter in the `skill.*` namespace: identity, activation, contract, bundle, composition. | 17 |
| `cross-layer.md` | The contract between layers: per-root inheritance / broadcasting / shadowing rules, resolution order, whole-ontology validation rules, and a worked end-to-end resolution. | 0 (no new params) |
| `README.md` | This file. | 0 |

**Total: 110 parameters across 4 layers, plus the cross-layer wiring.**

## Naming convention (the prefix is metadata)

- A reference in this ontology takes the form `<layer>.<name>` (e.g. `command.parallel`).
- Composite types use a dotted continuation (e.g. `command.retry_policy.max_retries`); these are sub-fields, not new parameters.
- When a prompt or doc shows a parameter to the user, the convention is to **render with braces and WITHOUT the layer prefix**: `{parallel}`, `{task}`, `{criteria}`. The prefix is purely for resolution.
- When a parameter name appears with no prefix in narrative prose, treat it as a *root name* that may live in multiple layers — consult `cross-layer.md` to see which.

## How to read this directory

1. Start in `shared.md` to learn the value-type vocabulary.
2. Read whichever of `command.md`, `subagent.md`, `skill.md` matches the layer you are designing for.
3. Whenever a Definition says "Sibling root: …" or "Derived from …", jump to `cross-layer.md` for the resolution rule.

## How to extend this directory

- New parameter at an existing layer: add a section in the appropriate `<layer>.md`, citing types from `shared.md`.
- New cross-layer relationship for an existing root name: add the new layer entry, then add a Per-root section in `cross-layer.md`.
- New layer entirely: add `<newlayer>.md` AND a column in the at-a-glance table in `cross-layer.md`. Justify in the README.

---

## Worked Example 1 — `critique.md` consumes this ontology

The current parameter block in `ai-coding/plugins/ai-coding/commands/critique.md`:

```text
{context}, {criteria}, {model}, {parallel}, {num_experiments}
```

Resolved against this ontology:

| Surface name in `critique.md` | Layer-prefixed reference | Notes |
| --- | --- | --- |
| `{context}` | `command.context` | Type `shared.addressable`; required. |
| `{criteria}` | `command.criteria` | Type `shared.addressable`; default `"quality + determinism"`. |
| `{model}` | `command.model` | The orchestrator's model. |
| `{parallel}` | `command.parallel` | Outer fan-out, `shared.int_range >= 1`. |
| `{num_experiments}` | `command.num_experiments` | Replicate count. |

What the orchestrator does with those (using `cross-layer.md`):

```text
# Validation
command.parallel : >= 1
command.num_experiments : >= 1

# Per-slot resolution (one slot per experiment)
for i in 1..command.num_experiments:
  subagent[i].slot_index    = i
  subagent[i].task          = rewrite(command.task, run_index=i)    # rewrite mode
  subagent[i].context       = command.context                       # broadcast
  subagent[i].criteria      = command.criteria                      # broadcast
  subagent[i].model         = command.model                         # broadcast (no command.agent_model in critique)
  subagent[i].guardrails    = command.guardrails ∪ {}               # no skill activation
  subagent[i].output_format = "json-schema:./schemas/finding.json"  # downcast
  subagent[i].parallel      = 1                                     # orthogonal — NOT inherited
```

Findings the slots emit conform to `subagent.output_format` (structured JSON), which the orchestrator merges into `command.output_format = "markdown:critique-report"`. The convergent vs divergent rendering required by Success Criterion #5 of `critique.md` corresponds to grouping `subagent[i].output_format` outputs by `(location, criterion)` across `i`.

If a future revision of `critique.md` added partition mode (one criterion per slot), the only change is in the orchestrator's resolution policy for `command.criteria` (broadcast → partition); the layer parameters themselves do not change.

---

## Worked Example 2 — `worktree-task-agent.md` consumes this ontology

The current parameter block in `ai-coding/plugins/ai-coding/commands/worktree-task-agent.md`:

```text
{task}, {base_branch}, {worktree_name}, {delete_worktree}, {merge_mode},
{test_command}, {agent_model}, {parallelism}, {num_partitions}, {stop_condition}
```

Resolved against this ontology:

| Surface name in `worktree-task-agent.md` | Layer-prefixed reference | Notes |
| --- | --- | --- |
| `{task}` | `command.task` | Required. |
| `{base_branch}` | `command.base_branch` | `shared.branch_ref`; default = current branch. |
| `{worktree_name}` | `command.worktree_name` | Slug; per-slot `-{i}` suffix when `command.parallel > 1`. |
| `{delete_worktree}` | `command.delete_worktree` | Boolean shortcut for `command.cleanup_policy`. |
| `{merge_mode}` | `command.merge_mode` | `shared.enum {interactive, auto}`. |
| `{test_command}` | `command.test_command` | Broadcast to `subagent.test_command`. |
| `{agent_model}` | `command.agent_model` | Per-slot model SETTER → `subagent.model`. |
| `{parallelism}` | `command.parallel` | Outer fan-out (sibling-name renamed to match this command's prose; the ontology root is `parallel`). |
| `{num_partitions}` | `command.num_partitions` | Orchestrator-only. |
| `{stop_condition}` | `command.stop_condition` | Broadcast to `subagent.stop_condition`. |

What the orchestrator does, walking the validation rules in `cross-layer.md`:

```text
# Validation (cross-layer.md § Whole-ontology validation rules)
command.parallel       : >= 1
command.num_partitions : >= 1
command.agent_model    : scalar  OR  list of length command.parallel
                          OR  list of length command.num_partitions (partition mode)

# Per-slot resolution
for i in 1..command.parallel:
  subagent[i].slot_index       = i
  subagent[i].worktree_path    = <command.worktree_root>/<command.worktree_name>-<i>/
  subagent[i].base_branch      = command.base_branch                  # broadcast
  subagent[i].task             = rewrite(command.task, slot=i)        # rewrite mode
  subagent[i].stop_condition   = command.stop_condition               # broadcast
  subagent[i].test_command     = command.test_command                 # broadcast
  subagent[i].model            = resolve(command.agent_model, i)      # broadcast or zip
  subagent[i].guardrails       = command.guardrails
                               ∪ command.subagent_constraints
                               ∪ ⋃ { skill.guardrails : skill activated for slot i }
  subagent[i].timeout          = 15m                                  # default; NOT inherited
  subagent[i].parallel         = 1                                    # orthogonal
```

On completion, each slot reports `subagent.status`, `subagent.summary`, `subagent.verification`, and `subagent.diff`. The orchestrator's "Worktree Results" section in `worktree-task-agent.md`'s Output Format is a direct rendering of those four parameters per slot.

Note the cross-layer subtlety the current `worktree-task-agent.md` already addresses: `{parallelism}` is `command.parallel` (NOT `subagent.parallel`). If a future revision wants to also let each subagent run tools in parallel internally, it would expose `{inner_parallel}` mapped to `command.subagent_constraints.inner_parallel` — there is no need to rename `{parallelism}`.

---

## Worked Example 3 — a skill activates inside a command

When `conventional-commits` (a SKILL) activates inside `worktree-task-agent` (a COMMAND), the layer wiring is:

```text
# skill.* layer (declared once, in the SKILL.md)
skill.name           = "conventional-commits"
skill.task           = "Format git commit messages following Conventional Commits 1.0.0."
skill.guardrails     = [
  "MUST use single quotes around `!` to avoid shell escaping issues.",
  "MUST NOT include a period at the end of the commit description.",
]
skill.output_format  = "text:conventional-commit-line"

# command.* layer (worktree-task-agent invocation)
command.task         = "Add OAuth2 support; commit the change."
command.test_command = "pytest -q"

# Skill activates inside each subagent (commit-style decision lives inside the slot)
subagent[i].guardrails = command.guardrails
                       ∪ command.subagent_constraints
                       ∪ skill.guardrails           # ← union mode

subagent[i].output_format = command.output_format    # the user-facing report
# but ANY commit emitted inside subagent[i] also MUST satisfy skill.output_format
# (cross-layer.md § output_format: skill imposes an invariant on outputs in its scope)
```

The skill never contributes to `command.task` (that is a `rewrite`-mode parameter the orchestrator owns), but it tightens `subagent.guardrails` and adds an invariant to `subagent.output_format`. No renames; no new root names; only layer-prefixed references.
