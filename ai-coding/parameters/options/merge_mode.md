# `merge_mode` — how the winning worktree branch is chosen

Enum (`interactive` | `auto`) deciding how the winning branch is picked
after diffs are presented: `interactive` asks the user which branch (if
any) to merge; `auto` merges at most one branch, and only when its agent
succeeded, `test_command` passed, `stop_condition` is satisfied, and the
merge is conflict-free. At most one branch merges per invocation either
way.

- **Used by:** worktree-task (declared), agent-swarm (sets it)
- **Full entry:** [concerns/lifecycle.md](../concerns/lifecycle.md#merge_mode)
