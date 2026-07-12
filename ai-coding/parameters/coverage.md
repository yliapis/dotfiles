# Coverage

Per-artifact index: every declared parameter, mapped to its canonical card (or
its artifact-specific entry) and concern file. Spellings are exactly as they
appear in each artifact.

The same artifacts are mirrored in `ai-coding/plugins/ai-coding/` and in the
repo-root `.cursor/commands/` and `.cursor/skills/`; this wiki tracks the
[`ai-coding/commands/`](../commands/) and [`ai-coding/skills/`](../skills/)
sources.

## Commands

### [critique](../commands/critique.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{context}` | [`context`](concerns/intent.md#context) | intent |
| `{criteria}` | artifact-specific | [constraints](concerns/constraints.md#artifact-specific) |
| `{model}` | artifact-specific | [models](concerns/models.md#artifact-specific) |
| `{parallel}` | [`concurrency`](concerns/replication.md#concurrency) | replication |
| `{num_experiments}` | [`candidate_count`](concerns/replication.md#candidate_count) | replication |
| `-i` / `--interactive` | [`interactive`](concerns/interaction.md#interactive) | interaction |

### [meta-prompt](../commands/meta-prompt.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{input}` | artifact-specific | [intent](concerns/intent.md#artifact-specific) |
| `{update_mode}` | [`write_gate` family](concerns/lifecycle.md#write_gate-family) | lifecycle |
| `{style}` / `{styles}` | artifact-specific | [composition](concerns/composition.md#artifact-specific) |
| `{save_path}` | [`artifact_path`](concerns/io.md#artifact_path) | io |
| `{worktree}` | [`worktree_name`](concerns/isolation.md#worktree_name) | isolation |
| `{n}` | [`candidate_count`](concerns/replication.md#candidate_count) | replication |
| `{k}` | [`concurrency`](concerns/replication.md#concurrency) | replication |
| `--interactive` / `-i` | [`interactive`](concerns/interaction.md#interactive) | interaction |

### [designer](../commands/designer.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{traits}` | [`traits`](concerns/composition.md#traits) | composition |
| `{target}` | [`context`](concerns/intent.md#context) | intent |
| `{trait_map}` | [`trait_map`](concerns/composition.md#trait_map) | composition |

### [merge-commit-push](../commands/merge-commit-push.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{source_branch}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `{target_branch}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `{merge_strategy}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `{remote}` | [`remote`](concerns/lifecycle.md#remote) | lifecycle |
| `{commit_message}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `{include_push}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |

### [wrap-up](../commands/wrap-up.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{base_branch}` | [`base_branch`](concerns/isolation.md#base_branch) | isolation |
| `{remote}` | [`remote`](concerns/lifecycle.md#remote) | lifecycle |
| `{archive_root}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `{rollup}` | artifact-specific | [selection](concerns/selection.md#wrap-up) |
| `{rollup_threshold}` | artifact-specific | [selection](concerns/selection.md#wrap-up) |
| `{include_categories}` | artifact-specific | [isolation](concerns/isolation.md#artifact-specific) |
| `{exclude_categories}` | artifact-specific | [isolation](concerns/isolation.md#artifact-specific) |
| `{delete_after_merge}` | [`delete_worktree`](concerns/isolation.md#delete_worktree) | isolation |
| `{event_log_path}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `{trajectory_path}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `{learnings_path}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `{save_trajectory}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `-i` / `--interactive` | [`interactive`](concerns/interaction.md#interactive) | interaction |

### [address-worklist-commit-loop](../commands/address-worklist-commit-loop.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{worklist}` | artifact-specific | [intent](concerns/intent.md#artifact-specific) |
| `{mode}` | [`approval_mode`](concerns/interaction.md#approval_mode) | interaction |
| `{parallelism}` | [`candidate_count`](concerns/replication.md#candidate_count) | replication |
| `{num_partitions}` | [`partition_count`](concerns/replication.md#partition_count) | replication |
| `{agent_model}` | [`agent_model`](concerns/models.md#agent_model) | models |
| `{base_branch}` | [`base_branch`](concerns/isolation.md#base_branch) | isolation |
| `{worktree_name}` | [`worktree_name`](concerns/isolation.md#worktree_name) | isolation |
| `{partition_strategy}` | artifact-specific | [replication](concerns/replication.md#artifact-specific) |
| `{commit_scope}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `{verify_command}` | [`test_command`](concerns/constraints.md#test_command) | constraints |
| `{on_failure}` | artifact-specific | [robustness](concerns/robustness.md#address-worklist-commit-loop) |
| `{max_consecutive_failures}` | artifact-specific | [robustness](concerns/robustness.md#address-worklist-commit-loop) |
| `{worklist_writeback}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `{max_items}` | artifact-specific | [constraints](concerns/constraints.md#artifact-specific) |
| `{dry_run}` | [`write_gate` family](concerns/lifecycle.md#write_gate-family) | lifecycle |

### [save-session-state](../commands/save-session-state.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{output_path}` | [`artifact_path`](concerns/io.md#artifact_path) | io |
| `{format}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `{mode}` | [`write_gate` family](concerns/lifecycle.md#write_gate-family) | lifecycle |
| `{workspace_roots}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `{transcript_paths}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `{include_sections}` | artifact-specific | [io](concerns/io.md#artifact-specific) |
| `-i` / `--interactive` | [`interactive`](concerns/interaction.md#interactive) | interaction |

### [soft-shutdown](../commands/soft-shutdown.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{session_branches}` | artifact-specific | [isolation](concerns/isolation.md#artifact-specific) |
| `{session_worktrees}` | artifact-specific | [isolation](concerns/isolation.md#artifact-specific) |
| `{base_branch}` | [`base_branch`](concerns/isolation.md#base_branch) | isolation |
| `{remote}` | [`remote`](concerns/lifecycle.md#remote) | lifecycle |
| `{todo_source}` | artifact-specific | [interaction](concerns/interaction.md#artifact-specific) |
| `{allow_unpushed}` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `-i` / `--interactive` | [`interactive`](concerns/interaction.md#interactive) | interaction |

### [ralph-design](../commands/ralph-design.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{domain}` | [`context`](concerns/intent.md#context) | intent |
| `{design_skill}` | artifact-specific | [composition](concerns/composition.md#artifact-specific) |
| `{mode}` | [`approval_mode`](concerns/interaction.md#approval_mode) | interaction |
| `{stop_condition}` | [`stop_condition`](concerns/constraints.md#stop_condition) | constraints |
| `{persistence}` | [`write_gate` family](concerns/lifecycle.md#write_gate-family) | lifecycle |
| `{artifact_path}` | [`artifact_path`](concerns/io.md#artifact_path) | io |
| `{use_worktree}` | [`use_worktree`](concerns/isolation.md#use_worktree) | isolation |
| `{base_branch}` | [`base_branch`](concerns/isolation.md#base_branch) | isolation |
| `{worktree_name}` | [`worktree_name`](concerns/isolation.md#worktree_name) | isolation |
| `{fanout_default_n}` | [`candidate_count`](concerns/replication.md#candidate_count) | replication |
| `{agent_model}` | [`agent_model`](concerns/models.md#agent_model) | models |
| `{max_iterations}` | [`max_iterations`](concerns/constraints.md#max_iterations) | constraints |

## Skills

### [worktree-task](../skills/worktree-task/SKILL.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{task}` | [`task`](concerns/intent.md#task) | intent |
| `{base_branch}` | [`base_branch`](concerns/isolation.md#base_branch) | isolation |
| `{worktree_name}` | [`worktree_name`](concerns/isolation.md#worktree_name) | isolation |
| `{delete_worktree}` | [`delete_worktree`](concerns/isolation.md#delete_worktree) | isolation |
| `{merge_mode}` | [`merge_mode`](concerns/lifecycle.md#merge_mode) | lifecycle |
| `{test_command}` | [`test_command`](concerns/constraints.md#test_command) | constraints |
| `{agent_model}` | [`agent_model`](concerns/models.md#agent_model) | models |
| `{parallelism}` | [`candidate_count`](concerns/replication.md#candidate_count) | replication |
| `{concurrency}` | [`concurrency`](concerns/replication.md#concurrency) | replication |
| `{num_partitions}` | [`partition_count`](concerns/replication.md#partition_count) | replication |
| `{stop_condition}` | [`stop_condition`](concerns/constraints.md#stop_condition) | constraints |

### [agent-swarm](../skills/agent-swarm/SKILL.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `{num_agents}` (aliases `{n}`, `{num}`) | [`candidate_count`](concerns/replication.md#candidate_count) | replication |
| `{parallel_agents}` (aliases `{p}`, `{parallel}`) | [`concurrency`](concerns/replication.md#concurrency) | replication |
| `{model_mix}` | artifact-specific | [models](concerns/models.md#artifact-specific) |
| `{num_partitions}` | [`partition_count`](concerns/replication.md#partition_count) | replication |
| `{selection_modes}` | artifact-specific | [selection](concerns/selection.md#agent-swarm) |
| `{test_command}` | [`test_command`](concerns/constraints.md#test_command) | constraints |
| `{aggregator}` | artifact-specific | [selection](concerns/selection.md#agent-swarm) |
| `{min_successes}` | artifact-specific | [selection](concerns/selection.md#agent-swarm) |
| `{relaunch_on_hang_after}` | artifact-specific | [robustness](concerns/robustness.md#agent-swarm) |
| `{replacement_policy}` | artifact-specific | [robustness](concerns/robustness.md#agent-swarm) |
| `{cost_cap}` | artifact-specific | [robustness](concerns/robustness.md#agent-swarm) |
| `{pattern}` | artifact-specific | [composition](concerns/composition.md#artifact-specific) |

### [design-skill](../skills/design-skill/SKILL.md)

Knobs are unbraced `key=value` tokens.

| Parameter | Canonical card | Concern |
|---|---|---|
| `trait_name` | artifact-specific | [intent](concerns/intent.md#artifact-specific) |
| `description` | artifact-specific | [intent](concerns/intent.md#artifact-specific) |
| `mode` | [`authoring_mode`](concerns/interaction.md#authoring_mode) | interaction |
| `force` | artifact-specific | [lifecycle](concerns/lifecycle.md#artifact-specific) |
| `persistence` | [`write_gate` family](concerns/lifecycle.md#write_gate-family) | lifecycle |
| `artifact_path` | [`artifact_path`](concerns/io.md#artifact_path) | io |
| `use_worktree` | [`use_worktree`](concerns/isolation.md#use_worktree) | isolation |
| `max_iterations` | [`max_iterations`](concerns/constraints.md#max_iterations) | constraints |

### [designer-controller](../skills/designer-controller/SKILL.md)

Knobs are unbraced `key=value` tokens.

| Parameter | Canonical card | Concern |
|---|---|---|
| `traits` | [`traits`](concerns/composition.md#traits) | composition |
| `target` | [`context`](concerns/intent.md#context) | intent |
| `mode` | [`authoring_mode`](concerns/interaction.md#authoring_mode) | interaction |
| `precedence` | artifact-specific | [composition](concerns/composition.md#artifact-specific) |
| `fan_out` | [`candidate_count`](concerns/replication.md#candidate_count) | replication |
| `deliverable_shape` | artifact-specific | [composition](concerns/composition.md#artifact-specific) |
| `audience` | artifact-specific | [composition](concerns/composition.md#artifact-specific) |
| `depth` | artifact-specific | [composition](concerns/composition.md#artifact-specific) |
| `persistence` | [`write_gate` family](concerns/lifecycle.md#write_gate-family) | lifecycle |
| `artifact_path` | [`artifact_path`](concerns/io.md#artifact_path) | io |
| `use_worktree` | [`use_worktree`](concerns/isolation.md#use_worktree) | isolation |
| `max_iterations` | [`max_iterations`](concerns/constraints.md#max_iterations) | constraints |
| `agent_model` | [`agent_model`](concerns/models.md#agent_model) | models |

### [prompt-template-library](../skills/prompt-template-library/SKILL.md)

| Parameter | Canonical card | Concern |
|---|---|---|
| `--interactive-template` | [`interactive`](concerns/interaction.md#interactive) | interaction |

### No parameter surface

Four skills declare no parameters, knobs, or flags — they activate
contextually (or are invoked manually) and are procedural rather than
knob-driven:

- [conventional-commits](../skills/conventional-commits/SKILL.md)
- [minimal-diffs](../skills/minimal-diffs/SKILL.md)
- [declarative-design](../skills/declarative-design/SKILL.md)
- [deterministic-design](../skills/deterministic-design/SKILL.md)
