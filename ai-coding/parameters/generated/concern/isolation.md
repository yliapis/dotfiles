# Concern: Isolation / Workspace

> **Responsibility:** Declare *where work runs* such that it cannot touch the parent checkout, sibling work, or arbitrary parts of the filesystem. Isolation is about *containment* (no spillover); lifecycle is about *promotion* (how isolated work gets out).
>
> **Primary parameters:** `isolation`, `base_branch`, `worktree_name`, `worktree_root`, `cleanup_policy`

## Why this concern exists

When `parallelism > 1`, sibling agents writing into the same checkout corrupt each other. Even when `parallelism = 1`, an agent that fails mid-task should not leave the parent checkout in a half-edited state. Git worktrees solve this with cheap, isolated filesystem checkouts, but they require their own vocabulary: which base branch to fork from, where the worktrees live, what their names are, when they get cleaned up.

Keeping isolation separate from lifecycle is what lets a prompt say "create isolated workspaces, run work, but *leave the worktrees alive* even after merge so I can poke at them later" (i.e. `cleanup_policy=keep merge_mode=auto`). The two knobs are orthogonal: isolation lifetime ≠ result promotion.

## Parameters

### `isolation`

**Aliases:** `workspace_mode`, `sandbox`
**Definition:** The isolation strategy used for the agent's working filesystem.
**Type:** Enum: `none | worktree | tempdir | container`.
**Default:** `none` for read-only commands (`/critique`); `worktree` for commands that produce diffs (`/worktree-task-agent`).

**Values:**

- `none` — the agent works directly in the parent checkout (read-only commands only).
- `worktree` — a git worktree is created per agent; all writes happen inside the worktree.
- `tempdir` — a temporary scratch directory (no git); used when no version control is needed.
- `container` — work runs inside a container; out of scope for the current commands but reserved for future use.

**Cross-refs:**

- [`base_branch` (this file)](#base_branch) — required when `isolation=worktree`.
- [`worktree_name` (this file)](#worktree_name) — required when `isolation=worktree`.
- [`cleanup_policy` (this file)](#cleanup_policy) — controls post-run disposal.
- [`subagent_constraints` (subagent-tree.md)](./subagent-tree.md#subagent_constraints) — typically includes "MUST run only inside its assigned workspace" when `isolation != none`.

**Example:** `/worktree-task-agent isolation=worktree task=X` — each agent gets its own git worktree (default behavior).

---

### `base_branch`

**Aliases:** `fork_from`, `source_branch`
**Definition:** The git branch (or any commit-ish) from which worktrees are forked.
**Type:** `string` — any commit-ish accepted by `git worktree add` (branch, tag, full SHA, `origin/main`, etc.).
**Default:** The current branch (`git rev-parse --abbrev-ref HEAD`).

**Cross-refs:**

- [`isolation` (this file)](#isolation) — only meaningful when `isolation=worktree`.
- [`merge_mode` (lifecycle.md)](./lifecycle.md#merge_mode) — when a worktree branch is merged, the target is `base_branch`.
- [`worktree_name` (this file)](#worktree_name) — worktree branches are derived from `worktree_name`, forked off `base_branch`.

**Example:** `/worktree-task-agent task=X base_branch=origin/main` — forks worktrees off the latest remote main rather than the local branch.

---

### `worktree_name`

**Aliases:** `worktree_slug`, `branch_base`
**Definition:** The base name used for the worktree directory and its associated branch.
**Type:** `string` — filesystem-safe (typically kebab-case).
**Default:** A filesystem-safe kebab-case slug derived from `task`.

**Cross-refs:**

- [`parallelism` (replication.md)](./replication.md#parallelism) — when `parallelism > 1`, the index suffix `-1` / `-2` / … is appended per sibling.
- [`worktree_root` (this file)](#worktree_root) — full path is `worktree_root / worktree_name`.

**Example:** `/worktree-task-agent task="Refactor auth" worktree_name=refactor-auth parallelism=3` — produces worktree dirs `refactor-auth-1`, `refactor-auth-2`, `refactor-auth-3` (in `worktree_root`).

---

### `worktree_root`

**Aliases:** `worktree_dir`, `workspaces_root`
**Definition:** The parent directory under which all worktrees for this invocation are created.
**Type:** `string` — absolute or workspace-relative directory path.
**Default:** `~/.cursor/worktrees/<WORKTREE_ID>/` (per the `/worktree` command convention).

**Cross-refs:**

- [`worktree_name` (this file)](#worktree_name) — combined to form the full worktree path.
- [`cleanup_policy` (this file)](#cleanup_policy) — `cleanup_policy=keep` leaves directories under `worktree_root` indefinitely; consider rotation.

**Example:** `/worktree-task-agent worktree_root=/tmp/runs` — keeps worktrees out of the home directory for short-lived experiments.

---

### `cleanup_policy`

**Aliases:** `delete_worktree`, `cleanup`, `disposal`
**Definition:** What happens to a worktree (and its branch) after the agent finishes and its result has been decided.
**Type:** Enum (or boolean shorthand):
- `keep` / `false` — leave the worktree and branch in place.
- `delete-on-merge` / `true` — delete only when the worktree's branch was merged successfully.
- `delete-always` — delete regardless of outcome.
- `delete-on-success` — delete when the agent reported success (independent of merge).
**Default:** `delete-on-merge` (matches `/worktree-task-agent`'s `delete_worktree=true`).

**Cross-refs:**

- [`merge_mode` (lifecycle.md)](./lifecycle.md#merge_mode) — `delete-on-merge` interacts with whether a merge happened.
- [`isolation` (this file)](#isolation) — only meaningful when `isolation=worktree`.
- [`auto_save_winner` (lifecycle.md)](./lifecycle.md#auto_save_winner) — if a winner was auto-saved, `cleanup_policy=delete-on-success` becomes safer.

**Example:** `/worktree-task-agent task=X parallelism=4 cleanup_policy=keep` — all four worktrees stay around for manual inspection after the run.
