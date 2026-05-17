# Stage: `isolate`

## Purpose
Provision one or more isolated workspaces (git worktrees, sandbox directories, branches) so downstream `execute` instances cannot interfere with each other or with the parent checkout.

## Position
Runs after `validate` and before `replicate` / `fan-out` / `execute`. Has filesystem side effects: creates branches and worktree directories.

## Input Contract

### Required
- `isolation` (enum: `none` | `worktree` | `sandbox-dir` | `container`, default: `worktree` when a git repo is detected, else `none`) — isolation mechanism.

### Optional
- `base_branch` (string, default: current branch via `git rev-parse --abbrev-ref HEAD`) — branch to fork from when `isolation == worktree`.
- `worktree_name` (string, default: kebab-case slug of `resolved_task`) — base name for the branch / worktree directory.
- `worktree_root` (path, default: `~/.cursor/worktrees/`) — parent directory under which worktrees are created.
- `count` (int, int_range: `>= 1`, default: `1`) — number of sibling isolations to create. Each gets a 1-based `-{i}` suffix when `count > 1`.
- `detached` (bool, default: `false`) — when `true`, the worktree is checked out detached (no new branch); incompatible with merge-back semantics in `persist`.
- `repo_root` (path, default: discovered via `git rev-parse --show-toplevel`) — source repo for worktree creation.
- `start_ref` (string, default: `HEAD`) — explicit commit-ish to seed the worktree from; overrides `base_branch` for the initial checkout when supplied.
- `cleanup_policy` (enum: `keep` | `remove-on-success` | `remove-always`, default: `keep`) — pre-declared cleanup behavior; consumed later by `persist`. Recorded here so the user knows up-front.

## Output Contract

- `isolations` (list<isolation_record>) — one per provisioned workspace. Each `isolation_record` is:
  - `index` (int, 1-based)
  - `worktree_path` (path)
  - `branch` (string)
  - `head_commit` (string, 40-char SHA)
  - `repo_root` (path)
  - `isolation_id` (string, unique slug `{worktree_name}-{i}-{8hex}`)
  - `start_ref` (string, the actual ref used)
- `isolation_warnings` (list<string>) — e.g., pre-existing branches reused, dirty working trees skipped, name collisions resolved by suffixing.

## Depth-Aware Aliasing

- `isolate` may legitimately appear at multiple depths: an outer `isolate` provisions worktrees per candidate; an inner `isolate` (rare) provisions further sub-worktrees inside a candidate (e.g., for nested fan-out where each inner agent needs its own scratch dir).
- Inner `isolate` MUST use the outer `worktree_path` as its `repo_root`; this is enforced at `validate`.
- Aliases: `isolate[0].count` (outer fan width), `isolate[1].count` (inner fan width).
- `cleanup_policy` cascades inward unless overridden; an inner override cannot escalate cleanup beyond the outer policy (e.g., inner cannot `remove-always` if outer is `keep`).

## Composition Rules

- Predecessors: `validate`.
- Successors: `replicate` or `fan-out` (which consume `isolations` as job templates), or directly `execute` when `count == 1` and no replication is wanted.
- MUST NOT mutate the original working tree; the only repo-level effect is the creation of new branches and worktree directories.
- Failures (e.g., name collisions, dirty parent tree) MUST leave the filesystem unchanged from the state before this stage started.

## Examples

### Example 1: worktree-task-agent — 4 sibling worktrees off `main`

```yaml
stage: isolate
isolation: worktree
base_branch: main
worktree_name: refactor-auth
count: 4
cleanup_policy: remove-on-success
outputs:
  isolations:
    - { index: 1, worktree_path: ~/.cursor/worktrees/.../refactor-auth-1, branch: refactor-auth-1, head_commit: abc…, isolation_id: refactor-auth-1-1a2b3c4d }
    - { index: 2, worktree_path: ~/.../refactor-auth-2, branch: refactor-auth-2, head_commit: abc…, isolation_id: refactor-auth-2-5e6f7a8b }
    - { index: 3, ... }
    - { index: 4, ... }
  isolation_warnings: []
```

### Example 2: critique — no isolation needed (read-only)

```yaml
stage: isolate
isolation: none
outputs:
  isolations: []
  isolation_warnings: ["isolation skipped: critique is read-only"]
```
