# Critique: `ai-coding/parameters/` (the parameter wiki)

- **Run id:** `bc-019f5750-503e-7d95-af86-87ace72378be`
- **Model id:** `claude-fable-5-thinking-max`
- **Date:** 2026-07-12 (UTC)
- **Base commit:** `9560abb` (`main`)
- **Context:** the entire `ai-coding/parameters/` section — 4 root pages + 11 concern
  files (15 files, 1,142 lines, the "live wiki"), the `generated/` archive
  (85 files, ~17,400 lines), and `trials/AGGREGATE.md` (197 lines).
- **Criteria applied:** the repo's own default `/critique` rubric — quality
  (clarity, correctness, completeness, robustness) and determinism
  (reproducibility, idempotency, stability) — plus fitness-for-purpose against
  the wiki's stated goals in `README.md`.
- **Method:** every live wiki file was read in full and cross-checked
  line-by-line against all 9 commands in `ai-coding/commands/` and all 10
  skills in `ai-coding/skills/` (the sources `coverage.md` says it tracks).
  The `generated/` archive was sampled (both entry docs, the concern-first
  candidate in full). Mirror sync (`plugins/`, `.cursor/`) was verified with
  `diff -rq`. Inbound references were checked with repo-wide search. Findings
  cite `file:line` as of the base commit.

## Summary

The live wiki is a genuinely good compression: 15 files distill eight
generated ontologies (~17k lines) into ~1,100 lines of mostly accurate,
honestly hedged, well-anchored reference material, and the
concern-first + live-surface-only architecture follows the trials consensus.
Most card facts — defaults, types, enum values, validation gates, the
replication trio split, the write-gate table — check out exactly against the
artifacts. But the wiki fails its own two headline promises in ways that
matter: its completeness claim ("every parameter declared") was already false
four days after it landed (the `trajectory-snapshot` skill and its three
parameters are absent from every wiki page), and its role as the
cross-artifact coherence layer goes unfulfilled at the one seam where it is
most needed (the documented `agent-swarm` → `worktree-task` dispatch violates
`worktree-task`'s own validation contract whenever the swarm's concurrency
cap differs from its size — transcribed, not caught). Add zero inbound links
from the artifacts it documents and a triple-redundant hand-maintained
mapping (Quick Map, cards, coverage) with no drift check, and the wiki's
main risk is structural: it is a snapshot posing as a reference, with no
mechanism keeping it true.

Finding counts: 2 critical, 4 major, 7 minor, 5 nits.

## Findings

### Critical

- **Completeness** @ `coverage.md` (whole file), `README.md:3-7`
  - Evidence: `README.md` promises a "reference for every parameter declared
    by the AI-coding commands ... and skills" and `coverage.md:211-220`
    closes with "Four skills declare no parameters". The live tree has ten
    skills; `skills/trajectory-snapshot/SKILL.md:13-20` declares three
    parameters (`{filename_format}`, `{granularity}`, `{coding_tool}`) and
    appears nowhere in the wiki — not in `coverage.md`, not in any concern
    file, not in the Quick Map. Git history: the wiki landed 2026-07-03
    (`e258beb`); the skill landed 2026-07-07 (`f8d0a74`, `149f7ee`) without a
    wiki touch.
  - Rationale: the wiki's core claim was falsified within four days of
    publication, by the very next artifact authored. Beyond the missing
    index rows, real concern content is lost: `{filename_format}` is a
    template-bearing kin of the `artifact_path` card (`concerns/io.md`), and
    the skill's collision policy (auto-suffix `-2`, `-3` — SKILL.md:26) is a
    third overwrite posture alongside save-session-state's abort/confirm and
    design-skill's `force`, which `concerns/lifecycle.md` should be
    contrasting. This is precisely the drift failure `future.md:60-65`
    ("structured card source ... so the indexes cannot drift") predicts —
    the mitigation was known at authoring time and deferred with nothing
    (not even a census checklist) in its place.

