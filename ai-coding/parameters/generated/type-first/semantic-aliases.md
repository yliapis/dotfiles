# Semantic Aliases

This file is the **reverse index** for the type-first ontology. The typed
files (`int-params.md`, `bool-params.md`, etc.) are organized by data
type; this file lets a caller who knows the **semantic name** of a
parameter ("I need the parallelism knob", "I need the criteria input")
jump directly to its typed entry.

If you find yourself wanting to add a new semantic alias, add it here
**and** in the relevant typed file. Both directions must agree.

## How to read this file

Each row has:

- **Semantic name** — the caller-facing or domain-meaningful name.
- **Typed entry** — the canonical typed name in this ontology.
- **Type file** — where the typed entry is defined.
- **Layer** — `cmd` (command), `sub` (subagent), `skl` (skill); a slash
  means it appears in multiple layers.
- **Notes** — disambiguation when the same semantic name resolves to more
  than one typed entry depending on shape (e.g. `context` may be a path
  or inline).

## A. Task / Intent

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `task`               | `task_prompt`       | `string-params.md`  | cmd/sub     |       |
| `task_description`   | `task_prompt`       | `string-params.md`  | cmd/sub     | alias |
| `input`              | `task_prompt`       | `string-params.md`  | cmd         | when prose |
| `input`              | `analyzable_input`  | `path-params.md`    | cmd         | when a path/url/inline blob |
| `context`            | `analyzable_input`  | `path-params.md`    | cmd/sub     | union over file / directory / url / inline |
| `inline`             | `inline_artifact`   | `string-params.md`  | cmd         |       |
| `inline_content`     | `inline_artifact`   | `string-params.md`  | cmd         | alias |
| `stop_condition`     | `stop_condition`    | `string-params.md`  | cmd/sub     |       |
| `done_when`          | `stop_condition`    | `string-params.md`  | cmd/sub     | alias |

## B. File I/O

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `file`               | `single_file`       | `file-params.md`    | cmd/sub     |       |
| `directory`          | `single_directory`  | `directory-params.md` | cmd/sub   |       |
| `glob`               | `glob_pattern`      | `string-params.md`  | cmd/sub     |       |
| `url`                | `url_ref`           | `string-params.md`  | cmd/sub     |       |
| `format`             | `format`            | `enum-params.md`    | cmd         |       |
| `output_format`      | `output_format`     | `enum-params.md`    | cmd         |       |
| `report_format`      | `output_format`     | `enum-params.md`    | cmd         | alias |
| `save_path`          | `save_path`         | `file-params.md`    | cmd         |       |
| `save_path`          | `artifact_target`   | `path-params.md`    | cmd         | when file-or-directory accepted |
| `output_path`        | `save_path`         | `file-params.md`    | cmd         | alias |
| `output_file`        | `save_path`         | `file-params.md`    | cmd         | alias |
| `report_path`        | `report_path`       | `file-params.md`    | cmd         |       |
| `log_file`           | `log_file`          | `file-params.md`    | cmd/sub     |       |
| `terminal_log_path`  | `log_file`          | `file-params.md`    | cmd/sub     | alias |
| `output_dir`         | `output_directory`  | `directory-params.md` | cmd       |       |
| `report_dir`         | `output_directory`  | `directory-params.md` | cmd       | alias |
| `context_files`      | `list-of-file`      | `list-params.md`    | cmd         | list of files |
| `contexts`           | `list-of-path`      | `list-params.md`    | cmd         | mixed-shape list |
| `corpus`             | `corpus_directory`  | `directory-params.md` | cmd/sub   |       |

## C. Constraints

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `criteria`           | `criteria_input`    | `path-params.md`    | cmd         | union over file / dir / inline |
| `criteria`           | `prompt_file`       | `file-params.md`    | cmd         | when pinned to a single .md file |
| `criteria`           | `criteria_directory` | `directory-params.md` | cmd       | when pinned to a directory of .md files |
| `criteria`           | `criteria_list`     | `list-params.md`    | cmd         | when given as a list of prose strings |
| `criterion`          | `criterion_label`   | `string-params.md`  | sub/skl     | per-criterion name within a criteria set |
| `criterion_label`    | `criterion_label`   | `string-params.md`  | sub/skl     |       |
| `guardrails`         | `list-of-string`    | `list-params.md`    | cmd/sub     | one prose entry per guardrail |
| `stop_condition`     | `stop_condition`    | `string-params.md`  | cmd/sub     |       |
| `test_command`       | `shell_command`     | `string-params.md`  | cmd/sub     | inline form |
| `test_command`       | `test_command_script` | `file-params.md`  | cmd         | script-file form |
| `verify_command`     | `shell_command`     | `string-params.md`  | cmd/sub     | alias of test_command |
| `file_type`          | `file_type` (formalism) | `file-params.md` | -           | type-language, not a parameter |
| `extension`          | `file_type`         | `file-params.md`    | -           | informal alias for file_type |
| `int_range`          | `int_range` (formalism) | `int-params.md` | -           | type-language, not a parameter |
| `integer_interval`   | `int_range`         | `int-params.md`     | -           | alias of int_range |

