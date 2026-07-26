---
name: designer-controller
description: "Manually-invoked design controller that orchestrates one or more <trait>-design skills against a target via explicit user-supplied control knobs (traits, mode, depth, audience, persistence, fan_out). Use when the user explicitly invokes designer-controller, asks for a designer with control knobs, asks to compose multiple design philosophies with explicit parameters, or asks for orchestrated design across declarative/deterministic/etc. traits. Manually invoked only — do not auto-apply on bare 'design X' phrasings, unrelated edits, or general refactoring."
license: MIT
---

# Designer Controller

Orchestrate one or more `<trait>-design` skills against a single target through user-supplied control knobs. The controller is the composition surface for the design skill family: pick which traits apply (`traits=[declarative,deterministic,...]`), pick the motion (`mode=propose` for one-shot composition or `mode=walkthrough` for step-by-step), pick the output shape (`deliverable_shape`, `audience`, `depth`), pick persistence (`chat` vs `codebase`), and run. The controller never inlines the trait skills' bodies; it reads each `<trait>-design/SKILL.md` at invocation time, applies its guidance, and emits a unified report.

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly invokes one of:

- `designer-controller traits=[...] target=...` (inline-token form).
- "design controller against `<target>` with `<trait1>` + `<trait2>`" (natural-language form).
- "compose `<trait1>` and `<trait2>` design against `<target>`".
- "run designer-controller", "design-controller", or any phrase containing `designer-controller`.

Do not auto-apply on bare "design X" phrasings or unrelated edits. If the user wants a single trait one-shot and has not invoked the controller, point them at the trait skill directly — the controller's job is composition and explicit knobs, not all design.

## Invocation Contract

The controller recognizes knobs in two forms in the user's invocation message:

1. **Inline `key=value` tokens** — anywhere in the message; whitespace-separated.
2. **Natural-language back-references** — e.g., "with declarative + deterministic", "depth deep", "walk through it".

If both forms are present and disagree, **inline tokens win**.

Inline parsing rules:

- Knobs are `key=value` tokens separated by whitespace.
- Lists are bracketed and comma-separated, no spaces inside the brackets: `traits=[declarative,deterministic]`.
- Strings containing whitespace are double-quoted: `target="user authentication"`.
- Booleans are `true` or `false` (case-insensitive).
- Integers are bare digits; no decimal point, no thousands separator.
- `target` may appear as `target=...` OR as the trailing free-form remainder of the message after the last recognized knob token. If both forms are present, `target=...` wins.
- An `=` inside a quoted value or inside a free-form `target` does NOT start a new knob.
- An unrecognized `key=...` token (key not in the knob inventory) aborts with `unknown knob: <key>; available knobs: <list>`.

## Knob Inventory

**Required:**

- `traits` — ordered list of trait names; non-empty. Every name MUST resolve via `## Trait Map`. In `mode=walkthrough`, exactly one trait; in `mode=propose`, one or more.
- `target` — the artifact being designed: inline text, repo-relative file path, repo-relative directory path, or free-form description.

**Composition:**

- `mode` — `propose` | `walkthrough`. Default `walkthrough`. `propose` runs one-pass multi-trait composition (designer-style); `walkthrough` runs a step-by-step loop against a single trait's enumerated procedure (ralph-design style).
- `precedence` — `none` | ordered list of traits | explicit rule string. Default `none`. Meaningful only in `mode=propose` with `traits.length >= 2`; rejected otherwise.
- `fan_out` — integer `>= 1`. Default `1`. Values `>= 2` are valid only in `mode=walkthrough`; rejected in `mode=propose`. When `>= 2`, each round dispatches `fan_out` sibling worktrees via `worktree-task` for variant exploration.

**Output shape:**

- `deliverable_shape` — `union` | `schema-doc` | `adr` | `prd` | `spec` | inline template string. Default `union`. In `union`, the controller composes per-trait deliverables under one umbrella report; named templates override the union with their own slot mapping.
- `audience` — `engineers` (default) | `managers` | `mixed` | free-form noun. Advisory; influences output tone and detail level, no hard contract.
- `depth` — `sketch` | `standard` | `deep`. Default `standard`. Advisory; influences output length and worked-example density, no hard contract.

