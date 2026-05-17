# Address Worklist Commit Loop

## Task
Iterate through a worklist of action items and produce exactly one Conventional Commits-style git commit per item, optionally fanning the work out across isolated git worktrees so disjoint slices of items proceed in parallel.

The loop normalizes any supported worklist shape (markdown checkbox file, prior chat content, MCP server endpoint, inline items) into a uniform internal queue, skips items already marked done, and runs each remaining item through implement → verify → writeback → commit in sequence inside the agent's worktree.

## Parameters
- `{worklist}` — required. Polymorphic worklist source. Accepts: a file path (markdown with `- [ ]` items, optionally with `Where:` / `Why:` / `Done-when:` subfields and severity-section headers), a reference to prior chat content (e.g., "the action items above"), an MCP server endpoint that exposes a list of items, or inline items in the invocation. Normalized into an internal list where each item carries a stable identifier, a description, and an optional done-when condition.
- `{mode}` — required. Approval policy. Allowed values: `interactive` (the user approves the overall plan AND each individual commit before it is created), `non-interactive` (the user approves the plan once, then the loop runs silently to completion without further approvals), `force-approve-all` (no approvals required at any point; every default is accepted automatically, including the plan).
- `{parallelism}` — number of agents to run concurrently, each in its own worktree, with the unchecked items partitioned across them; optional, default: `1`. MUST be an integer `>= 1`; otherwise the workflow aborts before any worktree is created. Each agent owns a disjoint slice of items and addresses its slice sequentially, one item at a time.
- `{num_partitions}` — number of partitions to split items into; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` and MUST evenly divide `{parallelism}`. When set together with an iterable `{agent_model}`, validation requires `{agent_model}` to provide either a full per-agent iteration or a correctly-sized per-partition slice.
- `{agent_model}` — model(s) to use for the worktree agent(s); optional, default: the parent agent's model. Accepts a single identifier (broadcast to every agent), a list of length `{parallelism}` (mapped positionally by agent), or a list of length `{num_partitions}` (mapped positionally by partition and broadcast within).
- `{base_branch}` — branch to fork each worktree from when `{parallelism} > 1`; optional, default: the current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name}` — base name for the worktree directory and branch when `{parallelism} > 1`; optional, default: a kebab-case slug derived from the worklist source. A 1-based index suffix (`-1`, `-2`, …) is appended per agent.
- `{partition_strategy}` — how items are assigned to partitions; optional, default: `chunked`. Allowed values: `chunked` (contiguous slices preserve worklist order locality per agent), `round-robin` (item `i` goes to partition `((i-1) mod {num_partitions}) + 1`), `interleaved-by-severity` (group items by their `severity` metadata when present and apply round-robin within each group so high-severity items are spread across agents; falls back to `round-robin` when no item carries severity metadata).
- `{test_command}` — shell command each agent runs inside its worktree after each item's commit, as a verification gate beyond the item's done-when condition; optional. Exit code `0` counts as pass; any other exit code is a verification failure that triggers the `{on_failure}` policy for that item.
- `{on_failure}` — what to do when a single item fails to verify or commit; optional, default: `rollback-and-skip`. Allowed values: `abort` (stop the agent immediately; remaining items in that partition are left unprocessed and reported as `deferred`), `continue` (commit anyway and proceed to the next item; the item is flagged in the report), `skip-item` (drop the item's working changes via `git restore --staged . && git restore .` and proceed without committing), `rollback-and-skip` (if a commit for the item was already created, revert it via `git reset --hard HEAD~1`; otherwise drop staged and unstaged changes for the item; then proceed).
- `{commit_scope}` — Conventional Commits scope override applied to every commit subject; optional, default: inferred per item from the dominant top-level directory or component the item's implementation touches. When set, every commit uses `type({commit_scope}): description`.
- `{worklist_writeback}` — whether and how to mutate the worklist source by flipping `- [ ]` to `- [x]` after each item's commit lands; optional, default: `auto`. Allowed values: `auto` (writeback when the source is mutable in the agent's worktree, e.g., a writable markdown file or an MCP endpoint that exposes an update operation; no-op for prior-chat or inline sources), `manual` (record the would-be edits in the per-item report but do not modify the source), `none` (skip writeback entirely, including the report entry).
- `{max_items_per_agent}` — safety cap on the number of items each agent will process; optional, default: unlimited. When set, agents truncate their assigned slice to the first `{max_items_per_agent}` items and report the remainder as `deferred`.
- `{dry_run}` — boolean flag; optional, default: `false`. When `true`, every step runs (normalization, implementation, verification, would-be commit subject derivation) except `git commit` and worklist writeback; agents leave their working trees with staged diffs and produce a report describing what would have been committed.

