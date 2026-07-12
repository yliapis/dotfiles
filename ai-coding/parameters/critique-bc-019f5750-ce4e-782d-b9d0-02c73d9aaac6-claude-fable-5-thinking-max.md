# Critique: `ai-coding/parameters/`

**Criteria applied:** quality — clarity, correctness, completeness, robustness;
determinism — reproducibility, idempotency, stability (the repo's default
`/critique` criteria)
**Runs:** 1 (parallel up to 1, model: `claude-fable-5-thinking-max`)
**Run id:** `bc-019f5750-ce4e-782d-b9d0-02c73d9aaac6`
**Corpus:** `ai-coding/parameters/` at commit `9560abb` (captured 2026-07-12)

## Summary

The parameter wiki is a high-fidelity, well-factored reference: of the roughly
thirty defaults, enums, validation rules, and propagation claims spot-checked
against the fourteen indexed artifacts, everything except the items flagged
below was accurate, and the live-vs-aspirational split (`future.md`) and the
provenance demotion (`generated/`, `trials/`) are clean. Findings: 0 critical,
3 major, 5 minor, 2 nit. The biggest concern is the maintenance model rather
than the content: every fact is hand-maintained in up to seven index rows with
no generation or checking, and the wiki has already drifted — the
`trajectory-snapshot` skill landed four days after the wiki commit and appears
nowhere in `coverage.md` or the concern files. The second-biggest concern is
that `propagation.md` presents the agent-swarm → worktree-task dispatch
mapping as a settled live rule even though the underlying contracts are
arithmetically inconsistent whenever `num_agents > parallel_agents`.

## Scope and Method

- Read in full: the 15 live wiki files (`README.md`, `coverage.md`,
  `propagation.md`, `future.md`, and 11 `concerns/*.md`; ≈1,140 lines) plus
  `trials/AGGREGATE.md`.
- Read as provenance (via `generated/INDEX.md`, `generated/README.md`, and
  sampled files): the 85-file, ≈17.4k-line `generated/` archive.
- Cross-checked card facts (aliases, types, defaults, validation, propagation)
  against all 9 commands in [`ai-coding/commands/`](../commands/) and all 10
  skills in [`ai-coding/skills/`](../skills/); verified `coverage.md`
  row-for-row against each indexed artifact's Parameters / Knob Inventory
  section; confirmed the in-repo mirrors (`ai-coding/plugins/ai-coding/`,
  `.cursor/commands/`, `.cursor/skills/`) are currently byte-identical to the
  tracked sources.

## Strengths (verified)

- `coverage.md` is row-complete for all 14 artifacts it indexes: every
  parameter declared in those artifacts' Parameters / Knob sections has a row
  with a correct card link and anchor, and no phantom rows exist.
- Spot-checked normative facts matched the artifacts exactly: all six
  write-gate spellings and their per-artifact enums
  ([lifecycle.md](concerns/lifecycle.md)), `base_branch`'s role-split defaults
  (fork-from-here vs. reconcile-against-`main`), `candidate_count`'s
  per-artifact defaults and `>= 2` gates, the `50`/`50`/`20`
  `max_iterations` caps, and the `{mode}`-dependent `{on_failure}` defaults.
- [propagation.md](propagation.md)'s vocabulary (broadcast / zip / partition /
  rewrite / orthogonal / bubble) is precise, and its invariants (isolation,
  single merge, no recursion, validate-before-side-effects) are each really
  restated in the artifacts they summarize.
- The two worst name overloads in the repo are correctly untangled: the
  count / concurrency / partition split in
  [replication.md](concerns/replication.md), and the interactive-flag /
  approval-mode / authoring-mode split over the overloaded spellings `-i` and
  `mode` in [interaction.md](concerns/interaction.md).
- Honest epistemics throughout: agent-swarm's `task` is marked "(relayed,
  undeclared)", ralph-design's `domain` is marked a loose alias, and
  [selection.md](concerns/selection.md) / [robustness.md](concerns/robustness.md)
  say plainly that they hold no cards instead of padding.

