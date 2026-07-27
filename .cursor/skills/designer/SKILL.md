---
name: designer
description: "Manually-invoked design controller that applies one or more design traits — declarative (YAML DSL and schema modeling) and deterministic (reproducibility and non-determinism elimination) — to a target via explicit control knobs (traits, mode, approval, depth, persistence, fan_out). Use when the user explicitly invokes designer, asks for a design controller, asks to compose multiple design philosophies with explicit parameters, or asks for a step-by-step design walkthrough against a named trait. Manually invoked only — do not auto-apply on bare 'design X' phrasings, unrelated edits, or general refactoring."
license: MIT
---

# Designer

Apply one or more design traits to a single target through user-supplied control knobs. This skill is the composition surface for the design family: pick which traits apply (`traits=[declarative,deterministic,...]`), pick the motion (`mode=propose` for one-shot composition or `mode=walkthrough` for a step-by-step loop), pick the output shape (`deliverable_shape`, `audience`, `depth`), pick persistence (`chat` vs `codebase`), and run. The controller never inlines a trait's body; it reads each trait card from [./traits/](./traits/) at invocation time, applies its guidance, and emits a unified report.

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly invokes one of:

- `designer traits=[...] target=...` (inline-token form).
- "design `<target>` with `<trait1>` + `<trait2>`" (natural-language form).
- "compose `<trait1>` and `<trait2>` design against `<target>`".
- "run designer", "design controller", or any phrase containing `designer`.

Do not auto-apply on bare "design X" phrasings or unrelated edits. If the user wants a single trait's guidance without the controller's knobs, read that trait card directly — this skill's job is composition and explicit knobs, not all design.

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

- `mode` — `propose` | `walkthrough`. Default `walkthrough`. `propose` runs one-pass multi-trait composition; `walkthrough` runs a step-by-step loop against a single trait's enumerated procedure.
- `precedence` — `none` | ordered list of traits | explicit rule string. Default `none`. Meaningful only in `mode=propose` with `traits.length >= 2`; rejected otherwise.
- `fan_out` — integer `>= 1`. Default `1`. Values `>= 2` are valid only in `mode=walkthrough`; rejected in `mode=propose`. When `>= 2`, a forked round dispatches `fan_out` sibling worktrees via `worktree-task` for variant exploration.

**Round control** (all rejected in `mode=propose`):

- `approval` — `interactive` | `non-interactive` | `force-approve-all`. Default `interactive`.
  - `interactive` — the user is asked at every round; every round offers `accept` / `refine` / `fork` / `back` / `done`.
  - `non-interactive` — the user approves the plan once, then every per-round draft is auto-accepted until `stop_condition` fires.
  - `force-approve-all` — no approval at any point, not even on the plan.
- `stop_condition` — explicit exit condition. Default `user-signals-done`.
  - `user-signals-done` — the loop exits only when the user chooses `done`. Valid only with `approval=interactive`.
  - `all-steps-complete` — exits once every walkthrough step (in declared order, with no later `back` rewinding past it) has been the subject of a round ending in `accept` or `fork`.
  - `validation-pass` — exits once the trait's declared validation rules all pass against the working artifact.
  - `max-rounds:<n>` — exits after `<n>` rounds, `<n>` a positive integer. Distinct from `max_iterations`, which is a safety cap, not a stop condition.

**Output shape:**

- `deliverable_shape` — `union` | `schema-doc` | `adr` | `prd` | `spec` | inline template string. Default `union`. In `union`, the controller composes per-trait deliverables under one umbrella report; named templates override the union with their own slot mapping.
- `audience` — `engineers` (default) | `managers` | `mixed` | free-form noun. Advisory; influences output tone and detail level, no hard contract.
- `depth` — `sketch` | `standard` | `deep`. Default `standard`. Advisory; influences output length and worked-example density, no hard contract.

**Persistence:**

- `persistence` — `chat` | `codebase`. Default `chat`. `chat` emits the deliverable inline only; `codebase` writes the deliverable to `artifact_path` and, in `mode=walkthrough`, writes a per-round snapshot to `<artifact_path>.snapshots/<round>-<step-slug>.md`.
- `artifact_path` — repo-relative path. Required when `persistence=codebase`; default `schemas/<kebab-target>.md` derived from `target`. Rejected when `persistence=chat`.
- `use_worktree` — boolean. Default `true` when `persistence=codebase`; MUST be `false` when `persistence=chat`. When `true`, all disk writes happen inside a dedicated worktree forked from `base_branch`; the calling working tree is never touched.
- `base_branch` — branch the worktree is forked from. Default: current branch (`git rev-parse --abbrev-ref HEAD`). Meaningful only when `use_worktree=true`.
- `worktree_name` — name of the worktree directory and branch. Default: a kebab-case slug derived from `target`, prefixed with `designer/`. Meaningful only when `use_worktree=true`.

