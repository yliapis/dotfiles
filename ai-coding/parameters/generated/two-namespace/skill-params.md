# Skill Parameters

Parameters in this file live exclusively on the **skill** side of the
ontology. A skill is a declarative knowledge artifact that activates based
on the agent's current context — the agent reads the skill, follows its
guidance, and emits results that conform to the skill's contract. Skills
are first-class units of "how this kind of work should be done" rather
than "do this specific thing right now."

The parameters below describe the dimensions a skill is actually
parameterized along today (the YAML frontmatter), the dimensions implicit
in the prose body (activation triggers, mandate level, hand-off shape,
decision framework, quality checks, references), and the dimensions a
future skill format could make first-class without changing what skills
already do.

> See also: [`shared-core.md`](./shared-core.md) for cross-namespace params
> (`task` reading as "trigger task", `criteria` reading as "implicit
> rubric", `guardrails` reading as "embedded MUST/MUST NOT clauses",
> `output_format` reading as `hand_off` schema),
> [`command-params.md`](./command-params.md) for execution-oriented
> command params that skills cannot set themselves,
> [`bridging.md`](./bridging.md) for the "n/a; consult parent" notes on
> command-only knobs.

The values referenced as `enum`, `bool`, `list<T>`, `dict<K, V>`,
`file_type` are defined in [`shared-core.md`](./shared-core.md) §0.

---

## L. Frontmatter metadata (the live spec)

Today's skill format uses YAML frontmatter on each `SKILL.md`. These are the
**only** parameters that are formally declared as parameters in current
skills. Every other parameter in this file is implicit-in-prose today and
would have to be hoisted to frontmatter (or to a richer skill format) to
become first-class.

### `name`
- aliases: `skill_id`, `id`
- definition: canonical, filesystem-safe identifier for the skill.
- namespace: skill
- type: string (kebab-case slug; MUST match the parent directory name)
- default: required
- bridging:
  - command: a command's identifier is its file path / slash-command name,
    not a frontmatter `name`. See `bridging.md`.
- example: `name: conventional-commits` in
  `ai-coding/plugins/ai-coding/skills/conventional-commits/SKILL.md`.

### `description`
- aliases: `summary`, `trigger`
- definition: a single prose sentence (or two) explaining what the skill
  does AND when to use it; today this string is the de-facto activation
  contract.
- namespace: skill
- type: string (prose; conventionally `<purpose>. Use when <triggers>.
  <value-prop>.`)
- default: required
- bridging:
  - command: a command's Task statement plays a similar role but is consumed
    only after explicit invocation, not used for trigger matching.
- example: `description: "Apply minimal, surgical changes when creating,
  editing, modifying, refactoring, or fixing any file. Use whenever making
  code edits, to avoid noisy diffs..."` (from `minimal-diffs`).

### `license`
- aliases: `spdx`
- definition: SPDX-style license identifier governing redistribution of the
  skill artifact.
- namespace: skill
- type: string (SPDX id)
- default: required (today both shipped skills use `MIT`)
- bridging:
  - command: commands in this repo do not declare a license in frontmatter
    (they inherit the repo license).
- example: `license: MIT`.

### `version`
- aliases: `semver`, `revision`
- definition: skill version string; not present in today's format, useful
  for breaking-change tracking when skills are distributed.
- namespace: skill
- type: string (SemVer recommended)
- default: optional; defaults to `0.0.0` when unset
- bridging:
  - command: commands have no version field; their revision is tracked via
    git history.
- example: `version: 1.0.0`.