## Findings

### Major

- **completeness** @ `coverage.md` (Skills section and "No parameter surface")
  - Evidence: `ai-coding/skills/trajectory-snapshot/SKILL.md` (L13–20)
    declares `{filename_format}`, `{granularity}`, and `{coding_tool}`, yet
    `trajectory-snapshot` appears nowhere under `ai-coding/parameters/`; the
    wiki commit `e258beb` is dated 2026-07-03 while the skill commits
    `f8d0a74` / `149f7ee` are dated 2026-07-07; `README.md` L3–5 promises a
    reference "for every parameter declared by the AI-coding commands … and
    skills".
  - Rationale: The wiki's charter is total coverage of today's live surface,
    so a parameterized skill missing from `coverage.md` and from `io.md`
    (where `{filename_format}` belongs beside the `artifact_path` family)
    means the canonical index silently under-reports the very surface it
    exists to document.

- **correctness** @ `propagation.md` L51–58 (worked example: agent-swarm →
  worktree-task)
  - Evidence: the table maps `{parallel_agents}` → `{parallelism}` and
    `per-agent` `{model_mix}` → "list of length `{num_agents}`", while
    `ai-coding/skills/worktree-task/SKILL.md` requires an `{agent_model}` list
    whose "length MUST equal `{parallelism}`" (L20) and creates "exactly
    `{parallelism}` isolated worktrees" (L27); no artifact defines how the
    remaining `num_agents − parallel_agents` members are dispatched.
  - Rationale: For any swarm where `parallel_agents < num_agents`, the
    documented live rule is unsatisfiable — the per-agent model list fails
    worktree-task's own validation and the member total cannot materialize —
    so the wiki is presenting a known-broken cross-artifact contract as
    settled fact instead of flagging it as an open contradiction.

- **robustness / idempotency** @ wiki-wide maintenance model
  - Evidence: a single fact fans out to up to seven hand-written rows — e.g.
    `test_command` lives in the `concerns/constraints.md` card, the Quick Map
    row (`README.md` L63), three `coverage.md` rows (L88, L147, L162), and two
    `propagation.md` rows (L34, L57); the `Makefile` and `ai-coding/scripts/`
    contain no wiki lint or generation target; `future.md` L62–65 defers the
    structured-card-source registry to a follow-up.
  - Rationale: With no generated indexes and no check, keeping the wiki
    correct requires a contributor to remember every mirror row on every
    artifact edit — a procedure that is not idempotent in practice, as the
    trajectory-snapshot drift above demonstrates within four days of the
    wiki's creation.

### Minor

- **clarity** @ `generated/README.md` + `generated/INDEX.md`
  - Evidence: `INDEX.md` (L3–5) describes only the eight best-of-8 ontology
    directories; `README.md` (L3–9) describes only the four older per-task
    sample directories (`param-ontology/`, `param-stages/`, `parameters/`,
    `params/`); neither mentions the other set, and the root `README.md`
    (L17–18) says the archive "holds eight candidate ontologies" although 12
    subdirectories are present.
  - Rationale: Two competing entry documents that each describe a disjoint
    subset — plus the self-shadowing path `parameters/generated/parameters/` —
    make the provenance layer materially harder to navigate than a single
    entry doc naming both archive generations would be.

- **reproducibility** @ `concerns/replication.md` L4–5 (and `future.md`
  L68–70)
  - Evidence: "seven artifacts spell the same three concepts eleven different
    ways"; enumerating the aliases actually listed on the three cards yields
    12 distinct spellings (`n`, `num`, `num_experiments`, `num_agents`,
    `parallelism`, `fan_out`, `fanout_default_n`, `k`, `p`, `parallel`,
    `parallel_agents`, `num_partitions`), or 10 when agent-swarm's declared
    alias forms are excluded.
  - Rationale: The headline number cannot be re-derived from the wiki's own
    data under any stated counting rule, which undercuts a document whose
    value proposition is being the checkable source of truth for exactly this
    kind of fact.

