# Critique: `ai-coding/parameters/` Parameter Wiki

**Run id:** `bc-019f5751-b041-7efd-83e4-6fb709c022d2`
**Model id:** `claude-opus-4-8-thinking-max-fast`
**Date (UTC):** 2026-07-12
**Target:** `ai-coding/parameters/` (the normative wiki: `README.md`, `coverage.md`,
`propagation.md`, `future.md`, `concerns/*.md`; provenance under `generated/` and
`trials/` reviewed but treated as explicitly non-normative).

**Criteria applied:** the repo's own default `/critique` rubric — **quality**
(clarity, correctness, completeness, robustness) and **determinism**
(reproducibility, idempotency, stability) — plus **maintainability** (drift
resistance), since a parameter reference's entire value proposition is that it
stays true to the artifacts it indexes.

**Method:** every claim below was checked against the live sources in
`ai-coding/commands/*.md` and `ai-coding/skills/*/SKILL.md`. All 19 artifacts (9
commands, 10 skills) were enumerated and cross-read against `coverage.md`, the
concern cards, the Quick Map, and `propagation.md`.

---

## Summary

This is a strong, unusually disciplined piece of documentation. The concern-first
split, the propagation vocabulary, and the strict separation of normative content
from the `generated/` provenance archive are all above the bar for internal
tooling docs, and spot-checking shows the cards are faithful to the artifacts on
defaults, enums, and types.

The wiki's central promise, however — stated in both `README.md` and
`coverage.md` — is **completeness**: a reference for *every* parameter declared by
*every* command and skill. That promise is broken. The `trajectory-snapshot`
skill and its three parameters are entirely absent from the index, so **18 of 19
artifacts are documented, not 19 of 19**. That single omission also propagates a
factual error into `future.md`, which makes the miss more than cosmetic. The root
cause is structural: correctness is hand-maintained across three overlapping
tables with no generation or lint, so drift is the expected steady state rather
than an accident.

Severity counts: **1 critical, 2 major, 5 minor, 3 nits.**
Biggest concern: the completeness contract is violated *and* unenforceable as
currently built.

---

## Strengths (what should not change)

- **High fidelity on documented artifacts.** Defaults, enum value sets, types,
  and alias attributions were verified accurate across the 18 documented
  artifacts — e.g. `ralph-design` `stop_condition` enum and `max_iterations=50`,
  `design-skill` `max_iterations=20`, `designer-controller` `persistence`
  defaulting to `chat` (the deliberate flip), `agent-swarm` `min_successes =
  ceil(n/2)`, `merge-commit-push` `commit_message` required-when-`--squash`. This
  is the hard part and it is done well.
- **The replication three-way split is genuinely useful.** Separating
  `candidate_count` (total), `concurrency` (cap), and `partition_count`
  (grouping) disentangles a real mess — seven artifacts that conflate count and
  concurrency behind overloaded spellings like `parallelism`. The card that flags
  `worktree-task`'s `parallelism` as "both count and concurrency" is exactly the
  kind of distinction a reader needs.
- **`propagation.md` is precise.** The resolution-mode vocabulary
  (broadcast / zip / partition / rewrite / orthogonal / bubble) and the worked
  `agent-swarm → worktree-task` dispatch table match the artifacts line for line,
  including the subtlety that the swarm feeds its concurrency cap into
  worktree-task's `parallelism` and owns the total via `num_agents`.
- **Disciplined provenance.** `generated/` (eight candidate ontologies) and
  `trials/AGGREGATE.md` are clearly marked non-normative, and `future.md` cleanly
  separates live surface from aspiration. The "card only when ≥2 artifacts use
  it" rule is a sound editorial policy.
- **Link and anchor hygiene is good.** No broken intra-wiki anchors were found in
  the `coverage.md` link set, and the fail-fast validation convention documented
  in `README.md` matches every artifact that declares validation.

---

## Findings

### Critical

