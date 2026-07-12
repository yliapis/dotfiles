# Parameter Wiki — Task List

Merged and deduplicated findings from four independent critiques of this
section, each reviewing revision `9560abb` on 2026-07-12. The critique files
were removed after consolidation; they are preserved in git history as
provenance:

| Label | Model | Added in commit |
|---|---|---|
| C1 | `gpt-5.6-sol-medium` | `bdc343e` |
| C2 | `claude-opus-4-8-thinking-max-fast` | `4d02766` |
| C3 | `claude-fable-5-thinking-max` (run `...503e...`) | `5a4cd80` |
| C4 | `claude-fable-5-thinking-max` (run `...ce4e...`) | `0e54e88` |

Each task notes which critiques flagged it; a higher consensus count is a
confidence signal. Evidence pointers cite files/lines as of `9560abb`.

## P0 — Correctness of the live contract (unanimous findings)

### 1. Fix the `agent-swarm` → `worktree-task` dispatch contract

Flagged by: C1, C2 (partially — treated as matching the artifacts), C3, C4.

When `num_agents > parallel_agents`, the documented single dispatch cannot be
executed:

- `agent-swarm/SKILL.md:17-18` defines `{num_agents}` as the total and
  `{parallel_agents}` as a concurrency cap in `1..num_agents`.
- The only dispatch instruction (`agent-swarm/SKILL.md:173`) invokes
  `worktree-task` with `{parallelism} = {parallel_agents}`.
- `worktree-task/SKILL.md:21,27` defines `{parallelism}` as both the number of
  worktrees created and the number run concurrently, and `SKILL.md:20`
  requires a list-valued `{agent_model}` to have length exactly
  `{parallelism}`.

With `num_agents=8, parallel_agents=4`, only four worktrees are created and a
per-agent model list of length 8 fails the child skill's fail-fast validation.
No artifact defines a queue, wave, or repeated-dispatch step for the
remainder. The wiki transcribes both halves of the contradiction without
flagging it (`propagation.md:54-56`, `concerns/replication.md:37-40`,
`concerns/models.md:34-38`).

Resolution — fix the artifacts first, then the wiki:

1. Either add a separate concurrency parameter to `worktree-task`, keep
   `parallelism` as total count, and dispatch
   `parallelism=num_agents, concurrency=parallel_agents`; or
2. Have `agent-swarm` dispatch explicit waves of at most `parallel_agents`,
   slicing model assignments and maintaining globally stable member indexes.

Then update `propagation.md`, `concerns/replication.md`, and
`concerns/models.md` to state the resolved contract, including the receiving
side's `len(agent_model) == parallelism` check. Add contract tests for `n=p`,
`n>p`, per-agent models, and per-partition models. Adopt a wiki norm of
flagging cross-artifact contradictions (a "Seams" / "Known mismatches"
subsection) instead of transcribing both sides.

### 2. Add `trajectory-snapshot` to the wiki

Flagged by: C1, C2, C3, C4.

`skills/trajectory-snapshot/SKILL.md:13-20` declares `{filename_format}`,
`{granularity}`, and `{coding_tool}`, yet the skill appears nowhere in the
wiki — not in `coverage.md` (which accounts for only 9 of 10 skills, see
`coverage.md:211-220`), not in any concern file, not in the Quick Map. This
falsifies the "reference for every parameter declared" claim in
`README.md:3-6` and `coverage.md:3-5`. The wiki landed 2026-07-03
(`e258beb`); the skill landed 2026-07-07 (`f8d0a74`, `149f7ee`) without a
wiki touch.

Work items:

- Add a `trajectory-snapshot` row-set to `coverage.md`.
- Place `{filename_format}` in `concerns/io.md` beside the `artifact_path`
  family; note it introduces a new addressing form the io card does not
  cover — a path *template* with `{coding_tool}` / `{datetime_timestamp}`
  token substitution.
- Note its `-2`/`-3` collision auto-suffix as a third distinct suffix
  semantics (vs `worktree_name`'s `-<i>` and meta-prompt's `-<i>`), and a
  third overwrite posture alongside save-session-state's abort/confirm and
  design-skill's `force` (`concerns/lifecycle.md`).
- Place `{granularity}` (closed enum `verbatim | condensed | summary |
  native`) and `{coding_tool}` in appropriate concerns.