- **Correctness / robustness** @ `propagation.md:54-55` vs
  `skills/worktree-task/SKILL.md:20-27`
  - Evidence: `propagation.md` documents the live dispatch as
    `{parallelism} = {parallel_agents}` with `model_mix: per-agent` resolving
    to "list of length `{num_agents}`" (same in
    `concerns/models.md:34-38` and `agent-swarm/SKILL.md:173`). But
    `worktree-task/SKILL.md:21` defines `{parallelism}` as the *total* agent
    count, `SKILL.md:27` requires "Exactly `{parallelism}` isolated worktrees
    are created", and `SKILL.md:20` requires a list-valued `{agent_model}`
    to have "length MUST equal `{parallelism}`".
  - Rationale: for any swarm where `parallel_agents < num_agents` (the whole
    point of having two knobs — e.g. `num_agents=8, parallel_agents=4`), the
    documented single dispatch is impossible: worktree-task would create 4
    worktrees, not 8, and a per-agent model list of length 8 fails
    worktree-task's own fail-fast validation against `parallelism=4`.
    Nothing anywhere specifies wave-based dispatch. The root defect lives in
    the artifacts, but the wiki is the designated cross-artifact coherence
    layer — `propagation.md` even walks this exact seam as its only worked
    example and transcribes both halves of the contradiction without
    noticing. A reference whose flagship example cannot execute as written
    undermines trust in every other propagation row.

### Major

- **Correctness** @ `concerns/replication.md:49-51` (self-contradiction 10
  lines later at :59-62)
  - Evidence: the `partition_count` card says the parameter is used "in
    address-worklist-commit-loop, for distributing work items". The artifact
    (`commands/address-worklist-commit-loop.md:15`) defines
    `{num_partitions}` as "number of **model-assignment** partitions over the
    `{parallelism}` worktrees"; work items are distributed by
    `{partition_strategy}` across `{parallelism}` slices (`:19-22`). The
    card's own Artifact-specific bullet gets it right: "Distinct from
    `partition_count`, which groups *agents* for model assignment; this
    groups *work items*."
  - Rationale: a canonical card states the opposite of both the artifact and
    the adjacent bullet in the same file. Anyone using the card to wire
    partitioning in a new artifact inherits the error.

- **Completeness** @ `propagation.md` (whole file)
  - Evidence: the live dispatch graph has four spawn edges plus one
    composition edge: agent-swarm→worktree-task, ralph-design→worktree-task
    (`commands/ralph-design.md:39,69` — `fork`), designer-controller→
    worktree-task (`skills/designer-controller/SKILL.md:117` — `fan_out`),
    meta-prompt→variant agents, and prompt-template-library→meta-prompt
    (`skills/prompt-template-library/SKILL.md:142-144`). `propagation.md`
    documents one edge in full (agent-swarm) and one partially (meta-prompt
    rows in the Live-rules table). Consequent inaccuracies in what *is*
    written: the `base_branch` row (`propagation.md:36`) says "broadcast —
    every member forks from it", but ralph-design's fork dispatches members
    from "the iterator's **current** branch" (ralph-design.md:69), i.e. a
    rewrite of scope, not a broadcast of the invocation's `{base_branch}`;
    the `merge_mode` card (`concerns/lifecycle.md:42-45`) says only
    agent-swarm sets it, but ralph-design pins `merge_mode = interactive`
    too (ralph-design.md:69); the `task` card's Used-by
    (`concerns/intent.md:20-21`) omits ralph-design and designer-controller,
    both of which synthesize a `task` at dispatch.
  - Rationale: propagation is the wiki's highest-value, hardest-to-recover
    content (it lives in no single artifact), and ~60% of the live graph is
    missing; two of the documented scope rules are contradicted by the
    undocumented edges.

- **Fitness for purpose (discoverability)** @ repo-wide
  - Evidence: zero inbound references. No command, skill, template, plugin
    manifest, repo README, Makefile, or AGENTS.md mentions
    `ai-coding/parameters/` (verified by repo-wide search; the only external
    match is an archived diff under `ai-coding/samples/`). Meanwhile
    `README.md:11-13` addresses artifact authors ("reuse the canonical names
    ... instead of inventing new spellings"), and the repo has three
    authoring flows where that instruction would bind — `/meta-prompt`,
    `design-skill`, `prompt-template-library` — none of which point at the
    wiki.
  - Rationale: a naming-convention reference only works if the moment of
    naming can find it. As wired, adoption depends on the author already
    knowing the wiki exists; the trajectory-snapshot episode shows what
    happens when they don't (or don't look).