**Persistence:**

- `persistence` — `chat` | `codebase`. Default `chat`. `chat` emits the deliverable inline only; `codebase` writes the deliverable to `artifact_path`.
- `artifact_path` — repo-relative path. Required when `persistence=codebase`; default `schemas/<kebab-target>.md` derived from `target`. Rejected when `persistence=chat`.
- `use_worktree` — boolean. Default `true` when `persistence=codebase`; MUST be `false` when `persistence=chat`. When `true`, all disk writes happen inside a dedicated worktree forked from the current branch; the calling working tree is never touched.

**Safety:**

- `max_iterations` — integer `>= 1`. Default `50`. Meaningful only in `mode=walkthrough`. Hard cap on total rounds across the loop's lifetime.
- `agent_model` — model identifier passed through to fan-out agents. Default: parent agent's model. Meaningful only when `fan_out >= 2`.

**Knob applicability rejections** (any of these abort with an explanatory error before any work begins):

- `precedence` set with `mode=walkthrough`, or with `traits.length == 1`.
- `fan_out >= 2` with `mode=propose`.
- `traits.length >= 2` with `mode=walkthrough`.
- `artifact_path` or `use_worktree=true` with `persistence=chat`.
- `max_iterations` set explicitly with `mode=propose`.
- `agent_model` set explicitly with `fan_out=1`.

## Trait Map

Trait names map to `<trait>-design/SKILL.md` paths, repo-relative under `.cursor/skills/`:

- `declarative` → `.cursor/skills/declarative-design/SKILL.md`
- `deterministic` → `.cursor/skills/deterministic-design/SKILL.md`

Add a new trait by:

1. Authoring a new `<trait>-design/SKILL.md` per [../design-skill/TEMPLATE.md](../design-skill/TEMPLATE.md). The [../design-skill/SKILL.md](../design-skill/SKILL.md) meta-skill scaffolds this.
2. Appending one row to the trait map list above pairing the trait name with its canonical `.cursor/skills/<trait>-design/SKILL.md` path.

The map is the single source of truth for trait → skill file resolution. Skill paths MUST be repo-relative under `.cursor/skills/`; absolute paths, `~/`, `$HOME`, and machine-specific home directories are rejected before any skill file is read.

## Walkthrough Header Resolution

`mode=walkthrough` requires the resolved `<trait>-design/SKILL.md` to expose an enumerated procedure the controller can iterate. Existing trait skills disagree on which header carries this content, so the controller resolves it against the resolved file in this order:

1. **`## Design Walkthrough`** (case-sensitive, exact match) — preferred. The numbered/bulleted enumeration under this header is the step list. Catches [../declarative-design/SKILL.md](../declarative-design/SKILL.md), and any trait skill authored against [../design-skill/TEMPLATE.md](../design-skill/TEMPLATE.md).
2. **First H2 section whose body is an ordered enumeration of named items** — fallback. Each item that begins with a `**bold name**` or matches a `### <Name>` heading becomes a step. Catches [../deterministic-design/SKILL.md](../deterministic-design/SKILL.md)'s `## Sources of Non-Determinism`, where each `### <Source name>` becomes a step.
3. **Neither matches** — abort with `trait <name> exposes no walkthrough section; cannot run mode=walkthrough against this trait.`

The header-resolution rule is a back-compat affordance for trait skills that pre-date [../design-skill/TEMPLATE.md](../design-skill/TEMPLATE.md). New trait skills authored against TEMPLATE.md SHOULD use `## Design Walkthrough` and rule 1; rule 2 is the grandfathering path.

The controller never edits the resolved trait skill to make it conform; the trait skill stays as-is, and the controller adapts.

## Workflow

