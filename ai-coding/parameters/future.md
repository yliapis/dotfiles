# Future Ideas

Aspirational parameters and tooling follow-ups. Nothing here is live; each
item traces back to the [generated/](generated/INDEX.md) ontology candidates
or [trials/AGGREGATE.md](trials/AGGREGATE.md). Promote an item by adding it to
a real artifact first, then documenting it in the relevant concern file.

## Candidate parameters (from the generated ontologies)

Diversity and sampling ([models](concerns/models.md)):

- `seed`, `temperature` — per-member sampling control, with an index-offset
  broadcast rule (`member[i].seed = seed + i - 1`) sketched in
  `generated/layered/cross-layer.md`.
- `focus_hints` — per-candidate angle list distributed across members so
  variants explore deliberately different directions instead of relying on
  sampling noise.

Selection and evaluation ([selection](concerns/selection.md)):

- `selection_mode` for non-swarm fan-out (worktree-task and meta-prompt
  currently hardcode manual-pick and no-pick respectively).
- `ranker`, `compare_against` — judge configuration and a baseline to compare
  candidates against (refine-style runs).
- `merge_count` — generalize today's hard "at most one branch merges" cap.
- Generalized `criteria` — today declared only by critique; analysis-style
  commands and review skills could share the rubric vocabulary.

Robustness ([robustness](concerns/robustness.md)):

- `timeout`, `retry_policy`, `hang_policy` — generalized per-scope budgets and
  recovery, beyond agent-swarm's `relaunch_on_hang_after` /
  `replacement_policy` pair.

Reporting ([reporting](concerns/reporting.md)):

- `verbosity`, `require_diff`, `include_terminal_log`, `output_format` —
  report-shape knobs. Two are live today: trajectory-snapshot's
  `{granularity}` and agent-swarm's `--preview-swarm-topology`; every other
  artifact fixes its Output Format section instead of parameterizing it. The
  earlier decision here deferred a reporting concern file until a second
  artifact shipped an output-shape knob. `--preview-swarm-topology` met that
  trigger, so [concerns/reporting.md](concerns/reporting.md) now owns both
  parameters.

Isolation ([isolation](concerns/isolation.md)):

- `isolation` (mechanism selector), `worktree_root`, `cleanup_policy` — richer
  forms of the current worktree-always / `delete_worktree` boolean world.

## Skill frontmatter extensions (from the two-namespace candidate)

Today's skill frontmatter is `name` + `description` (+ `license`); activation
semantics live inside the `description` prose. `generated/two-namespace/skill-params.md`
sketches hoisting them into first-class keys:

- `activation_trigger`, `applicability_scope`, `precondition`,
  `trigger_keywords`, `negative_trigger` — testable activation contracts.
- `mandate_level` (recommendation | default | required) — how strongly an
  activated skill binds.
- `hand_off` (artifact | behavior | tool-call | none) — what the skill
  produces; makes the conventional-commits (artifact) vs minimal-diffs
  (behavior) distinction explicit.

## Tooling follow-ups (from trials/AGGREGATE.md)

- **Structured card source:** move card fields (aliases, type, default, used-by)
  into YAML frontmatter or a registry file and generate the Quick Map and
  [coverage.md](coverage.md) from it, so the indexes cannot drift from the
  cards.
- **Alias status taxonomy:** tag each alias `preferred` | `surface` | `compat`
  | `proposed` | `deprecated` to support gradual canonical-name adoption.
- **Rename adoption pass:** update artifacts to canonical spellings (the
  replication trio first — it has eleven spellings for three concepts),
  keeping old names as documented compat aliases for one release.
- **Recipes and traces:** short task-routed guides ("add fan-out to a
  command", "author a new skill") and de-duplicated worked examples, per the
  atlas architecture in trials/AGGREGATE.md.
