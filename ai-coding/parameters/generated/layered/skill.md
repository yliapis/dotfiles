# `skill.*` — Parameters of a Skill (Activation Plane)

The `skill.*` namespace describes the **activation plane**: parameters that define when and how a skill fires, what it promises, and what it contributes to whatever command or subagent activated it. Skills do NOT have an invocation parameter list the way commands do — they are auto-activated by the agent runtime when their `skill.task` description matches the situation. The parameters in this layer therefore describe a **declaration**, not a **call**.

A skill that activates inside a command's orchestrator contributes to that orchestrator's effective guardrails, criteria, and (sometimes) output format. A skill that activates inside a subagent contributes only at that slot's scope. The merge rules live in `cross-layer.md`.

**Read order:** read `shared.md` for value-type references, then this file. `command.md` and `subagent.md` are useful for the cross-layer sections at the bottom.

---

## Convention reminder

- Skills are *declared*, not *invoked*. Every `skill.*` parameter is therefore a property of a `SKILL.md` file, not an argument someone supplies.
- The runtime equivalent of a "default value" for skill parameters is "what the runtime substitutes when the SKILL.md omits the field".
- The `description` field in a SKILL.md frontmatter maps to BOTH `skill.description` (the short index entry) AND `skill.task` (the activation trigger). The two are separable concepts that today happen to share a source string.

---

## Index

### Identity
- `skill.name`, `skill.description`, `skill.license`, `skill.version`

### Activation
- `skill.task`, `skill.applies_to`, `skill.file_type`, `skill.priority`

### Contract
- `skill.input`, `skill.output_format`, `skill.guardrails`, `skill.criteria`, `skill.scope`

### Bundle
- `skill.references`, `skill.examples`

### Composition
- `skill.requires`, `skill.conflicts_with`

---

## Identity

### `skill.name`

**Definition.** A short, kebab-case, repo-wide-unique identifier for the skill. Used by the runtime to address it (e.g., for logs, telemetry, conflict resolution).

**Cross-layer notes.** No sibling in `command.*` or `subagent.*` — names are for activation indexing, not for orchestration.

**Type.** `string` (kebab-case, ASCII alphanumerics + hyphens).

