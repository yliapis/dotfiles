# Parameter Wiki Trial Aggregate

Random seed: `73`
Trials: `10`
Source corpus: `ai-coding/parameters/generated/`

## Consensus Recommendation

Do not promote any one generated ontology as the canonical wiki. The generated sets are best treated as source lenses over one shared parameter vocabulary:

- `concern/` and `flat/`: best for human authoring and migration/search.
- `type-first/`: best for validation, parser shape, and type contracts.
- `lifecycle/` and `stage-modular/`: best for execution order and side-effect boundaries.
- `tree/` and `layered/`: best for scope, inheritance, and subagent propagation.
- `two-namespace/`: best for command-vs-skill boundaries, with live/proposed skill status made explicit.

Build a compact atlas/router layer above `generated/`. The atlas should route humans and AI agents by task, then land on canonical parameter cards. Generated docs remain provenance and long-form rationale.

## Synthesized Architecture

Recommended target:

```text
ai-coding/parameters/wiki/
  README.md                    # route atlas and human/AI entry point
  cards/                       # canonical facts, one card per parameter concept/family
    intent-subject.md
    input-addressing.md
    constraints-done.md
    fanout-count.md
    fanout-concurrency.md
    agent-routing.md
    scope-propagation.md
    workspace-isolation.md
    selection-reduce.md
    persist-promote.md
    report-render.md
    skill-activation.md
  indexes/                     # thin facets over cards, not repeated definitions
    by-artifact.md
    by-concern.md
    by-stage.md
    by-scope.md
    by-type.md
    by-status.md
    aliases.md
  recipes/                     # task routes for authors and agents
    new-command.md
    new-skill.md
    fanout-command.md
    worktree-isolation.md
    validation-before-effects.md
  traces/                      # worked examples kept once
    critique.md
    meta-prompt.md
    worktree-task.md
  provenance.md                # map back to generated ontology candidates
```

The operating rule is:

```text
cards own facts
indexes own routes
recipes own decisions
traces own examples
generated owns provenance
```

## Compression Strategy

Compress by semantic concept, not by generated file or parameter spelling.

- Collapse repeated definitions into family cards. Start with the highest-collision families: fan-out counts, concurrency, model assignment, worktree isolation, selection, persistence, reporting, and skill activation.
- Keep aliases on cards and in `indexes/aliases.md`, with status values such as `preferred`, `surface`, `compat`, `internal`, `proposed`, and `deprecated`.
- Split true semantic collisions instead of hiding them. For example, `parallelism` should resolve to either `fanout-count` or `fanout-concurrency` depending on context.
- Keep indexes thin. A facet row should link to a card and add only local placement notes.
- Keep generated docs unchanged at first. Use them as source links until the card layer proves coverage.
- Move repeated examples into traces. `/critique`, `meta-prompt`, and worktree fan-out should be described once and linked from every relevant card or recipe.

## Card Template

Use stable headings so cards can later become structured source material.

```markdown
# <Concept Title>

Stable ID: `<concept.id>`
Status: `live | live-prose | proposed | archived`

## Definition

One short paragraph.

## Surface Names

Preferred, surface, compatibility, and internal aliases.

## Scope Behavior

Root, command, subagent, leaf, skill, shared, inherit, shadow, reset, or bubble.

## Validation

Type formalism and cross-parameter checks.

## Stage Use

When this value is read, validated, consumed, emitted, or persisted.

## Common Gotchas

Two to four bullets, especially alias collisions.

## Source Pointers

- Semantic:
- Type:
- Stage:
- Scope:
- Artifact:
```

## Trial Architectures

| Trial | Architecture | Distinct Contribution | Recommended Use |
|---|---|---|---|
| 01 | Parameter Atlas | Clear rule: cards own facts, lenses own routes, recipes own decisions. | Use as the core implementation principle. |
| 02 | Facet Atlas | Strong facet matrix and explicit mapping of each generated ontology to its best role. | Use for the router and source-lens map. |
| 03 | Facet Router | Strong alias ledger and high-conflict card list. | Use for migration and name-resolution policy. |
| 04 | Facet Switchboard | Best "AI traversal contract" and minimum vocabulary framing. | Use for the top of `README.md`. |
| 05 | Route-Map Atlas | Strong goal-first route cards, drift notes, and current artifact map. | Use for live-vs-generated link hygiene. |
| 06 | Registry-Backed Facet Router | Most concrete registry/facet/routes/examples directory split. | Use as the file layout baseline. |
| 07 | Facet Router With Shared Traces | Strong example trace de-duplication and facet-source table. | Use for `traces/` and provenance. |
| 08 | Lens Hub | Strong concept kernel and alias status taxonomy. | Use for card metadata and live/proposed skill handling. |
| 09 | Parameter Atlas | Most compact stable concept ID set. | Use for the first 12 seed cards. |
| 10 | Route Atlas | Strong link hygiene notes, status legend, and generated/archive demotion. | Use for adoption rules and provenance policy. |