- Document the security-relevant distinction: rendered snapshots redact
  secrets while `native` mode intentionally preserves sensitive transcript
  bytes (`trajectory-snapshot/SKILL.md:19,30-31,38-39`). See also task 9.
- Fix the now-false claim in `future.md:35-39` that "today every artifact
  fixes its Output Format section instead of parameterizing it" —
  `{granularity}` is a live, shipping output-shape parameter. Decide whether
  a reporting/output-shape concern is warranted now that a live example
  exists.
- Until a coverage check exists (task 3), soften "every" to "intended to
  cover every."

## P1 — Drift prevention and factual card fixes

### 3. Add a drift/census check; move toward structured card data

Flagged by: C1, C2, C3, C4.

The artifact↔parameter↔card relation is hand-encoded in up to seven places
(Quick Map rows, card Aliases/Used-by fields, `coverage.md` tables,
`propagation.md` rows) with no generator, schema, or lint. The
trajectory-snapshot omission proves the failure mode: the one
post-publication change to the documented surface missed all copies at once.
`trials/AGGREGATE.md:187-193` predicted exactly this risk and
`future.md:62-65` deferred the fix.

Work items, in order:

- Minimum viable check: a script (hosted in `scripts/` with a `make` target)
  that enumerates `commands/*.md` + `skills/*/SKILL.md`, extracts declared
  parameters, and diffs them against `coverage.md` rows — failing on any
  missing artifact, missing parameter, or phantom row.
- Extend the check to: registry artifact paths exist, live links resolve
  (archival links labeled separately), alias resolution includes artifact
  context, cross-parameter references resolve, card `Used by` lists match
  `coverage.md`.
- Longer term: put stable IDs, aliases with artifact context, type, default,
  status, and `used_by` in machine-readable frontmatter or a registry file;
  generate the Quick Map and `coverage.md` from it. Keep meaning, gotchas,
  and rationale in prose beside the structured fields.

### 4. Fix specific card errors (small, high-confidence edits)

- **`partition_count` misattribution** (C3): `concerns/replication.md:49-51`
  says the parameter is used in address-worklist-commit-loop "for
  distributing work items"; the artifact
  (`commands/address-worklist-commit-loop.md:15`) defines `{num_partitions}`
  as model-assignment partitions — work items are distributed by
  `{partition_strategy}`. The card contradicts its own adjacent bullet.
- **`parallel` alias attribution** (C2): `concerns/replication.md:29` lists
  `parallel` only for critique; `agent-swarm/SKILL.md:18` also declares it as
  an alias of `{parallel_agents}`. Attribute to both.
- **Divisibility rule overstated** (C2): `concerns/constraints.md:78-79`
  states globally that `partition_count` must divide `candidate_count`;
  worktree-task sets both but imposes no divisibility check
  (`worktree-task/SKILL.md:22`). Scope the rule to agent-swarm and
  address-worklist-commit-loop, matching the card
  (`concerns/replication.md:47`).
- **`worktree_name` suffix rule** (C3, C4): `propagation.md:37` and
  `concerns/isolation.md:34-36` state the `-<i>` suffix unconditionally;
  `worktree-task/SKILL.md:16` appends it only when `parallelism > 1`. Also,
  meta-prompt's declared `{worktree}` is only relevant when `n=1`
  (`meta-prompt.md:19`); its fan-out worktrees are named from the H1
  kebab-name, not the declared parameter.
- **"Eleven spellings" headline count** (C2, C4):
  `concerns/replication.md:4-5` claims eleven spellings; the cards' own
  enumeration yields twelve. Bump the number or state the counting rule.
- **Fork-edge scope errors** (C3): `propagation.md:36` says `base_branch` is
  "broadcast — every member forks from it", but ralph-design's fork
  dispatches members from the iterator's *current* branch
  (`ralph-design.md:69`). The `merge_mode` card
  (`concerns/lifecycle.md:42-45`) says only agent-swarm sets it, but
  ralph-design pins `merge_mode = interactive` too. The `task` card's
  Used-by (`concerns/intent.md:20-21`) omits ralph-design and
  designer-controller, which synthesize a `task` at dispatch. (Consider a
  `Set by` vs `Declared by` field split — see task 11.)
