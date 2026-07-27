# Interaction

When the user is asked something. Three distinct concepts share the overloaded
spellings `-i` and `mode`: the **interactive flag** (may the run ask clarifying
questions at all), the **approval mode** (how often a loop pauses for
sign-off), and the **authoring mode** (one-shot draft vs stepwise
walkthrough).

## Cards

### `interactive`
- **Aliases:** `-i` / `--interactive` (critique, meta-prompt, wrap-up,
  save-session-state, soft-shutdown, ticket-create),
  `--interactive-template` (prompt-template-library)
- **Applies to:** command, skill
- **Type:** boolean flag; bare token, no value (`key=value` form rejected
  where validated)
- **Default:** absent (non-interactive)
- **Meaning:** Opt-in to clarifying questions and confirmations. When absent,
  the run asks nothing: it proceeds with inferable inputs, surfaces
  ambiguities in the report instead of asking, or aborts naming the missing
  slot. Per artifact:

  | Artifact | With the flag |
  |---|---|
  | critique | asks about ambiguous `{context}` / `{criteria}` before running (otherwise ambiguities go to Open Questions) |
  | meta-prompt | asks about ambiguous inputs, missing critical slots, the `{worktree}` choice; enables `confirm` mode's y/n |
  | wrap-up | prompts for rollup decisions, ambiguous categorization, deletion, trajectory save; flips `{rollup}` / `{save_trajectory}` defaults |
  | save-session-state | asks before overwriting an existing `{output_path}` (otherwise an existing target aborts) |
  | soft-shutdown | asks about ambiguous session scope (otherwise unresolved scope is recorded as a blocker) |
  | prompt-template-library | presents the template catalog and lets the user pick, instead of auto-selecting by score |
  | ticket-create | presents the validated ticket plan for approval before atomic publication (otherwise ambiguities go to Open Questions and the plan is not gated) |

- **Propagation:** meta-prompt passes the same flag setting to its spawned
  variant agents.
- **Used by:** critique, meta-prompt, wrap-up, save-session-state,
  soft-shutdown, prompt-template-library, ticket-create

### `approval_mode`
- **Aliases:** `mode` (ticket-execute, ticket-update,
  address-worklist-commit-loop compatibility command, agent-swarm),
  `approval` (designer)
- **Applies to:** command, skill
- **Type:** ticket-execute, the compatibility command, and designer:
  `interactive` | `non-interactive` | `force-approve-all`; ticket-update:
  `interactive` | `non-interactive`; agent-swarm:
  `default` | `preview` | `interactive` | `plan`.
- **Default:** `interactive`; agent-swarm instead resolves the value from the
  invocation context (the user asking to design the swarm gives `plan`, a user
  settling one that would dispatch this turn gives `interactive`, a request to
  see the shape gives `preview`) and falls back to `default`.
- **Meaning:** Approval cadence for a loop. Ticket execution approves the plan
  and each final ticket diff in `interactive`, the plan once in
  `non-interactive`, and nothing in `force-approve-all`. Ticket update binds
  interactive approval to a plan digest; non-interactive mutation requires
  that digest through `{approve}`. agent-swarm's values also decide whether
  the run draws its topology at all: `default` states the plan in text and
  dispatches, `preview` adds the diagram, `interactive` adds one go/no-go, and
  `plan` iterates on the design until the user verifies it or
  [`max_iterations`](constraints.md#max_iterations) halts the loop with
  `plan-cap-hit`. The rendering half of those values is documented on
  [`{preview_swarm_topology}`](reporting.md#agent-swarm). designer's
  `approval` governs its `mode=walkthrough` rounds: `interactive` offers
  `accept` / `refine` / `fork` / `back` / `done` every round, `non-interactive`
  approves the plan once and auto-accepts each round, `force-approve-all` skips
  the plan approval too.
- **Validation:** designer rejects `approval` outside `mode=walkthrough`, and
  pairs it with [`stop_condition`](constraints.md#stop_condition) — the
  `user-signals-done` default requires `interactive`, and the two unattended
  cadences each require an explicit stop condition other than it.
- **Used by:** ticket-execute, ticket-update,
  address-worklist-commit-loop (relayed), designer, agent-swarm; reached
  through the `/ralph-design` preset, which presets it to `interactive`

### `authoring_mode`
- **Aliases:** `mode` (design-skill, designer)
- **Applies to:** skill
- **Type:** enum: `walkthrough` | `propose`
- **Default:** `walkthrough`
- **Meaning:** The authoring motion: `walkthrough` runs an interactive
  section-by-section loop (one round per section); `propose` generates the
  full draft in one shot from the spec.
- **Validation:** gates other knobs — `max_iterations`, `approval`,
  `stop_condition`, and `fan_out >= 2` are walkthrough-only; `precedence` and
  multi-trait composition are propose-only (designer); `description` is
  required in propose (design-skill).
- **Used by:** design-skill, designer. The `/designer` and `/ralph-design`
  presets each pin one value and do not expose it.

## Artifact-specific

- `{todo_source}` (soft-shutdown) — where the thread's TODO/task list is read
  from: `agent` (default — the calling agent's in-memory list) |
  `path:<file>` | `none`.

Note: save-session-state also declares a `{mode}`, but its values
(`write` | `preview`) make it a write gate, not an interaction knob — see
[lifecycle.md](lifecycle.md#write_gate-family).
