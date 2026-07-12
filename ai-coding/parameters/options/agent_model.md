# `agent_model` — model(s) assigned to spawned worker agents

Assigns models to spawned workers (defaults to the parent agent's model).
A scalar broadcasts to every member; a list maps positionally per agent
(length `candidate_count`) or per partition (length `partition_count`).
Distinct from `model`, which is the model the current agent runs on.

- **Used by:** worktree-task, address-worklist-commit-loop, ralph-design, designer-controller
- **Full entry:** [concerns/models.md](../concerns/models.md#agent_model)
