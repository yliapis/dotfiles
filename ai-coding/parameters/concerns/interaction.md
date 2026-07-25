# Interaction

When the user is asked something. Three distinct concepts share the overloaded
spellings `-i` and `mode`: the **interactive flag** (may the run ask clarifying
questions at all), the **approval mode** (how often a loop pauses for
sign-off), and the **authoring mode** (one-shot draft vs stepwise
walkthrough).

## Cards

### `interactive`
- **Aliases:** `-i` / `--interactive` (critique, meta-prompt, wrap-up, save-session-state, soft-shutdown, ticket-breakdown), `--interactive-template` (prompt-template-library)
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
  | ticket-breakdown | asks about ambiguous `{analysis}` content and presents the ticket plan for approval before rendering or writing (otherwise ambiguities go to Open Questions and the plan is not gated) |

- **Propagation:** meta-prompt passes the same flag setting to its spawned
  variant agents.
- **Used by:** critique, meta-prompt, wrap-up, save-session-state, soft-shutdown, prompt-template-library, ticket-breakdown

### `approval_mode`
- **Aliases:** `mode` (address-worklist-commit-loop, ralph-design)
- **Applies to:** command
- **Type:** enum: `interactive` | `non-interactive` | `force-approve-all`
- **Default:** required (address-worklist-commit-loop); `interactive`
  (ralph-design)
- **Meaning:** Approval cadence for a loop: `interactive` approves the plan
  and each step/commit; `non-interactive` approves the plan once, then runs
  silently; `force-approve-all` accepts every default with no approvals.
- **Validation:** address-worklist-commit-loop's `{on_failure}` default
  depends on it (`abort` when interactive, `retry-once-then-skip` otherwise).
- **Used by:** address-worklist-commit-loop, ralph-design

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
