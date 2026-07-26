# Ticket Operations Engineering Loop

Date: 2026-07-26

## Baseline Analysis

The repository had no literal `ticket-operating` skill. Ticket work was split
between:

- `ticket-breakdown`, which rendered rich Markdown tickets and a thin
  `WORKLIST.md`;
- `/address-worklist-commit-loop`, which executed worklist entries and updated
  only checkbox state; and
- `/merge-commit-push`, `minimal-diffs`, and `conventional-commits`, which
  handled delivery concerns.

The old creation contract was deterministic and well guarded, but the execution
command ignored rich ticket files. No contract updated ticket metadata,
acceptance criteria, dependencies, or authoritative lifecycle state after
creation. Re-running creation produced another directory rather than
reconciling an existing set.

## Architecture Decision

`git-delivery` was renamed and expanded into one `ticket-operations` plugin.
Keeping the delivery primitives with the lifecycle skills avoids an undeclared
cross-plugin dependency while preserving their broader use.

| Skill | Owns | Explicitly does not own |
|---|---|---|
| `ticket-create` | deterministic source normalization, ticket rendering, set identity, initial worklist | implementation, lifecycle edits, trackers |
| `ticket-execute` | runnable selection, implementation, runtime evidence, lifecycle completion, one commit per ticket | definition edits, fan-out, remotes |
| `ticket-update` | explicit definition/lifecycle patches, projection repair, legacy completion proposals | implementation or acceptance execution |

Ticket frontmatter is authoritative. `WORKLIST.md` is a validated projection.
All three skills share schema version 1, stable `ticket_set` lineage,
definition fingerprints, compare-before-write revisions, one mutation lock,
and journaled recovery.

## Swarm Authoring Loop

The repository's `agent-swarm` policy was applied with:

- gate triggers `T3` (open design), `T4` (independent exploration), and `T6`
  (explicit fan-out);
- three members per skill;
- broadcast model assignment and full concurrency; and
- manual comparison plus synthesis.

| Skill | Candidate runs | Synthesis result |
|---|---:|---|
| `ticket-create` | 3 | ticket-file lifecycle authority, deterministic set reuse, atomic publication |
| `ticket-execute` | 3 plus one replacement for an isolation failure | tracked/local persistence, provisional claim transaction, evidence-bound single commits |
| `ticket-update` | 3 isolated worktrees | stable lineage, explicit patch schema, zero-revision projection repair, strict legacy import |

The first swarm runner placed two members in the calling checkout despite the
`worktree-task` isolation contract. Their candidate snapshots were preserved,
the collided member stopped without overwriting, and the missing execution
candidate was replaced in an explicitly created worktree. All three
`ticket-update` candidates ran in pre-created isolated worktrees.

## Behavioral Trial Matrix

Each finalized skill ran three end-to-end scenarios in isolated worktrees.
Skills are procedural Markdown, so the trials applied their contracts directly
and used independent parsers/hashers to validate persisted bytes.

| Skill | Trial | Result | Evidence |
|---|---|---|---|
| create | render two findings into native tickets | PASS | schemas, source refs, fingerprints, ticket count, projection, accounting |
| create | merge, split, filter, and account source items | PASS after two specification feedback loops | exact payloads, multi-ID outcomes, byte-identical reuse |
| create | reuse, collision rejection, and deterministic new-set path | PASS | unchanged hashes/mtimes, hash suffix, no numeric fallback |
| execute | successful local ticket implementation | PASS | one commit, fresh evidence, `open@1 -> done@3`, state-hash footers |
| execute | supplemental verifier failure | PASS | no commit, exact tree/index/ticket/worklist rollback to `open@1` |
| execute | dependency-ordered two-ticket execution and rerun | PASS | two linear commits, done projections, zero-work `already-done` rerun |
| update | definition edit with local audit commit | PASS | changed fingerprint, stable lineage, revision 2, hash-bound receipt/replay |
| update | dependency and evidence-gated lifecycle transitions | PASS after evidence-schema feedback | rejected premature claim, `TKT-001 done@3`, dependent claim allowed |
| update | inspect/discard/unsafe-import legacy marker drift | PASS after preflight feedback | read-only inspect, zero-revision repair, byte-identical rejection |

Representative execution commits produced only inside disposable trial
branches:

- successful single ticket: `d109137a687a3f92ca00431aaa8e4008075398f7`;
- dependency chain:
  `db8571965c1026b18160d176154e325153ae3968` then
  `a9ebb68b7c2fd538eb227ef29cf1c57345f07ece`;
- local update audit:
  `c8da026bfe2a7331133faab49248ce416f3a441e`.

## Feedback Defects Closed

| Finding from a trial | Contract correction |
|---|---|
| duplicate-then-split sources had no unique accounting outcome | `merged-into` now carries every ordered descendant ID |
| fingerprints named inputs but not exact serialized preimages | canonical JSON schemas, key names, encoding, and null/default values are explicit |
| severity, split refs, statement fields, and fallback prose could vary | inheritance, propagation, parsing, literal notes, and tokenization are exact |
| YAML, Markdown blocks, and worklist accounting could render differently | field order, scalar/list encoding, block formats, separators, escaping, and final LF are exact |
| execution set-key and claim-owner hashes lacked payload schemas | shared lock and owner JSON payloads are byte-specified |
| update evidence records lacked exact keys/indexing | one-based kind-specific evidence schemas reject unknown keys |
| managed `[x]` drift failed before legacy inspection | narrow marker proposals are classified before projection enforcement |
| Conventional Commits bundled a dead relative reference | link now targets the official versioned specification |

No exercised defect remains open.

## Structural Validation

Final automated checks:

```text
PASS json=12 plugins=5 skills=15 commands=9 mirrors=3 links=2
PASS ticket-operations manifests, schemas, lifecycle vocabulary, and supersession
PASS ticket parameter coverage links resolve
PASS live parameter cards contain no superseded ticket-breakdown references
```

Portable sync dry-runs passed for all six tool/type combinations:

- Cursor skills and commands: 15 / 9;
- Claude skills and commands: 15 / 9; and
- OpenCode skills and commands: 15 / 9.

The VM bootstrap did not install `zsh`, `rsync`, or `shellcheck` because package
metadata was rejected by the VM's clock, so the zsh/rsync-backed primary sync
preview was not available. The POSIX sync collision checker and project mirror
validation both passed without writes.

## Result

The merged plugin exposes one coherent local-ticket lifecycle, preserves the
minimal-diff and Conventional Commit delivery primitives, keeps the old slash
command as a fail-closed compatibility route, and removes the overlapping
`ticket-breakdown` activation surface.
