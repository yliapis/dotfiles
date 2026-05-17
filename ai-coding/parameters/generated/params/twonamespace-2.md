# `ai-coding/parameters/` — Parameter Ontology

**Angle: two-namespace (skill vs. command) + shared core.**

This directory is a reusable parameter vocabulary for the artifacts in
`ai-coding/plugins/ai-coding/`. Commands and skills both have parameters,
but they are different *kinds* of artifacts and they're parameterized
along different axes. This ontology treats that split as **first-class**:
three primary files (one per namespace) plus two supporting files.

---

## Motivation: why two namespaces + a shared core?

Commands and skills are not the same kind of thing.

- A **command** (`/critique`, `/meta-prompt`, `/worktree-task-agent`,
  `/trajectory`) is an **imperative** artifact the user explicitly invokes.
  Its parameters describe **how to execute**: which model, how many
  workers, what to fork from, what to merge back, how to recover from
  hangs. The lifecycle is "user invokes → execution → result".
- A **skill** (`conventional-commits`, `minimal-diffs`) is a **declarative**
  artifact that activates implicitly based on the parent agent's current
  context. Its parameters describe **when it applies and what it produces**:
  trigger conditions, applicability scope, mandate level, hand-off shape.
  The lifecycle is "context matches → guidance applied → behavior changes".

A single flat dictionary would have to either (a) treat command-only
parameters like `parallelism` and `subagent_model` as universal — they're
not, they're meaningless to skills; or (b) treat skill-only parameters
like `activation_trigger` and `mandate_level` as universal — they're not,
they're meaningless to commands.

The shared core then holds exactly the parameters that genuinely mean the
same thing (or read meaningfully) on both sides: `task`, `input`,
`context`, file I/O, `criteria`, `guardrails`, `output_format`,
`verbosity`, and the foundational type formalisms (`int_range`,
`file_type`, `enum`, etc.).

The win: the skill-vs-command distinction is first-class and explicit.
The cost: cross-cutting axes (lifecycle, types, tree) are secondary —
they show up in multiple files. We handle the cost with a bridging
catalogue (see [`bridging.md`](./bridging.md)) and a subagent-overrides
catalogue (see [`overrides.md`](./overrides.md)).

---

## The picture

```text
                            ┌──────────────────────────┐
                            │      SHARED-CORE         │
                            │                          │
                            │ task, input, context,    │
                            │ file, directory, glob,   │
                            │ url, inline, format,     │
                            │ save_path, output_format,│
                            │ criteria, guardrails,    │
                            │ stop_condition,          │
                            │ test_command, file_type, │
                            │ int_range, verbosity     │
                            │                          │
                            │ + type formalisms        │
                            │   (int_range, file_type, │
                            │    enum, path, url,      │
                            │    glob, bool, list, dict)│
                            └────────────┬─────────────┘
                                         │
                                         │ (defines vocabulary)
                                         │
              ┌──────────────────────────┴──────────────────────────┐
              │                                                     │
              ▼                                                     ▼
   ┌──────────────────────┐        ◄──────────►       ┌──────────────────────┐
   │   COMMAND-PARAMS     │        bridging.md        │    SKILL-PARAMS      │
   │   (execution-side)   │     cross-references      │  (activation-side)   │
   │                      │                           │                      │
   │ parallelism          │                           │ name                 │
   │ n_candidates         │                           │ description          │
   │ num_experiments      │                           │ license, version     │
   │ num_partitions       │                           │ activation_trigger   │
   │                      │                           │ applicability_scope  │
   │ subagent_type        │                           │ precondition         │
   │ subagent_model       │                           │ trigger_keywords     │
   │ subagent_prompt      │                           │ negative_trigger     │
   │ subagent_constraints │                           │                      │
   │ depth, fan_out       │                           │ mandate_level        │
   │                      │                           │ hand_off             │
   │ model, focus_hints   │                           │ delegation_mode      │
   │ seed, temperature    │                           │ applies_to_artifacts │
   │                      │                           │ co_skills, precedence│
   │ selection_mode       │                           │                      │
   │ min_successes        │                           │ examples             │
   │ ranker, aggregator   │                           │ decision_framework   │
   │ compare_against      │                           │ references           │
   │                      │                           │ quality_checks       │
   │ isolation            │                           │ decomposition_pattern│
   │ base_branch          │                           │                      │
   │ worktree_name/root   │                           │                      │
   │ cleanup_policy       │                           │                      │
   │                      │                           │                      │
   │ auto_save_winner     │                           │                      │
   │ merge_mode/count     │                           │                      │
   │ delete_worktree      │                           │                      │
   │                      │                           │                      │
   │ timeout, retry_policy│                           │                      │
   │ relaunch_on_hang_*   │                           │                      │
   │ hang_policy          │                           │                      │
   │                      │                           │                      │
   │ require_diff         │                           │                      │
   │ include_terminal_log │                           │                      │
   │ test_cmd_per_worker  │                           │                      │
   └──────────┬───────────┘                           └──────────────────────┘
              │
              │ (subagent layer)
              ▼
   ┌──────────────────────┐
   │     overrides.md     │
   │  re-bindings at the  │
   │   child-agent layer  │
   │ (commands only —     │
   │  skills cannot spawn │
   │  subagents)          │
   └──────────────────────┘
```