- **`{input}` self-contradiction** (C4): `concerns/intent.md:40-41` says
  "Required (may be empty, which triggers HELP)". Rephrase: always present;
  empty input selects HELP mode.
- **Under-documented values/preconditions** (C2): `save_trajectory` accepts
  an explicit `true` (`wrap-up.md:21,34,62`) that the card
  (`concerns/lifecycle.md:75-77`) omits; save-session-state's `-i`
  overwrite-confirmation applies only when `{mode}` is `write`
  (`save-session-state.md:12,16,21`), which
  `concerns/interaction.md:26-27` omits.
- **Missing mode/stop-condition coupling** (C1): ralph-design requires
  `stop_condition=user-signals-done` only with `mode=interactive`
  (`commands/ralph-design.md:11-16,32`). Record the bidirectional constraint
  in both `concerns/constraints.md:29-41` and the `approval_mode` card in
  `concerns/interaction.md:35-46`.
- **Flag, don't silently normalize, two inherited contradictions** (C3):
  (a) `concerns/constraints.md:20-21` vs `concerns/selection.md:25` mirror
  conflicting artifact lines on whether `vote` requires `test_command` or
  accepts "comparable signature" (`agent-swarm/SKILL.md:22` vs `:118`) —
  pick one reading, fix the artifact line and both concern files;
  (b) `future.md:21-22` claims worktree-task hardcodes manual-pick, but
  `merge_mode=auto` implements an auto-best-like rule
  (`worktree-task/SKILL.md:32`, correctly noted in
  `concerns/selection.md:5-7`).

### 5. Complete the propagation dispatch graph

Flagged by: C3.

The live graph has four spawn edges plus one composition edge; only
agent-swarm → worktree-task is documented in full, with meta-prompt partial.
Add one table per edge, in the agent-swarm example's format:

- ralph-design → worktree-task (`fork`, `commands/ralph-design.md:39,69`)
- designer-controller → worktree-task (`fan_out`,
  `skills/designer-controller/SKILL.md:117`)
- meta-prompt → variant agents
- prompt-template-library → meta-prompt (composition,
  `skills/prompt-template-library/SKILL.md:142-144`)

Fix the `base_branch` and `merge_mode` rows/cards to account for the fork
edge (see task 4).

### 6. Wire inbound links and document the sync policy

Flagged by: C1, C3.

Zero inbound references point at the wiki: no command, skill, template,
plugin manifest, repo README, Makefile, or AGENTS.md mentions
`ai-coding/parameters/`, and the sync script installs only commands, skills,
and rules (`scripts/sync:122-125,182-237`). Yet `README.md:11-13` addresses
artifact authors, and three authoring flows (`/meta-prompt`, `design-skill`,
`prompt-template-library`) would bind on the instruction.

Work items: link the wiki from the repo README and the authoring flows (one
line each); state explicitly whether `parameters/` is intentionally excluded
from sync. A sync feature is optional; discoverability is not.

## P2 — Structure, conventions, and hygiene

### 7. Template and conventions

Flagged by: C1, C2, C3, C4 (overlapping subsets).

- Add a family-card template variant: `write_gate`
  (`concerns/lifecycle.md:10-29`) legitimately has no single Type/Default —
  it spans a five-state policy, a two-state persistence location, a dry-run
  boolean, and a write/preview mode. Distinguish semantic *families* from
  atomic parameter cards; generators and rename tools must operate on atomic
  cards. `artifact_path` has the same issue at smaller scale
  (`concerns/io.md:24-36`).
- Mark Type/Default/Validation/Propagation optional in the Conventions, or
  make the cards conform (`remote`, `delete_worktree`, `traits`,
  `trait_map`, `max_iterations`, `task`, `context` all omit mandated
  fields).
- Define the `X → spawned agent` arrow notation used in "Applies to" lines
  (`concerns/constraints.md:12`, `concerns/models.md:13`) — it is not one of
  the three documented values (`README.md:31-34`).
- Tag each card's canonical name `coined` vs `in-use`: several canonical
  names (`candidate_count`, `concurrency`, `write_gate`, `approval_mode`,
  `authoring_mode`) appear in no artifact.
- Allow single-artifact atomic cards with a status field (e.g. `live` /
  `proposed-general`) so `selection.md` and `robustness.md` are not cardless
  appendices; "used by two artifacts" is a Quick Map threshold, not a
  threshold for stable identity. At minimum add a one-line note so the
  card-free files don't read as unfinished.

