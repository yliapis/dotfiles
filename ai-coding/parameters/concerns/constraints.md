# Constraints

What counts as done, valid, or acceptable. Constraints make "the agent is
finished" observable: a test command exits `0`, a stop condition is satisfied,
a rubric is applied with evidence, an iteration cap halts a loop. This file
also defines the validation vocabulary the other concern files reference.

## Cards

### `test_command`
- **Aliases:** `verify_command` (ticket-execute and the
  address-worklist-commit-loop compatibility command)
- **Applies to:** command, skill → spawned agent
- **Type:** shell command; exit code `0` = pass, anything else = fail
- **Default:** unset (no programmatic gate)
- **Meaning:** A per-candidate verifier run inside the candidate's workspace
  after the agent reports done (worktree-task, agent-swarm) or after each
  ticket's implementation is staged but before completion/commit
  (ticket-execute, where failure invokes journal-guarded rollback and
  `{on_failure}`).
- **Validation:** agent-swarm requires it when any of `auto-best`, `vote`,
  `hybrid`, `tournament` is in `{selection_modes}`.
  ticket-execute exports `TICKET_*` and `WORKLIST_FILE` variables.
- **Propagation:** broadcast to every member; per-member exit codes bubble back
  into the report and gate merge eligibility. See
  [propagation.md](../propagation.md).
- **Used by:** worktree-task, agent-swarm, ticket-execute,
  address-worklist-commit-loop (relayed)

### `stop_condition`
- **Aliases:** —
- **Applies to:** skill → spawned agent (worktree-task); command (ralph-design)
- **Type:** two live shapes — free-text predicate (worktree-task) vs closed
  enum (ralph-design: `user-signals-done` | `all-steps-complete` |
  `validation-pass` | `max-rounds:<n>` with `<n>` a positive integer)
- **Default:** unset (worktree-task, falling back to "task implemented and
  verified"); `user-signals-done` (ralph-design)
- **Meaning:** An explicit completion condition beyond the implicit "done":
  per-member in worktree-task (gates merge eligibility), loop-exit in
  ralph-design.
- **Propagation:** broadcast per member (worktree-task).
- **Used by:** worktree-task, ralph-design

### `max_iterations`
- **Aliases:** —
- **Applies to:** command, skill
- **Type:** integer `>= 1`
- **Default:** 50 (ralph-design, designer-controller), 20 (design-skill)
- **Meaning:** Hard safety cap on total loop rounds, counting repeats via
  `refine` / `back`; hitting it halts with a terminal state (e.g.
  `iteration-cap-hit`) regardless of `stop_condition`.
- **Validation:** the two skills accept it only in `mode=walkthrough`;
  setting it explicitly with `mode=propose` is rejected.
- **Used by:** ralph-design, design-skill, designer-controller

## Artifact-specific

- `{criteria}` (critique) — the judgment rubric findings are evaluated
  against; file | directory | inline (see [addressing forms](io.md#addressing-forms)).
  Default: quality (clarity, correctness, completeness, robustness) +
  determinism (reproducibility, idempotency, stable outputs across runs).
  Every finding must name the specific criterion it relates to; the model must
  not substitute its own preferences. Expected to generalize to other
  analysis-style artifacts — see [future.md](../future.md).
- `{max_items}` (address-worklist-commit-loop compatibility command) — limits
  the native IDs routed to `ticket-execute`; `1` means `select=next`, larger
  values select that many IDs, and omission means `select=all`.
- `{min_severity}` (ticket-create) — lowest severity that still gets a
  ticket, over `critical > major > minor > nit`; items below the threshold
  are reported as `filtered`, never silently dropped, and severity-less
  (`unclassified`) items are always retained. Default: include all.

## Validation vocabulary

Conventions used across cards and artifacts:

- **Integer ranges** are written as `>= 1`, `>= 2`, or `1..{other_param}`;
  every artifact validates them before any side effect and aborts with an
  explanatory error and no filesystem changes on failure.
- **Enums** are closed value sets, listed per card or per artifact bullet.
- **List-length links:** a list-valued parameter's length must equal
  `candidate_count` (positional zip) or `partition_count` (per-partition
  broadcast). See [replication.md](replication.md) and
  [models.md](models.md#agent_model).
- **Divisibility:** `partition_count` must divide `candidate_count` evenly
  where both are set.
- **Flags** are bare tokens (`-i`, `--interactive-template`); supplying a flag
  in `key=value` form is rejected. `key=value` parameters embedded in free
  text (meta-prompt) are parsed and stripped before the remaining text is
  interpreted.
- **Conditional requirements** are stated as "required when ..." (e.g.
  `{commit_message}` required when `{merge_strategy}` is `--squash`;
  `{aggregator}` required when `synthesize` or `hybrid` is selected).