**Safety:**

- `max_iterations` — integer `>= 1`. Default `50`. Meaningful only in `mode=walkthrough`. Hard cap on total rounds across the loop's lifetime, including rounds repeated via `refine` and `back`.
- `agent_model` — model identifier passed through to fan-out agents. Default: parent agent's model. Meaningful only when `fan_out >= 2`.

**Knob applicability rejections** (any of these abort with an explanatory error before any work begins):

- `precedence` set with `mode=walkthrough`, or with `traits.length == 1`.
- `fan_out >= 2` with `mode=propose`.
- `traits.length >= 2` with `mode=walkthrough`.
- `approval` or `stop_condition` set explicitly with `mode=propose`.
- `stop_condition=user-signals-done` with `approval` other than `interactive`.
- `approval=non-interactive` or `approval=force-approve-all` without an explicit `stop_condition` other than `user-signals-done`.
- `artifact_path` or `use_worktree=true` with `persistence=chat`.
- `base_branch` or `worktree_name` set explicitly with `use_worktree=false`.
- `max_iterations` set explicitly with `mode=propose`.
- `agent_model` set explicitly with `fan_out=1`.

## Trait Map

Trait names map to trait cards under this skill's own [./traits/](./traits/) directory:

- `declarative` → [./traits/declarative.md](./traits/declarative.md)
- `deterministic` → [./traits/deterministic.md](./traits/deterministic.md)

Add a new trait by:

1. Authoring a new `./traits/<trait>.md` card per [../design-skill/TEMPLATE.md](../design-skill/TEMPLATE.md). The [../design-skill/SKILL.md](../design-skill/SKILL.md) meta-skill scaffolds this.
2. Appending one row to the trait map list above pairing the trait name with its `./traits/<trait>.md` path.

The map is the single source of truth for trait → card resolution. Trait paths MUST be relative to this skill's own directory and MUST resolve under `./traits/`; `..` segments, absolute paths, `~/`, `$HOME`, and machine-specific home directories are rejected before any card is read. Sibling-relative paths are what let the same skill directory work unchanged as plugin source, as a generated project mirror, and as a home-scope install.

## Walkthrough Header Resolution

`mode=walkthrough` requires the resolved trait card to expose an enumerated procedure the controller can iterate. Trait cards disagree on which header carries this content, so the controller resolves it against the resolved file in this order:

1. **`## Design Walkthrough`** (case-sensitive, exact match) — preferred. The numbered/bulleted enumeration under this header is the step list. Catches [./traits/declarative.md](./traits/declarative.md), and any trait card authored against [../design-skill/TEMPLATE.md](../design-skill/TEMPLATE.md).
2. **First H2 section whose body is an ordered enumeration of named items** — fallback. Each item that begins with a `**bold name**` or matches a `### <Name>` heading becomes a step. Catches [./traits/deterministic.md](./traits/deterministic.md)'s `## Sources of Non-Determinism`, where each `### <Source name>` becomes a step.
3. **Neither matches** — abort with `trait <name> exposes no walkthrough section; cannot run mode=walkthrough against this trait.`

The step slug used in snapshot filenames and the iteration log is a kebab-case slug of the resolved step name.

Round 0 (principle selection) sources its list from the trait card's first `## …Principles` section, matched by header. A trait card with no such section skips round 0 and starts at step 1.

The header-resolution rule is a back-compat affordance for trait cards that pre-date [../design-skill/TEMPLATE.md](../design-skill/TEMPLATE.md). New trait cards authored against TEMPLATE.md SHOULD use `## Design Walkthrough` and rule 1; rule 2 is the grandfathering path.

The controller never edits the resolved trait card to make it conform; the card stays as-is, and the controller adapts.

## Workflow

