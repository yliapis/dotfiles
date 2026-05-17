# Shared-Core Parameters

Parameters in this file have meaning in **both** command and skill contexts.
They form the common vocabulary that lets commands and skills reference the
same concept without re-inventing it. Each entry includes a `bridging` note
explaining how commands and skills interpret the parameter differently when
that matters.

This file also defines the **type formalisms** referenced from every other
file in this ontology (`int_range`, `file_type`, `enum`, `path`, `url`,
`glob`). When a parameter elsewhere says `type: int_range >= 1` or
`type: file_type {.md, .json}`, the formal meaning is defined here.

> See also: [`README.md`](./README.md) for the angle + diagram,
> [`command-params.md`](./command-params.md) for execution-oriented params,
> [`skill-params.md`](./skill-params.md) for activation/scope params,
> [`overrides.md`](./overrides.md) for subagent re-bindings,
> [`bridging.md`](./bridging.md) for cross-namespace cross-references.

---

## 0. Type formalisms

These are foundational types used by every parameter spec in this ontology.
They are not themselves parameters; they are the value-spec grammar.

### `int_range`
- aliases: `integer_interval`, `int_interval`
- definition: an integer-valued domain constraint expressed as a bound or
  closed/open interval.
- canonical forms:
  - `>= N` — N or greater
  - `> N` — strictly greater than N
  - `[a, b]` — closed interval, both ends inclusive
  - `(a, b)` — open interval, both ends exclusive
  - `[a, b)` / `(a, b]` — half-open
  - `(a, ∞)` / `[a, ∞)` — unbounded above
- example usage: `{parallelism}` is `int_range >= 1`; `{depth}` is
  `int_range [0, 8]`.

### `file_type`
- aliases: `extension`, `file_extension`
- definition: a restriction on accepted file extensions for a `file`, `glob`,
  or `directory` parameter.
- canonical forms:
  - `.md` — a single extension
  - `{.py, .ts, .tsx}` — a set of extensions
  - `any` — no extension restriction
- example usage: `conventional-commits` skill's `applies_to_artifacts` is
  `file_type any` (it governs commit messages, not files); a hypothetical
  markdown linter command's `{file}` might be `file_type .md`.

### `enum`
- aliases: `choice`, `oneof`
- definition: a closed set of allowed string values.
- canonical form: `enum {a | b | c}` (pipes separate variants).
- example usage: `{merge_mode}` is `enum {interactive | auto}`;
  `{selection_mode}` is `enum {manual | auto-best | synthesize}`.

### `path`
- aliases: `fs_path`
- definition: an absolute or artifact-relative filesystem path.
- canonical form: `path` (free-form) or `path[file_type X]` to combine with a
  file-type restriction.
- example usage: `{save_path}` is `path`; `{file}` is `path` constrained by
  `{file_type}` when present.

### `url`
- aliases: —
- definition: a fully-qualified URL (scheme required).
- canonical form: `url` (free-form, validated at consumption time).
- example usage: `{context}` may be a `url` pointing to a documentation page.

### `glob`
- aliases: `pattern`
- definition: a glob pattern matched against filesystem entries.
- canonical form: `glob` (e.g. `**/*.md`, `src/**/*.{ts,tsx}`).
- example usage: `{context}` may be a `glob` selecting many files at once.

### `bool`
- aliases: `boolean`, `flag`
- definition: `true` / `false`.
- canonical form: `bool`.
- example usage: `{require_diff}` is `bool`; `{delete_worktree}` is `bool`.

### `list<T>`
- aliases: `iterable<T>`, `array<T>`
- definition: an ordered collection of values of type `T`. Length constraints
  (e.g. "length MUST equal `{parallelism}`") are declared per parameter.
- canonical form: `list<T>` or `list<T>[len = N]` for length-pinned lists.
- example usage: `{agent_model}` may be `list<string>[len = {parallelism}]`.

### `dict<K, V>`
- aliases: `map<K, V>`, `record`
- definition: a key/value mapping.
- canonical form: `dict<K, V>`.
- example usage: `{focus_hints}` may be `dict<int, string>` mapping candidate
  index to a refinement angle.

---

## A. Task / intent

### `task`
- aliases: `mission`, `objective`
- definition: the work the artifact governs — commands execute it, skills
  trigger on it.
- namespace: shared-core
- type: string (free-form prose, typically a single imperative sentence)
- default: required
- bridging:
  - command: the imperative work the executing agent must complete; e.g.
    `worktree-task-agent.md`'s `{task}` is the agent's mission for the run.
  - skill: the kind of task whose presence activates the skill; encoded today
    inside the YAML `description` field. See [`skill-params.md`](./skill-params.md)
    → `activation_trigger`.