## D. Replication / Parallelism

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `k`                  | `positive_count`    | `int-params.md`     | cmd/sub     |       |
| `n_candidates`       | `positive_count`    | `int-params.md`     | cmd         |       |
| `num_experiments`    | `positive_count`    | `int-params.md`     | cmd         |       |
| `parallel`           | `positive_count`    | `int-params.md`     | cmd         |       |
| `parallelism`        | `positive_count`    | `int-params.md`     | cmd         |       |
| `num_partitions`     | `positive_count`    | `int-params.md`     | cmd         |       |
| `partition_sizes`    | `list-of-int`       | `list-params.md`    | cmd         | `len_link=num_partitions`, sum=parallelism |

## E. Subagent tree

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `subagent_type`      | `subagent_type`     | `enum-params.md`    | sub         |       |
| `agent_role`         | `subagent_type`     | `enum-params.md`    | sub         | alias |
| `subagent_model`     | `model_id`          | `string-params.md`  | sub         | scalar form |
| `subagent_model`     | `list-of-string`    | `list-params.md`    | sub         | list form, `len_link=parallelism` |
| `subagent_prompt`    | `subagent_prompt`   | `string-params.md`  | sub         |       |
| `subagent_constraints` | `subagent_constraints` | `compound-params.md` | sub  |       |
| `subagent_spec`      | `subagent_spec`     | `compound-params.md` | sub        |       |
| `subagent_specs`     | `list-of-compound`  | `list-params.md`    | cmd/sub     | `T=subagent_spec`, `len_link=parallelism` |
| `depth`              | `non_negative_count` | `int-params.md`    | sub         |       |
| `fan_out`            | `positive_count`    | `int-params.md`     | sub         | scalar form (single level) |
| `fan_outs`           | `list-of-int`       | `list-params.md`    | sub         | per-level form, `len_link=depth+1` |

## F. Models / Diversity

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `model`              | `model_id`          | `string-params.md`  | cmd/sub     |       |
| `agent_model`        | `model_id`          | `string-params.md`  | cmd/sub     | scalar form |
| `agent_model`        | `list-of-string`    | `list-params.md`    | cmd/sub     | list form, `len_link=parallelism` |
| `focus_hint`         | `focus_hint`        | `string-params.md`  | cmd/sub     | scalar form |
| `focus_hints`        | `list-of-string`    | `list-params.md`    | cmd         | list form, `len_link=n_candidates` |
| `seed`               | `seed`              | `int-params.md`     | cmd/sub     | scalar form |
| `seeds`              | `list-of-int`       | `list-params.md`    | cmd/sub     | list form, `len_link=n_candidates` |
| `temperature`        | `temperature`       | `int-params.md`     | cmd/sub     | float subtype |
| `temperatures`       | `list-of-float`     | `list-params.md`    | cmd/sub     | list form |

## G. Selection / Aggregation

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `selection_mode`     | `selection_mode`    | `enum-params.md`    | cmd         |       |
| `selection_policy`   | `selection_policy`  | `compound-params.md` | cmd        | structured grouping of selection_mode + ranker + aggregator + min_successes + tie_break |
| `aggregation_mode`   | `selection_mode`    | `enum-params.md`    | cmd         | alias |
| `min_successes`      | `non_negative_count` | `int-params.md`    | cmd         |       |
| `ranker`             | `ranker_prompt`     | `string-params.md`  | cmd/sub     |       |
| `aggregator`         | `aggregator_prompt` | `string-params.md`  | cmd         | prompt form |
| `aggregator`         | `shell_command`     | `string-params.md`  | cmd         | shell-command form |
| `synthesize_prompt`  | `aggregator_prompt` | `string-params.md`  | cmd         | alias |
| `compare_against`    | `comparison_target` | `path-params.md`    | cmd         | union over file / git-ref / inline |
| `baseline`           | `comparison_target` | `path-params.md`    | cmd         | alias |
| `tie_break`          | `enum<...>`         | `compound-params.md` | cmd        | sub-field of `selection_policy` |

## H. Isolation / Workspace

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `isolation`          | `isolation`         | `enum-params.md`    | cmd         |       |
| `isolation_mode`     | `isolation`         | `enum-params.md`    | cmd         | alias |
| `base_branch`        | `base_branch`       | `string-params.md`  | cmd         | `format=branch-name` |
| `worktree_name`      | `worktree_name`     | `string-params.md`  | cmd         |       |
| `worktree_names`     | `list-of-string`    | `list-params.md`    | cmd         | `len_link=parallelism` |
| `worktree_root`      | `worktree_root`     | `directory-params.md` | cmd       |       |
| `worktree_path`      | `worktree_path`     | `directory-params.md` | cmd/sub   | output of `/worktree`, input to subsequent calls |
| `repo_root`          | `repo_root`         | `directory-params.md` | cmd       |       |
| `cleanup_policy`     | `cleanup_policy`    | `enum-params.md`    | cmd         |       |
| `worktree_layout`    | `worktree_layout`   | `compound-params.md` | cmd        | structured grouping |
| `WORKTREE_START_REF` | `git_ref`           | `string-params.md`  | cmd         | per `/worktree` |
| `start_ref`          | `git_ref`           | `string-params.md`  | cmd         | alias |

