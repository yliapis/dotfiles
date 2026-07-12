# `interactive` — opt-in to clarifying questions and confirmations

Boolean flag opting the run into clarifying questions and confirmations.
When absent, the run asks nothing: it proceeds with inferable inputs,
surfaces ambiguities in the report instead of asking, or aborts naming the
missing slot. Spelled `-i` / `--interactive` in most artifacts,
`--interactive-template` in prompt-template-library.

- **Used by:** critique, meta-prompt, wrap-up, save-session-state, soft-shutdown, prompt-template-library
- **Full entry:** [concerns/interaction.md](../concerns/interaction.md#interactive)
