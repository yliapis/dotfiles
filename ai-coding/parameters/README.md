# Parameter Wiki

Canonical, concern-first reference, intended to cover every parameter declared
by the AI-coding commands ([`ai-coding/commands/`](../commands/)) and skills
([`ai-coding/skills/`](../skills/)). One page per concern; one card per
cross-artifact parameter concept. This wiki documents **today's live surface
only** — aspirational parameters and tooling ideas live in [future.md](future.md).

## How to use this wiki

- **Authoring a new command or skill:** skim the Quick Map below, reuse the
  canonical names and card semantics instead of inventing new spellings.
- **Resolving a name you found in an artifact:** look it up in
  [coverage.md](coverage.md) (artifact → parameter-as-written → card).
- **Wiring fan-out or subagent dispatch:** read [propagation.md](propagation.md)
  for the scope rules and the live `agent-swarm` → `worktree-task` mapping.
- **Long-form design rationale:** the [generated/](generated/INDEX.md) archive
  holds eight candidate ontologies from the original design swarm, and
  [trials/AGGREGATE.md](trials/AGGREGATE.md) holds the consolidation study.
  Both are provenance; neither is normative.

## Conventions

- A **card** is the canonical definition of one parameter concept. Cards live in
  `concerns/*.md`. A parameter gets a card when **two or more artifacts** use
  it; single-artifact parameters are listed in the "Artifact-specific" section
  at the bottom of their concern file.
- **Canonical name ≠ rename mandate.** Artifacts keep their current spellings;
  each card's Aliases line maps spelling → artifact. Adopting canonical names
  inside artifacts is a possible follow-up, not the status quo.
- **Applies to** values: `command` (a slash command invocation), `skill` (a
  skill's invocation contract), `spawned agent` (a subagent launched by a
  fan-out artifact: a worktree-task member, swarm member, or meta-prompt
  variant agent).
- Validation is always **fail-fast**: parameters are checked before any side
  effect, and failure aborts with an explanatory error and no filesystem
  changes. Cards note only checks beyond that baseline.
- **Flag contradictions, don't transcribe them.** When two artifacts state
  incompatible contracts (e.g. a dispatch edge whose parameter shapes cannot
  both hold), the wiki must not neutrally record both sides. Add a **Known
  seams** note on the affected card(s) and in
  [propagation.md](propagation.md) naming the conflict, and file the fix
  against the artifacts. The wiki is a map of the live surface, not an
  arbiter of last edit wins.

Card template:

```markdown
### `canonical_name`
- **Aliases:** `spelling` (artifact), `spelling` (artifact)
- **Applies to:** command | skill | spawned agent
- **Type:** <type + validation, e.g. integer >= 1>
- **Default:** <value or "artifact-specific">
- **Meaning:** <1-2 sentences>
- **Validation:** <cross-parameter checks, e.g. list length = candidate_count>
- **Propagation:** <one line; link propagation.md when it crosses scopes>
- **Used by:** <artifact list>
```

## Quick map

Cross-artifact cards only; single-artifact parameters are indexed in
[coverage.md](coverage.md).