- **consistency** @ card template vs. cards (`README.md` L39–51)
  - Evidence: the template mandates Aliases / Applies to / Type / Default /
    Meaning / Validation / Propagation / Used by, but the `write_gate` card
    (`concerns/lifecycle.md` L10–29) has no Type, Default, or Propagation
    lines, `task` (`concerns/intent.md`) lacks Default, and `context` lacks
    Propagation; `constraints.md` L12 and `models.md` L13 use an
    `command, skill → spawned agent` arrow notation that is not one of the
    three documented "Applies to" values (`README.md` L31–34).
  - Rationale: Silent field omission and undocumented notation make it
    impossible to tell "not applicable" apart from "not yet documented"; the
    template should mark optional fields (or the cards should conform) before
    the drift compounds.

- **completeness** @ `concerns/intent.md` L25 (`context` card Type)
  - Evidence: the card types `context` as the union "file path | directory
    path | URL | inline text | free-form description", but critique's
    `{context}` accepts no free-form description
    (`ai-coding/commands/critique.md` L7), designer's and
    designer-controller's `target` accept no URL
    (`ai-coding/commands/designer.md` L10), and ralph-design's `{domain}` is
    free-form only (`ai-coding/commands/ralph-design.md` L9); `io.md` L17–20
    delegates per-parameter subsets to the artifacts, and the card records
    none of them.
  - Rationale: A union type on the canonical card masks exactly the
    per-artifact differences a caller needs — which addressing forms this
    alias actually accepts — and only `{criteria}` gets its subset spelled
    out anywhere in the wiki.

- **clarity** @ `README.md` L17–20 vs. `trials/AGGREGATE.md`
  - Evidence: the consolidation study's consensus opens "Do not promote any
    one generated ontology as the canonical wiki" (L9) and specifies a
    `wiki/` atlas layout with cards / indexes / recipes / traces (L23–58);
    what was built is the concern-first ontology plus two facets
    (`coverage.md` ≈ by-artifact, `propagation.md` ≈ by-scope) at the section
    root, with no note recording why this divergence was chosen.
  - Rationale: The section preserves ≈17k lines of design provenance yet
    omits the one decision record a future maintainer will actually look for —
    why the live shape is concern-first-plus-facets rather than the atlas the
    trials recommended.

### Nit

- **clarity** @ `concerns/intent.md` L40–41
  - Evidence: "`{input}` … Required (may be empty, which triggers HELP)."
  - Rationale: "Required but may be empty" is self-contradictory as a
    validation contract; "always present; empty input selects HELP mode" says
    the same thing without the paradox.

- **correctness** @ `propagation.md` L37 (`worktree_name` rule)
  - Evidence: "rewrite: member *i* gets the `-<i>` suffix" is stated
    unconditionally, while `ai-coding/skills/worktree-task/SKILL.md` L16
    appends the suffix only when `{parallelism}` is greater than 1.
  - Rationale: The single-member run (bare name, no suffix) is the default
    invocation shape, so the canonical propagation rule as written is wrong
    for the most common case.

## Open Questions

- **Swarm totals.** Is worktree-task's `parallelism` meant to be split into
  separate total-count and concurrency knobs (neither appears in
  `future.md`), or is agent-swarm expected to dispatch in waves? Until one is
  chosen, the propagation worked example cannot be made consistent.
- **Known-contradiction annotations.** Should the wiki carry an explicit
  marker for documented-but-inconsistent cross-artifact contracts (see the
  second major finding), so that faithful documentation is distinguishable
  from endorsement?
- **Card lifecycle.** The two-or-more-artifacts threshold for cards
  (`README.md` L24–27) has no demotion rule — when an artifact is removed or
  renames a parameter, does its card revert to an artifact-specific bullet,
  and what surfaces the need?
- **Mirror authority.** `coverage.md` L7–10 names the `plugins/` and
  `.cursor/` mirrors (byte-identical today), but no check enforces parity;
  when they diverge, which copy is the surface the wiki documents?