- **Robustness / idempotency of maintenance** @ `README.md:53-81`,
  `coverage.md`, `concerns/*.md`
  - Evidence: the artifact↔parameter↔card relation is hand-encoded three
    times — Quick Map rows (aliases + used-by), card fields (Aliases +
    Used by), and coverage.md tables (121 parameter rows across 14
    artifacts) — with no generation or consistency check. Adding one
    artifact touches at minimum three files; renaming an alias touches all
    three plus propagation.md. `trials/AGGREGATE.md:189-193` names exactly
    this risk ("Derived indexes can diverge if edited as source") and
    `future.md:60-65` defers the fix.
  - Rationale: today the three copies agree (verified) — but only because
    the wiki has never been updated. The one post-publication change to the
    documented surface (trajectory-snapshot) missed all three copies at
    once, which is the failure mode this structure guarantees under drift.
    A ~50-line script diffing declared `{parameters}` in artifacts against
    coverage.md rows would catch it; the repo already has `scripts/` and a
    Makefile to host it.

### Minor

- **Correctness (inherited inconsistency)** @ `concerns/constraints.md:20-21`
  vs `concerns/selection.md:25`
  - Evidence: constraints.md says agent-swarm requires `test_command` "when
    any of `auto-best`, `vote`, `hybrid`, `tournament` is in
    `{selection_modes}`"; selection.md's mode table says `vote` requires
    "`test_command` **or comparable signature**". Both faithfully mirror
    different lines of the artifact itself (`agent-swarm/SKILL.md:22` vs
    `:118`).
  - Rationale: the wiki reproduces an artifact's internal contradiction into
    two concern files without flagging it. Surfacing seams like this is the
    wiki's comparative advantage; silently normalizing both variants wastes
    it.

- **Internal consistency** @ `future.md:21-22` vs `concerns/selection.md:5-7`
  - Evidence: future.md motivates a `selection_mode` parameter by claiming
    "worktree-task and meta-prompt currently hardcode manual-pick and
    no-pick respectively"; selection.md correctly notes worktree-task's
    pick-a-winner step is governed by `merge_mode`, which has an `auto`
    value implementing an auto-best-like rule
    (`worktree-task/SKILL.md:32`).
  - Rationale: two wiki pages disagree about the same artifact; the
    future-work rationale overstates the gap.

- **Clarity / vocabulary coverage** @ `concerns/io.md:3-6, 8-20`
  - Evidence: io.md claims the addressing-form vocabulary
    (file | directory | url | inline) covers `worklist`, with artifacts
    declaring "subsets". `{worklist}`'s live forms include a chat reference
    and an MCP endpoint (`address-worklist-commit-loop.md:7-12`;
    `concerns/intent.md:42-43`), neither expressible in the vocabulary — so
    its form set is not a subset. The `context` card similarly adds
    "free-form description" (`intent.md:25`) outside the vocabulary.
  - Rationale: the shared vocabulary undersells the live surface it claims
    to standardize; either add `chat-ref` / `mcp` / `description` forms or
    scope the claim.

- **Correctness (overgeneralized rule)** @ `concerns/isolation.md:34-36`,
  `propagation.md:37`
  - Evidence: the `worktree_name` card says "When fanning out, a 1-based
    index suffix is appended per member" and propagation says "rewrite:
    member *i* gets the `-<i>` suffix", with meta-prompt listed as a user.
    meta-prompt's declared `{worktree}` is explicitly "only relevant when
    ... `{n}` is `1`" (`meta-prompt.md:19`); its fan-out worktrees are named
    from the H1 kebab-name instead (`meta-prompt.md:102`).
  - Rationale: for one of the four listed users, the propagation rule
    applies to an internal naming scheme, not the declared parameter —
    exactly the kind of distinction a parameter wiki exists to keep sharp.

