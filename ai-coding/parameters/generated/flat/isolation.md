# Isolation / Workspace (Category H)

Covers *how* subagents are sandboxed from each other and from the user's working tree, *where* their workspaces live on disk, *which* branch they fork from, and *what* cleanup happens after.

All isolation parameters apply at the subagent / per-slot layer by construction; the orchestrator's own workspace is the user's checkout and is not configurable here.

---

## `isolation`

**Aliases:** `isolation_kind`, `sandbox`.
**Definition:** The mechanism used to keep each subagent's filesystem and process state separate from the user's working tree and from sibling subagents.
**Type:** enum: `worktree` | `container` | `sandbox` | `none`.
  - `worktree`: each slot gets its own `git worktree`; current production isolation in `worktree-task-agent.md`.
  - `container`: each slot runs inside a fresh OCI container.
  - `sandbox`: each slot runs inside an OS-level sandbox (e.g., macOS sandbox-exec, Linux landlock).
  - `none`: no isolation; slots share the user's working tree (only safe for read-only subagents).
**Default:** `worktree` for editing subagents; `none` for read-only `critic`/`explore` subagents.
**Rename rationale (multi-depth):** layer-neutral; no rename.
**Consumed by:** `worktree-task-agent` (`worktree`); reserved for future runners.
**Example:**

```
isolation: worktree
isolation: none           # read-only critic, no sandbox needed
```

---

## `base_branch`

**Aliases:** `from_branch`, `fork_point`.
**Definition:** Git branch each slot's worktree is forked from when `isolation = worktree`.
**Type:** branch name string. Accepts any git ref (branch, tag, full SHA, `origin/main`).
**Default:** the current branch as reported by `git rev-parse --abbrev-ref HEAD`.
**Rename rationale (multi-depth):** layer-neutral (one orchestrator-set value applied uniformly across slots); no rename.
**Consumed by:** `worktree-task-agent` (`{base_branch}`).
**Example:**

```
base_branch: main
base_branch: feature/auth-rewrite
```

---

## `worktree_name`

**Aliases:** `slot_name`, `branch_slug`.
**Definition:** Base name used for each slot's worktree directory and branch; per-slot index suffix (`-1`, `-2`, ...) is appended when `outer_k > 1`.
**Type:** filesystem-safe kebab-case string.
**Default:** derived from `command_task` (kebab-case slug).
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** `worktree-task-agent` (`{worktree_name}`).
**Example:**

```
worktree_name: refactor-auth-module      # → refactor-auth-module-1, ..., refactor-auth-module-N
```

---

## `worktree_root`

**Aliases:** `worktree_parent`, `worktree_dir`.
**Definition:** Directory under which all slot worktrees are created; lets the user keep run artifacts off the main checkout's sibling tree.
**Type:** absolute or workspace-relative POSIX path string. Created if missing.
**Default:** `$HOME/.cursor/worktrees/` (matches the `/worktree` slash command layout).
**Rename rationale (multi-depth):** layer-neutral. Introduced in `trajectory.md` as a layout-control need.
**Consumed by:** future revisions of `worktree-task-agent`; the `/worktree` slash command uses an equivalent fixed path.
**Example:**

```
worktree_root: /Users/me/.cursor/worktrees/refine-best-of-n-2026-05-16/
```

---

## `cleanup_policy`

**Aliases:** `on_done`, `disposal`.
**Definition:** What happens to each slot's workspace once selection / merge is finished.
**Type:** enum: `delete_on_merge` | `keep` | `delete_all` | `ask_user`.
  - `delete_on_merge`: only the workspaces whose branches were merged are removed.
  - `keep`: leave every workspace in place for forensic inspection.
  - `delete_all`: remove every workspace, even unmerged ones.
  - `ask_user`: prompt per workspace before removing.
**Default:** `ask_user` for interactive `selection_mode`; `delete_on_merge` for non-interactive.
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** `worktree-task-agent` (a coarse version is the `{delete_worktree}` boolean).
**Example:**

```
cleanup_policy: delete_on_merge
cleanup_policy: keep            # debugging fan-out runs
```

---

## `delete_worktree`

**Aliases:** `cleanup`.
**Definition:** Whether to delete a slot's worktree after its branch is merged successfully; coarse boolean form of `cleanup_policy`.
**Type:** boolean.
**Default:** `true`.
**Rename rationale (multi-depth):** layer-neutral. Kept as a separate parameter for backwards compatibility with the current `worktree-task-agent.md` API; under the flat angle, new commands SHOULD prefer `cleanup_policy` over `delete_worktree`.
**Consumed by:** `worktree-task-agent` (`{delete_worktree}`).
**Example:**

```
delete_worktree: false       # keep merged worktrees around for inspection
```