### `frontmatter_keys`
- aliases: `reserved_keys`, `meta_keys`
- definition: the meta-parameter listing which keys are reserved frontmatter
  fields (so authors don't repurpose them). Today: `{name, description,
  license}`; forward-looking: add `version`, `activation_trigger`,
  `applies_to_artifacts`, `mandate_level`, `precedence`, `co_skills`.
- namespace: skill (meta)
- type: `list<string>`
- default: `[name, description, license]`
- bridging:
  - command: commands have no formal frontmatter schema.
- example: a future schema validator would consult this list.

---

## M. Activation

`description` (above) is today's catch-all activation contract. Hoisting
its sub-concerns to dedicated keys makes the contract testable and lets
multiple skills coexist without ambiguity. Every parameter in this section
is a refinement of `description`.

### `activation_trigger`
- aliases: `trigger_condition`, `when_to_apply`
- definition: the prose conditions under which the skill should be loaded
  and consulted by the parent agent; today this is encoded inside the
  `description` field (`...Use when the user asks to commit changes...`).
- namespace: skill
- type: string (prose; conventionally a "Use when X, Y, or Z" clause)
- default: required (subsumed by `description` if not hoisted)
- bridging:
  - command: a command does not have a trigger — it is invoked explicitly.
    The closest analog is the prose Task statement, but only after
    invocation. See `bridging.md`.
- example: from `conventional-commits`: "Use when the user asks to commit
  changes, create a git commit, or mentions committing code."

### `applicability_scope`
- aliases: `domain`, `applies_to`
- definition: the categorical domain(s) the skill governs (e.g. "git
  commits", "any file edit", "markdown formatting", "React components").
- namespace: skill
- type: `list<string>` (canonical taxonomy TBD; today free-form)
- default: required (extracted from `description` if not hoisted)
- bridging:
  - command: the closest analog is a command's "Scope:" line in
    `## Guardrails`.
- example: `applicability_scope: [git-commit]` for `conventional-commits`;
  `applicability_scope: [file-edit, code-edit]` for `minimal-diffs`.

### `precondition`
- aliases: `requires`, `prereq`
- definition: an observable fact that MUST be true before the skill can
  apply (e.g. "there are staged changes" for a commit skill).
- namespace: skill
- type: string (prose predicate, or a `{test_command}` reference)
- default: optional
- bridging:
  - command: analogous to a command's "Workflow → Resolve / Validate" step.