| Canonical | Concern | Aliases | Used by |
|---|---|---|---|
| `task` | [intent](concerns/intent.md) | — | worktree-task, agent-swarm (relayed) |
| `context` | [intent](concerns/intent.md) | `target`, `domain` | critique, designer, designer-controller, ralph-design |
| `artifact_path` | [io](concerns/io.md) | `save_path`, `output_path` | meta-prompt, save-session-state, ralph-design, design-skill, designer-controller |
| `test_command` | [constraints](concerns/constraints.md) | `verify_command` | worktree-task, agent-swarm, ticket-execute, address-worklist-commit-loop (relayed) |
| `stop_condition` | [constraints](concerns/constraints.md) | — | worktree-task, ralph-design |
| `max_iterations` | [constraints](concerns/constraints.md) | — | ralph-design, design-skill, designer-controller, agent-swarm |
| `candidate_count` | [replication](concerns/replication.md) | `n`, `num_experiments`, `parallelism`, `num_agents`, `num`, `fan_out`, `fanout_default_n` | meta-prompt, critique, worktree-task, agent-swarm, designer-controller, ralph-design |
| `concurrency` | [replication](concerns/replication.md) | `k`, `parallel`, `parallel_agents`, `p` | meta-prompt, critique, agent-swarm, worktree-task |
| `partition_count` | [replication](concerns/replication.md) | `num_partitions` | worktree-task, agent-swarm |
| `agent_model` | [models](concerns/models.md) | — | worktree-task, ralph-design, designer-controller |
| `base_branch` | [isolation](concerns/isolation.md) | — | worktree-task, ralph-design, wrap-up, soft-shutdown |
| `worktree_name` | [isolation](concerns/isolation.md) | `worktree` | worktree-task, ralph-design, meta-prompt |
| `use_worktree` | [isolation](concerns/isolation.md) | — | ralph-design, design-skill, designer-controller |
| `delete_worktree` | [isolation](concerns/isolation.md) | `delete_after_merge` | worktree-task, wrap-up |
| `write_gate` (family) | [lifecycle](concerns/lifecycle.md) | `update_mode`, `persistence`, `dry_run`, `mode` | meta-prompt, ralph-design, design-skill, designer-controller, ticket-create, ticket-execute, ticket-update, address-worklist-commit-loop, save-session-state |
| `merge_mode` | [lifecycle](concerns/lifecycle.md) | — | worktree-task, agent-swarm (sets it) |
| `remote` | [lifecycle](concerns/lifecycle.md) | — | merge-commit-push, wrap-up, soft-shutdown |
| `interactive` | [interaction](concerns/interaction.md) | `-i`, `--interactive`, `--interactive-template` | critique, meta-prompt, wrap-up, save-session-state, soft-shutdown, prompt-template-library, ticket-create |
| `approval_mode` | [interaction](concerns/interaction.md) | `mode` | ticket-execute, ticket-update, address-worklist-commit-loop, ralph-design, agent-swarm |
| `authoring_mode` | [interaction](concerns/interaction.md) | `mode` | design-skill, designer-controller |
| `traits` | [composition](concerns/composition.md) | — | designer, designer-controller |
| `trait_map` | [composition](concerns/composition.md) | — | designer, designer-controller |

## Concern files

| File | Responsibility |
|---|---|
| [concerns/intent.md](concerns/intent.md) | What the invocation is about: the goal, the raw input, the subject artifact. |
| [concerns/io.md](concerns/io.md) | How inputs are addressed (file / directory / URL / inline) and where outputs land. |
| [concerns/constraints.md](concerns/constraints.md) | What counts as done, valid, or acceptable: rubrics, gates, caps, validation vocabulary. |
| [concerns/replication.md](concerns/replication.md) | How many independent runs, how many at once, how they partition. |
| [concerns/models.md](concerns/models.md) | Which model runs where: the current agent vs spawned workers. |
| [concerns/selection.md](concerns/selection.md) | How multiple candidates reduce to an outcome. |
| [concerns/isolation.md](concerns/isolation.md) | Where work happens without touching the calling tree: branches, worktrees, cleanup. |
| [concerns/lifecycle.md](concerns/lifecycle.md) | What persists at the end of a run: write gating, merging, pushing, write-back. |
| [concerns/robustness.md](concerns/robustness.md) | What happens when members hang, fail, or overspend. |
| [concerns/interaction.md](concerns/interaction.md) | When the user is asked: interactive flags, approval cadence, authoring motion. |
| [concerns/reporting.md](concerns/reporting.md) | What the run shows the reader: detail level, plan diagrams, other output-shape knobs. |
| [concerns/composition.md](concerns/composition.md) | How artifacts select and shape other skills: traits, registries, presets, styles. |

## Other pages

- [propagation.md](propagation.md) — scope and propagation rules between an
  invocation and its spawned agents.
- [coverage.md](coverage.md) — per-artifact index of declared parameters.
- [future.md](future.md) — aspirational parameters and tooling follow-ups.
