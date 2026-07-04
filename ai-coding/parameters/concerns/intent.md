# Intent

What the invocation is about. Every artifact declares at least one intent
parameter: an imperative goal (`task`), raw user text whose first job is to be
classified (`input`), or a subject artifact the verb operates on (`context`).
Other concerns (replication, selection, isolation, ...) presuppose the intent
is already pinned down.

## Cards

### `task`
- **Aliases:** —
- **Applies to:** skill, spawned agent
- **Type:** free-text imperative; required
- **Meaning:** The goal each spawned agent must complete end-to-end inside its
  own workspace, including verification.
- **Propagation:** broadcast verbatim to every member; `agent-swarm` relays the
  verbatim `{task}` into `worktree-task` for every member. See
  [propagation.md](../propagation.md).
- **Used by:** worktree-task (declared), agent-swarm (relayed, undeclared)

### `context`
- **Aliases:** `target` (designer, designer-controller), `domain` (ralph-design — loose alias: names the domain being modeled rather than an existing artifact)
- **Applies to:** command, skill
- **Type:** file path | directory path | URL | inline text | free-form description (see [addressing forms](io.md#addressing-forms))
- **Default:** required in all current uses
- **Meaning:** The subject artifact the invocation operates on, supplied as
  data; the verb lives in the command or skill itself (`critique` analyzes it,
  `designer` designs it).
- **Validation:** consumers record what was loaded and what was skipped or
  unreachable; critique surfaces unresolvable ambiguity in an Open Questions
  section instead of guessing.
- **Used by:** critique (`{context}`), designer (`{target}`), designer-controller (`target`), ralph-design (`{domain}`)

## Artifact-specific

- `{input}` (meta-prompt) — everything the user typed after `/meta-prompt`; raw
  text whose first job is classification into HELP / CREATE / REFINE mode.
  `key=value` tokens (`n=`, `k=`, `update-mode=`, `style(s)=`) and flags are
  parsed out of it and stripped before mode detection. Required (may be empty,
  which triggers HELP).
- `{worklist}` (address-worklist-commit-loop) — the work-item source: a
  markdown path, chat reference, MCP endpoint, or inline items. Required.
- `trait_name` (design-skill) — kebab-case identifier for the trait skill being
  authored; becomes the directory name (`<trait_name>-design/`) and the
  trait-map row. Validation: `^[a-z][a-z0-9-]*$`. Required.
- `description` (design-skill) — one-paragraph spec for the trait the new skill
  models. Required in `mode=propose`; collected during round 0 in
  `mode=walkthrough` when not pinned at invocation.