- example: `precondition: "git diff --cached --stat is non-empty"` for
  `conventional-commits` (the skill's Workflow already does this).

### `trigger_keywords`
- aliases: `keywords`, `hot_words`
- definition: explicit keywords whose appearance in user prompts strongly
  imply activation; synthesized from `description` for routing.
- namespace: skill
- type: `list<string>`
- default: extracted from `description` when not hoisted
- bridging:
  - command: a command's slash-name is its only routing keyword.
- example: `trigger_keywords: [commit, "git commit", committing]` for
  `conventional-commits`.

### `negative_trigger`
- aliases: `do_not_use_when`, `anti_trigger`
- definition: prose conditions under which the skill should explicitly NOT
  apply, even if `activation_trigger` partially matches.
- namespace: skill
- type: string (prose)
- default: optional
- bridging:
  - command: the closest analog is a command's "Scope: out of scope" clause.
- example: `negative_trigger: "Do not use when the user is undoing or
  reverting a previous commit; let them re-use the prior message."`

---

## N. Scope / guidance contract

### `mandate_level`
- aliases: `strictness`, `enforcement`
- definition: how strongly the parent agent must obey the skill once it
  activates.
- namespace: skill
- type: `enum {recommendation | default | required}`
- default: `default`
- bridging:
  - command: a command's `## Guardrails` clauses are implicitly `required`
    within that command's invocation; commands have no `recommendation`
    mode. See [`command-params.md`](./command-params.md) →
    `subagent_constraints`.
- example: `mandate_level: required` for `conventional-commits` (every
  commit must conform); `mandate_level: default` for `minimal-diffs` (the
  default behavior, overridable when the user explicitly requests a broader
  refactor).

### `hand_off`
- aliases: `output_contract`, `produces`, `emits`
- definition: the shape, content, and destination of what the skill returns
  to the parent agent (a formatted message, an edit diff style, a checklist,
  a tool invocation, or nothing-but-behavioral-change).
- namespace: skill
- type: `dict<{kind: enum, schema: string, destination: enum}>`
  - `kind` ∈ `{artifact | behavior | tool-call | none}`
  - `schema` references a shape (e.g. "conventional commit message string")
  - `destination` ∈ `{parent-agent | stdout | file | git-commit-msg}`
- default: required
- bridging:
  - command: the command's `## Output Format` section plays the same role.
    See [`shared-core.md`](./shared-core.md) → `output_format`.
- example:
  - `conventional-commits`: `hand_off = {kind: artifact, schema:
    "conventional commit message string", destination: git-commit-msg}`.
  - `minimal-diffs`: `hand_off = {kind: behavior, schema: "edits that
    preserve unrelated formatting", destination: parent-agent}` — i.e.
    the skill changes how the agent edits, not what it emits.

### `delegation_mode`
- aliases: `consumption_mode`, `embedding`
- definition: how the skill is consumed by the parent agent.
- namespace: skill
- type: `enum {inline-guidance | sub-agent | tool-execution}`
  - `inline-guidance` — agent reads the skill and applies it itself
    (today's default).
  - `sub-agent` — parent spawns a dedicated subagent that holds the skill
    as its system prompt.
  - `tool-execution` — the skill's Workflow is executed as a sequence of
    tool calls (potentially deterministically).
- default: `inline-guidance`
- bridging:
  - command: a command always runs in its own agent invocation; the closest
    analog is `subagent_type` in [`command-params.md`](./command-params.md).
- example: `delegation_mode: inline-guidance` for both shipped skills.

### `applies_to_artifacts`
- aliases: `governs`, `applies_to_files`
- definition: the file kinds (and other artifact kinds) the skill governs;
  uses the `file_type` formalism.
- namespace: skill
- type: `file_type` | `list<file_type>` | `glob` | `enum {git-commit-msg |
  pull-request-body | chat-reply | any}`
- default: `any`
- bridging:
  - command: a command's `{file_type}` / `{glob}` parameters serve the
    parallel role of input restriction.
- example: `applies_to_artifacts: git-commit-msg` for
  `conventional-commits`; `applies_to_artifacts: any` for `minimal-diffs`.

### `co_skills`
- aliases: `companion_skills`, `pairs_with`
- definition: other skills that are commonly invoked together with this one.
- namespace: skill
- type: `list<string>` (skill `name`s)
- default: `[]`
- bridging:
  - command: a command may invoke other commands but does not list them in
    metadata; the dependency is in the Workflow body.
- example: `co_skills: [minimal-diffs]` for any skill that produces edits.

### `precedence`
- aliases: `priority`, `rank`
- definition: integer priority used when multiple skills compete to apply to
  the same context; higher wins.
- namespace: skill
- type: `int_range >= 0`
- default: `100`
- bridging:
  - command: commands do not compete (the user picks one explicitly).
- example: `precedence: 150` for a strict-org-policy skill that should
  shadow a generic `conventional-commits` skill.

---

## O. Authoring / discovery

These parameters describe sections that every well-written skill body
already contains (today, as prose in the body), making each section a
first-class addressable artifact would enable validation, indexing, and
re-use across skills.

### `examples`
- aliases: `sample_invocations`, `samples`
- definition: concrete example invocations that illustrate when the skill
  applies and what it produces.
- namespace: skill
- type: `list<dict<{title: string, input: string, output: string}>>`
- default: required for any non-trivial skill (both shipped skills supply
  an `## Examples` section)
- bridging:
  - command: a command's Output Format section often includes one example;
    [`meta-prompt.md`](../plugins/ai-coding/commands/meta-prompt.md) goes
    further and embeds a full `## Help Message` with examples.
- example: see `conventional-commits` → `## Examples` for the full set.

### `decision_framework`
- aliases: `branching_logic`, `when_to_use_what`
- definition: explicit branching that the skill body provides to disambiguate
  sub-cases (e.g. `conventional-commits`'s "When determining commit type,
  ask: does it add new functionality? → `feat` ...").
- namespace: skill
- type: string (prose; conventionally a Q→branch list)
- default: optional; required when the skill governs multi-modal behavior.
- bridging:
  - command: a command's Workflow steps already encode branching.
- example: `conventional-commits` → `## Decision Framework`.

### `references`
- aliases: `see_also`, `bibliography`
- definition: pointers to supporting documents that ground the skill (specs,
  RFCs, internal style guides) and are read on demand rather than at every
  activation.
- namespace: skill
- type: `list<path | url>`
- default: `[]`
- bridging:
  - command: a command may cite references inline; no formal field.
- example: `conventional-commits` → `references/full-spec.md` (full
  Conventional Commits 1.0.0 spec).

### `quality_checks`
- aliases: `invariants`, `post_conditions`, `checklist`
- definition: observable checks the parent agent runs after applying the
  skill, to verify the hand-off conforms to the contract.
- namespace: skill
- type: `list<string>` (each item a predicate or a `{test_command}`-style
  string)
- default: optional; recommended for any `mandate_level: required` skill.
- bridging:
  - command: a command's `## Success Criteria` plays the same role; the
    skill-side version is typically expressed as a bulleted checklist.
- example: `conventional-commits` → `## Quality Checks`:
  - [ ] Message accurately describes the changes
  - [ ] Type correctly categorizes the change
  - [ ] Description is clear and under 50 characters

### `decomposition_pattern`
- aliases: `workflow_shape`, `process_pattern`
- definition: declared shape of the skill's Workflow section (e.g.
  "linear-N-step", "branching-by-decision-framework", "checklist-only").
- namespace: skill
- type: `enum {linear | branching | checklist | hybrid}`
- default: `linear`
- bridging:
  - command: a command's Workflow is always a numbered linear sequence in
    today's format.
- example: `conventional-commits` → `linear` (its `## Workflow` is a
  numbered 8-step procedure).

---

## P. Skill-side reading of shared-core params

Several shared-core params have skill-side readings that don't fit the
"override" pattern (because skills don't truly own these params, they only
reinterpret them). The full bridging table lives in
[`bridging.md`](./bridging.md); summarized here for orientation:

| shared-core param | skill-side reading |
|---|---|
| `task` | trigger task ("the kind of work that activates me") |
| `context` | implicit — the artifact under edit |
| `criteria` | implicit rubric baked into the skill body |
| `guardrails` | the MUST / MUST NOT clauses embedded in the body |
| `output_format` | the `hand_off` schema |
| `verbosity` | governs how chatty the skill is in its response |
| `test_command` | usually a verify step inside the skill's `## Workflow` |
| `stop_condition` | implicit — "the action the skill governs is complete" |

---

## Index of skill-only parameters

| # | parameter | section |
|--:|---|---|
|  1 | `name` | L. Frontmatter |
|  2 | `description` | L. Frontmatter |
|  3 | `license` | L. Frontmatter |
|  4 | `version` | L. Frontmatter |
|  5 | `frontmatter_keys` | L. Frontmatter |
|  6 | `activation_trigger` | M. Activation |
|  7 | `applicability_scope` | M. Activation |
|  8 | `precondition` | M. Activation |
|  9 | `trigger_keywords` | M. Activation |
| 10 | `negative_trigger` | M. Activation |
| 11 | `mandate_level` | N. Scope / guidance |
| 12 | `hand_off` | N. Scope / guidance |
| 13 | `delegation_mode` | N. Scope / guidance |
| 14 | `applies_to_artifacts` | N. Scope / guidance |
| 15 | `co_skills` | N. Scope / guidance |
| 16 | `precedence` | N. Scope / guidance |
| 17 | `examples` | O. Authoring / discovery |
| 18 | `decision_framework` | O. Authoring / discovery |
| 19 | `references` | O. Authoring / discovery |
| 20 | `quality_checks` | O. Authoring / discovery |
| 21 | `decomposition_pattern` | O. Authoring / discovery |