- **completeness** @ `coverage.md` (whole file; `## Skills`, lines 136–220) and
  `README.md` (lines 3–5) — **The `trajectory-snapshot` skill is undocumented,
  breaking the wiki's stated completeness contract.**
  - Evidence: `README.md` promises a "reference for **every** parameter declared
    by the AI-coding commands … and skills"; `coverage.md` opens "Per-artifact
    index: **every** declared parameter." Yet `skills/trajectory-snapshot/SKILL.md`
    declares three parameters under its `## Parameters` heading —
    `{filename_format}`, `{granularity}`, `{coding_tool}` (SKILL.md lines 13–20) —
    and the skill appears **nowhere** in `coverage.md`: not in the five
    parameterized-skill sections, and not in the "No parameter surface" list
    (lines 211–220), which names only conventional-commits, minimal-diffs,
    declarative-design, and deterministic-design.
  - Rationale: the filesystem has 10 skills
    (`agent-swarm`, `conventional-commits`, `declarative-design`,
    `designer-controller`, `design-skill`, `deterministic-design`,
    `minimal-diffs`, `prompt-template-library`, `trajectory-snapshot`,
    `worktree-task`); `coverage.md` accounts for 9. For a document whose sole job
    is to be an exhaustive index, silently omitting a whole artifact is a
    correctness failure, not a gap — a reader cannot tell "not documented yet"
    from "no such parameters." It is especially glaring because the omitted skill
    is the explicit sibling of `save-session-state` (its SKILL.md says so), and
    `save-session-state` *is* documented in full.
  - Recommendation: add a `trajectory-snapshot` row-set to `coverage.md` and place
    its three parameters. `{filename_format}` is an output-path concept adjacent
    to [`artifact_path`](concerns/io.md#artifact_path) but introduces a **new
    addressing form the io card does not cover** — a path *template* with
    `{coding_tool}` / `{datetime_timestamp}` token substitution. `{granularity}`
    is a closed enum (`verbatim | condensed | summary | native`) with no home in
    the current concern set (see M1). Its `-2`/`-3` collision suffix is also a
    third distinct "suffix" semantics next to `worktree_name`'s `-<i>` and
    meta-prompt's `-<i>`, and deserves a note.

### Major

- **correctness / completeness** @ `future.md` (lines 35–39) — **The
  `trajectory-snapshot` omission propagates a false claim about report-shape
  knobs.**
  - Evidence: `future.md` lists reporting as aspirational — "Reporting (no live
    concern file yet): `verbosity`, `require_diff`, `include_terminal_log`,
    `output_format` — report-shape knobs; **today every artifact fixes its Output
    Format section instead of parameterizing it**." But `trajectory-snapshot`'s
    `{granularity}` (SKILL.md lines 15–19) is exactly a live, shipping
    output-shape parameter: it selects verbatim vs condensed vs summary vs native
    rendering of the same content.
  - Rationale: the completeness miss is not contained to `coverage.md`; it caused
    a second document to assert something demonstrably untrue. This is the
    concrete cost of the gap and why it rises above "just add a row."
  - Recommendation: correct the `future.md` sentence, and consider whether
    `granularity` seeds a real (small) reporting/output-shape concern now that a
    live example exists.

- **maintainability / determinism** @ whole wiki (`README.md` Quick Map lines
  58–82; every `concerns/*.md` card's `Used by:` line; `coverage.md` tables) —
  **The same facts are hand-maintained in three places with no generator or lint,
  so drift is the default.**
  - Evidence: each cross-artifact fact (aliases, "Used by" artifact lists) is
    restated in the Quick Map, again in the card, and again per-artifact in
    `coverage.md`. `future.md` itself names the fix — "move card fields … into
    YAML frontmatter or a registry file and generate the Quick Map and
    coverage.md from it, so the indexes cannot drift from the cards" (lines
    62–65) — but files it under aspiration.
  - Rationale: the critical finding above is proof the risk is *realized*, not
    hypothetical: three overlapping sources of truth diverged the moment a 10th
    skill landed. The document's whole value is accuracy, and accuracy is
    currently defended only by manual diligence.
  - Recommendation: promote the "structured card source + generated indexes"
    follow-up from `future.md` to actual work. Even a lightweight check script
    that (a) enumerates `commands/*.md` and `skills/*/SKILL.md`, (b) asserts each
    appears in `coverage.md`, and (c) diffs card `Used by` lists against
    `coverage.md` would have caught this and prevents recurrence.