1. **Parse the invocation.** Extract knob tokens (inline first, then natural-language back-references); apply documented defaults; collect the unparsed remainder as `target` if `target=` was not pinned. Empty invocations (no `traits`, no `target`, no inline tokens) abort with `missing required knobs: traits, target. See ## Worked Examples for invocation forms.`
2. **Validate every knob.** Run every applicability check from `## Knob Inventory` and `## Validation Rules`. Validation failure aborts with an explanatory error and zero filesystem side effects (no worktree created, no file written, no agent dispatched).
3. **Resolve trait skills.** For each name in `traits`, look up its path in `## Trait Map`; reject any non-repo-relative path. `Read` every resolved `<trait>-design/SKILL.md` in full before any design output is drafted. If a resolved file cannot be read, abort with `trait <name>: cannot read <path>`.
4. **Set up persistence.** When `persistence=codebase` and `use_worktree=true`, run `git worktree add` to create a new worktree forked from the current branch and route every subsequent disk write into it. When `persistence=codebase` and `use_worktree=false`, write directly into the calling working tree (caller has accepted the risk). When `persistence=chat`, hold artifact state in memory only.
5. **Dispatch on `mode`:**
   - **`propose`**: apply every named trait's guidance to `target` together in one pass. Record per-trait contributions; flag any decision where two traits' guidance gives contradictory direction.
   - **`walkthrough`**: walk the resolved trait's enumerated steps in declared order (per `## Walkthrough Header Resolution`). For each step:
     1. Draft an update to the working artifact scoped to the current step, anchored on the step's question/artifact and the artifact state so far.
     2. When `fan_out >= 2`, dispatch `worktree-task` with `parallelism=fan_out`, `agent_model=<resolved>`, and a task that runs only the current step on a copy of the working artifact at `artifact_path`. Read each variant's `artifact_path`; present every variant's proposed update side by side; pick exactly one.
     3. Apply the chosen update to the working artifact; advance to the next step.
     4. Evaluate `max_iterations`; halt with terminal state `iteration-cap-hit` if reached.
6. **Detect tensions.** Whenever two or more traits' skills give contradictory direction for the same decision, capture both positions and label the conflict by the traits involved. Do not pick a winner unless `precedence` says how.
7. **Compose the deliverable.** Assemble the final artifact in the shape declared by `deliverable_shape`. When `persistence=codebase`, write the deliverable verbatim to `artifact_path` (overwriting prior content) inside the worktree (when `use_worktree=true`).
8. **Emit the report** per `## Output Format`. Do not merge the worktree branch and do not delete the worktree.

## Output Format

A single markdown report with these sections, in order. Omit any section whose body would be empty.

### Run Summary

- `Mode`: `propose` or `walkthrough`.
- `Traits`: comma-separated, in invocation order.
- `Target`: resolved `target` (path or first ~80 chars of inline text).
- `Knobs`: every resolved knob name and value.
- `Persistence`: `chat`, or `codebase` plus the resolved `artifact_path`.
- `Worktree`: branch name and absolute path, or `n/a` when `use_worktree=false` or `persistence=chat`.
- `Counts`: rounds run / variants spawned (only in `mode=walkthrough`).

### Per-Trait Contribution

One subsection per trait, in invocation order. Each subsection records what the trait contributed: which decisions it shaped, which artifacts it produced, which constraints it imposed. The body cites specific guidance from the resolved trait skill but does NOT inline its body.

### Tensions and Tradeoffs

Each unresolvable conflict between traits as a labeled bullet (e.g., `**declarative vs. deterministic:** <one-line summary of both positions>`), or `_None._` when no conflict was detected. Conflicts are surfaced; the controller never silently picks a winner unless `precedence` says how.

### Final Deliverable

The artifact assembled per `deliverable_shape`. In `union` (default), this section contains one subsection per trait holding that trait's declared deliverable shape (e.g., declarative-design contributes a schema + worked instance + validation rules; deterministic-design contributes a checklist of sources/mitigations). In `schema-doc` / `adr` / `prd` / `spec` / inline-template modes, the section follows the named template's slots; per-trait contributions map into the slots as the trait skills' deliverables permit.

### Persistence Result

Present this section only when `persistence=codebase`.

