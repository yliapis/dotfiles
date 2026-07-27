# Isolation

Where work happens without touching the calling tree. The repo's isolation
mechanism is the git worktree: fan-out members and codebase-persisting design
loops each get a worktree forked from a base branch; session-hygiene commands
(wrap-up, soft-shutdown) operate over the set of worktrees a session created.
The invariant every artifact repeats: members never read, write, or run
commands against the calling worktree or any sibling.

## Cards

### `base_branch`
- **Aliases:** —
- **Applies to:** command, skill
- **Type:** branch name
- **Default:** current branch via `git rev-parse --abbrev-ref HEAD`
  (worktree-task, ralph-design); `main`
  (wrap-up, soft-shutdown)
- **Meaning:** The branch worktrees are forked from and merged back into. The
  default split follows the artifact's role: fan-out artifacts fork from where
  you are; session-hygiene commands reconcile against `main`.
- **Propagation:** broadcast — every member forks from the same branch, and
  per-member diffs are rendered against it. Exception: agent-swarm's
  `pipeline` topology rewrites it per stage so each stage builds on its
  predecessor's branch. See [propagation.md](../propagation.md).
- **Used by:** worktree-task, designer, wrap-up, soft-shutdown

### `worktree_name`
- **Aliases:** `worktree` (meta-prompt)
- **Applies to:** command, skill
- **Type:** filesystem-safe kebab-case name for the worktree directory and its
  branch
- **Default:** kebab-case slug derived from the intent parameter (`task`,
  `target`); designer prefixes `designer/`; meta-prompt
  defaults to empty (write into the current tree, no worktree)
- **Meaning:** Base name for the worktree directory and branch. When fanning
  out, a 1-based index suffix (`-1`, `-2`, ...) is appended per member.
  agent-swarm's `staged` and `pipeline` topologies dispatch each wave or stage
  under its own name (`<slug>-w<j>`, `<slug>-s<i>`), so that suffix numbers
  members within one wave or stage rather than across the swarm.
- **Propagation:** rewrite — each member gets the suffixed variant. See
  [propagation.md](../propagation.md).
- **Used by:** worktree-task, designer, meta-prompt

### `use_worktree`
- **Aliases:** —
- **Applies to:** command, skill
- **Type:** boolean
- **Default:** `true` when `persistence=codebase`, otherwise `false`
- **Meaning:** Whether disk writes for a codebase-persisted deliverable happen
  inside a dedicated worktree forked from the current branch; when `true`, the
  calling working tree is never touched.
- **Validation:** must be `false` when `persistence=chat` (rejected otherwise).
  designer additionally rejects `base_branch` and `worktree_name` when it is
  `false`.
- **Used by:** design-skill, designer

### `delete_worktree`
- **Aliases:** `delete_after_merge` (wrap-up)
- **Applies to:** command, skill
- **Type:** boolean
- **Default:** `true` (wrap-up: prompts per worktree when `-i` is set)
- **Meaning:** Remove a worktree (and delete its branch) after its branch is
  merged successfully. Unmerged worktrees are always left in place; deletion
  never happens before the user has seen the diff (interactive) or the merge
  succeeded (auto).
- **Used by:** worktree-task, wrap-up

## Artifact-specific

- `{session_branches}` (soft-shutdown) — branches created during this thread
  that gate shutdown. Default: each branch associated with a path in the
  resolved `{session_worktrees}` set, plus the current branch when it differs
  from `{base_branch}`.
- `{session_worktrees}` (soft-shutdown) — worktree absolute paths created
  during this thread that gate shutdown. Default: every worktree from
  `git worktree list --porcelain` other than the main and calling worktrees.
- `{include_categories}` (wrap-up) — only wrap up worktrees whose name begins
  with one of these category prefixes. Default: every non-base, non-calling
  worktree.
- `{exclude_categories}` (wrap-up) — skip worktrees whose name begins with one
  of these category prefixes. Default: empty.
