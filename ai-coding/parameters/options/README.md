# Options

One page per parameter on the live surface. Each file's header states what
the parameter is; the body states what it is used for, who uses it, and
links back to the authoritative entry in [`concerns/`](../concerns/). These
pages are a thin per-parameter index over the concern files — the cards and
bullets there stay normative; nothing here adds new semantics.

Files are named after the parameter's canonical name (cross-artifact cards)
or its as-written spelling (artifact-specific parameters), matching the
naming in [coverage.md](../coverage.md).

## Intent

- [task.md](task.md) — the goal a spawned agent must complete
- [context.md](context.md) — the subject artifact an invocation operates on
- [input.md](input.md) — raw user text meta-prompt classifies into a mode
- [worklist.md](worklist.md) — the work-item source for the commit loop
- [trait_name.md](trait_name.md) — identifier for the trait skill being authored
- [description.md](description.md) — one-paragraph spec for the trait being modeled

## I/O

- [artifact_path.md](artifact_path.md) — destination file for the run's primary artifact
- [format.md](format.md) — session-snapshot serialization format
- [workspace_roots.md](workspace_roots.md) — repository roots for the snapshot's Git section
- [transcript_paths.md](transcript_paths.md) — transcript paths cited in the snapshot
- [include_sections.md](include_sections.md) — subset of snapshot sections to emit
- [archive_root.md](archive_root.md) — root directory for wrap-up's category archives
- [event_log_path.md](event_log_path.md) — where wrap-up persists its JSONL event log
- [trajectory_path.md](trajectory_path.md) — session trajectory log destination
- [learnings_path.md](learnings_path.md) — session learnings note destination
- [filename_format.md](filename_format.md) — snapshot output path template
- [granularity.md](granularity.md) — snapshot detail level
- [coding_tool.md](coding_tool.md) — tool slug for snapshot naming and transcript lookup

## Constraints

- [test_command.md](test_command.md) — per-candidate verifier command
- [stop_condition.md](stop_condition.md) — explicit completion condition
- [max_iterations.md](max_iterations.md) — hard safety cap on loop rounds
- [criteria.md](criteria.md) — the judgment rubric critique evaluates against
- [max_items.md](max_items.md) — hard cap on total worklist items addressed

## Replication

- [candidate_count.md](candidate_count.md) — total independent runs launched per invocation
- [concurrency.md](concurrency.md) — cap on simultaneously active members
- [partition_count.md](partition_count.md) — grouping of members into contiguous slices
- [partition_strategy.md](partition_strategy.md) — how work items distribute across agent slices

## Models

- [agent_model.md](agent_model.md) — model(s) assigned to spawned worker agents
- [model.md](model.md) — the model the current agent runs analysis on
- [model_mix.md](model_mix.md) — model-assignment shape for a swarm

## Selection

- [selection_modes.md](selection_modes.md) — how swarm candidates reduce to an outcome
- [aggregator.md](aggregator.md) — producer of a merged artifact from candidates
- [min_successes.md](min_successes.md) — success floor before aggregation runs
- [rollup.md](rollup.md) — mode for rolling up substantive variant content
- [rollup_threshold.md](rollup_threshold.md) — line floor for a variant to count as substantive

## Isolation

- [base_branch.md](base_branch.md) — branch worktrees fork from and merge back into
- [worktree_name.md](worktree_name.md) — base name for the worktree directory and branch
- [use_worktree.md](use_worktree.md) — whether codebase writes happen in a dedicated worktree
- [delete_worktree.md](delete_worktree.md) — remove a worktree after its branch merges
- [session_branches.md](session_branches.md) — branches created this thread that gate shutdown
- [session_worktrees.md](session_worktrees.md) — worktrees created this thread that gate shutdown
- [include_categories.md](include_categories.md) — only wrap up matching worktree categories
- [exclude_categories.md](exclude_categories.md) — skip matching worktree categories

## Lifecycle

- [write_gate.md](write_gate.md) — whether the run writes files or only previews (family)
- [merge_mode.md](merge_mode.md) — how the winning worktree branch is chosen
- [remote.md](remote.md) — git remote used for end-of-run push and hygiene checks
- [source_branch.md](source_branch.md) — branch merge-commit-push merges from
- [target_branch.md](target_branch.md) — branch merge-commit-push merges into
- [merge_strategy.md](merge_strategy.md) — merge-commit shape
- [commit_message.md](commit_message.md) — squash commit message
- [include_push.md](include_push.md) — push after a successful merge
- [commit_scope.md](commit_scope.md) — Conventional Commits scope for per-item commits
- [worklist_writeback.md](worklist_writeback.md) — how completed items are marked done
- [save_trajectory.md](save_trajectory.md) — whether trajectory and learnings files are written
- [force.md](force.md) — overwrite an existing artifact instead of aborting
- [allow_unpushed.md](allow_unpushed.md) — tolerate unpushed commits at shutdown

## Robustness

- [relaunch_on_hang_after.md](relaunch_on_hang_after.md) — hang timeout before a member is killed
- [replacement_policy.md](replacement_policy.md) — whether killed members are respawned
- [cost_cap.md](cost_cap.md) — soft cap on projected swarm spend
- [on_failure.md](on_failure.md) — per-item failure policy in the commit loop
- [max_consecutive_failures.md](max_consecutive_failures.md) — per-agent circuit breaker

## Interaction

- [interactive.md](interactive.md) — opt-in to clarifying questions and confirmations
- [approval_mode.md](approval_mode.md) — how often a loop pauses for user sign-off
- [authoring_mode.md](authoring_mode.md) — one-shot draft vs stepwise walkthrough
- [todo_source.md](todo_source.md) — where the thread's TODO list is read from

## Composition

- [traits.md](traits.md) — the design traits to apply to the target
- [trait_map.md](trait_map.md) — registry resolving trait names to design skills
- [style.md](style.md) — design dimensions biasing prompt drafting
- [pattern.md](pattern.md) — preset shortcut bundling swarm defaults
- [design_skill.md](design_skill.md) — the design skill the ralph-design loop walks
- [precedence.md](precedence.md) — trait-conflict resolution rule
- [deliverable_shape.md](deliverable_shape.md) — output document shape
- [audience.md](audience.md) — advisory tone and detail target
- [depth.md](depth.md) — advisory length and density
