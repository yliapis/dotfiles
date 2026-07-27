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
  | ticket-create | presents the validated task plan for approval before the first `backlog task create` (otherwise ambiguities go to Open Questions and the plan is not gated) |

- **Propagation:** meta-prompt passes the same flag setting to its spawned
  variant agents.
- **Used by:** critique, meta-prompt, wrap-up, save-session-state,
  soft-shutdown, prompt-template-library, ticket-create

### `approval_mode`
- **Aliases:** `mode` (ticket-execute, ticket-update, ralph-design,
  agent-swarm)
- **Applies to:** command, skill
- **Type:** ticket-execute:
  `interactive` | `non-interactive` | `force-approve-all`; ticket-update:
  `interactive` | `non-interactive`; agent-swarm:
  `default` | `preview` | `interactive` | `plan`; ralph-design uses its
  documented loop values.
- **Default:** `interactive`; agent-swarm instead resolves the value from the
  invocation context (the user asking to design the swarm gives `plan`, a user
  settling one that would dispatch this turn gives `interactive`, a request to
  see the shape gives `preview`) and falls back to `default`.
- **Meaning:** Approval cadence for a loop. Ticket execution approves the plan
  and each final task diff in `interactive`, the plan once in
  `non-interactive`, and nothing in `force-approve-all`. Ticket update presents
  one complete plan and requires approval in `interactive`. agent-swarm's
  values also decide whether
  the run draws its topology at all: `default` states the plan in text and
  dispatches, `preview` adds the diagram, `interactive` adds one go/no-go, and
  `plan` iterates on the design until the user verifies it or
  [`max_iterations`](constraints.md#max_iterations) halts the loop with
  `plan-cap-hit`. The rendering half of those values is documented on
  [`{preview_swarm_topology}`](reporting.md#agent-swarm).
- **Used by:** ticket-execute, ticket-update, ralph-design, agent-swarm

### `authoring_mode`
- **Aliases:** `mode` (design-skill, designer-controller)
- **Applies to:** skill
- **Type:** enum: `walkthrough` | `propose`
- **Default:** `walkthrough`
- **Meaning:** The authoring motion: `walkthrough` runs an interactive
  section-by-section loop (one round per section); `propose` generates the
  full draft in one shot from the spec.
- **Validation:** gates other knobs — `max_iterations` and `fan_out >= 2` are
  walkthrough-only; `precedence` and multi-trait composition are propose-only
  (designer-controller); `description` is required in propose (design-skill).
- **Used by:** design-skill, designer-controller

## Artifact-specific

- `{todo_source}` (soft-shutdown) — where the thread's TODO/task list is read
  from: `agent` (default — the calling agent's in-memory list) |
  `path:<file>` | `none`.

Note: save-session-state also declares a `{mode}`, but its values
(`write` | `preview`) make it a write gate, not an interaction knob — see
[lifecycle.md](lifecycle.md#write_gate-family).