---

## Files in this directory

| file | purpose | parameter count |
|---|---|---|
| [`README.md`](./README.md) | this file: angle, motivation, diagram, worked examples | n/a |
| [`shared-core.md`](./shared-core.md) | parameters meaningful in BOTH command and skill contexts + the type formalisms (`int_range`, `file_type`, `enum`, `path`, `url`, `glob`, `bool`, `list<T>`, `dict<K, V>`) | 18 params + 9 type formalisms |
| [`command-params.md`](./command-params.md) | execution-oriented parameters: replication, subagent tree, models, selection, isolation, lifecycle, robustness, reporting | 35 params |
| [`skill-params.md`](./skill-params.md) | activation/scope/guidance parameters: frontmatter, activation triggers, mandate level, hand-off, authoring sections | 21 params |
| [`overrides.md`](./overrides.md) | catalogue of how each parent parameter is re-bound at the subagent layer (commands only) | re-binding catalogue |
| [`bridging.md`](./bridging.md) | for each parameter, its reading on the OPPOSITE side of the namespace divide | cross-reference table |

**Total: 74 parameters** (18 shared-core + 35 command + 21 skill) plus 9
foundational type formalisms. Four names (`int_range`, `file_type`,
`glob`, `url`) appear both as type formalisms in `shared-core.md` §0 AND
as parameters in their own right elsewhere in shared-core; the parameter
count above counts each role once.

---

## Parameter spec template

Every parameter in every file follows this skeleton:

```text
### `canonical_name`
- aliases: `alt1`, `alt2`           (or `—` when there are none)
- definition: one-sentence prose explaining what the parameter is.
- namespace: shared-core | command | skill
- type: <type or type-formalism reference>
- default: <value> or `required`
- bridging: (when the parameter has cross-namespace meaning)
  - command: ...
  - skill: ...
- example: a concrete usage from a real or hypothetical artifact.
```

---

## Worked example 1 — command: `worktree-task-agent.md`

The full command lives at
[`ai-coding/plugins/ai-coding/commands/worktree-task-agent.md`](../plugins/ai-coding/commands/worktree-task-agent.md).
Its parameters map onto the three namespaces as follows:

| param in command | namespace | canonical name | notes |
|---|---|---|---|
| `{task}` | shared-core | `task` | inherited verbatim by every subagent (see [`overrides.md`](./overrides.md)). |
| `{base_branch}` | command | `base_branch` | scalar broadcast to every worktree. |
| `{worktree_name}` | command | `worktree_name` | derived-from-parent with `-<i>` suffix per child. |
| `{delete_worktree}` | command | `delete_worktree` | inherited per child. |
| `{merge_mode}` | command | `merge_mode` | parent-only; forbidden in child layer. |
| `{test_command}` | shared-core | `test_command` | inherited per child; list variant available as `test_command_per_worker`. |
| `{agent_model}` | command | `subagent_model` | the canonical example of list-by-position vs. scalar-broadcast re-binding. |
| `{parallelism}` | command | `parallelism` | the fan-out factor; forbidden to nest. |
| `{num_partitions}` | command | `num_partitions` | grouping of agents/models; semantics still under design (see `trajectory.md`). |
| `{stop_condition}` | shared-core | `stop_condition` | inherited per child. |