- `Wrote artifact to`: absolute path inside the worktree (or in the calling tree when `use_worktree=false`).
- `Worktree path`: absolute path, or `n/a` when `use_worktree=false`.
- `Branch`: branch name, or `n/a`.
- `Diff`: a fenced ` ```diff ` block containing `git diff <base>..HEAD`, truncated above ~400 lines with `... (truncated, K lines omitted)` when oversized.

### Iteration Log

Present this section only in `mode=walkthrough`. A bullet list with one entry per round, in execution order. Each entry records: round index, step name, variants spawned (`fan_out` value when `>= 2`, else `1`), and a one-line decision summary describing what the round's update applied to the artifact.

## Guardrails

- MUST require explicit invocation (a phrase from `## When to Invoke`); MUST NOT auto-apply on bare "design X" phrasings.
- MUST `Read` every resolved `<trait>-design/SKILL.md` from its canonical repo-relative path; reject `~/`, `$HOME`, absolute paths outside the repo, and machine-specific home directories before any read.
- MUST NOT inline, hard-code, summarize, or paraphrase any per-trait skill body into the report; reference each trait's guidance, do not transclude it.
- MUST NOT pick a winner on a trait-vs-trait conflict unless `precedence` is set; conflicts surface in `## Tensions and Tradeoffs` with both positions stated.
- MUST NOT recurse: fan-out agents dispatched via `worktree-task` MUST run with their own `fan_out=1` and MUST NOT invoke `designer-controller`.
- MUST NOT make determinism, byte-equivalence, or reproducibility claims about the controller's output. The controller's WORKFLOW is well-defined (same knobs route to the same dispatch path), but the LLM-generated deliverable is not bit-stable across runs absent a frozen model, temperature 0, and a seeded sampler — none of which the controller pins.
- MUST keep every disk write inside the worktree when `use_worktree=true`; MUST NOT touch the calling working tree's working directory or index for the artifact, snapshots, or fan-out scaffolding.
- MUST NOT push, open PRs, merge branches, delete worktrees, create tags, or rebase pre-existing branches; the worktree is left in place for the user to review and merge separately.
- MUST validate every knob before any read, write, or agent dispatch; abort fast on validation failure with zero filesystem side effects.
- Scope: orchestrate `<trait>-design` skills against one `target`. Out of scope: editing `target`; modifying any `<trait>-design/SKILL.md`; seeding new traits beyond `## Trait Map`; executing the resulting deliverable; recursive controller invocation.

## Worked Examples

### Example 1: Multi-trait one-shot composition (chat)

```
designer-controller traits=[declarative,deterministic] target=schemas/feature-flags.md mode=propose persistence=chat
```

Resolved knobs: `traits=[declarative,deterministic]`, `target=schemas/feature-flags.md`, `mode=propose`, `persistence=chat`, `use_worktree=false`, `precedence=none`, `deliverable_shape=union`, `audience=engineers`, `depth=standard`.

Behavior: the controller reads both trait skills, applies them together to the target, composes one unified report with two `## Per-Trait Contribution` subsections, surfaces any tensions in `## Tensions and Tradeoffs`, and emits the deliverable inline. No filesystem writes; no worktree.

### Example 2: Single-trait deep walkthrough (codebase, no fan-out)

```
designer-controller traits=[declarative] target="feature flags" mode=walkthrough depth=deep persistence=codebase artifact_path=schemas/feature-flags.md
```

Resolved knobs: `traits=[declarative]`, `target="feature flags"`, `mode=walkthrough`, `depth=deep`, `persistence=codebase`, `artifact_path=schemas/feature-flags.md`, `use_worktree=true`, `fan_out=1`, `max_iterations=50`.

Behavior: the controller reads `declarative-design/SKILL.md`, locates its `## Design Walkthrough` (rule 1 of header resolution), creates a worktree forked from the current branch, walks the steps in order, writes the working artifact to `schemas/feature-flags.md` inside the worktree on each round, and emits a per-round iteration log. The calling working tree is never touched.

### Example 3: Single-trait walkthrough with fan-out

```
designer-controller traits=[deterministic] target=src/pipeline.py mode=walkthrough fan_out=4 agent_model=gpt-5.5-extra-high-fast persistence=codebase artifact_path=docs/pipeline-deterministic-audit.md
```

Resolved knobs: `traits=[deterministic]`, `target=src/pipeline.py`, `mode=walkthrough`, `fan_out=4`, `agent_model=gpt-5.5-extra-high-fast`, `persistence=codebase`, `artifact_path=docs/pipeline-deterministic-audit.md`, `use_worktree=true`.