**Default.** Required (and MUST match the SKILL.md's frontmatter `name:` field, if present).

**Example.**
```text
skill.name: "conventional-commits"
```

---

### `skill.description`

**Definition.** A one-paragraph index entry shown to the agent runtime so it can decide whether the skill is relevant. SHOULD be self-contained and grounded in concrete trigger phrases ("Use when the user...").

**Cross-layer notes.** Distinct from `skill.task`. Today both are commonly sourced from the SKILL.md frontmatter `description:`, but they have separable semantics: `skill.description` is for *discovery*, `skill.task` is for *activation*.

**Type.** `shared.inline`.

**Default.** Required.

**Example.**
```text
skill.description: "Format git commit messages following Conventional Commits 1.0.0 specification. Use when the user asks to commit changes, create a git commit, or mentions committing code."
```

---

### `skill.license`

**Definition.** SPDX license identifier for the skill body.

**Cross-layer notes.** No sibling in other layers.

**Type.** `string` (SPDX id, e.g. `MIT`, `Apache-2.0`).

**Default.** Inherited from the repo if unset.

**Example.**
```text
skill.license: "MIT"
```

---

### `skill.version`

**Definition.** Semantic version of the skill. Skills MAY break compatibility with prior versions and bumping `skill.version` MUST follow SemVer.

**Cross-layer notes.** No sibling. Useful for skill marketplaces.

**Type.** `string` (SemVer).

**Default.** Unset (interpreted as `0.0.0`).

**Example.**
```text
skill.version: "1.0.0"
```

---

## Activation

### `skill.task`

**Definition.** The trigger description that tells the agent runtime *when* this skill should activate — phrased as the *kind of work* the skill exists to support. This is the same root name as `command.task` and `subagent.task` but a CATEGORICAL description, not an invocation.

**Cross-layer notes.** Sibling roots: `command.task` (a single invocation's work), `subagent.task` (one slot's scoped work). Mnemonic: `command.task` and `subagent.task` answer "what should I do RIGHT NOW?"; `skill.task` answers "what category of moment activates me?". See `cross-layer.md § task`.

**Type.** `shared.inline` (typically 1–3 sentences, starting with an imperative verb describing the support the skill provides).

**Default.** Required. (If absent from the SKILL.md, the runtime cannot decide when to activate.)

**Example.**
```text
skill.task: "Format git commit messages following Conventional Commits 1.0.0 specification."
```

---

### `skill.applies_to`

**Definition.** Optional file-pattern restriction that scopes activation to specific paths (e.g., a code-style skill that only applies to `*.py`).

**Cross-layer notes.** When a skill activates inside a subagent, `skill.applies_to` is matched against `subagent.context`, not against the whole repo.

**Type.** `list<shared.glob>?`.

**Default.** Unset (no path restriction).

**Example.**
```text
skill.applies_to: ["**/*.py", "**/pyproject.toml"]
```

---

### `skill.file_type`

**Definition.** A narrower restriction than `skill.applies_to`: activates only when the artifact under consideration has one of the listed types.

**Cross-layer notes.** Uses the `shared.file_type` formalism.

**Type.** `shared.file_type?`.

**Default.** Unset.

**Example.**
```text
skill.file_type: [".md", ".mdx"]
```

---

### `skill.priority`

**Definition.** When multiple skills match the same activation context, `skill.priority` provides the tiebreaker (higher wins).

**Cross-layer notes.** No sibling. The runtime owns the conflict-resolution semantics; `skill.priority` is just one input.

**Type.** `int with shared.int_range [0, 1000]`.

**Default.** `100`.

**Example.**
```text
skill.priority: 200   # outranks a sibling skill matching the same trigger
```

---

## Contract

### `skill.input`

**Definition.** What kind of payload the skill expects to find in the activating context (e.g., "staged git changes", "a markdown body without front-matter"). This is a DESCRIPTION, not a typed argument list, because skills are not invoked with arguments.

**Cross-layer notes.** Sibling root: `command.input` (the raw user text after a slash command). `skill.input` is a CATEGORY of input ("staged commits"), not a literal string the user typed.

**Type.** `shared.inline` (natural language description, optionally annotated with a `shared.format`).

**Default.** Unset (skill works against whatever the activating context provides).

**Example.**
```text
skill.input: "the set of files in `git diff --cached`."
```

---

### `skill.output_format`

**Definition.** The structural contract the skill promises for whatever output it produces inside the activating context (commit message format, code style, etc.).

**Cross-layer notes.** Sibling roots: `command.output_format` (the user-facing final), `subagent.output_format` (per-slot structured intermediate). When a skill activates inside a command, the orchestrator MUST satisfy `skill.output_format` as part of its `command.output_format`.

**Type.** `shared.output_format`.

**Default.** Unset (the skill does not constrain output shape).

**Example.**
```text
skill.output_format: "text:conventional-commit-line"
```

---

### `skill.guardrails`

**Definition.** Hard invariants the skill brings into every activating context — things the activating command or subagent MUST respect once the skill fires.

**Cross-layer notes.** Sibling roots: `command.guardrails`, `subagent.guardrails`. The effective guardrail set in a subagent is `command.guardrails ∪ command.subagent_constraints ∪ ⋃ skill.guardrails`. See `cross-layer.md § guardrails`.

**Type.** `shared.addressable` (list of MUST / MUST NOT / Scope lines).

**Default.** Empty list (the skill imposes nothing).

**Example.**
```text
skill.guardrails:
  - MUST use single quotes around `!` to avoid shell escaping issues.
  - MUST NOT include period at end of commit description.
```

---

### `skill.criteria`

**Definition.** The quality bar the skill applies to its own output (or to the activating context's output, when the skill is a critic-style skill like `minimal-diffs`).

**Cross-layer notes.** Sibling roots: `command.criteria`, `subagent.criteria`. When a command activates a skill, `skill.criteria` is unioned into the effective criteria the subagents apply.

**Type.** `shared.addressable`.

**Default.** Unset.

**Example.**
```text
skill.criteria:
  - "Description under 50 characters."
  - "Type correctly categorizes the change."
```

---

### `skill.scope`

**Definition.** A short prose statement of what is in scope and (especially) what is out of scope for the skill. Helps the runtime avoid spurious activation.

**Cross-layer notes.** Compatible with the "Scope: ..." line common in `command.guardrails` and `subagent.guardrails`, but lives one layer up: this scopes the SKILL itself, not a single invocation.

**Type.** `shared.inline`.

**Default.** Unset.

**Example.**
```text
skill.scope: "Commit message formatting only. Out of scope: staging logic, branch management, PR descriptions."
```

---

## Bundle

### `skill.references`

**Definition.** Additional files the skill bundles (e.g., `references/full-spec.md`), addressed relative to the SKILL.md.

**Cross-layer notes.** Once the skill activates, these are typically read on demand by the runtime. The runtime MUST resolve `skill.references[i]` relative to the SKILL.md directory, NOT relative to the activating context's working tree.

**Type.** `list<shared.addressable>`.

**Default.** Empty.

**Example.**
```text
skill.references:
  - "references/full-spec.md"
  - "references/examples/"
```

---

### `skill.examples`

**Definition.** Worked examples the skill bundles, useful for few-shot conditioning. May be inline or referenced.

**Cross-layer notes.** Distinct from `skill.references` only by intent — examples are for *conditioning*, references are for *citation*.

**Type.** `list<shared.addressable>`.

**Default.** Empty.

**Example.**
```text
skill.examples:
  - "examples/breaking-change.md"
  - "examples/with-issue-reference.md"
```

---

## Composition

### `skill.requires`

**Definition.** Other skills that MUST also activate for this skill to function (e.g., a `release-notes` skill might require `conventional-commits`).

**Cross-layer notes.** The runtime resolves transitive requires; cycles are an error.

**Type.** `list<skill.name>`.

**Default.** Empty.

**Example.**
```text
skill.requires: ["conventional-commits"]
```

---

### `skill.conflicts_with`

**Definition.** Other skills that MUST NOT activate alongside this skill (e.g., two style skills with incompatible formatting rules).

**Cross-layer notes.** When two `conflicts_with`-paired skills both match, the runtime picks the one with the higher `skill.priority`; ties are an activation error.

**Type.** `list<skill.name>`.

**Default.** Empty.

**Example.**
```text
skill.conflicts_with: ["non-conventional-commits"]
```
