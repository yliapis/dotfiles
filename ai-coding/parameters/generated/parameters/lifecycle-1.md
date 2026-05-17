# Stage 1 — Input

**Position in lifecycle:** first stage. Nothing precedes it.

**Purpose:** turn the raw invocation (the slash-command call, the file the user dragged in, the `/foo bar=baz` arguments) into resolved, typed values that downstream stages can consume without ambiguity. This is where every parameter is first **read in**; later stages either reference what input resolved or **write out** derived values.

**Flows in:** the user's invocation string and any referenced files / URLs / inline blobs.
**Flows out:** a fully-resolved parameter bag — task statement, context payloads, criteria text, type-checked numerics, persistence intent. Every later stage assumes "input has run" and reads from this bag.

**Type formalisms live here.** `int_range`, `file_type`, and the source-form selectors (`file` / `directory` / `glob` / `url` / `inline`) are not lifecycle stages — they are type machinery that the input stage uses to validate everything else. They are documented here once and referenced from every later file.

**Skipped when:** never. Even a parameterless command runs an input stage (resolving zero parameters, validating zero inputs).

---

## Source-form parameters (where input data comes from)

These are mutually-exclusive "shapes" a value can take. A parameter declared as `source_ref` accepts any of these.

### `file`

**Aliases:** `path`, `filepath`
**Definition:** A single filesystem path whose contents are loaded into the parameter.
**Stages:** input (read).
**Depth:** both. Outer commands consume user-supplied files; inner subagents may receive a sliced sub-path.
**Type:** absolute or workspace-relative path; constrained by `file_type` when the consuming parameter declares one.
**Default:** n/a (a source-form, not a parameter on its own — selected when the value parses as a path that exists).

**Example:**

```
{context} = file:./src/parseConfig.ts
```

### `directory`

**Aliases:** `dir`, `folder`
**Definition:** A filesystem directory whose contents (recursively or one level deep, per consumer) are loaded.
**Stages:** input (read).
**Depth:** both. Outer commands receive whole trees; inner agents often get a per-partition sub-directory.
**Type:** absolute or workspace-relative path.
**Default:** n/a.

**Example:**

```
{context} = directory:./ai-coding/plugins/ai-coding/commands
```

### `glob`

**Aliases:** `pattern`, `globs`
**Definition:** A glob pattern (or list of patterns) expanded against the workspace to produce a file set.
**Stages:** input (read).
**Depth:** both.
**Type:** glob string; recursive `**` prefix is auto-applied when the pattern does not start with `**/`.
**Default:** n/a.

**Example:**

```
{context} = glob:**/*.md
```

### `url`

**Aliases:** `link`, `uri`
**Definition:** An `http(s)` URL whose body is fetched and converted to markdown text.
**Stages:** input (read).
**Depth:** outer (subagents rarely fetch URLs directly; usually they receive the already-fetched body).
**Type:** URL with `http` or `https` scheme.
**Default:** n/a.

**Example:**

```
{criteria} = url:https://example.com/our-style-guide.md
```

### `inline`

**Aliases:** `literal`, `text`
**Definition:** Raw text supplied directly on the command line or in a code fence; used as-is.
**Stages:** input (read).
**Depth:** both.
**Type:** text (no path resolution attempted).
**Default:** n/a.

**Example:**

```
{criteria} = inline:"Findings must cite line numbers. Severity uses critical/major/minor."
```

### `format`

**Aliases:** `mime`, `content_type`
**Definition:** Declared content type of a loaded payload, when the source form alone is ambiguous.
**Stages:** input (read).
**Depth:** both.
**Type:** enum `code | md | json | image | csv | binary | text`.
**Default:** inferred from file extension or content sniffing; unset when ambiguous and the consumer accepts any.

**Example:**

```
{context} = file:./results.csv  format=csv
```

---

## Type-formalism parameters (meta — used to constrain other parameters)

These are not invoked directly; they appear in the **Type** field of other parameters' definitions. They are first-class citizens of the input stage because validation lives here.

### `file_type`

**Aliases:** `extension`, `ext`, `allowed_extensions`
**Definition:** A whitelist of file extensions accepted when a parameter resolves to a `file` source-form.
**Stages:** input (validation predicate).
**Depth:** both.
**Type:** set of dotted extension strings, e.g. `{.md, .json}`.
**Default:** unrestricted unless the consuming parameter specifies one.

**Example:**

```
{criteria}: file_type ∈ {.md, .txt}
   ⇒ file:./rubric.md   ✓ accepted
   ⇒ file:./rubric.bin  ✗ rejected at input
```

### `int_range`

**Aliases:** `integer_interval`, `range`
**Definition:** A domain spec for integer parameters, written in standard interval notation.
**Stages:** input (validation predicate).
**Depth:** both.
**Type:** one of `>= N`, `<= N`, `[low, high]`, `(low, high)`, `(low, ∞)`, etc. Endpoints may reference other parameters (e.g. `[0, n_candidates]`).
**Default:** unrestricted unless declared.

**Examples:**

```
{parallel}:        int_range[>= 1]
{min_successes}:   int_range[0, n_candidates]
{temperature}:     float in [0, 2]   (analogous, not int)
```

