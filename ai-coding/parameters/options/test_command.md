# `test_command` — per-candidate verifier command

Shell command run inside each candidate's workspace; exit code `0` means
pass. Runs after the agent reports done (worktree-task, agent-swarm) or
before each item's commit (address-worklist-commit-loop, where a failure
suppresses the commit and triggers `{on_failure}`). Aliased as
`verify_command` (address-worklist-commit-loop).

- **Used by:** worktree-task, agent-swarm, address-worklist-commit-loop
- **Full entry:** [concerns/constraints.md](../concerns/constraints.md#test_command)