### Minor

- **correctness (internal consistency)** @ `concerns/constraints.md` (lines
  78–79) vs `concerns/replication.md` (line 47) — **The divisibility rule is
  stated globally but enforced by only two of three partition-using artifacts.**
  - Evidence: `constraints.md` "Validation vocabulary" states flatly:
    "Divisibility: `partition_count` must divide `candidate_count` evenly where
    both are set." But the `partition_count` card scopes it: "must divide
    `candidate_count` evenly (agent-swarm, address-worklist-commit-loop)."
    `worktree-task` sets both (`parallelism` default `1`, `num_partitions`
    default = parallelism) yet imposes **no** divisibility check — SKILL.md line
    22 requires only `>= 1` plus the iterable-`agent_model` slice rule.
  - Rationale: a reader taking the "Validation vocabulary" section as the
    authority would believe worktree-task rejects indivisible partitions; it does
    not. The two normative statements disagree on scope.
  - Recommendation: qualify the constraints.md line ("where the artifact requires
    it — agent-swarm, address-worklist-commit-loop") to match the card.

- **correctness (alias attribution)** @ `concerns/replication.md` (line 29,
  `concurrency` card) — **`parallel` is a two-artifact alias but attributed to
  only one.**
  - Evidence: the card lists "Aliases: `k` (meta-prompt), `parallel` (critique),
    `parallel_agents` / `p` (agent-swarm)." But `agent-swarm/SKILL.md` line 18
    declares "`{parallel_agents}` (aliases: `{p}`, `{parallel}`)" — so `parallel`
    is also an agent-swarm spelling for the concurrency cap.
  - Rationale: alias resolution is a primary use case the README calls out
    ("Resolving a name you found in an artifact"); an incomplete attribution sends
    a reader who found `parallel` in agent-swarm to the wrong (or an ambiguous)
    place.
  - Recommendation: attribute `parallel` to both critique and agent-swarm.

- **consistency (template adherence)** @ `README.md` card template (lines 39–51)
  vs several cards — **Cards diverge from their own mandated template.**
  - Evidence: the template mandates `Type` and `Default` lines, but the
    `write_gate (family)` card (`concerns/lifecycle.md` lines 10–29) has neither
    (nor `Propagation`); `remote`, `delete_worktree`, `traits`, `trait_map`, and
    `max_iterations` omit `Validation` and/or `Propagation`.
  - Rationale: `write_gate` legitimately can't carry one `Type`/`Default` (it is a
    family of four different enums), which means the *template itself* has no
    provision for family cards — a small schema gap rather than sloppiness, but it
    reads as inconsistency.
  - Recommendation: either mark `Type`/`Default`/`Propagation` optional in the
    Conventions, or add an explicit "family card" template variant.

- **clarity (undefined notation)** @ `concerns/constraints.md` (line 12),
  `concerns/models.md` (line 13), `concerns/constraints.md` (line 31) — **The
  `→ spawned agent` arrow in "Applies to" is used but never defined.**
  - Evidence: cards write "Applies to: command, skill → spawned agent," yet the
    Conventions/template only enumerate the flat set "`command` | `skill` |
    `spawned agent`" (README lines 31–34, 46). The arrow (meaning "declared here,
    takes effect on the spawned member") is left to inference.
  - Recommendation: one sentence in Conventions defining `X → spawned agent`.