---

## Task / intent parameters

### `task`

**Aliases:** `goal`, `objective`
**Definition:** A natural-language statement of what the agent (outer or inner) must accomplish.
**Stages:** input (read) → plan (decomposed into per-slot prompts when fanning out) → execute (consumed by each agent).
**Depth:** **both.** Outer = the command's overall task; inner = each subagent's slice, often derived but not always equal.
**Type:** text.
**Default:** required when the command does anything more than a single helper read.

**Example:**

```
{task} = "implement keyboard navigation for the file tree and add Playwright coverage"
```

### `input`

**Aliases:** `user_input`, `raw_input`
**Definition:** The verbatim string the user typed after the slash-command name, before any parameter parsing.
**Stages:** input (read).
**Depth:** outer only (subagents receive structured prompts, not raw `/foo …` strings).
**Type:** text.
**Default:** empty string.

**Example:**

```
User types: /meta-prompt save as /pr-review: review a PR for security issues
{input} = "save as /pr-review: review a PR for security issues"
```

### `context`

**Aliases:** `artifact`, `subject`, `material`
**Definition:** The data the task operates on or reasons about — the *thing* being changed, critiqued, or summarized.
**Stages:** input (read) → execute (referenced by each agent) → evaluate (the criteria are applied against it).
**Depth:** both. Outer = whole context; inner = a per-agent slice or scope.
**Type:** `source_ref` — accepts `file`, `directory`, `glob`, `url`, or `inline`.
**Default:** required for analysis commands; absent for pure-generation commands.

**Example:**

```
{context} = file:./src/parseConfig.ts
{context} = directory:./ai-coding/plugins
{context} = inline:"```py\ndef foo():\n    return None\n```"
```

---

## Criteria / constraint parameters (resolved at input, consumed later)

### `criteria`

**Aliases:** `rubric`, `judgment_criteria`, `standards`
**Definition:** The yardstick the agent (or evaluator) judges work against.
**Stages:** input (read) → evaluate (applied).
**Depth:** both. Outer = command-wide criteria; inner = per-subagent criteria, defaults to outer.
**Type:** `source_ref` — file / directory / inline. When file, `file_type ∈ {.md, .txt}` by convention.
**Default:** command-specific. For `critique.md`: `quality + determinism`.

**Example:**

```
{criteria} = inline:"determinism, idempotency, clarity"
{criteria} = file:./rubrics/security-review.md
```

### `guardrails`

**Aliases:** `constraints`, `must_must_not`
**Definition:** Hard MUST / MUST-NOT / Scope rules the agent may not violate.
**Stages:** input (read) → execute (enforced during agent run) → evaluate (post-hoc check).
**Depth:** both. Inner often inherits outer plus subagent-specific additions.
**Type:** text or `source_ref`.
**Default:** command-specific (the `## Guardrails` section of the command prompt).

**Example:**

```
{guardrails} = inline:"MUST NOT modify the working tree. MUST NOT spawn more than 4 subagents."
```

### `stop_condition`

**Aliases:** `done_when`, `halt_condition`, `completion_signal`
**Definition:** An explicit termination predicate beyond "task implemented and verified".
**Stages:** input (read) → execute (consulted to decide when to stop) → evaluate (verified post-run).
**Depth:** both.
**Type:** text predicate, or a `test_command` whose `exit == 0` signals done.
**Default:** none (the implicit "task is done" suffices).

**Example:**

```
{stop_condition} = "all Playwright tests pass AND no TypeScript errors AND README updated"
```

---

## Forward-declaration parameters (resolved at input, applied in a later stage)

These exist solely so the user can express *intent* at invocation time for a downstream stage.

### `save_path`

**Aliases:** `output_path`, `out`, `dest`
**Definition:** Filesystem path where the final artifact (rendered prompt, report, diff bundle) is written.
**Stages:** input (read) → persist (written to).
**Depth:** both. Outer = where the final aggregated artifact lands; inner = where each candidate's artifact lands (typically derived from outer).
**Type:** file path. `file_type` may be constrained by the command (e.g. `meta-prompt.md` → `.md`).
**Default:** unset (write nothing). When save intent is detected without a path, commands default to a derived location (e.g. `meta-prompt.md` → `.cursor/commands/<kebab-name>.md`).

**Example:**

```
{save_path} = .cursor/commands/pr-review.md
```

### `output_format`

**Aliases:** `output_shape`, `render_format`
**Definition:** The shape of the final rendered artifact.
**Stages:** input (read) → report (applied).
**Depth:** outer (subagents typically emit a canonical interchange shape; only the outer report cares).
**Type:** enum `markdown | json | diff | raw | report-template`.
**Default:** `markdown`.

**Example:**

```
{output_format} = json
```

### `compare_against`

**Aliases:** `baseline`, `reference`
**Definition:** A reference artifact used during evaluate to rank candidates against a baseline.
**Stages:** input (read) → evaluate (used by the ranker).
**Depth:** outer (typically — comparing N candidates against one baseline).
**Type:** `source_ref`.
**Default:** none.

**Example:**