- example:
  - command: `{task}` = "Refactor the auth flow to use OAuth2."
  - skill: trigger description = "Use when the user asks to commit changes."

### `input`
- aliases: `payload`, `raw_input`
- definition: opaque text/payload supplied by the user or a parent agent at
  invocation time, before any structured parameter extraction.
- namespace: shared-core
- type: string | path | structured
- default: required (commands), n/a (skills)
- bridging:
  - command: text following the slash-command marker; e.g. `meta-prompt.md`'s
    `{input}` is everything after `/meta-prompt`.
  - skill: skills do not receive a discrete `input`; they observe the parent
    agent's full context and react. See `activation_trigger`.
- example: `/meta-prompt write a prompt that reviews a PR for security issues`
  → `{input}` = "write a prompt that reviews a PR for security issues".

### `context`
- aliases: `artifact`, `subject`, `target`
- definition: the artifact(s) the work operates on (one or many files, dirs,
  URLs, or inline content).
- namespace: shared-core
- type: `file | directory | url | inline | list<file>` (see `format`)
- default: required (most commands), implicit (most skills)
- bridging:
  - command: explicit parameter (see `critique.md`'s `{context}`).
  - skill: usually implicit — the file currently under edit, the commit being
    drafted, the diff being reviewed.
- example:
  - command: `{context}` = `src/auth/oauth.ts`.
  - skill: `minimal-diffs` activates against whatever file the agent is about
    to edit, without naming it.

---

## B. File I/O

### `file`
- aliases: `file_path`
- definition: a single filesystem path pointing to one file.
- namespace: shared-core
- type: `path` (optionally constrained by `file_type`)
- default: required when used
- bridging:
  - command: input source or output destination.
  - skill: the file under edit at the activation moment.
- example: `{file}` = `ai-coding/parameters/README.md`.

### `directory`
- aliases: `dir`, `folder`
- definition: a single filesystem path pointing to a directory.
- namespace: shared-core
- type: `path`
- default: required when used
- bridging:
  - command: bulk input or output root.
  - skill: scope hint (e.g. "applies to files under `tests/`").
- example: `{directory}` = `ai-coding/plugins/ai-coding/commands/`.

### `glob`
- aliases: `pattern`, `file_glob`
- definition: a glob pattern selecting multiple filesystem entries.
- namespace: shared-core
- type: `glob`
- default: optional
- bridging:
  - command: multi-file input selector (e.g. `{context}` = `**/*.md`).
  - skill: applicability scope expressed as a glob (see
    [`skill-params.md`](./skill-params.md) → `applies_to_artifacts`).
- example: `{glob}` = `ai-coding/**/*.md`.

### `url`
- aliases: `link`
- definition: a URL pointing at remote content used as input.
- namespace: shared-core
- type: `url`
- default: optional
- bridging:
  - command: fetched and treated as `{context}` content.
  - skill: rarely consumed directly; usually referenced from a skill's
    `references` list.
- example: `{url}` = `https://www.conventionalcommits.org/en/v1.0.0/`.

### `inline`
- aliases: `literal`, `text`
- definition: raw inline content (string) provided in lieu of a file/url.
- namespace: shared-core
- type: string
- default: optional
- bridging:
  - command: `{context}` or `{criteria}` provided inline rather than as a path.
  - skill: typically the snippet the user just pasted into chat.
- example: `{criteria}` = "Optimize for read latency over write latency."

### `format`
- aliases: `content_type`, `mime`
- definition: the kind of content held by a `{file}`, `{inline}`, `{context}`,
  or output payload.
- namespace: shared-core
- type: `enum {code | md | json | yaml | image | csv | binary | text}`
- default: inferred from `{file_type}` when possible; otherwise `text`
- bridging:
  - command: governs how a parameter is parsed and how output is rendered.
  - skill: signals what shape of content the skill emits via `hand_off`.
- example: `{format}` = `md` for prompt artifacts; `{format}` = `json` for
  structured reports.

### `save_path`
- aliases: `output_path`, `destination`
- definition: filesystem path at which to persist the artifact produced by
  the run.
- namespace: shared-core
- type: `path`
- default: optional; when unset, no file is written. Some commands infer a
  default (`meta-prompt.md` derives `.cursor/commands/<kebab-name>.md` from
  the H1).
- bridging:
  - command: where the produced artifact is written.
  - skill: where a skill-produced artifact (e.g. a commit message draft)
    should be saved. Usually n/a — skills hand off in-memory content.
- example: `{save_path}` = `.cursor/commands/critique.md`.

### `output_format`
- aliases: `result_schema`, `report_schema`
- definition: declared structure / schema / template that the produced output
  MUST conform to.
- namespace: shared-core
- type: string (often a reference to a schema name, template name, or inline
  skeleton)
- default: required when the command/skill has an Output Format section
- bridging:
  - command: typically the literal "Output Format" section of the command.
  - skill: the shape of the skill's `hand_off` payload (e.g. a conventional
    commit message).
