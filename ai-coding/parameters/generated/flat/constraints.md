# Constraints (Category C)

Covers the *judgment rubric*, the *MUST/MUST NOT scope rules*, the *done-when predicates*, the *pass/fail commands*, and the *type formalisms* used to constrain values across the ontology.

Under the flat angle, `criteria`, `stop_condition`, and `test_command` each split by layer so the orchestrator-layer rubric is never confused with a per-slot or per-finding criterion.

`int_range` and `file_type` are *type formalisms*: they live in this category because they are the language other parameters cite to express their allowed values.

---

## `command_criteria`

**Aliases (deprecated under this angle):** `criteria` (when referring to the overall rubric the command applies).
**Definition:** The plural rubric — the full list of criteria the command evaluates against across every run.
**Type:** one of `file` | `directory` | `inline` (see `io.md`), resolving to a list of named criteria with definitions.
**Default:** command-defined; `critique` defaults to "quality (clarity, correctness, completeness, robustness) and determinism (reproducibility, idempotency, stable outputs across runs)".
**Rename rationale (multi-depth):** a finding is tagged with *one* criterion drawn from the rubric (`finding_criterion`); the rubric itself is the *set*. Reusing `criteria` for both confused per-finding tagging with rubric resolution in early drafts of `critique.md`.
**Consumed by:** `critique` (`{criteria}`); any future evaluation command.
**Example:**

```
command_criteria: inline:"clarity, correctness, completeness, robustness, determinism"
command_criteria: file:./docs/rubrics/code-review.md
```

---

## `finding_criterion`

**Aliases (deprecated under this angle):** `criteria` (when referring to one tag attached to one finding), `criterion`.
**Definition:** The single criterion (drawn from `command_criteria`) that a single finding cites.
**Type:** string identifier matching one entry in the resolved `command_criteria` list.
**Default:** required on every finding emitted by a `critique`-style command.
**Rename rationale (multi-depth):** the singular-per-finding usage is structurally different from the plural rubric. Distinct names let the success criteria say "every finding names the specific `finding_criterion` from `command_criteria` it relates to" without grammatical contortions.
**Consumed by:** `critique` Output Format (`{location, criterion, severity, evidence, rationale}` tuple).
**Example:**

```
finding_criterion: "determinism"
```

---

## `guardrails`

