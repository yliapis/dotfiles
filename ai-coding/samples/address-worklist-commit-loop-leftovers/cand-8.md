# Address Worklist Commit Loop

## Task
Drive an unchecked worklist of work items to completion by addressing each item, optionally verifying it, and producing exactly one Conventional Commits–style git commit per item; when `{parallelism} > 1`, partition the unchecked items across isolated git worktrees so each agent owns a disjoint slice and processes its slice sequentially.

The command normalizes a polymorphic `{worklist}` source (markdown file, prior-chat reference, MCP server endpoint, or inline list), filters out items already marked done, dispatches partitions of items to one or more worktree agents, and after each successful per-item commit marks the originating item as done in the source when the source is mutable and in-repo.

## Parameters
- `{worklist}` — work-item source; required. Accepts any of: a path to a markdown file containing `- [ ]` checkbox items (optionally with subfields such as `Where:`, `Why:`, and `Done when:`), a reference to prior chat content (e.g., "the action items I described above"), an MCP server endpoint that exposes a list of work items, or inline items in the invocation itself. Items already marked done (`[x]` in markdown, `done` status from MCP, etc.) are filtered out before dispatch. Each retained item is normalized to an internal record holding a stable id, a title, a description, and an optional done-when condition.
- `{mode}` — approval mode; required. Allowed values: `interactive` (the user approves the dispatch plan AND each individual commit before it is created), `non-interactive` (the user approves the dispatch plan once, then the loop runs silently to completion without further approvals), `force-approve-all` (no approvals at any point; every default is accepted automatically including the dispatch plan itself).
- `{parallelism}` — number of isolated worktrees to create, each owning a disjoint slice of unchecked items processed SEQUENTIALLY one item at a time; optional, default: `1`. MUST be an integer `>= 1`. With `1`, no worktrees are created and the entire item list is processed in the calling working tree.
- `{num_partitions}` — number of partitions used to group worktrees by `{agent_model}`; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` and MUST evenly divide `{parallelism}`. When set together with an iterable `{agent_model}`, the iterable MUST either be a full iteration (length `{parallelism}`, one model per worktree) or a correctly-sized slice for the partitions (length `{num_partitions}`, one model per partition broadcast to that partition's worktrees).
- `{agent_model}` — model(s) to use for the worktree agent(s); optional, default: the parent agent's model. Accepts a single model identifier (broadcast to every agent), a list whose length equals `{parallelism}` (positional per agent), or a list whose length equals `{num_partitions}` (per partition, broadcast to that partition's agents).
- `{base_branch}` — branch to fork worktrees from when `{parallelism} > 1`; optional, default: the current branch (`git rev-parse --abbrev-ref HEAD`).
- `{partition_strategy}` — how unchecked items are split across worktrees; optional, default: `round-robin`. Allowed values: `round-robin` (interleave items by index for balanced load when item costs are heterogeneous), `chunk` (contiguous slices preserving source order so related items stay together), `severity-balanced` (when items carry a severity field, distribute so each partition holds a comparable mix of severities). Strategies that depend on a missing field (e.g., `severity-balanced` on a flat list) fall back to `chunk` and the fallback is recorded in the report.
- `{verify_command}` — shell command run inside the worktree after the item's edits but before the per-item commit is created; optional. Exit code `0` counts as pass; any non-zero exit triggers `{on_failure}`. The command receives the normalized item id via the environment variable `WORKLIST_ITEM_ID`.
- `{on_failure}` — policy applied when an item's edits or `{verify_command}` fail; optional, default: `retry-once-then-skip`. Allowed values: `abort` (stop the partition immediately and leave the worktree dirty for inspection), `skip` (revert the item's edits, record the failure, continue with the next item), `retry-once-then-skip` (revert, re-attempt the item once with the captured failure output injected as additional context, then skip on a second failure).
- `{commit_scope}` — Conventional Commits scope override applied to every commit subject; optional, default: derived per-item from the worklist source (e.g., for a markdown file, the nearest section heading slug; for an MCP item, the `module` field when present; otherwise omitted). When the resolved scope is empty, the commit subject omits the parenthetical scope.
- `{max_items}` — hard cap on the total number of items the loop will address across all partitions; optional, default: unlimited. MUST be a positive integer when set; reaching the cap stops further dispatch and is reported as `cap-hit`.
- `--dry-run` — flag that runs normalization, partitioning, and per-item planning, then emits the dispatch plan and exits without creating worktrees, editing files, running `{verify_command}`, or creating commits; optional, default: absent.

## Success Criteria
- [ ] Parameters are validated before any worktree is created or any item is touched: `{parallelism}` is an integer `>= 1`, `{num_partitions}` is an integer `>= 1` that evenly divides `{parallelism}`, an iterable `{agent_model}` has length equal to `{parallelism}` or `{num_partitions}`, `{mode}` is one of the three allowed values, `{partition_strategy}` is one of the three allowed values, `{on_failure}` is one of the three allowed values, `{max_items}` is unset or a positive integer, and the resolved `{worklist}` is reachable and contains at least one unchecked item. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] The polymorphic `{worklist}` is normalized into a uniform internal list of records `{id, title, description, done_when}` before partitioning; items lacking a stable id receive a deterministic id derived from a hash of their title and description, items already marked done in the source are filtered into the `skipped (already done)` bucket, and the report records both the source kind and the filter counts.
- [ ] When `{parallelism} > 1`, exactly `{parallelism}` isolated worktrees are created off `{base_branch}`, each agent owns a disjoint slice of unchecked items determined by `{partition_strategy}`, and no item appears in more than one partition.
- [ ] In `interactive` mode, the user is shown the dispatch plan (per-partition item lists with ids and titles, planned commit subjects, partition strategy, model assignment) and explicitly approves it before any worktree is launched; the user is also shown each formatted commit subject and body and explicitly approves before that commit is created.
- [ ] In `non-interactive` mode, the user is shown the dispatch plan and explicitly approves it once before any worktree is launched; no further approval is requested for individual commits.
- [ ] In `force-approve-all` mode, no approval prompts are issued at any point; the dispatch plan is auto-accepted and every commit is created without per-item confirmation.
- [ ] Each addressed item produces exactly one git commit on the agent's branch whose subject follows Conventional Commits 1.0.0 (a type token, an optional parenthesized scope, an optional breaking-change `!`, a colon, then the item title) and whose body includes a `Worklist-Source:` footer naming the original `{worklist}` location and, when the item carries a done-when condition, a `Done-When:` footer restating that condition verbatim.
- [ ] If `{verify_command}` is provided, it is invoked inside the worktree with `WORKLIST_ITEM_ID` set to the item's normalized id and the captured exit code is recorded per item; on non-zero exit, `{on_failure}` is applied and the resulting outcome (`retried-passed`, `retried-failed-skipped`, `aborted`, `skipped`) is recorded in the report.
- [ ] When the `{worklist}` source is mutable and in-repo (e.g., a markdown file in the repository), the corresponding source entry is mutated to mark the item done and that mutation is staged into the SAME commit as the item's other changes, so the source mutation lands atomically with the item's commit; when the source is external (prior chat, read-only MCP), every successfully addressed item is flagged in the report under `external-source-not-mutated`.
- [ ] When `--dry-run` is set, the command emits the dispatch plan and exits without creating worktrees, editing any files outside the dispatch-plan output, running `{verify_command}`, or creating any commits.
- [ ] The final report includes, per partition, the worktree path, branch, agent model, and per-item record `{id, title, outcome, commit_sha or n/a, verify_exit or n/a}`, plus an aggregate Run Summary with counts by outcome and a `Cross-branch conflicts predicted` list naming any source files mutated by more than one partition.

## Guardrails
- MUST validate every parameter before creating any worktree, editing any file, running `{verify_command}`, or producing any commit; create nothing on validation failure.
- MUST keep each partition's processing isolated to its assigned worktree; agents MUST NOT read, write, or run commands against the calling working tree, any sibling worktree, or any path outside their assigned worktree root.
- MUST produce exactly one commit per addressed item; agents MUST NOT batch multiple worklist items into a single commit, MUST NOT amend prior commits, and MUST NOT push, open PRs, create tags, or rebase pre-existing branches.
- MUST honor `{mode}` literally: `interactive` requires per-commit approval, `non-interactive` requires plan-once approval and zero further prompts, `force-approve-all` issues no approval prompts at any stage.
- MUST format every commit subject per Conventional Commits 1.0.0 and MUST include the `Worklist-Source:` footer in every commit body; commits that cannot be formatted (missing item title, malformed scope) MUST trigger `{on_failure}` rather than be created with placeholder text.
- MUST NOT mutate items in the worklist source that the loop did not successfully address in this invocation; partial-success runs leave unaddressed items untouched in the source.
- MUST NOT recursively launch worktree agents from inside an already-running worktree partition; partitions are leaf workers.
- Scope: this command processes one `{worklist}`, dispatches its unchecked items across up to `{parallelism}` sibling worktrees forked from one `{base_branch}`, and produces one commit per addressed item on each agent's branch. Out of scope: pushing branches, opening PRs, creating tags, merging worktree branches back into `{base_branch}`, and managing items beyond the supplied `{worklist}`.

## Workflow
1. **Parse and validate.** Extract `{worklist}`, `{mode}`, `{parallelism}`, `{num_partitions}`, `{agent_model}`, `{base_branch}`, `{partition_strategy}`, `{verify_command}`, `{on_failure}`, `{commit_scope}`, `{max_items}`, and `--dry-run` from the invocation. Validate types, allowed values, even-division of `{num_partitions}` into `{parallelism}`, and the `{agent_model}` length contract; abort with an explanatory error and no filesystem side effects on any failure.
2. **Resolve and normalize the worklist.** Detect the source kind from `{worklist}` (markdown file path, prior-chat reference, MCP endpoint, or inline list) and read it. Parse `- [ ]` / `- [x]` checkboxes for markdown, `done`/`open` status for MCP, and pattern-match prior-chat content into discrete items. Filter already-done items into the `skipped (already done)` bucket. Normalize each remaining item into `{id, title, description, done_when}`, generating deterministic ids from a hash of title and description where missing.
3. **Plan partitioning.** Apply `{partition_strategy}` to split the normalized unchecked items into `{parallelism}` disjoint slices, falling back to `chunk` and recording the fallback when the strategy depends on a missing field. Resolve the per-agent model assignment via `{agent_model}` and `{num_partitions}`. When `{max_items}` is set, truncate the global dispatch list to that cap before partitioning and record the cap-hit count.
4. **Approve the plan.** Render the dispatch plan: per-partition item lists with ids and titles, planned commit subjects, partition strategy, model assignment, and any fallback notes. In `interactive` and `non-interactive` modes, present the plan to the user and require explicit approval before continuing; in `force-approve-all` mode, auto-accept the plan. If `--dry-run` is set, emit the plan and exit without further side effects.
5. **Create worktrees (when `{parallelism} > 1`).** For each partition `i` in `1..{parallelism}`, create a new branch off `{base_branch}` named after the worklist source slug with a `-{i}` suffix and add a matching worktree via `git worktree add`. With `{parallelism} = 1`, skip this step and operate in the calling working tree.
6. **Dispatch partitions.** Launch one agent per worktree on its assigned model, instructing each to process its slice SEQUENTIALLY one item at a time using the per-item loop in step 7. Concurrency across partitions is unbounded — every worktree runs in parallel — but within a partition the loop is strictly sequential.
7. **Per-item loop (sequential, inside each worktree).** For each item in the partition, in the assigned order:
   1. Make the edits required to satisfy the item's description and done-when condition.
   2. If `{verify_command}` is set, run it with `WORKLIST_ITEM_ID` set to the item's id and capture the exit code; on non-zero exit, apply `{on_failure}` (`abort` ends the partition, `skip` reverts the item's edits and continues, `retry-once-then-skip` reverts and re-attempts once with the captured failure output injected, then skips on a second failure).
   3. If the worklist source is mutable and in-repo, mutate the source to mark this item done.
   4. Stage all changes (item edits plus the source mutation when applicable).
   5. Format the commit subject per Conventional Commits 1.0.0 (type inferred from the item, scope from `{commit_scope}` or derived per-item, optional `!` for breaking changes, item title as the description) and the commit body with the `Worklist-Source:` footer and (when present) the `Done-When:` footer.
   6. In `interactive` mode, present the formatted subject and body to the user and require explicit approval; on decline, revert all staged changes for this item, record `skipped (commit-declined)`, and continue. In `non-interactive` and `force-approve-all` modes, create the commit without prompting.
   7. Create the commit and record its SHA against the item.
8. **Aggregate and report.** After all partitions complete (or abort), collect per-partition and per-item outcomes (commit SHAs, verification results, failure dispositions, source-mutation status) and emit the report using the Output Format below.

## Output Format
Return a single response with the following named sections, in this order:

### Run Summary
- `Worklist source`: kind (`markdown`, `prior-chat`, `mcp`, or `inline`) and reference (path, endpoint, or `inline`).
- `Mode`: `interactive`, `non-interactive`, or `force-approve-all`.
- `Parallelism`: `{parallelism}`.
- `Partition strategy`: `round-robin`, `chunk`, or `severity-balanced`, with a fallback note when one was applied.
- `Items`: total normalized / unchecked / addressed / skipped (already done) / skipped (failed) / cap-hit.
- `Counts by outcome`: committed / retried-passed / retried-failed-skipped / aborted / skipped (commit-declined) / cap-hit.

### Partitions
One block per partition, in launch order:
- `Index`: 1-based partition index.
- `Worktree path`: absolute path, or `n/a` when `{parallelism} = 1`.
- `Branch`: branch name, or `n/a` when `{parallelism} = 1`.
- `Agent model`: model identifier used.
- `Items`: ordered list of `{id, title, outcome, commit_sha or n/a, verify_exit or n/a}` in processed order.

### Worklist Source Mutations
- `Mutated`: list of items whose source entries were marked done in this invocation, with file path and line range when the source is a markdown file in-repo, plus the commit SHA each mutation landed in.
- `Not mutated`: list of items addressed but whose source is external (prior chat, read-only MCP), flagged under `external-source-not-mutated`.
- `Cross-branch conflicts predicted`: list of source files mutated by more than one partition (these will conflict when their branches are merged); empty when `{parallelism} = 1` or no shared source mutations occurred.

### Errors and Skips
One bullet per failed or skipped item with: item id, partition index, disposition (`aborted`, `skipped`, `cap-hit`, `retried-failed-skipped`, `skipped (commit-declined)`), and a one-sentence reason grounded in the captured failure output.