## Success Criteria
- [ ] Parameters are validated before any worktree is created: `{parallelism}` and `{num_partitions}` are integers `>= 1`; `{num_partitions}` evenly divides `{parallelism}`; `{agent_model}` shape matches scalar, list-of-`{parallelism}`, or list-of-`{num_partitions}`; `{mode}`, `{partition_strategy}`, `{on_failure}`, and `{worklist_writeback}` each take a value from their allowed set. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] `{worklist}` is resolved into a normalized internal list before partitioning. Each normalized item carries a stable identifier, a description, and an optional done-when condition; items already marked done in the source (e.g., `- [x]` in a markdown file) are excluded from the list entirely and never re-processed.
- [ ] In `interactive` mode, the user approves the rendered plan once before any worktree is created AND is shown each item's staged diff plus proposed commit subject for explicit approval before the commit is created.
- [ ] In `non-interactive` mode, the user approves the rendered plan exactly once; after approval the loop runs to completion without further approval prompts.
- [ ] In `force-approve-all` mode, no approval prompts are issued; every default is accepted automatically including the plan itself.
- [ ] Exactly `{parallelism}` isolated worktrees are created from `{base_branch}` when `{parallelism} > 1`, each on its own branch derived from `{worktree_name}` with a 1-based index suffix. When `{parallelism} == 1`, no worktree is created and the loop runs in the calling working tree.
- [ ] Each unchecked, non-deferred worklist item produces exactly one git commit whose subject follows Conventional Commits 1.0.0 (`type(scope): description`, with `scope` optional and `description` derived from the item's title), and whose body links back to the worklist source (path or reference) and includes the item's done-when condition verbatim when one was present.
- [ ] Each agent owns a disjoint slice of items determined by `{partition_strategy}` and processes its slice sequentially in order; no two agents commit changes for the same worklist identifier.
- [ ] When `{test_command}` is provided, each agent runs it inside its worktree after each item's commit and the captured exit code is reported per item; non-zero exit codes invoke the `{on_failure}` policy for that item.
- [ ] When `{worklist_writeback}` is `auto` and the source is mutable inside the agent's worktree, the agent flips that item's `- [ ]` to `- [x]` as part of the SAME commit that addresses the item (staged together with the implementation changes), preserving the one-item-one-commit invariant.
- [ ] When `{dry_run}` is `true`, no `git commit` is executed and no worklist source is mutated; the report enumerates the would-be commit subjects and the staged diff for each item.
- [ ] The final response includes a Run Summary, the approved Plan reproduced verbatim, per-agent Agent Results blocks, and an Overall Summary as defined in the Output Format below.

## Guardrails
- MUST validate `{parallelism}`, `{num_partitions}`, `{agent_model}`, `{mode}`, `{partition_strategy}`, `{on_failure}`, and `{worklist_writeback}` before creating any worktree; fail fast with no filesystem side effects on validation failure.
- MUST keep each agent's work isolated to its assigned worktree; agents MUST NOT read, write, or run commands against the calling working tree or any sibling worktree.
- MUST produce exactly one git commit per addressed worklist item; an agent that creates zero or multiple commits for the same item is reporting a workflow failure for that item.
- MUST derive every commit subject from the item's title using Conventional Commits 1.0.0 syntax, applying `{commit_scope}` as the scope when set and otherwise inferring scope from the dominant directory or component the item's implementation touches.
- MUST skip every item already marked done in the source without touching it, without committing on its behalf, and without re-flipping its state.
- MUST NOT bundle changes from multiple worklist items into a single commit, even when the items touch overlapping files; sequence dependent items within the same partition and commit each separately.
- MUST NOT modify the worklist source when `{worklist_writeback}` is `manual` or `none`, nor when `{dry_run}` is `true`.
- MUST apply `{on_failure}` deterministically: a verification or commit failure invokes exactly the configured behavior for that item and never silently falls through to another policy.
- MUST NOT push, open pull requests, create tags, rebase pre-existing branches, merge worktree branches back into `{base_branch}`, delete worktrees, or touch any branch outside the worktrees this command creates.
- MUST NOT recursively spawn worktree agents from inside a worktree agent.
- Scope: this command owns the per-item loop end-to-end inside the worktrees it creates — normalization, partitioning, implementation, verification, commit, and writeback. Out of scope: producing the worklist itself, judging item priority, merging worktree branches, deleting worktrees after completion, and any cross-item refactor that would require multiple worklist items to share a single commit.

## Workflow
1. Parse and validate parameters. Confirm `{parallelism}` and `{num_partitions}` are integers `>= 1`, `{num_partitions}` evenly divides `{parallelism}`, `{agent_model}` shape matches one of the allowed forms, and the enumerated parameters (`{mode}`, `{partition_strategy}`, `{on_failure}`, `{worklist_writeback}`) take allowed values. Abort with an explanatory error and no filesystem side effects on any validation failure.
2. Resolve `{worklist}` to a normalized list. Detect shape: markdown file path → parse `- [ ]` items together with their `Where:` / `Why:` / `Done-when:` subfields and severity-section header (when present); prior chat reference → extract the items from the referenced content; MCP endpoint → fetch and map each entry to the internal item shape; inline items → parse directly. Assign each item a stable identifier (source-derived when present, otherwise a hash of the item's text). Exclude items the source marks done.
3. Apply `{max_items_per_agent}` per-partition cap (after partitioning, see step 4). Compute partitions per `{partition_strategy}`: `chunked` produces `{num_partitions}` contiguous slices of roughly equal size; `round-robin` sends item `i` to partition `((i-1) mod {num_partitions}) + 1`; `interleaved-by-severity` buckets items by severity metadata and applies round-robin within each bucket, falling back to `round-robin` overall when no item carries severity. Map each partition to its agents and resolve `{agent_model}` per agent.
4. Render the plan: total items resolved, items skipped as already-done, per-partition item assignments, agent-to-model mapping, worktree-to-branch mapping, the resolved value of every optional parameter, and the explicit ordered list of items each agent will own.
5. Plan approval. In `interactive` and `non-interactive` modes, present the plan and wait for the user's explicit go-ahead. In `force-approve-all` mode, accept the plan without prompting.
6. When `{parallelism} > 1`, for each `i` in `1..{parallelism}`, create a new branch off `{base_branch}` named `{worktree_name}-{i}` and add a matching worktree via `git worktree add`. When `{parallelism} == 1`, skip worktree creation and run the loop in the calling working tree.
7. Launch one agent per worktree concurrently. Each agent receives: its assigned slice (the normalized items), the resolved source location (for writeback), `{mode}`, `{test_command}`, `{commit_scope}`, `{worklist_writeback}`, `{on_failure}`, `{dry_run}`, and `{max_items_per_agent}`. Spawned agents MUST NOT fan out further.
8. Per-agent loop. For each assigned item in order:
   a. Implement the change required by the item's description and done-when condition inside the worktree only.
   b. Evaluate the done-when condition. When the condition is a shell command, run it and treat exit code `0` as pass. When it is a description, self-check against it and record the rationale.
   c. When `{test_command}` is set, run it inside the worktree and record the exit code.
   d. If any verification step failed, apply `{on_failure}` for this item and continue or stop accordingly; record the outcome (`failed`, `skipped`, or `deferred`) in the per-item report.
   e. Stage the implementation changes. When `{worklist_writeback}` is `auto` and the source is mutable in this worktree, flip the item's `- [ ]` to `- [x]` in the source and stage that change together with the implementation so both land in the same commit.
   f. Derive the commit subject: type inferred from the item's nature (`feat`, `fix`, `refactor`, `docs`, `perf`, `test`, `chore`, etc.); scope set to `{commit_scope}` when provided or inferred from the dominant directory or component touched; description derived from the item's title. Build the body: link back to the worklist source (path or reference), include the item's done-when condition verbatim when present, and reference the item's stable identifier.
   g. In `interactive` mode, present the staged diff and proposed commit subject and wait for the user's per-item approval; in `non-interactive` and `force-approve-all` modes, proceed without prompting.
   h. When `{dry_run}` is `false`, run `git commit` to produce exactly one commit for this item. When `{dry_run}` is `true`, leave the changes staged, record the would-be subject and body, and skip writeback even when `{worklist_writeback}` is `auto`.
   i. When the per-partition cap from `{max_items_per_agent}` is reached, mark every remaining assigned item as `deferred` and stop the agent's loop.
9. Collect per-agent results: terminal status (`success` when every assigned item produced a commit or was deliberately skipped/deferred per the policies; `partial` when at least one item failed but the loop continued; `failed` when `{on_failure}=abort` was triggered; `incomplete` when the agent did not return), per-item rows, the `git log {base_branch}..HEAD --oneline` listing, and any `{test_command}` output tails.
10. Render the final report using the Output Format below. Do not merge worktree branches, do not delete worktrees, and do not push: those decisions are out of scope and belong to a subsequent workflow.

## Output Format
Return a single response with the following named sections, in this order:

### Run Summary
- `Mode`: resolved `{mode}`.
- `Parallelism`: `{parallelism}` agents across `{num_partitions}` partitions, strategy `{partition_strategy}`.
- `Base branch`: resolved `{base_branch}`, or `n/a` when `{parallelism} == 1`.
- `Worklist source`: original `{worklist}` reference and the counts `resolved` / `skipped-as-done` / `deferred` / `failed` / `committed`.
- `Dry run`: `true` or `false`.

### Plan
The rendered plan as approved (or auto-accepted in `force-approve-all` mode), reproduced verbatim. Includes per-agent item assignments, the agent-to-model mapping, and the resolved value of every optional parameter.

### Agent Results
One block per agent, in launch order:

- `Index`: 1-based agent index.
- `Worktree path`: absolute path, or `n/a` when `{parallelism} == 1`.
- `Branch`: branch name, or the calling branch when `{parallelism} == 1`.
- `Agent model`: model identifier used.
- `Status`: `success`, `partial`, `failed`, or `incomplete`.
- `Items`: a table, one row per assigned item, with columns `item_id`, `commit_sha` (or `dry-run` / `skipped` / `deferred` / `failed`), `verification` (`pass` / `fail` / `n/a`), `writeback` (`done` / `manual-noted` / `skipped` / `n/a`), and a one-line `outcome` summary.
- `Commit log`: a fenced ` ```text ` block containing `git log {base_branch}..HEAD --oneline` for that worktree, truncated above ~200 lines with `... (truncated, K lines omitted)` when oversized.
- `Verification tail`: when `{test_command}` is set, the last ~40 lines of its output from the final item this agent processed; otherwise `n/a`.

### Overall Summary
- Total items addressed, failed, skipped, deferred, and dry-run across all agents.
- Aggregate verification pass/fail counts.
- The next manual step the user is expected to take (e.g., reviewing each worktree's diffs and choosing whether to merge), framed as informational only since this command does not perform merges.