- **Clarity (archive navigation)** @ `generated/INDEX.md` vs
  `generated/README.md`
  - Evidence: two competing entry documents describe disjoint subsets of
    `generated/`: INDEX.md covers the eight ontology directories;
    README.md covers only the four older single-file sample directories
    (`param-ontology/`, `param-stages/`, `parameters/`, `params/`). Neither
    mentions the other's content.
  - Rationale: a reader entering via the conventional README.md never
    learns the eight main candidates exist; a reader via INDEX.md can't
    place the four stray directories. One entry doc should own the whole
    archive.

- **Completeness (concern layer unevenness)** @ `concerns/selection.md:9-10`,
  `concerns/robustness.md:6-7`, `concerns/models.md:3-7`
  - Evidence: the two-artifact card threshold (`README.md:24-27`) leaves
    selection and robustness with zero cards — pure per-artifact
    restatements — while models.md's header prose elevates `model` (vs
    `agent_model`) to a headline concept that then lives only in an
    Artifact-specific bullet.
  - Rationale: the threshold optimizes for spelling collisions, but some
    single-artifact parameters (`criteria`, `selection_modes`) are central
    concepts the wiki itself expects to generalize (`future.md:19-27`). A
    status field (`live` / `proposed-general`) on single-artifact entries —
    as trials/AGGREGATE.md's card template suggests — would serve better
    than cardlessness.

- **Vocabulary self-consistency** @ `propagation.md:39` vs `:13-27`
  - Evidence: the resolution-mode vocabulary defines six modes (broadcast,
    zip, partition, rewrite, orthogonal, bubble); the `candidate_count` row
    uses "orthogonal, **always reset to 1**" — reset is not a defined mode,
    and forced-to-constant is not independence.
  - Rationale: the no-recursion rule is important enough to deserve its own
    mode name (`reset`) rather than stretching `orthogonal`.

### Nit

- `generated/concern/README.md:52,70,85` (and ~90 sibling occurrences across
  the archive) link to `../plugins/ai-coding/commands/...` — which resolves
  to the nonexistent `parameters/generated/plugins/...` — and reference
  retired artifacts (`worktree-task-agent.md`, `trajectory.md`). Frozen
  provenance may keep stale content, but INDEX.md should warn that archive
  links do not resolve (trials/AGGREGATE.md:192 flagged this exact risk).
- `generated/INDEX.md:3` attributes the archive to `/best-of-n (n=8)` — a
  command that exists nowhere in the repo, so the stated provenance is not
  reconstructible from the repo itself.
- The `write_gate` family card (`concerns/lifecycle.md:10-29`) omits the
  Type and Default fields the card template (`README.md:39-51`) declares
  required; family cards deserve an explicit template variant rather than a
  silent deviation.
- `{todo_source}` (soft-shutdown) is filed under interaction
  (`concerns/interaction.md:63-65`); it selects an input source, which is an
  io/intent concern by the wiki's own responsibility table.
- Volume framing: 84% of the section's files (85 of 101) and 93% of its
  lines (~17.4k of ~18.8k) are archive. The demotion notes in README.md are good; a one-line
  "everything under generated/ and trials/ is frozen — edit only concerns/
  and the root pages" guard in each archive entry doc would make the
  live/frozen boundary mechanical.

## Strengths

Recorded so the findings above read in proportion.

- **The architecture is right.** Concern-first cards for the live surface,
  aspirations quarantined in `future.md`, design history demoted to
  provenance — this matches the trials consensus and avoids both the "ninth
  ontology" and "aspirational parameters presented as real" failure modes
  the aggregate warned about.
- **Card accuracy is high where it was checkable.** Defaults, types, enums,
  validation gates, and cross-parameter rules were verified against all 14
  covered artifacts; apart from the findings above they match exactly —
  including fiddly details like designer-controller's `persistence` default
  flipping to `chat`, ralph-design's `max-rounds:<n>` vs `max_iterations`
  distinction, and the full meta-prompt `update_mode` behavior table.
- **The replication concern earns its keep.** The count / concurrency /
  partition split is the wiki's best analytical contribution: it correctly
  untangles worktree-task's conflated `parallelism` and explains the
  agent-swarm workaround rather than papering over it (the remaining seam
  defect notwithstanding).