1. **Parse the invocation.** Extract knob tokens (inline first, then natural-language back-references); apply documented defaults; collect the unparsed remainder as `target` if `target=` was not pinned. Empty invocations (no `traits`, no `target`, no inline tokens) abort with `missing required knobs: traits, target. See ## Worked Examples for invocation forms.`
2. **Validate every knob.** Run every applicability check from `## Knob Inventory` and `## Validation Rules`. Validation failure aborts with an explanatory error and zero filesystem side effects (no worktree created, no file written, no agent dispatched).
3. **Resolve trait cards.** For each name in `traits`, look up its path in `## Trait Map`; reject any path that escapes `./traits/`. `Read` every resolved card in full before any design output is drafted. If a resolved file cannot be read, abort with `trait <name>: cannot read <path>`.
4. **Render the plan** (`mode=walkthrough` only). List resolved knobs, trait card path, principle names, ordered step names, persistence and worktree resolution, fan-out count, stop condition, and iteration cap. Under `approval=interactive` and `approval=non-interactive`, present the plan and require approval; under `approval=force-approve-all`, auto-accept.
5. **Set up persistence.** When `persistence=codebase` and `use_worktree=true`, run `git worktree add` to create `worktree_name` forked from `base_branch` and route every subsequent disk write into it. When `persistence=codebase` and `use_worktree=false`, write directly into the calling working tree (caller has accepted the risk). When `persistence=chat`, hold artifact and snapshot state in memory only.
6. **Dispatch on `mode`:**
   - **`propose`**: apply every named trait's guidance to `target` together in one pass. Record per-trait contributions; flag any decision where two traits' guidance gives contradictory direction.
   - **`walkthrough`**: run round 0, then walk the resolved trait's enumerated steps in declared order (per `## Walkthrough Header Resolution`).
     - **Round 0 (principle selection).** Present the captured principle names. Under `approval=interactive`, prompt for a subset or accept-all; under the other cadences, accept all. Record the selection; it persists across the rest of the loop and appears in the final report. Snapshot.
     - **Rounds 1..N.** For each step:
       1. Draft an update to the working artifact scoped to the current step, anchored on the principles selected in round 0, the step's question/artifact, and the artifact state so far.
       2. Under `approval=interactive`, present the draft and the artifact diff, then prompt for one of:
          - `accept` — apply the draft, snapshot, advance.
          - `refine` — take the user's feedback, redraft the same step without advancing (the round counter still increments per attempt).
          - `fork` — dispatch variants (see step 3 below), apply the user's pick, snapshot, advance.
          - `back` — ask which earlier step to return to; restore that step's snapshot as the working artifact (overwriting `artifact_path` when `persistence=codebase`); re-enter at the step after the named one.
          - `done` — exit the loop; the current artifact is final.

          Under `approval=non-interactive` and `approval=force-approve-all`, behave as if `accept` was chosen every round; never prompt for `refine` / `fork` / `back` / `done` mid-loop.
       3. On `fork`, dispatch `worktree-task` with `parallelism=<n>`, `base_branch=` the iterator's current branch, `agent_model=<resolved>`, and a task that runs only the current step on a copy of the working artifact at `artifact_path`. `<n>` is `fan_out` when `fan_out >= 2`; when `fan_out=1`, prompt for the count. Read each variant's `artifact_path`, present every variant's proposed update side by side as fenced diffs, and have the user pick exactly one. Discarded variants' worktrees are left in place per `worktree-task`'s own policy.
       4. Snapshot the artifact after `accept` and after `fork` (post-variant-pick), tagged by round index and step slug.
       5. Evaluate `stop_condition` after any chosen update is applied; the first satisfied condition halts the loop. Evaluate `max_iterations` independently; halt with terminal state `iteration-cap-hit` when reached, regardless of `stop_condition`.
7. **Detect tensions.** Whenever two or more traits' cards give contradictory direction for the same decision, capture both positions and label the conflict by the traits involved. Do not pick a winner unless `precedence` says how.
8. **Compose the deliverable.** Assemble the final artifact in the shape declared by `deliverable_shape`. When `persistence=codebase`, write the deliverable verbatim to `artifact_path` (overwriting prior content) inside the worktree (when `use_worktree=true`).
9. **Emit the report** per `## Output Format`. Do not merge the worktree branch and do not delete the worktree.

## Output Format

A single markdown report with these sections, in order. Omit any section whose body would be empty.

### Run Summary