Implicit cross-namespace concerns this command relies on:

- `{guardrails}` — the command's `## Guardrails` section enumerates them
  (isolation, no-cross-tree edits, no-push, single-merge cap). These are
  shared-core in the ontology.
- `{output_format}` — the command's `## Output Format` section (Run
  Summary + per-worktree Worktree Results + Merge Recommendation + Merge
  Prompt). This is shared-core.

Reading via [`bridging.md`](./bridging.md), every command-only parameter
above has a skill-side reading of `n/a; consult parent` — confirming
this command is operating purely in the command-execution lane and is not
attempting to express skill-like activation semantics.

---

## Worked example 2 — skill: `conventional-commits/SKILL.md`

The full skill lives at
[`ai-coding/plugins/ai-coding/skills/conventional-commits/SKILL.md`](../plugins/ai-coding/skills/conventional-commits/SKILL.md).
Its YAML frontmatter today carries `name`, `description`, `license` only;
the rest of the parameter surface is implicit in the prose body. The
ontology lets us name those implicit knobs:

| concept in skill | namespace | canonical name | how it's expressed today |
|---|---|---|---|
| `name: conventional-commits` | skill | `name` | YAML frontmatter (live spec). |
| `description: "Format git commit messages..."` | skill | `description` | YAML frontmatter (live spec). |
| `license: MIT` | skill | `license` | YAML frontmatter (live spec). |
| "Use when the user asks to commit changes..." | skill | `activation_trigger` | implicit — embedded inside `description`. |
| "git commits" | skill | `applicability_scope` | implicit — implied by `description`. |
| "git diff --cached --stat is non-empty" | skill | `precondition` | implicit — Workflow step 1 "Check for staged changes". |
| "commit, git commit, committing" | skill | `trigger_keywords` | implicit — extractable from `description`. |
| every commit must conform | skill | `mandate_level: required` | implicit — the body is written as MUST clauses, no "optional" framing. |
| "produce a conventional commit message string" | skill | `hand_off` | implicit — the `## Examples` section IS the schema. |
| "agent reads the skill and applies it" | skill | `delegation_mode: inline-guidance` | implicit — today's default for all skills. |
| `git-commit-msg` | skill | `applies_to_artifacts` | implicit — the entire skill body is about commit messages. |
| the `## Examples` section | skill | `examples` | a real section in the body. |
| the `## Decision Framework` section | skill | `decision_framework` | a real section in the body. |
| `references/full-spec.md` | skill | `references` | a real reference. |
| the `## Quality Checks` section | skill | `quality_checks` | a real section in the body. |
| numbered 8-step `## Workflow` | skill | `decomposition_pattern: linear` | implicit — the workflow is linear. |
| "format commit messages" | shared-core | `task` | implicit on the skill side; reads as "the trigger task". |
| the commit message being drafted | shared-core | `context` | implicit — the artifact at activation time. |
| the `## Type Reference` + `## Message Best Practices` body | shared-core | `criteria` | implicit rubric the skill enforces. |
| the `## Examples` + `## Quality Checks` schema | shared-core | `output_format` | implicit; expressed via the skill's body, not a literal `## Output Format`. |
| MUST clauses about quoting and HEREDOC | shared-core | `guardrails` | implicit; embedded in `## Command Execution`. |
| `git log -1` post-step | shared-core | `test_command` | embedded in `## Workflow` step 8. |

Reading via [`bridging.md`](./bridging.md), every skill-only parameter
above has a command-side reading along the lines of "the closest analog
is the command's `## Workflow` / `## Output Format` / `## Guardrails`
section, but it isn't formally factored out as a parameter." This is
exactly the gap the two-namespace split makes visible: a command's
analogous concepts are baked into prose sections, whereas a skill's are
(potentially) hoistable into frontmatter.

---

## Worked example 3 — skill: `minimal-diffs/SKILL.md`

A briefer cross-check against the second shipped skill to confirm the
ontology generalizes:

| concept | namespace | canonical name | how expressed |
|---|---|---|---|
| `name: minimal-diffs` | skill | `name` | frontmatter |
| `description: "Apply minimal, surgical changes..."` | skill | `description` | frontmatter |
| "any file edit, refactor, fix" | skill | `applicability_scope` | embedded in `description` |
| `any` (no file-extension restriction) | skill | `applies_to_artifacts` | implicit |
| **behavior change, not artifact emission** | skill | `hand_off: {kind: behavior, ...}` | implicit |
| `mandate_level: default` (overridable when user explicitly requests broader refactor) | skill | `mandate_level` | implicit — the "When in doubt" section explicitly allows escalation |
| the `## What "minimal" means in practice` section | skill | `decision_framework` | a real section |
| the `## Examples` section | skill | `examples` | a real section |
| n/a | skill | `references` | not used by this skill |
| n/a | skill | `quality_checks` | not separately listed; rules embedded in the body |
| "edit files as instructed" | shared-core | `task` | implicit trigger task |
| the file under edit | shared-core | `context` | implicit |
| "noisy diff makes review harder" | shared-core | `criteria` | implicit rubric |
| MUST / "Don't" clauses throughout | shared-core | `guardrails` | implicit |

The contrast with `conventional-commits` is illuminating: `minimal-diffs`
has `hand_off.kind = behavior` (the skill changes how the agent edits,
not what it outputs), whereas `conventional-commits` has `hand_off.kind =
artifact` (the skill produces a commit-message string). This distinction
is invisible in the unstructured `description` text but becomes obvious
once `hand_off` is a first-class parameter.

---

## How to use this ontology in new artifacts

When authoring a new command:

1. Skim [`shared-core.md`](./shared-core.md) first; reuse the canonical
   names there for any parameter that has cross-namespace meaning.
2. Then go to [`command-params.md`](./command-params.md) and pull in the
   execution knobs that apply. Prefer canonical names over aliases.
3. If your command spawns subagents, consult
   [`overrides.md`](./overrides.md) for the re-binding shape of each
   parameter you propagate.
4. For each parameter you choose, restate its type using the formalisms
   in [`shared-core.md`](./shared-core.md) §0 (`int_range`, `file_type`,
   `enum`, …) — don't invent new type vocabulary.

When authoring a new skill:

1. Always declare the live-spec frontmatter (`name`, `description`,
   `license`) from [`skill-params.md`](./skill-params.md) §L.
2. Identify which §M (activation) sub-keys your skill needs to hoist out
   of `description` for clarity (`applicability_scope`,
   `trigger_keywords`, `negative_trigger`).
3. Declare your §N contract explicitly: `mandate_level` (default vs.
   required), `hand_off` (kind ∈ {artifact, behavior, tool-call, none},
   schema, destination), `applies_to_artifacts`.
4. Write the body using the §O sections: `examples`,
   `decision_framework` (when behavior branches), `references`,
   `quality_checks`.
5. Cross-check against [`bridging.md`](./bridging.md) to make sure your
   skill isn't accidentally trying to set command-only parameters
   (`parallelism`, `subagent_model`, `merge_mode`, etc.).

---

## Self-critique: weaknesses of this angle vs. alternatives

1. **Cross-cutting axes get fragmented.** Lifecycle (setup → execution →
   teardown), the subagent tree (parent → child → grandchild), and the
   robustness story (timeout, retry, hang_policy) all *also* cross commands
   in a way that a single "lifecycle" file or a single "tree" file would
   make easier to scan. Splitting by namespace forces these axes into the
   command file in chunks, scattered across sections D/E/I/J/K, which a
   lifecycle-first or tree-shaped ontology would handle more directly.
2. **The skill-side namespace is mostly aspirational.** Of the 21 skill
   parameters, only 3 are live spec today (`name`, `description`,
   `license`); the other 18 are hoisted from prose. This makes the
   skill-params surface look larger than the system actually parameterizes,
   and risks an "ontology bigger than the artifacts" failure mode. A
   flat-shared-dictionary or concern-first ontology would avoid the
   appearance of formal symmetry that doesn't exist yet.
3. **Shared-core can become a dumping ground.** Anything that has even a
   weak reading on both sides gets pulled into shared-core, which then
   accumulates parameters whose bridging notes are essentially "command:
   real meaning; skill: 'implicit, baked into the body'". Five or six of
   the shared-core entries are in this shape, and a type-first or
   concern-first ontology would either reify the formalisms separately
   (making shared-core leaner) or move the implicit-on-skill-side
   parameters fully into command-params with an explicit "n/a on skill
   side" note (making bridging.md unnecessary).