## Seed Concept Cards

Create these first, before attempting full migration:

| Stable ID | Covers |
|---|---|
| `intent.subject` | `task`, `input`, `context`, `criteria` |
| `input.addressing` | `file`, `directory`, `glob`, `url`, `inline`, `format`, `file_type` |
| `constraints.done` | `guardrails`, `stop_condition`, `test_command`, validation predicates |
| `fanout.count` | `k`, `n`, `n_candidates`, `num_experiments`, `num_agents`, count-style `parallelism` |
| `fanout.concurrency` | `parallel`, `parallel_agents`, concurrency-style `parallelism` |
| `agent.routing` | `model`, `agent_model`, `subagent_model`, `model_mix`, `seed`, `temperature`, `focus_hints` |
| `scope.propagation` | command/subagent/leaf/skill binding, inherit, shadow, reset, bubble |
| `workspace.isolation` | `isolation`, `base_branch`, `worktree_name`, `worktree_root` |
| `selection.reduce` | `selection_mode`, `selection_modes`, `ranker`, `aggregator`, `min_successes`, `compare_against` |
| `persist.promote` | `save_path`, `auto_save_winner`, `merge_mode`, `merge_count`, `cleanup_policy`, `delete_worktree` |
| `report.render` | `verbosity`, `require_diff`, `include_terminal_log`, `output_format`, result sections |
| `skill.activation` | `name`, `description`, `license`, activation prose, mandate, hand-off, applicability |

## Navigation Contract

Human routes:

- Writing a slash command: `recipes/new-command.md` -> relevant cards -> `indexes/by-type.md` for validation.
- Writing a skill: `recipes/new-skill.md` -> `skill.activation` -> `indexes/by-artifact.md` for live/proposed boundaries.
- Adding fan-out: `recipes/fanout-command.md` -> `fanout.count` -> `fanout.concurrency` -> `agent.routing` -> `selection.reduce`.
- Adding worktree mutation: `recipes/worktree-isolation.md` -> `workspace.isolation` -> `persist.promote` -> `report.render`.
- Debugging side effects: `indexes/by-stage.md` -> card -> trace.
- Resolving a name: `indexes/aliases.md` -> card -> one source pointer.

AI route:

1. Identify artifact kind: command, skill, subagent prompt, generated doc, report, or persisted file.
2. Identify operation: author, validate, execute, select, persist, report, migrate, or debug.
3. Resolve named parameters through `indexes/aliases.md`.
4. Load the card and at most one next facet: type, stage, scope, artifact, or trace.
5. Keep surface names already present in an artifact unless the task is explicitly a migration.

## Adoption Plan

1. Create `ai-coding/parameters/wiki/README.md` as the atlas entry point.
2. Create the 12 seed cards above.
3. Add `indexes/aliases.md`, `indexes/by-type.md`, `indexes/by-stage.md`, `indexes/by-scope.md`, and `indexes/by-artifact.md` as thin link maps.
4. Add three traces: `critique`, `meta-prompt`, and `worktree-task`.
5. Add `provenance.md` describing the eight generated perspectives and the older archive snapshots.
6. Use the atlas to update or review one command and one skill before migrating the rest.
7. If the shape works, move card metadata into YAML/frontmatter and generate indexes from cards.

## Risks

- The atlas can become a ninth ontology if it grows too much prose. Keep the first page short and route to cards.
- Family cards can hide real distinctions. Split roles when aliases conflate semantics, especially count vs concurrency.
- Skill-side parameters are partly aspirational. Mark `live`, `live-prose`, `proposed`, and `archived` explicitly.
- Generated links may drift. Use checked repo-root-relative references when building the final wiki.
- Derived indexes can diverge if edited as source. Cards should become the source of truth before generation is introduced.

## Final Decision

Adopt the route atlas/card registry architecture. It preserves the value of every generated ontology while compressing the daily reading path for humans and AI agents into a small, stable wiki surface.
