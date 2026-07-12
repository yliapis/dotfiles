# Lifecycle

What persists when a run ends: whether files are written at all (the write
gate), which branch merges where, what gets pushed, and how sources are marked
done. Isolation ([isolation.md](isolation.md)) governs where work happens;
lifecycle governs what escapes it.

## Cards

### `write_gate` (family)
- **Aliases:** `update_mode` (meta-prompt), `persistence` (ralph-design, design-skill, designer-controller), `dry_run` (address-worklist-commit-loop), `mode` (save-session-state)
- **Applies to:** command, skill
- **Meaning:** Whether the run mutates the filesystem or only shows what it
  would do. Four spellings with distinct enums, one concept — each artifact
  below gates its primary deliverable write behind a no-write mode. (Not
  every writing artifact is in the family: trajectory-snapshot has no
  preview mode and guards its snapshot write with a never-overwrite
  collision rename instead — see
  [Overwrite postures](#overwrite-postures).)

  | Artifact | Spelling | Values | Write behavior |
  |---|---|---|---|
  | meta-prompt | `{update_mode}` | `auto` (default), `plan`, `agent`, `dry-run`, `confirm` | `auto` writes when a target is resolvable, else shows the block; `plan` always shows; `agent` always writes (aborts without a target); `dry-run` previews manifest + diffs; `confirm` asks y/n (interactive only, else behaves as `plan`) |
  | ralph-design | `{persistence}` | `chat`, `codebase` (default) | `chat` keeps the working artifact in-conversation; `codebase` writes `artifact_path` each round (inside a worktree per `use_worktree`) |
  | design-skill | `persistence` | `chat`, `codebase` (default) | same semantics; the artifact is the deliverable |
  | designer-controller | `persistence` | `chat` (default), `codebase` | same semantics; note the default flips to `chat` |
  | address-worklist-commit-loop | `{dry_run}` | `true`, `false` (default) | `true` emits the dispatch plan and exits — no worktrees, edits, verify runs, commits, or source mutation, even in `force-approve-all` |
  | save-session-state | `{mode}` | `write` (default), `preview` | `preview` emits the snapshot in chat and creates or replaces no file |

- **Validation:** the design skills reject `artifact_path` / `use_worktree`
  when `persistence=chat`; meta-prompt's `agent` mode requires a resolvable
  save target.
- **Used by:** meta-prompt, ralph-design, design-skill, designer-controller, address-worklist-commit-loop, save-session-state

### `merge_mode`
- **Aliases:** —
- **Applies to:** skill
- **Type:** enum: `interactive` | `auto`
- **Default:** `interactive`
- **Meaning:** How the winning worktree branch is chosen after diffs are
  presented: `interactive` asks the user which branch (if any) to merge;
  `auto` merges at most one branch, and only when its agent reported success,
  `test_command` passed, `stop_condition` is satisfied, and
  `git merge --no-ff` produces no conflicts (lowest index wins ties). At most
  one branch merges per invocation in either mode.
- **Propagation:** agent-swarm always dispatches worktree-task with
  `{merge_mode} = interactive` and hands the chosen branch back through
  worktree-task's merge prompt.
- **Used by:** worktree-task (declared), agent-swarm (sets it)

### `remote`
- **Aliases:** —
- **Applies to:** command
- **Type:** configured git remote name
- **Default:** `origin`
- **Meaning:** The remote used for end-of-run push or push-hygiene checks:
  merge-commit-push pushes the target branch to it; wrap-up pushes
  `base_branch` after the archive merge; soft-shutdown checks it for unpushed
  commits.
- **Used by:** merge-commit-push, wrap-up, soft-shutdown

## Overwrite postures

What happens when an output path already exists. Three distinct postures are
live:

- **Abort or confirm** — save-session-state (`{mode}` = `write`): an existing
  `{output_path}` aborts with an explanatory error naming the path; with
  `-i` / `--interactive` the run asks before overwriting. No silent
  truncation either way.
- **Explicit force** — design-skill: an existing `artifact_path` aborts
  unless `force=true` (see Artifact-specific below).
- **Never overwrite, rename** — trajectory-snapshot: on collision a `-2`
  (then `-3`, …) suffix is appended before the extension until the name is
  free, so overwriting is impossible by contract. This suffix dodges
  collisions; it is distinct from the fan-out index suffix `-<i>` that
  numbers siblings on [`worktree_name`](isolation.md#worktree_name) and on
  meta-prompt's rewritten [`artifact_path`](io.md#artifact_path).

## Artifact-specific

- `{source_branch}` (merge-commit-push) — branch to merge from. Default:
  current branch.
- `{target_branch}` (merge-commit-push) — branch merged into; must exist
  locally. Default: `main`.
- `{merge_strategy}` (merge-commit-push) — merge-commit shape: `--no-ff`
  (default) | `--ff-only` | `--squash`.
- `{commit_message}` (merge-commit-push) — squash commit message; required
  when `{merge_strategy}` is `--squash`.
- `{include_push}` (merge-commit-push) — push after a successful merge.
  Default: `true`.
- `{commit_scope}` (address-worklist-commit-loop) — Conventional Commits scope
  for per-item commit subjects. Default: derived per item (Where: subfield →
  nearest heading slug → MCP module → source basename).
- `{worklist_writeback}` (address-worklist-commit-loop) — how completed items
  are marked done in the source: `auto` (default) | `always` | `never`.
- `{save_trajectory}` (wrap-up) — whether the trajectory + learnings files are
  written. Default: `interactive` (prompt at end) when `-i` is set, `false`
  otherwise.
- `force` (design-skill) — overwrite an existing `artifact_path` instead of
  aborting. Default: `false`; rejected with `persistence=chat`.
- `{allow_unpushed}` (soft-shutdown) — tolerate unpushed commits on the
  current branch without blocking shutdown. Default: `false`.