```
{compare_against} = file:./original-prompt.md
```

### `selection_mode`

**Aliases:** `selector_mode`
**Definition:** How the winning candidate (or set) is chosen after evaluate.
**Stages:** input (read) → select (applied).
**Depth:** outer (select is an outer-stage concern; nested subagents rarely re-select).
**Type:** enum `manual | auto-best | synthesize`.
**Default:** `manual`.

**Example:**

```
{selection_mode} = auto-best
```

### `aggregator`

**Aliases:** `candidate_aggregator`, `merger`, `synthesizer`
**Definition:** A command or prompt that merges multiple candidate outputs into one synthesized artifact (used when `selection_mode = synthesize`).
**Stages:** input (read) → select (executed).
**Depth:** outer.
**Type:** shell command string, prompt path (`file_type ∈ {.md}`), or inline prompt.
**Default:** none (required when `selection_mode = synthesize`).

**Example:**

```
{aggregator} = file:./prompts/merge-critiques.md
```

### `ranker`

**Aliases:** `judge`, `scorer`
**Definition:** The mechanism that orders candidates by quality during evaluate.
**Stages:** input (read) → evaluate (executed) → select (consumes the ranking).
**Depth:** outer.
**Type:** shell command (exit code or stdout ordering), prompt path, or model spec; falls back to a heuristic.
**Default:** heuristic (`test_command` pass + summary length + finding count, per consumer).

**Example:**

```
{ranker} = "shellcheck -S warning"
{ranker} = file:./prompts/judge-prompt.md
```

### `auto_save_winner`

**Aliases:** `autosave`
**Definition:** When `n_candidates > 1` and a clear winner is selected, persist it automatically to `save_path` without asking.
**Stages:** input (read) → select (decision) → persist (applied).
**Depth:** outer.
**Type:** bool.
**Default:** `false`.

**Example:**

```
{auto_save_winner} = true
```

### `merge_mode`

**Aliases:** `merge_decision_mode`
**Definition:** Whether merges are gated on user confirmation (`interactive`) or proceed automatically when guardrails pass (`auto`).
**Stages:** input (read) → select (gating decision) → persist (applied).
**Depth:** outer.
**Type:** enum `interactive | auto`.
**Default:** `interactive`.

**Example:**

```
{merge_mode} = auto
```

### `merge_count`

**Aliases:** `merges_per_invocation`
**Definition:** Upper bound on how many candidate branches may be merged in a single invocation.
**Stages:** input (read) → select (cap) → persist (applied).
**Depth:** outer.
**Type:** enum `one | all-passing | user-pick-multi`, or `int_range[>= 0]`.
**Default:** `one`.

**Example:**

```
{merge_count} = one
{merge_count} = all-passing
```

### `cleanup_policy`

**Aliases:** `delete_worktree`, `cleanup`, `on_finish`
**Definition:** What to do with intermediate worktrees / temp dirs after persist.
**Stages:** input (read) → persist (applied).
**Depth:** outer.
**Type:** enum `keep | delete | delete-merged-only` — or a bool when the consumer only distinguishes keep vs. delete-merged.
**Default:** `delete-merged-only` (== `true` for `worktree-task-agent.md`'s `{delete_worktree}`).

**Example:**

```
{cleanup_policy} = keep
{delete_worktree} = true
```

### `verbosity`

**Aliases:** `detail_level`
**Definition:** How much detail the final report includes.
**Stages:** input (read) → report (applied).
**Depth:** both. Outer = overall report verbosity; inner = per-candidate verbosity (defaults to outer).
**Type:** enum `silent | summary | normal | full`.
**Default:** `normal`.

**Example:**

```
{verbosity} = full
```

### `require_diff`

**Aliases:** `show_diff`, `include_diff`
**Definition:** Whether the rendered report must include a diff block per candidate.
**Stages:** input (read) → report (applied).
**Depth:** outer.
**Type:** bool.
**Default:** `true` for code-modifying commands; `false` for read-only commands.

**Example:**

```
{require_diff} = true
```

### `include_terminal_log`

**Aliases:** `attach_logs`, `tail_logs`
**Definition:** Whether to attach captured terminal output (and how much) to the report.
**Stages:** input (read) → report (applied).
**Depth:** outer.
**Type:** bool, or `int_range[>= 1]` (number of trailing lines).
**Default:** `false`.

**Example:**

```
{include_terminal_log} = 200    # tail last 200 lines
{include_terminal_log} = true   # full log
```

---

## Cross-stage notes

- **Inner inheritance:** Every parameter tagged "Depth: both" defaults inner to the resolved outer value unless the command explicitly overrides. See `inner-vs-outer.md` for the rules.
- **Validation gate:** the input stage MUST type-check every parameter against its `int_range` / `file_type` / enum before any later stage runs. Per `worktree-task-agent.md`'s contract: "Parameters are validated before any worktree is created … Validation failure aborts with an explanatory error and no filesystem side effects."
- **Forward-declared params** in this file (`save_path`, `merge_mode`, etc.) are documented again — briefly — in the stage that *applies* them, with a back-reference here. The canonical home is input because that is where they are **read**.