- `Mode`: `propose` or `walkthrough`.
- `Traits`: comma-separated, in invocation order.
- `Target`: resolved `target` (path or first ~80 chars of inline text).
- `Knobs`: every resolved knob name and value.
- `Persistence`: `chat`, or `codebase` plus the resolved `artifact_path`.
- `Worktree`: branch name and absolute path, or `n/a` when `use_worktree=false` or `persistence=chat`.
- `Approval` / `Stop condition` / `Iteration cap`: resolved values (only in `mode=walkthrough`).
- `Terminal state`: `user-done` / `all-steps-complete` / `validation-pass` / `max-rounds-hit` / `iteration-cap-hit` / `plan-declined` / `validation-error` (only in `mode=walkthrough`).
- `Counts`: rounds run / accepted / refined / forked / backs / variants spawned (only in `mode=walkthrough`).

### Selected Principles

Present this section only in `mode=walkthrough`. A bullet list of the principle names selected at round 0, in the order they appear in the trait card. Includes a sub-bullet `All principles selected.` when the full list was accepted.

### Per-Trait Contribution

One subsection per trait, in invocation order. Each subsection records what the trait contributed: which decisions it shaped, which artifacts it produced, which constraints it imposed. The body cites specific guidance from the resolved trait card but does NOT inline its body.

### Tensions and Tradeoffs

Each unresolvable conflict between traits as a labeled bullet (e.g., `**declarative vs. deterministic:** <one-line summary of both positions>`), or `_None._` when no conflict was detected. Conflicts are surfaced; the controller never silently picks a winner unless `precedence` says how.

### Final Deliverable

The artifact assembled per `deliverable_shape`. In `union` (default), this section contains one subsection per trait holding that trait's declared deliverable shape (e.g., the declarative trait contributes a schema + worked instance + validation rules; the deterministic trait contributes a checklist of sources/mitigations). In `schema-doc` / `adr` / `prd` / `spec` / inline-template modes, the section follows the named template's slots; per-trait contributions map into the slots as the trait cards' deliverables permit.

### Iteration Log

Present this section only in `mode=walkthrough`. A table with one row per round, in execution order:

| Round | Step | Choice | Variants spawned | Snapshot |
|-------|------|--------|------------------|----------|

Each `Snapshot` cell is the snapshot file path (when `persistence=codebase`) or `(in-memory)` (when `persistence=chat`).

### Persistence Result

Present this section only when `persistence=codebase`.

- `Wrote artifact to`: absolute path inside the worktree (or in the calling tree when `use_worktree=false`).
- `Snapshots directory`: absolute path of `<artifact_path>.snapshots/`, or `n/a` in `mode=propose`.
- `Snapshot files`: bullet list of every snapshot written, in round order (only in `mode=walkthrough`).

### Worktree Result

Present this section only when `use_worktree=true`.

- `Worktree path`: absolute path.
- `Branch`: resolved `worktree_name`.
- `Base branch`: resolved `base_branch`.
- `Diff`: a fenced ` ```diff ` block containing `git diff <base_branch>..HEAD`, truncated above ~400 lines with `... (truncated, K lines omitted)` when oversized.

### Next Steps

- The worktree and its branch are left in place for the user to inspect, refine further, and merge separately.
- For forked rounds: sibling worktrees created by `worktree-task` are left in place per its own merge policy.
- For `iteration-cap-hit` runs: raise `max_iterations` and rerun, or split the remaining steps into a second invocation against the persisted snapshots.
- A reminder that no branches were merged, no worktrees were deleted, and no remotes were touched.

## Guardrails

- MUST require explicit invocation (a phrase from `## When to Invoke`); MUST NOT auto-apply on bare "design X" phrasings.
- MUST `Read` every resolved trait card from its `./traits/` path; reject `..` segments, `~/`, `$HOME`, absolute paths, and machine-specific home directories before any read.
- MUST NOT inline, hard-code, summarize, or paraphrase any trait card's body into the report; reference each trait's guidance, do not transclude it.
- MUST source principle names, step names, step order, and the deliverable's shape from the resolved trait card; MUST NOT inline or paraphrase those lists into this skill.
- MUST NOT pick a winner on a trait-vs-trait conflict unless `precedence` is set; conflicts surface in `## Tensions and Tradeoffs` with both positions stated.
- MUST treat round 0 (principle selection) as part of every walkthrough whose trait card exposes a principles section; MUST NOT advance to step 1 until the principles are selected or accepted wholesale.
- MUST keep the loop user-in-the-loop under `approval=interactive`: every round asks for one of `accept` / `refine` / `fork` / `back` / `done` before mutating the artifact; MUST NOT silently apply a draft.
- MUST NOT bundle multiple walkthrough steps into a single round; one round addresses exactly one step. `back` re-enters at a single named earlier step and resumes forward step-by-step.
- MUST honor `stop_condition` exactly; MUST NOT exit the loop on any condition not declared in `stop_condition` or `max_iterations`.
- MUST NOT recurse: fan-out agents dispatched via `worktree-task` MUST run with their own `fan_out=1` and MUST NOT invoke `designer`.
- MUST NOT make determinism, byte-equivalence, or reproducibility claims about the controller's output. The controller's WORKFLOW is well-defined (same knobs route to the same dispatch path), but the LLM-generated deliverable is not bit-stable across runs absent a frozen model, temperature 0, and a seeded sampler — none of which the controller pins.
- MUST keep every disk write inside the worktree when `use_worktree=true`; MUST NOT touch the calling working tree's working directory or index for the artifact, snapshots, or fan-out scaffolding.
- MUST NOT mutate any file when `persistence=chat`, including snapshot files.
- MUST NOT push, open PRs, merge branches, delete worktrees, create tags, or rebase pre-existing branches; the worktree is left in place for the user to review and merge separately.
- MUST validate every knob before any read, write, or agent dispatch; abort fast on validation failure with zero filesystem side effects.
- Scope: apply trait cards against one `target`. Out of scope: editing `target`; modifying any trait card; seeding new traits beyond `## Trait Map`; executing the resulting deliverable; recursive invocation.