### 8. Generated-archive hygiene

Flagged by: C1, C3, C4.

- Merge the two competing entry docs: `generated/INDEX.md` covers the eight
  ontology directories, `generated/README.md` only the four older sample
  directories; neither mentions the other. One entry doc should own the
  whole archive. Also fix the root `README.md:17-18` claim of "eight
  candidate ontologies" vs 12 actual subdirectories.
- Add a frozen-provenance banner to every generated entry page: snapshot
  revision/date, renamed artifacts (the archive pervasively references a
  removed `worktree-task-agent` command and retired `trajectory.md`), a
  warning that internal links predate the layout and do not resolve, and a
  link back to the normative wiki.
- Note the semantic conflicts with the normative wiki (e.g. generated docs
  treat `k` as a count alias — `generated/tree/0-root.md:152`,
  `generated/stage-modular/stage-replicate.md:13` — while
  `concerns/replication.md:28-35` correctly maps meta-prompt's `k` to
  concurrency).
- Have the link checker (task 3) classify expected archival breakage
  separately from live-reference failures.
- Nit: `generated/INDEX.md:3` attributes the archive to `/best-of-n (n=8)`,
  a command that exists nowhere in the repo — the stated provenance is not
  reconstructible.

### 9. Add a thin security/data-handling cross-cutting index

Flagged by: C1.

The concern taxonomy has no security or data-handling route; security-relevant
behavior appears only where an artifact happens to mention it (clearest
example: trajectory-snapshot's rendered-redaction vs `native` no-redaction
split, task 2). Add a thin cross-cutting index — not a full ontology — for
parameters that execute commands, fetch URLs, accept paths, overwrite files,
expose transcripts, or alter redaction, each row linking to the owning atomic
card and live source.

### 10. Close io vocabulary gaps

Flagged by: C3, C4.

- `concerns/io.md:3-6,8-20` claims the addressing-form vocabulary
  (file | directory | url | inline) covers `worklist`, but `{worklist}`'s
  live forms include a chat reference and an MCP endpoint
  (`address-worklist-commit-loop.md:7-12`), and the `context` card adds
  "free-form description" (`concerns/intent.md:25`) — neither expressible in
  the vocabulary. Add `chat-ref` / `mcp` / `description` forms or scope the
  claim.
- The `context` card's union type masks per-artifact accepted subsets:
  critique's `{context}` accepts no free-form description
  (`commands/critique.md:7`), designer's `target` accepts no URL
  (`commands/designer.md:10`), ralph-design's `{domain}` is free-form only
  (`commands/ralph-design.md:9`). Record per-artifact subsets on the card.
- Nit (C3): `{todo_source}` (soft-shutdown) is filed under interaction
  (`concerns/interaction.md:63-65`) but selects an input source — an
  io/intent concern by the wiki's own responsibility table.

### 11. Record open design decisions

Flagged by: C2, C3, C4.

Preserve the decisions a future maintainer will look for, in a short
decision-record note:

- Why the live shape is concern-first-plus-facets rather than the
  atlas/cards/indexes/recipes/traces layout the trials aggregate recommended
  (`trials/AGGREGATE.md:23-58`) — currently undocumented divergence.
- Whether cards should track synthesizers as well as declarers (`Set by` vs
  `Declared by`), so the dispatch graph is visible from the card side.
- Mirror authority: `coverage.md:7-10` names the `plugins/` and `.cursor/`
  mirrors (byte-identical today), but nothing states whether the
  completeness claim extends to them or which copy wins on divergence.
- Card lifecycle: the two-or-more-artifacts threshold has no demotion rule
  when an artifact is removed or renames a parameter.
- Rename adoption: the canonical layer currently *adds* a twelfth spelling
  on top of eleven live ones; `future.md`'s alias-status taxonomy and
  "replication trio first" adoption pass need a trigger condition.
- Primary reader: humans or agents? If agents load concern files as context
  when authoring artifacts, file-size and self-containment budgets should be
  explicit, and inbound links (task 6) become mandatory.
- Whether provenance metadata (snapshot revision, generation date, status,
  adopted/rejected recommendations) should be added as a concise provenance
  map rather than embedded per-card.
