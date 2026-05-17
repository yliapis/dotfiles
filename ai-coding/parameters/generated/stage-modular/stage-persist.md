# Stage: `persist`

## Purpose
Materialize the selected artifacts: write files to `save_path`, merge worktree branches into `base_branch`, delete worktrees per `cleanup_policy`, and emit a manifest of everything that touched disk. The only stage (besides `isolate`) with durable side effects beyond the worktrees.

## Position
Runs after `select` (and after `aggregate` when there is no `select`). Side effects: file writes, `git merge`, `git worktree remove`, `git branch -d`.

## Input Contract

### Required
- `selected` (list<execution_result | synthesized_artifact>) — from `select`. Empty list is a legal no-op.

### Optional
- `save_path` (path, default: `null`) — explicit destination for a single artifact. For `meta-prompt`, defaults to `.cursor/commands/<kebab-name>.md` when save intent is detected. When `save_path` is a directory, each `selected[i]` is written under `save_path/<i>-<isolation_id>.<ext>`.
- `output_format` (enum: `md` | `json` | `diff` | `patch` | `binary`, default: inferred from `save_path` extension, else `md`) — serialization format for written artifacts.
- `auto_save_winner` (bool, default: `false`) — when `true` and `len(selected) == 1` and `save_path` is set, write without prompting.
- `merge_mode` (enum: `interactive` | `auto` | `skip`, default: `interactive`) — how to merge selected worktree branches.
  - `interactive`: ask the user per-branch before merging.
  - `auto`: merge eligible selected branches without prompting.
  - `skip`: do not merge; leave branches in place.
- `merge_count` (int, int_range: `>= 0`, default: `1`, alias: `max_merged`) — maximum branches to merge in this invocation; `1` matches `worktree-task-agent.md`.
- `merge_strategy` (enum: `no-ff` | `ff-only` | `squash`, default: `no-ff`) — git merge mode.
- `base_branch` (string, default: from `isolate.isolations[*].base_branch`) — merge destination.
- `cleanup_policy` (enum: `keep` | `remove-on-success` | `remove-always`, default: from `isolate.cleanup_policy`) — worktree cleanup behavior.
- `delete_worktree` (bool, default: `true` when `cleanup_policy == remove-on-success`) — fine-grained override.
- `branch_naming` (string template, default: `null`) — rename merged branches before merge (rare).
- `dry_run` (bool, default: `false`) — when `true`, compute the manifest but do not write/merge/delete.

## Output Contract

- `persisted_paths` (list<path>) — files written this stage.
- `merged_branches` (list<{ branch, base_branch, sha_before, sha_after, strategy }>) — branches successfully merged.
- `removed_worktrees` (list<path>) — worktree directories cleaned up.
- `kept_worktrees` (list<path>) — worktree directories retained (per policy or due to merge failure).
- `merge_failures` (list<{ branch, reason }>) — branches that could not be merged (conflicts, ineligibility, user skip).
- `manifest` (list<{ kind: write|merge|remove, target, source_index, status }>) — full ordered action log; written even when `dry_run == true`.

## Depth-Aware Aliasing

- `persist[0]` writes outer-level artifacts; `persist[1]` is rare but legal (e.g., each outer slot persists its own intermediate before the outer `select`).
- `save_path` does NOT cascade; each depth declares its own. Inner save paths SHOULD live inside the outer slot's worktree to avoid cross-slot collisions.
- `base_branch` cascades from the outer `isolate`; an inner `persist` SHOULD reference `isolate[1].base_branch` explicitly when nested isolation introduces a different base.
- `merge_count` does NOT cascade; outer `merge_count: 1` and inner `merge_count: 1` are independent caps.

## Composition Rules

- Predecessors: `select` (or `aggregate` directly when `selection_mode == none`).
- Successors: `report`.
- `persist` MUST NOT write or merge anything beyond what `selected` indicates.
- `persist` MUST NOT delete a worktree before its merge has succeeded (mirrors `worktree-task-agent.md` guardrail).
- On merge conflict, `persist` MUST abort the merge and record it in `merge_failures`; subsequent eligible branches MAY still be processed unless the caller specifies fail-fast.
- `dry_run == true` MUST produce no side effects, even on filesystem `write`.

## Examples

### Example 1: worktree-task-agent — interactive merge of one branch, cleanup on success

```yaml
stage: persist
selected: [<execution_result index=2>]
save_path: null
merge_mode: interactive
merge_count: 1
merge_strategy: no-ff
base_branch: main
cleanup_policy: remove-on-success
delete_worktree: true
outputs:
  persisted_paths: []
  merged_branches:
    - { branch: refactor-auth-2, base_branch: main, sha_before: abc..., sha_after: def..., strategy: no-ff }
  removed_worktrees: [~/.cursor/worktrees/.../refactor-auth-2]
  kept_worktrees: [~/.cursor/worktrees/.../refactor-auth-1, .../refactor-auth-3, .../refactor-auth-4, ...] # 7 left in place
  merge_failures: []
  manifest:
    - { kind: merge,  target: main, source_index: 2, status: success }
    - { kind: remove, target: ~/.cursor/worktrees/.../refactor-auth-2, source_index: 2, status: success }
```

### Example 2: meta-prompt — auto-save the single winner to .cursor/commands/

```yaml
stage: persist
selected: [<synthesized_artifact: refined /pr-review prompt body>]
save_path: .cursor/commands/pr-review.md
output_format: md
auto_save_winner: true
merge_mode: skip
cleanup_policy: keep
outputs:
  persisted_paths: [.cursor/commands/pr-review.md]
  merged_branches: []
  removed_worktrees: []
  kept_worktrees: []
  merge_failures: []
  manifest:
    - { kind: write, target: .cursor/commands/pr-review.md, source_index: null, status: success }
```