## I. Lifecycle / Persistence

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `save_path`          | (see B)             |                     |             |       |
| `auto_save_winner`   | `auto_save_winner`  | `bool-params.md`    | cmd         |       |
| `persist_winner`     | `auto_save_winner`  | `bool-params.md`    | cmd         | alias |
| `merge_mode`         | `merge_mode`        | `enum-params.md`    | cmd         |       |
| `merge_count`        | `merge_count`       | `enum-params.md`    | cmd         | enum form |
| `merge_count`        | `bounded_count`     | `int-params.md`     | cmd         | integer form |
| `delete_worktree`    | `delete_worktree`   | `bool-params.md`    | cmd         |       |
| `cleanup_worktree`   | `delete_worktree`   | `bool-params.md`    | cmd         | alias |

## J. Robustness / Recovery

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `timeout`            | `duration_str`      | `string-params.md`  | cmd/sub     | string form |
| `timeout`            | `timeout_seconds`   | `int-params.md`     | cmd/sub     | integer form |
| `relaunch_on_hang_after` | `duration_str`  | `string-params.md`  | cmd/sub     | preferred form |
| `relaunch_on_hang_after` | `timeout_seconds` | `int-params.md`   | cmd/sub     | integer form |
| `retry_policy`       | `retry_policy`      | `compound-params.md` | cmd/sub    |       |
| `retry_on`           | `retry_on`          | `enum-params.md`    | cmd/sub     | sub-field of retry_policy |
| `backoff`            | `backoff`           | `enum-params.md`    | cmd/sub     | sub-field of retry_policy |
| `hang_policy`        | `hang_policy`       | `compound-params.md` | cmd/sub    |       |
| `hang_action`        | `hang_action`       | `enum-params.md`    | cmd/sub     | sub-field of hang_policy |

## K. Reporting

| Semantic name        | Typed entry         | Type file           | Layer       | Notes |
|----------------------|---------------------|---------------------|-------------|-------|
| `verbosity`          | `verbosity`         | `enum-params.md`    | cmd/sub     |       |
| `log_level`          | `verbosity`         | `enum-params.md`    | cmd/sub     | alias |
| `verbose`            | `verbose`           | `bool-params.md`    | cmd/sub     | shorthand for verbosity=verbose |
| `quiet`              | `quiet`             | `bool-params.md`    | cmd/sub     | shorthand for verbosity=quiet |
| `require_diff`       | `require_diff`      | `bool-params.md`    | cmd         |       |
| `emit_diff`          | `require_diff`      | `bool-params.md`    | cmd         | alias |
| `include_terminal_log` | `include_terminal_log` | `bool-params.md` | cmd/sub  |       |
| `include_logs`       | `include_terminal_log` | `bool-params.md` | cmd/sub    | alias |
| `dry_run`            | `dry_run`           | `bool-params.md`    | cmd         |       |
| `force`              | `force`             | `bool-params.md`    | cmd         |       |
| `interactive`        | `interactive`       | `bool-params.md`    | cmd         | shorthand for merge_mode=interactive |
| `severity`           | `severity`          | `enum-params.md`    | sub/skl     |       |
| `finding`            | `finding`           | `compound-params.md` | sub/skl    |       |
| `findings`           | `list-of-compound`  | `list-params.md`    | sub/skl     | `T=finding` |
| `divergent_finding`  | `divergent_finding` | `compound-params.md` | sub/skl    |       |
| `worktree_result`    | `worktree_result`   | `compound-params.md` | cmd        |       |
| `worktree_results`   | `list-of-compound`  | `list-params.md`    | cmd         | `T=worktree_result`, `len_link=parallelism` |
| `run_summary`        | `run_summary`       | `compound-params.md` | cmd        |       |

## Disambiguation rules

When a semantic name appears more than once above (e.g. `criteria`,
`context`, `compare_against`), the consumer resolves it by **input
classification** (see `path-params.md → Shape detection`) and then dispatches
to the corresponding typed entry. A consumer MUST report the resolved typed
entry in its run header so the user can replay the call deterministically.

## Maintenance

- New parameter ⇒ add a typed entry first (in the relevant type file),
  then add every semantic alias here.
- Renamed alias ⇒ keep the old name as an alias row with a note for one
  release before removing.
- Conflict (two type files claim the same semantic alias) ⇒ the type-first
  rule applies: prefer the more specific type (e.g. `single_file` over
  `analyzable_input`). Mark the looser entry with "alias of …" in the
  Notes column.