Behavior: the controller reads `deterministic-design/SKILL.md`, locates `## Sources of Non-Determinism` via header-resolution rule 2 (no `## Design Walkthrough` present), creates a worktree, and at each step dispatches 4 sibling agents through `worktree-task` (each in its own sub-worktree, model broadcast to `gpt-5.5-extra-high-fast`) to explore variants of that step's checklist update. The user picks one variant per round; the loop continues until the checklist is complete or `max_iterations=50` is reached.

## When Not To Use

- **Bare "design X" phrasings.** This skill is manually invoked. If the user has not used a phrase from `## When to Invoke`, point them at the trait skill they actually want or ask them to invoke the controller explicitly.
- **Single-trait one-shot design.** If the user wants one trait's deliverable in one pass, the trait skill itself is the right tool — the controller adds friction without adding value.
- **Recursive composition.** The controller MUST NOT invoke itself; fan-out agents MUST run with `fan_out=1` and MUST NOT call `designer-controller`.
- **Modifying trait skills.** The controller reads `<trait>-design/SKILL.md` files but MUST NOT edit them. To change a trait's behavior, edit the trait skill directly (or, for new traits, scaffold via [../design-skill/SKILL.md](../design-skill/SKILL.md)).
- **Executing the deliverable.** The controller produces a deliverable; running it (validators, codegen, deployment) is the user's call and outside this skill's scope.

## Validation Rules

A valid `designer-controller` invocation MUST satisfy every rule below. Each rule traces back to a specific decision in `## Knob Inventory` or `## Workflow`.

- **Required knobs present.** `traits` and `target` are present and non-empty.
- **Trait names resolve.** Every name in `traits` is a key of `## Trait Map`.
- **Mode-traits compatibility.** `mode=walkthrough` requires `traits.length == 1`; `mode=propose` requires `traits.length >= 1`.
- **Mode-precedence compatibility.** `precedence` is unset or `none` unless `mode=propose` AND `traits.length >= 2`.
- **Mode-fan_out compatibility.** `fan_out >= 2` requires `mode=walkthrough`; `mode=propose` forces `fan_out=1`.
- **Mode-max_iterations compatibility.** `max_iterations` is set only when `mode=walkthrough`.
- **Fan_out-agent_model compatibility.** `agent_model` is set only when `fan_out >= 2`.
- **Persistence-path compatibility.** `artifact_path` is set if and only if `persistence=codebase`. `use_worktree=true` requires `persistence=codebase`.
- **Skill paths repo-relative.** Every path resolved from `## Trait Map` is repo-relative under `.cursor/skills/`; `~/`, `$HOME`, absolute paths outside the repo, and machine-specific home directories are rejected before any read.
- **Walkthrough resolves.** When `mode=walkthrough`, the resolved trait skill exposes a section satisfying `## Walkthrough Header Resolution`.
- **No unknown knobs.** Every `key=...` token's key is in the knob inventory; unknown keys abort with `unknown knob: <key>; available knobs: <list>`.

## Designer-Controller Principles

Frame every controller decision around these. Each is a "do this, not that" choice, not an abstract value.

- **Knobs are explicit, not inferred.** Every behavior of the controller is a knob the user can set; the controller never infers a knob from "what they probably meant" outside of documented defaults.
- **Trait bodies are read, not inlined.** Every `<trait>-design/SKILL.md` is `Read` at invocation time and treated as the canonical guidance for that trait; the controller never copies, paraphrases, or summarizes a trait body into its own prompt or output.
- **Tensions surface, never silently resolve.** Conflicts between traits are labeled and presented; the controller never picks a winner without an explicit `precedence` rule.
- **Composition is the controller's only job.** The controller does not edit `target`, modify trait skills, or execute deliverables. It composes; everything else is downstream.
- **Worktree-first persistence.** When the controller writes to disk, it writes inside a dedicated worktree; the calling working tree is never silently mutated.
- **No false determinism claims.** The controller's workflow is well-defined; the LLM-generated deliverable is not bit-stable. Promising byte-equivalence to the user is a bug, not a feature.