- **Honest hedging.** "Loose alias" on `domain`, the save-session-state
  `mode` disambiguation note, selection.md admitting it has no cards, and
  the "canonical name ≠ rename mandate" stance are the right calls, made
  explicitly.
- **Navigation mechanics work.** Every coverage.md anchor and cross-file
  link in the live wiki resolves (checked against GitHub slug rules); the
  spelled-as-written index answers the "what is this parameter I found"
  query in one hop.
- **The propagation vocabulary is reusable.** broadcast / zip / partition /
  rewrite / orthogonal / bubble is a compact abstraction that future
  artifacts can cite; the agent-swarm worked example is the right *shape*
  for documenting every other edge.

## Recommendations

In priority order; the first three are correctness, the rest structure.

1. **Restore completeness and add a census gate.** Add trajectory-snapshot
   to coverage.md and the io/lifecycle concern files, then add a
   `make`-target script that extracts declared parameters from
   `commands/*.md` + `skills/*/SKILL.md` and diffs them against coverage.md
   rows, failing on any mismatch. This converts the wiki's central promise
   from an assertion into an invariant.
2. **Resolve the swarm dispatch seam — in the artifacts, then the wiki.**
   Either worktree-task grows a real concurrency knob (count vs concurrency
   split, per the wiki's own replication cards) or agent-swarm documents
   wave-based dispatch with per-wave model-list slicing. Whichever way it
   lands, propagation.md should state the contract check
   (`len(agent_model) == parallelism` at the receiving side) and the wiki
   should adopt a norm of *flagging* cross-artifact contradictions it finds
   (a "Seams" or "Known mismatches" subsection) instead of transcribing
   both sides.
3. **Fix the replication.md partition claim** (one line) and the vote-mode
   requirement inconsistency (pick one reading, fix the artifact line and
   both concern files, and note the correction).
4. **Document the full dispatch graph.** One table per edge in
   propagation.md, in the agent-swarm example's format: ralph-design fork,
   designer-controller fan_out, meta-prompt variants, and the
   prompt-template-library → meta-prompt composition seam. Fix the
   `base_branch` and `merge_mode` rows/cards to account for the fork edge.
5. **Wire inbound links.** meta-prompt's parameter-drafting step,
   design-skill's TEMPLATE, agent-swarm/worktree-task's parameter sections,
   and the repo README should each point at the wiki (one line each). The
   wiki is only as canonical as its inbound degree.
6. **Move card facts into structured source next, not eventually.** The
   future.md plan (YAML frontmatter per card; generate Quick Map +
   coverage.md) eliminates two of the three hand-maintained copies. Until
   then the census gate from (1) is the minimum viable drift control.
7. **Merge the two `generated/` entry docs** (INDEX.md absorbs the sample
   table) and stamp both archives with a frozen-provenance banner noting
   that internal links predate the layout and do not resolve.

## Open Questions

- **Who is the primary reader — humans or agents?** The trials aggregate
  designed for both ("AI traversal contract"); the live wiki dropped the
  routing layer. If agents are expected to load concern files as context
  when authoring artifacts, file size and per-file self-containment budgets
  should be explicit (and inbound links from the authoring flows become
  mandatory, not nice-to-have).
- **Should `Used by` track synthesizers?** ralph-design and
  designer-controller construct `task` values and pin `merge_mode` at
  dispatch without declaring those parameters. The cards currently track
  declarers only, which makes the dispatch graph invisible from the card
  side. A second field (`Set by` vs `Declared by`) would resolve the
  ambiguity found in the `task` and `merge_mode` cards.
- **Is the mirror set part of the contract?** coverage.md:7-10 notes the
  `plugins/` and `.cursor/` mirrors and tracks only the `ai-coding/`
  sources. The mirrors are in sync today, but nothing states whether the
  wiki's completeness claim extends to them or what happens when they
  diverge.
- **When does rename adoption start?** The wiki adds canonical names on top
  of eleven live spellings for the replication trio without retiring any —
  net vocabulary grew. future.md's alias-status taxonomy and the
  "replication trio first" adoption pass have no trigger condition; absent
  one, the canonical layer risks remaining a twelfth spelling indefinitely.
