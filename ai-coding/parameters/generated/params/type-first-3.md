# Parameter Ontology — Type-First

A reusable parameter ontology for the `ai-coding/` commands and skills,
organized **strictly by data type**.

## The angle: Type-first

Every parameter in this ontology is defined by its **type and schema
first**. Its semantic meaning ("this is the parallelism knob", "this is
the criteria input") is a **secondary attribute** captured by a list of
semantic aliases on the typed entry, plus a reverse-index file
(`semantic-aliases.md`) that lets callers navigate from meaning to type.

### Why type-first

- **Validation, parsing, and shape checks become first-class.** Every
  consumer can ask one question — "what is the type and does the input
  satisfy it?" — instead of bespoke per-command validators.
- **One source of truth per type formalism.** `int_range` and `file_type`
  are defined once, then reused everywhere. New parameters compose the
  building blocks instead of reinventing them.
- **Aliasing makes role overlap explicit.** When a single typed entry
  (`positive_count`) plays seven semantic roles (`parallel`, `parallelism`,
  `k`, `n_candidates`, `num_experiments`, `num_partitions`, `fan_out`),
  this is recorded in the typed file rather than scattered across seven
  command specs that disagree about the bounds.
- **List-of-T with length links is a real type, not a footnote.** The
  shape "`agent_model` is a string OR a list of strings whose length
  equals `parallelism`" is what `worktree-task-agent.md` actually
  validates; this ontology makes that contract a first-class type.

### The cost

Semantic browsing ("just show me everything about parallelism") is
indirect: you start at `semantic-aliases.md` and then jump to one or
two typed entries. We accept that cost in exchange for validation
clarity. See the self-critique in `trajectory.md`-style notes at the
bottom of this README.

## File index

The ontology is split into 10 files plus this README. Eight files cover
**types**; one file is the reverse semantic index; this file is the
entry-point.

| File                     | Purpose                                                                          |
|--------------------------|----------------------------------------------------------------------------------|
| `int-params.md`          | All integer-valued scalars. Defines the **`int_range` formalism**. Includes the `float_range` subtype used by `temperature`. |
| `bool-params.md`         | All boolean parameters; coercion rules at the input boundary; mutually-exclusive sets. |
| `enum-params.md`         | All string-from-fixed-set parameters. Defines the **`enum<...>` formalism**, plus closed-vs-open enum semantics. |
| `string-params.md`       | All free-form strings, with the `string(format=...)` formalism and named format subtypes (`shell-command`, `url`, `model-id`, `branch-name`, `duration`, ...). |
| `file-params.md`         | All single-file path parameters. Defines the **`file_type` formalism**. |
| `directory-params.md`    | All single-directory path parameters, including git-aware variants (`worktree_path`, `repo_root`). |
| `path-params.md`         | The tagged-union **`path` type** for parameters that legitimately accept file OR directory OR url OR inline (`context`, `criteria`, `compare_against`). |
| `list-params.md`         | The **`list-of-T` type** with first-class `len_link` constraints (e.g. `agent_model: list-of-string len_link=parallelism`). |
| `compound-params.md`     | All object-typed parameters with named sub-fields (`retry_policy`, `hang_policy`, `subagent_spec`, `finding`, `worktree_result`, `selection_policy`, `worktree_layout`). |
| `semantic-aliases.md`    | Reverse index: semantic name → typed entry. Organized by the eleven concern groups (A–K) from the base inventory. |

## How a caller reaches a parameter

1. **You know the semantic name** ("I need the parallelism knob"):
   - Open `semantic-aliases.md` and search for that name.
   - Follow the "Type file" column to the typed entry.
   - Read the schema and example there.

2. **You know the shape but not the name** ("I need a string that's also
   a git ref"):
   - Open `string-params.md` and scan the format subtypes table.
   - Find `git-ref`; jump to the catalog entry that uses it (`git_ref`).

3. **You are designing a new command**:
   - Pick one typed entry per parameter slot from the type files.
   - For each slot, register every semantic alias the command exposes in
     `semantic-aliases.md`.
   - Run the validation contracts (see each type file) at command entry
     before any side effect — this is the contract `worktree-task-agent.md`
     and `critique.md` already implement.

## Worked example 1: `critique.md` consuming this ontology

`critique.md` declares the following parameters:

| Source name (in critique.md) | Resolved typed entry                              | Defined in           |
|------------------------------|---------------------------------------------------|----------------------|
| `{context}`                  | `analyzable_input` (`path(any_of=[file, directory, url, inline])`) | `path-params.md`     |
| `{criteria}`                 | `criteria_input` (`path(any_of=[file, directory, inline])`) | `path-params.md`     |
| `{model}`                    | `model_id` (`string(format=model-id)`)            | `string-params.md`   |
| `{parallel}`                 | `positive_count` (`int_range(1, +inf)`)           | `int-params.md`      |
| `{num_experiments}`          | `positive_count` (`int_range(1, +inf)`)           | `int-params.md`      |

Output-side parameters that the report contents themselves consume:

| Source name                  | Resolved typed entry                              | Defined in           |
|------------------------------|---------------------------------------------------|----------------------|
| `{severity}` (per finding)   | `severity` (`enum<critical | major | minor | nit>`) | `enum-params.md`     |
| each finding                 | `finding` (compound)                              | `compound-params.md` |
| Findings section             | `list-of-compound(T=finding)`                     | `list-params.md`     |
| Divergent findings           | `list-of-compound(T=divergent_finding)`           | `compound-params.md` + `list-params.md` |

### What validation now looks like

`critique.md` Workflow §1 ("Resolve `{context}`") becomes:

```text
resolve_path(context, schema=analyzable_input)
  → if url, fetch
  → if directory, enumerate (mode=recursive)
  → if file, validate file_type=any
  → if inline, accept as prose

assert positive_count(parallel)           # int_range(1, +inf)
assert positive_count(num_experiments)    # int_range(1, +inf)
assert model_id(model)                    # string(format=model-id)
```

All four validations run **before any analysis is dispatched**, satisfying
the critique guardrail "MUST honor the requested replication".

## Worked example 2: `worktree-task-agent.md` consuming this ontology

`worktree-task-agent.md` declares a longer parameter list:

| Source name                          | Resolved typed entry                                  | Defined in           |
|--------------------------------------|-------------------------------------------------------|----------------------|
| `{task}`                             | `task_prompt`                                         | `string-params.md`   |
| `{base_branch}`                      | `base_branch` (`string(format=branch-name)`)          | `string-params.md`   |
| `{worktree_name}`                    | `worktree_name` (`string(format=kebab-case)`)         | `string-params.md`   |
| `{delete_worktree}`                  | `delete_worktree` (`bool`)                            | `bool-params.md`     |
| `{merge_mode}`                       | `merge_mode` (`enum<interactive | auto>`)             | `enum-params.md`     |
| `{test_command}`                     | `shell_command` (`string(format=shell-command)`)      | `string-params.md`   |
| `{agent_model}` (scalar)             | `model_id` (`string(format=model-id)`)                | `string-params.md`   |
| `{agent_model}` (list)               | `list-of-string` with `len_link=parallelism`          | `list-params.md`     |
| `{parallelism}`                      | `positive_count` (`int_range(1, +inf)`)               | `int-params.md`      |
| `{num_partitions}`                   | `positive_count` (`int_range(1, +inf)`)               | `int-params.md`      |
| `{stop_condition}`                   | `stop_condition`                                      | `string-params.md`   |

The Run Summary and per-worktree results in the Output Format resolve to:

| Source name                  | Resolved typed entry                                  | Defined in           |
|------------------------------|-------------------------------------------------------|----------------------|
| Run Summary block            | `run_summary` (compound)                              | `compound-params.md` |
| Worktree Results block       | `list-of-compound(T=worktree_result, len_link=parallelism)` | `compound-params.md` + `list-params.md` |
| per-worktree `Status`        | `enum<success | failed | incomplete>` (inline)        | `compound-params.md → worktree_result.status` |
| per-worktree `Merge recommendation` | `enum<merge | skip | hold>` (inline)           | `compound-params.md → worktree_result.merge_recommendation` |

### What validation now looks like

`worktree-task-agent.md` Workflow §1 ("Validate parameters") becomes a
mechanical sweep of the typed entries:

```text
assert positive_count(parallelism)        # int_range(1, +inf)
assert positive_count(num_partitions)     # int_range(1, +inf)

resolve_list(agent_model, schema=list-of-string,
             T=model_id, len_link=parallelism, broadcast=scalar_ok)
  → if scalar: broadcast to length=parallelism
  → if list:   assert len == parallelism

if num_partitions > 1 and agent_model is list:
    assert is_full_iteration_or_slice(agent_model, num_partitions)

assert branch-name(base_branch) or use default (current branch)
assert kebab-case(worktree_name) or derive from task
assert bool(delete_worktree)
assert merge_mode in {interactive, auto}
assert shell_command(test_command)        # if provided
assert stop_condition(stop_condition)     # if provided
```

This is exactly the contract the existing `worktree-task-agent.md`
Workflow §1 enforces ("fail fast and create nothing on validation
failure"), but expressed in typed-entry vocabulary that another command
can reuse verbatim.

### What proposed extensions look like

The `trajectory.md` working notes propose adding `min_successes`,
`relaunch_on_hang_after`, `selection_mode`, `candidate_aggregator`,
`merge_count`, `worktree_root`. Under this ontology those become:

```text
min_successes:           non_negative_count            # int-params.md
relaunch_on_hang_after:  duration_str  OR  timeout_seconds   # string-params.md OR int-params.md
selection_mode:          selection_mode                # enum-params.md
candidate_aggregator:    aggregator_prompt  OR  shell_command  # string-params.md
merge_count:             merge_count (enum) OR bounded_count (int)  # enum-params.md OR int-params.md
worktree_root:           worktree_root                 # directory-params.md
```

…and the related compounds `retry_policy`, `hang_policy`,
`selection_policy`, `worktree_layout` in `compound-params.md` collect
several of these into structured groupings the caller can pass as a
single object.

## Conventions used across the ontology

- **Schema notation:** consistent shorthands (`>= 1`, `[1, 8]`, `(0, +inf)`)
  for `int_range`; named format subtypes for `string`; `file_type` aliases
  (`markdown`, `code`, `image`, ...) for `file`.
- **Layer labels:** `command` (caller-facing), `subagent` (per-tree-node),
  `skill` (skill-internal). A parameter may live in more than one layer.
- **Per-role defaults:** when a typed entry has multiple semantic aliases,
  defaults are listed **per alias** because they legitimately differ
  (e.g. `parallel` defaults to `1` in `critique.md`, `parallelism` also
  defaults to `1` in `worktree-task-agent.md`, but `min_successes` defaults
  to `1` while `depth` defaults to `0`).
- **Examples:** every typed entry has at least one example pulled from an
  existing command, an existing proposal (in `trajectory.md`), or a
  realistic future extension.

## Maintenance

- New parameter ⇒ pick the type file; add the typed entry; add every
  semantic alias to `semantic-aliases.md`.
- New type formalism (akin to `int_range` or `file_type`) ⇒ define at the
  top of the relevant type file; document where it appears across the
  ontology.
- Renamed semantic alias ⇒ keep the old name as an alias row with a note
  for one release.
- Conflict (two type files would claim the same typed entry) ⇒ the
  type-first rule applies; prefer the more specific type and mark the
  looser one as "alias of …" in `semantic-aliases.md`.

## Coverage snapshot

- **Type formalisms defined:** `int_range`, `float_range`, `bool`,
  `enum<...>`, `string(format=...)`, `file`, `file_type`, `directory`,
  `path`, `list-of-T`, `compound`.
- **Named string formats:** `none`, `kebab-case`, `snake_case`, `git-ref`,
  `branch-name`, `model-id`, `glob`, `url`, `shell-command`, `duration`,
  `prose`, `markdown`, `regex`, `selector` (14).
- **Length-link patterns:** `len_link=parallelism`,
  `len_link=n_candidates`, `len_link=num_partitions`, `len_link=depth+1`.
- **Compounds defined:** `retry_policy`, `hang_policy`, `subagent_spec`,
  `subagent_constraints`, `finding`, `divergent_finding`,
  `worktree_result`, `run_summary`, `selection_policy`,
  `worktree_layout` (10).
- **Semantic aliases catalogued:** see `semantic-aliases.md`
  (≈110 rows across the eleven concern groups A–K from the base
  inventory).

## Self-critique (compare type-first vs alternative angles)

These notes are intentionally short; they are bookmarks for future
discussion across the eight angles (flat dictionary; layered namespaces;
type-first ← this one; lifecycle-first; concern-first; tree-shaped;
stage-modular; two-namespace).

1. **Semantic browsing is indirect.** A caller who knows only "I need the
   criteria parameter" must hop through `semantic-aliases.md` to reach
   `criteria_input` in `path-params.md`. Concern-first (e.g.
   `constraints.md`) puts everything about criteria in one place; this
   ontology splits it across `path-params.md`, `file-params.md`,
   `directory-params.md`, `list-params.md`, and `string-params.md`. We
   mitigate with the aliases file but do not eliminate the cost.

2. **Defaults are awkward when one type plays many roles.** `positive_count`
   has seven semantic aliases with the same schema but different defaults
   per command (`parallel=1`, `min_successes=1`, `depth=0`, ...). We list
   defaults per alias in the typed file, which works but duplicates info
   the consuming command also documents. A layered-namespace or
   concern-first ontology would carry defaults closer to the use site.

3. **Layer information ("command vs subagent vs skill") is a secondary
   axis we tack on inside type files.** A stage-modular or tree-shaped
   ontology would make layer the primary axis instead; that would
   simplify questions like "what knobs does a leaf subagent see?". Under
   the type-first ontology you answer that question by scanning every
   typed file for entries whose layer column contains `subagent`. Doable,
   but not as direct as a dedicated layer file.