- **completeness (value sets)** @ `concerns/lifecycle.md` (lines 75–77) and
  `concerns/interaction.md` (lines 26–27) — **Two cards under-document an
  invocable value / precondition.**
  - Evidence: `save_trajectory` is documented only by its default resolution, but
    `wrap-up.md` accepts an explicit `true` (lines 21, 34, 62). The
    `save-session-state` row for `-i` omits that the overwrite-confirmation
    behavior applies only when `{mode}` is `write` (`save-session-state.md` lines
    12, 16, 21); in `preview` mode the flag has no documented effect.
  - Rationale: these are omissions, not wrong values, but they weaken the "every
    parameter fully specified" standard the rest of the wiki meets.
  - Recommendation: add the explicit `true` value and the `mode=write` guard.

### Nit

- **correctness (self-consistent count)** @ `concerns/replication.md` (lines
  4–5) — "seven artifacts spell the same three concepts **eleven** different
  ways." The trio's own cards enumerate **twelve** distinct alias spellings:
  count = `n`, `num`, `num_agents`, `num_experiments`, `parallelism`, `fan_out`,
  `fanout_default_n` (7); concurrency = `k`, `parallel`, `parallel_agents`, `p`
  (4); partition = `num_partitions` (1). "Eleven" equals count+concurrency (7+4)
  only if `num_partitions` is excluded. Either bump to twelve or scope the claim.

- **clarity (structure)** @ `concerns/selection.md`, `concerns/robustness.md` —
  by the "card only when ≥2 artifacts" rule, two of the eleven concern files
  contain zero cards. That is internally consistent, but it means the
  concern-first framing is partly aspirational: two "concerns" are really
  single-artifact appendices. Worth a one-line note so the empty-of-cards files
  don't read as unfinished.

- **maintainability (aspirational vocabulary)** @ `README.md` (lines 28–30) —
  several canonical names (`candidate_count`, `concurrency`, `write_gate`,
  `approval_mode`, `authoring_mode`) appear in **no** artifact; a reader grepping
  the codebase for them finds only the wiki. This is deliberate ("canonical name
  ≠ rename mandate"), but it is a real second-vocabulary cost whose payoff (the
  rename-adoption pass) is deferred to `future.md`. Consider tagging each card's
  canonical name as `coined` vs `in-use` so readers know which names exist in
  code today.

---

## Prioritized recommendations

1. **Document `trajectory-snapshot`** in `coverage.md` and place its three
   parameters (resolves the Critical finding). Decide the home for
   `{granularity}` and the "templated path" form of `{filename_format}`.
2. **Correct the `future.md` reporting claim** (M1) — it is falsified by the
   parameter added in step 1.
3. **Add a completeness/consistency check** (M2): enumerate artifacts, assert each
   is in `coverage.md`, and diff `Used by` lists against it. This is the durable
   fix; steps 1–2 are the one-time cleanup.
4. **Reconcile the divisibility statement** (m1) and **fix the `parallel` alias
   attribution** (m2) — both are small, high-confidence edits.
5. Tidy template adherence, the undefined `→` arrow, and the two value-set gaps
   (m3–m5) as a batch.

## Open questions

- Is `trajectory-snapshot` an *intentional* exclusion (e.g. considered a
  session-hygiene utility rather than a "parameterized" artifact), or genuine
  drift? Nothing in the wiki states an exclusion, and its `## Parameters` section
  makes it in-scope by the wiki's own definition — but confirming intent changes
  whether the fix is "add it" or "state the exclusion rule explicitly."
- Should report-shape become a real concern file now that `granularity` is a live
  example, or stay in `future.md` until a second artifact parameterizes output?
- The `trials/AGGREGATE.md` adoption plan recommends a `wiki/` atlas with
  `recipes/` and `traces/` directories that were not built; is the current
  lighter concern-first layout the accepted final shape, or an interim step? The
  provenance implies more was planned than shipped.