## Worked Examples

### Example 1: Multi-trait one-shot composition (chat)

```
designer traits=[declarative,deterministic] target=schemas/feature-flags.md mode=propose persistence=chat
```

Resolved knobs: `traits=[declarative,deterministic]`, `target=schemas/feature-flags.md`, `mode=propose`, `persistence=chat`, `use_worktree=false`, `precedence=none`, `deliverable_shape=union`, `audience=engineers`, `depth=standard`.

Behavior: the controller reads both trait cards, applies them together to the target, composes one unified report with two `## Per-Trait Contribution` subsections, surfaces any tensions in `## Tensions and Tradeoffs`, and emits the deliverable inline. No filesystem writes; no worktree; no rounds.

### Example 2: Single-trait deep walkthrough (codebase, no fan-out)

```
designer traits=[declarative] target="feature flags" mode=walkthrough depth=deep persistence=codebase artifact_path=schemas/feature-flags.md
```

Resolved knobs: `traits=[declarative]`, `target="feature flags"`, `mode=walkthrough`, `depth=deep`, `persistence=codebase`, `artifact_path=schemas/feature-flags.md`, `use_worktree=true`, `approval=interactive`, `stop_condition=user-signals-done`, `fan_out=1`, `max_iterations=50`.

Behavior: the controller reads [./traits/declarative.md](./traits/declarative.md), locates its `## Design Walkthrough` (rule 1 of header resolution), creates a worktree forked from the current branch, runs round 0 against the card's `## Declarative Principles`, walks the steps in order prompting at each round, writes the working artifact to `schemas/feature-flags.md` and a snapshot to `schemas/feature-flags.md.snapshots/<round>-<step-slug>.md` per round, and exits when the user chooses `done`. The calling working tree is never touched.

### Example 3: Single-trait walkthrough with fan-out, unattended

```
designer traits=[deterministic] target=src/pipeline.py mode=walkthrough approval=non-interactive stop_condition=all-steps-complete fan_out=4 agent_model=gpt-5.5-extra-high-fast persistence=codebase artifact_path=docs/pipeline-deterministic-audit.md
```

Resolved knobs: `traits=[deterministic]`, `target=src/pipeline.py`, `mode=walkthrough`, `approval=non-interactive`, `stop_condition=all-steps-complete`, `fan_out=4`, `agent_model=gpt-5.5-extra-high-fast`, `persistence=codebase`, `artifact_path=docs/pipeline-deterministic-audit.md`, `use_worktree=true`, `max_iterations=50`.

Behavior: the controller reads [./traits/deterministic.md](./traits/deterministic.md), locates `## Sources of Non-Determinism` via header-resolution rule 2 (no `## Design Walkthrough` present), takes plan approval once, creates a worktree, and walks every source as a round, dispatching 4 sibling agents through `worktree-task` per round (each in its own sub-worktree, model broadcast to `gpt-5.5-extra-high-fast`). The loop exits once every step has landed, or at `max_iterations=50`, whichever comes first.

## When Not To Use

