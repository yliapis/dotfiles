---
name: design-skill
description: "Manually-invoked meta-skill that authors a new designer trait card against design-skill/TEMPLATE.md. Use when the user explicitly asks to author a new design trait, scaffold a new trait card for the designer skill, add a design flavor alongside declarative and deterministic, or run a design-skill walkthrough. Manually invoked only — do not auto-apply on bare 'create a skill' phrasings or unrelated authoring tasks."
license: MIT
---

# Design Skill

Author a new trait card that conforms to [./TEMPLATE.md](./TEMPLATE.md). Two motions: `mode=walkthrough` walks the user through TEMPLATE.md section-by-section (drafting each section's body, prompting for review, advancing); `mode=propose` takes a trait name and a one-paragraph spec and generates a complete first draft in one shot. Both motions consume TEMPLATE.md at invocation time as the canonical contract; the meta-skill never inlines, paraphrases, or summarizes TEMPLATE.md's body into its own prompt or output.

The deliverable is the new trait card itself — a plain markdown file under the `designer` skill's `traits/` directory, not a standalone skill. By default, the meta-skill writes it to `ai-coding/plugins/design-suite/skills/designer/traits/<trait_name>.md` inside a dedicated worktree; opt out with `persistence=chat` for a draft-only run.

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly invokes one of:

- `design-skill mode=... trait_name=... description="..."` (inline-token form).
- "author a new `<trait>` design trait"
- "scaffold a new trait card for the designer skill"
- "add a design flavor alongside declarative and deterministic"
- "run design-skill walkthrough" / "run design-skill propose"

Do not auto-apply on bare "create a skill" phrasings or unrelated authoring tasks. The cost of authoring a new trait is real (it adds a new row to the controller's trait map; future composition will load it); apply only when the user has explicitly asked to scaffold one.

## Invocation Contract

Same parsing rules as [../designer/SKILL.md](../designer/SKILL.md):

- Inline `key=value` tokens win over natural-language back-references.
- Lists bracketed and comma-separated; strings with whitespace double-quoted; booleans `true`/`false`; integers bare digits.
- Unknown keys abort with `unknown knob: <key>; available knobs: <list>`.

## Knob Inventory

**Required:**

- `trait_name` — kebab-case identifier; becomes the card filename (`<trait_name>.md`) and the trait-map row name. Validation: matches `^[a-z][a-z0-9-]*$`.
- `description` — one-paragraph spec for the trait the new skill models. Required in `mode=propose`. In `mode=walkthrough`, collected during the framing step (round 0) if not pinned at invocation.

**Composition:**

- `mode` — `walkthrough` | `propose`. Default `walkthrough`. `walkthrough` runs an interactive section-by-section authoring loop against TEMPLATE.md (one round per section); `propose` generates the full draft in one shot from `description`.
- `force` — boolean. Default `false`. When `false`, abort if `<artifact_path>` already exists. When `true`, overwrite.

**Persistence:**

- `persistence` — `chat` | `codebase`. Default `codebase` (the artifact IS the deliverable).
- `artifact_path` — repo-relative path. Default `ai-coding/plugins/design-suite/skills/designer/traits/<trait_name>.md`. Required when `persistence=codebase`; rejected when `persistence=chat`. The default targets the plugin source, never a generated mirror under `.cursor/`, `.claude/`, `.opencode/`, or `.agents/`; a card written into a mirror is overwritten or pruned on the next `make mirrors`.
- `use_worktree` — boolean. Default `true` when `persistence=codebase`; MUST be `false` when `persistence=chat`. When `true`, the disk write happens inside a dedicated worktree forked from the current branch; the calling working tree is never touched.

**Safety:**

- `max_iterations` — integer `>= 1`. Default `20`. Meaningful only in `mode=walkthrough`. Hard cap on total rounds (one per TEMPLATE.md section, plus refines).

**Knob applicability rejections** (any of these abort with an explanatory error before any work begins):

- `description` unset with `mode=propose`.
- `force=true` with `persistence=chat` (no file to overwrite).
- `artifact_path` or `use_worktree=true` with `persistence=chat`.
- `max_iterations` set explicitly with `mode=propose`.

## Workflow

1. **Parse and validate.** Extract knobs; apply defaults; run every applicability check from `## Knob Inventory` and `## Validation Rules`. Abort fast on validation failure with zero filesystem side effects.
2. **Resolve TEMPLATE.md.** `Read` [./TEMPLATE.md](./TEMPLATE.md) in full. Identify its section headers and section order; these become the round structure for `mode=walkthrough` and the slot list for `mode=propose`. If TEMPLATE.md cannot be read, abort with `cannot read design-skill/TEMPLATE.md: <path>`.
3. **Pre-flight artifact path.** When `persistence=codebase`, check whether `<artifact_path>` already exists. If yes and `force=false`, abort with `<artifact_path> already exists; pass force=true to overwrite, or pick a different trait_name`. If no, continue.
4. **Set up persistence.** When `persistence=codebase` and `use_worktree=true`, run `git worktree add` to create a new worktree forked from the current branch and route every subsequent disk write into it. When `persistence=codebase` and `use_worktree=false`, write directly into the calling working tree (caller has accepted the risk). When `persistence=chat`, hold draft state in memory only.
5. **Dispatch on `mode`:**
   - **`propose`**: from `trait_name` and `description`, generate every section of TEMPLATE.md in a single pass. Replace placeholders with concrete content; remove the template's `<!-- TEMPLATE FILE -->` HTML comment and every italic *guidance note*. Emit the assembled draft.
   - **`walkthrough`**: walk TEMPLATE.md's sections in declared order. For each section:
     1. Read the section's placeholder structure and italic guidance from TEMPLATE.md.
     2. Draft the section's body (anchored on `trait_name`, `description`, and content drafted in earlier sections).
     3. Present the draft and the running working-document state; prompt the user to review.
     4. On `accept`: apply, advance.
     5. On `refine`: take the user's feedback, redraft, re-prompt (round counter still increments per attempt).
     6. On `back`: rewind to the named earlier section's last accepted draft; re-enter the loop at the section after.
     7. On `done`: exit the loop with the current document.
     8. Evaluate `max_iterations`; halt with terminal state `iteration-cap-hit` if reached.
6. **Write the deliverable.** When `persistence=codebase`, write the assembled card verbatim to `<artifact_path>` (overwriting only when `force=true`) inside the worktree (when `use_worktree=true`). The HTML template comment and italic guidance notes are stripped before writing.
7. **Emit the report** per `## Output Format`. Do not merge the worktree branch; do not delete the worktree. Do not edit the controller's trait map (the user adds the row themselves once the new skill is reviewed).

## Output Format

A single markdown report with these sections, in order. Omit any section whose body would be empty.

### Run Summary

- `Mode`: `walkthrough` or `propose`.
- `Trait name`: resolved `trait_name`.
- `Knobs`: every resolved knob name and value.
- `Persistence`: `chat`, or `codebase` plus the resolved `artifact_path`.
- `Worktree`: branch name and absolute path, or `n/a` when `use_worktree=false` or `persistence=chat`.
- `Counts`: rounds run / accepted / refined / backs (only in `mode=walkthrough`).

### Iteration Log

Present this section only in `mode=walkthrough`. A bullet list with one entry per round, in execution order: round index, section name, choice (`accept` / `refine` / `back` / `done`), and a one-line summary of what landed.

### Final Draft

The assembled `traits/<trait_name>.md` content, rendered inline as a fenced code block. The reader can copy-paste this verbatim into the canonical path even when `persistence=chat`.

### Persistence Result

Present this section only when `persistence=codebase`.

- `Wrote artifact to`: absolute path inside the worktree (or in the calling tree when `use_worktree=false`).
- `Worktree path`: absolute path, or `n/a` when `use_worktree=false`.
- `Branch`: branch name, or `n/a`.
- `Diff`: a fenced ` ```diff ` block containing `git diff <base>..HEAD`.

### Next Steps

A short bullet list reminding the user of the steps NOT done by this skill:

- Add a row to [../designer/SKILL.md](../designer/SKILL.md)'s `## Trait Map` pairing `<trait_name>` with `./traits/<trait_name>.md`.
- Review and merge the worktree branch.
- Run `make mirrors` so the new card reaches the project mirrors.

## Guardrails

- MUST require explicit invocation (a phrase from `## When to Invoke`); MUST NOT auto-apply on bare "create a skill" phrasings or unrelated authoring tasks.
- MUST `Read` [./TEMPLATE.md](./TEMPLATE.md) at invocation time and use it as the canonical contract for the new skill's structure; MUST NOT inline, hard-code, summarize, or paraphrase TEMPLATE.md's body into this skill or the emitted draft.
- MUST strip the template's `<!-- TEMPLATE FILE -->` HTML comment and every italic *guidance note* from the emitted draft before writing or rendering.
- MUST refuse to overwrite an existing `<artifact_path>` unless `force=true`.
- MUST keep every disk write inside the worktree when `use_worktree=true`; MUST NOT touch the calling working tree's working directory or index.
- MUST NOT modify any other file: not the controller's trait map, not other trait cards, not TEMPLATE.md itself. The new card is one new file; everything else is the user's call.
- MUST NOT push, open PRs, merge branches, delete worktrees, create tags, or rebase pre-existing branches.
- MUST validate every knob before any read, write, or worktree creation; abort fast on validation failure with zero filesystem side effects.
- Scope: produce one new `traits/<trait_name>.md` card against TEMPLATE.md. Out of scope: editing the controller, editing TEMPLATE.md, editing other trait cards, registering the new trait in the controller's map, applying the new trait, or invoking `design-skill` recursively.

## Worked Examples

### Example 1: Interactive walkthrough, codebase persistence

```
design-skill mode=walkthrough trait_name=secure description="Audit a target for security regressions and propose minimal patches that close them" persistence=codebase
```

Resolved knobs: `mode=walkthrough`, `trait_name=secure`, `description="Audit a target for ..."`, `persistence=codebase`, `artifact_path=ai-coding/plugins/design-suite/skills/designer/traits/secure.md`, `use_worktree=true`, `force=false`, `max_iterations=20`.

Behavior: the meta-skill reads TEMPLATE.md, creates a worktree forked from the current branch, walks the TEMPLATE.md sections in declared order, prompts the user at each section, and writes the final assembled card to `ai-coding/plugins/design-suite/skills/designer/traits/secure.md` inside the worktree. Round 0 collects the framing paragraph; rounds 1..N draft each subsequent section. The calling working tree is never touched.

### Example 2: One-shot propose, chat persistence (preview)

```
design-skill mode=propose trait_name=accessible description="Audit a UI target for accessibility regressions (WCAG AA), enumerate violations with severity, and propose minimal changes that bring it back into compliance" persistence=chat
```

Resolved knobs: `mode=propose`, `trait_name=accessible`, `description="Audit a UI target for ..."`, `persistence=chat`, `use_worktree=false`, `force=false`.

Behavior: the meta-skill reads TEMPLATE.md, generates a full draft of `traits/accessible.md` in one shot from `description` and the template's section structure, and emits the complete draft inline in `## Final Draft`. No filesystem writes; no worktree. Used for previewing what the meta-skill would produce before committing to a `persistence=codebase` run.

## When Not To Use

- **Bare "create a skill" phrasings.** This skill is manually invoked. If the user has not used a phrase from `## When to Invoke`, point them at the right artifact (a new trait card, a hook, a rule, a regular skill) instead of inferring intent.
- **Editing an existing trait card.** This skill scaffolds NEW cards. To change an existing trait, edit its card directly; this skill MUST refuse to overwrite without `force=true`.
- **Authoring a standalone skill.** TEMPLATE.md is specific to the design-trait family (When to Invoke → Walkthrough → Worked Example → Deliverable → Validation & Verification → When Not To Use → Principles), and its output is a card the `designer` skill loads, not a skill a client discovers on its own. For a standalone skill, see the `create-skill` skill or write `SKILL.md` from scratch.
- **Registering a new trait in the controller.** This skill produces the new card only; adding the row to the controller's `## Trait Map` is the user's call. Out of scope on purpose so the card can be reviewed before it goes live.
- **Recursive scaffolding.** This skill MUST NOT invoke itself.

## Validation Rules

A valid `design-skill` invocation MUST satisfy every rule below.

- **Required knobs present.** `trait_name` is set; `description` is set in `mode=propose`.
- **Trait name shape.** `trait_name` matches `^[a-z][a-z0-9-]*$` (kebab-case, lowercase, no leading digit, no underscores).
- **Mode-description compatibility.** `description` is required in `mode=propose`; optional in `mode=walkthrough` (collected at round 0 if not pinned).
- **Mode-max_iterations compatibility.** `max_iterations` is set only when `mode=walkthrough`.
- **Persistence-path compatibility.** `artifact_path` is set if and only if `persistence=codebase`. `use_worktree=true` requires `persistence=codebase`. `force=true` requires `persistence=codebase`.
- **Artifact path repo-relative.** `artifact_path` is repo-relative under `ai-coding/plugins/design-suite/skills/designer/traits/`; generated mirrors (`.cursor/`, `.claude/`, `.opencode/`, `.agents/`), `~/`, `$HOME`, absolute paths outside the repo, and machine-specific home directories are rejected before any read or write.
- **No clobber without force.** When `persistence=codebase` and `<artifact_path>` already exists, abort unless `force=true`.
- **Template available.** [./TEMPLATE.md](./TEMPLATE.md) is readable from the canonical path before any draft is generated.
- **No unknown knobs.** Every `key=...` token's key is in the knob inventory.

## Design-Skill Principles

Frame every meta-skill decision around these. Each is a "do this, not that" choice, not an abstract value.

- **TEMPLATE.md is read, not transcribed.** The meta-skill `Read`s TEMPLATE.md at invocation and uses it as the structural contract; it never copies TEMPLATE.md's body verbatim into its own prompt or its emitted draft.
- **One file per invocation.** The meta-skill produces exactly one new `traits/<trait_name>.md`. The controller's trait map, other trait cards, and TEMPLATE.md are out of scope.
- **No clobber by default.** The meta-skill refuses to overwrite an existing skill file unless the caller explicitly opts in via `force=true`.
- **Worktree-first persistence.** When the meta-skill writes to disk, it writes inside a dedicated worktree; the calling working tree is never silently mutated.
- **The new card must stand on its own.** Once generated, the card should be readable end-to-end with no reference back to TEMPLATE.md or the meta-skill; placeholder text and italic guidance notes are stripped at emit time.
- **Authoring is the artifact.** The deliverable IS the new card (when `persistence=codebase`) or its draft (when `persistence=chat`). The skill's report exists to record what was done; the file is what ships.