**Aliases:** `constraints`, `rules`.
**Definition:** The MUST / MUST NOT / Scope rules the command (or subagent) must honor. Always plural; always rendered as a bulleted list.
**Type:** list of strings, each starting with `MUST`, `MUST NOT`, or `Scope:`.
**Default:** required for every command (per `meta-prompt`'s success criteria).
**Rename rationale (multi-depth):** `guardrails` is layer-neutral; commands and subagents alike consume the same shape. No rename needed.
**Consumed by:** every command's `## Guardrails` section.
**Example:**

```
guardrails:
  - "MUST NOT modify {command_context}; analysis is read-only."
  - "MUST evaluate against {command_criteria} even when it conflicts with the model's defaults."
  - "Scope: produce findings only; do not propose code edits."
```

---

## `command_stop_condition`

**Aliases (deprecated under this angle):** `stop_condition` (at the orchestrator layer).
**Definition:** Predicate the *command* uses to decide the run is complete (typically: "all subagents reported `success` AND `min_successes` met").
**Type:** free-form predicate string, or named gate (`all_slots_success`, `min_successes_met`, `aggregator_emitted`).
**Default:** `all_slots_success` for fan-out commands; `task_implemented_and_verified` for single-shot commands.
**Rename rationale (multi-depth):** `worktree-task-agent.md` already uses `{stop_condition}` to mean *the per-slot completion gate each subagent must satisfy*. Without a rename, "the command is done" and "this single subagent is done" collide.
**Consumed by:** `worktree-task-agent` orchestrator loop; any future fan-out command.
**Example:**

```
command_stop_condition: "min_successes_met AND aggregator_emitted"
```

---

## `subagent_stop_condition`

**Aliases (deprecated under this angle):** `stop_condition` (at the slot layer).
**Definition:** Predicate one subagent slot must satisfy before it reports `success`; this is the original meaning of `{stop_condition}` in `worktree-task-agent.md`.
**Type:** free-form predicate string per slot, or scalar broadcast.
**Default:** when omitted, the implicit predicate is "the subagent's `subagent_task` is implemented and verified".
**Rename rationale (multi-depth):** see `command_stop_condition`.
**Consumed by:** every subagent launched by a fan-out command.
**Example:**

```
subagent_stop_condition: "git diff --quiet || (subagent_test_command exited 0)"
```

---

## `command_test_command`

**Aliases (deprecated under this angle):** `test_command` (at the orchestrator layer).
**Definition:** A shell command the *orchestrator* runs once after all subagents finish, to verify the combined / merged artifact.
**Type:** shell string. Exit code `0` = pass; non-zero = fail.
**Default:** unset; not all commands have a post-aggregation check.
**Rename rationale (multi-depth):** `worktree-task-agent.md` defines `{test_command}` as *per-worktree*; reusing the same name for a post-aggregation check would conflate two different scopes.
**Consumed by:** future `refine-best-of-n` (e.g., final lint of the picked candidate); `worktree-task-agent` *only if* a future revision adds a post-merge check.
**Example:**

```
command_test_command: "pnpm run lint && pnpm run typecheck"
```

---

## `subagent_test_command`

**Aliases (deprecated under this angle):** `test_command` (at the per-slot layer).
**Definition:** Shell command each subagent runs inside its own slot (e.g., inside its worktree) to verify its local result. Direct rename of `worktree-task-agent.md`'s `{test_command}`.
**Type:** shell string per slot, or scalar broadcast.
**Default:** unset.
**Rename rationale (multi-depth):** see `command_test_command`.
**Consumed by:** `worktree-task-agent` (`{test_command}`).
**Example:**

```
subagent_test_command: "pnpm test --filter=auth"
```

---

## `file_type`

**Aliases:** `extension`, `ext`.
**Definition:** A type formalism declaring which file extensions a parameter will accept; used wherever an artifact-pointer parameter restricts the shape of acceptable files.
**Type:** list of dotted extensions: `[".md"]`, `[".md", ".json"]`, `[".py", ".pyi"]`. `["*"]` means any extension.
**Default:** when unset, any extension is accepted.
**Rename rationale (multi-depth):** none — this is a value-domain formalism, not a layer-specific concept.
**Consumed by:** any parameter that declares its allowed file shapes (typically in the `## Parameters` section of a command, e.g. "`{command_save_path}` — `file_type: [.md]`").
**Example:**

```
command_save_path: file_type: [".md"]      # only markdown
command_context:  file_type: [".py"]       # Python sources only
command_context:  file_type: ["*"]          # any file
```

---

## `int_range`

**Aliases:** `integer_interval`, `int_interval`.
**Definition:** A type formalism declaring an integer parameter's allowed numeric domain, in standard interval notation.
**Type:** string in one of these shapes:
  - `>= N` or `<= N` — half-bounded inclusive
  - `> N` or `< N` — half-bounded exclusive
  - `[A, B]` — closed interval
  - `(A, B)` — open interval
  - `[A, B)` or `(A, B]` — half-open intervals
  - `(0, ∞)` / `[1, ∞)` — explicit unbounded
**Default:** when unset, no domain constraint beyond "integer".
**Rename rationale (multi-depth):** none — value-domain formalism.
**Consumed by:** every integer parameter in this ontology (`outer_k`, `inner_k`, `command_parallel`, `subagent_parallel`, `outer_partitions`, `min_successes`, `depth`, `fan_out`, `merge_count` when numeric).
**Example:**

```
outer_k:          int_range: ">= 1"
command_parallel: int_range: "[1, 32]"
outer_partitions: int_range: ">= 1"
min_successes:    int_range: "[0, outer_k]"   # data-dependent upper bound
temperature:      n/a (not int; uses a float interval instead, see models.md)
```