- **Bare "design X" phrasings.** This skill is manually invoked. If the user has not used a phrase from `## When to Invoke`, point them at the trait card they actually want or ask them to invoke the controller explicitly.
- **Reading a trait's guidance directly.** If the user wants one trait's principles or walkthrough without a composed report or knob surface, read `./traits/<trait>.md` — the controller adds friction without adding value.
- **Recursive composition.** The controller MUST NOT invoke itself; fan-out agents MUST run with `fan_out=1` and MUST NOT call `designer`.
- **Modifying trait cards.** The controller reads `./traits/*.md` but MUST NOT edit them. To change a trait's behavior, edit the card directly (or, for new traits, scaffold via [../design-skill/SKILL.md](../design-skill/SKILL.md)).
- **Executing the deliverable.** The controller produces a deliverable; running it (validators, codegen, deployment) is the user's call and outside this skill's scope.

## Validation Rules

A valid `designer` invocation MUST satisfy every rule below. Each rule traces back to a specific decision in `## Knob Inventory` or `## Workflow`.

- **Required knobs present.** `traits` and `target` are present and non-empty.
- **Trait names resolve.** Every name in `traits` is a key of `## Trait Map`.
- **Mode-traits compatibility.** `mode=walkthrough` requires `traits.length == 1`; `mode=propose` requires `traits.length >= 1`.
- **Mode-precedence compatibility.** `precedence` is unset or `none` unless `mode=propose` AND `traits.length >= 2`.
- **Mode-fan_out compatibility.** `fan_out >= 2` requires `mode=walkthrough`; `mode=propose` forces `fan_out=1`.
- **Mode-round-control compatibility.** `approval`, `stop_condition`, and `max_iterations` are set only when `mode=walkthrough`.
- **Approval-stop_condition compatibility.** `stop_condition=user-signals-done` requires `approval=interactive`; `approval=non-interactive` and `approval=force-approve-all` each require an explicit `stop_condition` other than `user-signals-done`.
- **Stop condition well-formed.** `stop_condition` is one of `user-signals-done`, `all-steps-complete`, `validation-pass`, or `max-rounds:<n>` with `<n>` a positive integer.
- **Fan_out-agent_model compatibility.** `agent_model` is set only when `fan_out >= 2`.
- **Persistence-path compatibility.** `artifact_path` is set if and only if `persistence=codebase`. `use_worktree=true` requires `persistence=codebase`.
- **Worktree-knob compatibility.** `base_branch` and `worktree_name` are set only when `use_worktree=true`.
- **Trait paths stay under `./traits/`.** Every path resolved from `## Trait Map` is relative to this skill's directory and resolves under `./traits/`; `..` segments, `~/`, `$HOME`, absolute paths, and machine-specific home directories are rejected before any read.
- **Walkthrough resolves.** When `mode=walkthrough`, the resolved trait card exposes a section satisfying `## Walkthrough Header Resolution`.
- **Iteration cap positive.** `max_iterations >= 1`.
- **No unknown knobs.** Every `key=...` token's key is in the knob inventory; unknown keys abort with `unknown knob: <key>; available knobs: <list>`.

## Designer Principles

Frame every controller decision around these. Each is a "do this, not that" choice, not an abstract value.

- **Knobs are explicit, not inferred.** Every behavior of the controller is a knob the user can set; the controller never infers a knob from "what they probably meant" outside of documented defaults.
- **Trait cards are read, not inlined.** Every `./traits/<trait>.md` is `Read` at invocation time and treated as the canonical guidance for that trait; the controller never copies, paraphrases, or summarizes a card into its own prompt or output.
- **Trait paths are sibling-relative.** Traits resolve under this skill's own directory, so the same skill works unchanged as plugin source, as a generated mirror, and as a home-scope install. A path that reaches outside the skill directory is a bug.
- **Tensions surface, never silently resolve.** Conflicts between traits are labeled and presented; the controller never picks a winner without an explicit `precedence` rule.
- **Composition is the controller's only job.** The controller does not edit `target`, modify trait cards, or execute deliverables. It composes; everything else is downstream.
- **One round, one step.** A walkthrough round addresses exactly one step, and the user sees it before it lands. Bundling steps to finish faster defeats the point of the motion.
- **Worktree-first persistence.** When the controller writes to disk, it writes inside a dedicated worktree; the calling working tree is never silently mutated.
- **No false determinism claims.** The controller's workflow is well-defined; the LLM-generated deliverable is not bit-stable. Promising byte-equivalence to the user is a bug, not a feature.