- example: `{output_format}` = `markdown report with H2 sections: Summary,
  Findings, Open Questions`.

---

## C. Constraints

### `criteria`
- aliases: `rubric`, `judgment_criteria`
- definition: the standards used to evaluate work, expressed inline or as a
  file/dir/URL of criteria.
- namespace: shared-core
- type: `file | directory | url | inline`
- default: optional; commands like `critique.md` default to a "quality +
  determinism" baseline.
- bridging:
  - command: explicit evaluation rubric for `critique.md`-style commands.
  - skill: the quality-bar a skill enforces (e.g. `minimal-diffs`' "noisy
    diff makes review harder" rubric is implicit criteria).
- example: `{criteria}` = `ai-coding/criteria/security-review.md`.

### `guardrails`
- aliases: `constraints`, `must_not`
- definition: MUST / MUST NOT / Scope clauses that bound acceptable behavior.
- namespace: shared-core
- type: string (prose; conventionally rendered as a bulleted list)
- default: required (commands), implicit (skills bake guardrails into prose)
- bridging:
  - command: explicit `## Guardrails` section.
  - skill: the MUST / MUST NOT clauses embedded in the skill body; e.g.
    `minimal-diffs`' "Don't add what wasn't asked for".
- example: `MUST NOT modify {context}; analysis is read-only.`

### `stop_condition`
- aliases: `done_condition`, `completion_predicate`
- definition: an explicit observable condition that, when met, ends the work.
- namespace: shared-core
- type: string (often a predicate or a reference to `{test_command}`)
- default: optional; when omitted, "task implemented and verified" is
  conventional for commands and "trigger no longer applies" for skills.
- bridging:
  - command: see `worktree-task-agent.md` → `{stop_condition}`.
  - skill: implicit; the skill's mandate ends with the action it governs.
- example: `{stop_condition}` = "all tests in `pytest tests/` pass".

### `test_command`
- aliases: `verification_command`, `verify`
- definition: a shell command whose exit code verifies the work.
- namespace: shared-core
- type: string (shell command)
- default: optional
- bridging:
  - command: literal command run inside the execution context;
    `worktree-task-agent.md` uses it per worktree.
  - skill: skills rarely shell out; when they do, the `test_command` is
    embedded in their Workflow (e.g. `conventional-commits` uses
    `git log -1` as a verify step).
- example: `{test_command}` = `pnpm test --filter @app/auth`.

### `file_type`
- aliases: `extension`, `accepted_extension`
- definition: restriction on file extensions accepted by a `file`, `glob`, or
  `directory` parameter.
- namespace: shared-core
- type: `file_type` (see §0)
- default: `any`
- bridging:
  - command: validates input/output paths against extension whitelist.
  - skill: declares the file kinds the skill governs via
    `applies_to_artifacts`.
- example: `{file_type}` = `{.md}` for a markdown-only command.

### `int_range`
- aliases: `integer_interval`
- definition: integer-domain constraint for an integer parameter.
- namespace: shared-core
- type: `int_range` (see §0)
- default: required when used as a domain spec
- bridging:
  - command: bounds integer params like `{parallelism}`, `{depth}`,
    `{num_partitions}`.
  - skill: bounds integer skill params like `precedence` (rare).
- example: `{parallelism}` ∈ `int_range >= 1`; `{temperature}` is not an
  `int_range` (it's a float range, formalism not defined here).

---

## D. Reporting (cross-cutting)

### `verbosity`
- aliases: `log_level`, `detail`
- definition: how much detail the artifact emits in its final response.
- namespace: shared-core
- type: `enum {silent | concise | normal | verbose | debug}`
- default: `normal`
- bridging:
  - command: governs how much the run's output includes (terse summary vs.
    full diff + logs).
  - skill: governs how chatty the skill is when invoked (e.g. a `quiet`
    skill simply emits the result, a `verbose` skill explains each decision).
- example: `{verbosity}` = `verbose` for a debugging run.
