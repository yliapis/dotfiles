# Address Worklist Commit Loop

## Task
Walk through a polymorphic list of work items and produce exactly one Conventional Commits commit per addressed item, optionally partitioning the items across isolated git worktrees that each work through their own slice sequentially.

The command targets a recurring pattern: a critique, review, or planning pass yields a bounded list of follow-ups, and each follow-up should land as a single focused commit so history reads "one item, one commit". The same loop must work whether the worklist comes from a markdown file with `- [ ]` checkboxes, a reference to prior chat content, an MCP server endpoint, or items typed inline in the invocation.

## Parameters
- `{worklist}` — source of work items; required. Accepts any of: a file path (typically markdown with `- [ ]` checkbox items, optionally with `Where:` / `Why:` / `Done-when:` subfields), a reference to prior chat content (e.g., "the action items I described above"), an MCP server endpoint that exposes a list of work items, or items typed inline in the invocation itself. The command normalizes any of these into a uniform internal worklist whose items each carry, at minimum, a stable identifier, a description, and an optional done-when condition. Items already marked done in the source (e.g., `- [x]`) are excluded from the loop.
- `{mode}` — approval policy for the loop; required. Allowed values: `interactive` (the user approves the overall plan AND each individual commit before it is created), `non-interactive` (the user approves the plan ONCE, then the loop runs to completion without further approvals), `force-approve-all` (no approvals are solicited at any point and every default is accepted automatically, including the plan itself).
- `{parallelism}` — number of isolated worktrees to partition unchecked items across; optional, default: `1`. MUST be an integer `>= 1`. Each spawned agent owns a disjoint slice of items and addresses its slice strictly sequentially, one item at a time. This is item partitioning, not best-of-N: slices are concatenated in the final report, never compared or selected from. Validation happens before any worktree is created.
- `{num_partitions}` — number of partitions used to group worktrees that share an `{agent_model}`; optional, default: same as `{parallelism}`. MUST be an integer `>= 1`. When set together with an iterable `{agent_model}`, the workflow raises an error unless `{agent_model}` provides a full per-agent iteration or a correctly-sized iterable slice for the partitions.
- `{agent_model}` — model(s) to use for the worktree agent(s); optional, default: the parent agent's model. Accepts a single model identifier (broadcast to every agent), a list of identifiers whose length equals `{parallelism}` (mapped positionally by agent index), or a list of identifiers whose length equals `{num_partitions}` (broadcast to every agent within a partition).
- `{base_branch}` — branch to fork worktrees from; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name}` — base name for the worktree directories and branches; optional, default: a filesystem-safe kebab-case slug derived from the resolved `{worklist}` source identifier. When `{parallelism}` is greater than `1`, a 1-based index suffix (`-1`, `-2`, …) is appended per agent.
- `{partition_strategy}` — algorithm for splitting unchecked items across `{parallelism}` slices; optional, default: `contiguous`. Allowed values: `contiguous` (preserve source order; agent `i` gets items `[i*chunk, (i+1)*chunk)`), `round-robin` (agent `i` gets items at indices `i, i+P, i+2P, …`), `by-severity` (group items by an explicit severity field — `critical`, `major`, `minor`, `nit` — and round-robin within each group across slices to spread risk evenly).
- `{commit_scope}` — Conventional Commits scope to apply to every commit subject; optional. When unset, the scope is derived per item from the worklist section heading or the source filename and is omitted entirely when no usable scope can be inferred.
- `{test_command}` — shell command run inside the agent's worktree after the item's edits and before its commit, used to evaluate the item's done-when condition; optional. Exit code `0` counts as pass; any other exit code counts as fail. The literal token `{item_id}` inside `{test_command}` is substituted with the current item's stable identifier before execution.
- `{retry_policy}` — how to handle a failing `{test_command}`; optional, default: `none`. Allowed values: `none` (a single failure is a failure), `retry-once` (re-run the same agent on the same item one more time before failing), `retry-once-with-feedback` (re-run with the captured failure output appended to the agent's context).
- `{on_item_failure}` — policy when an item ultimately fails after `{retry_policy}` is exhausted; optional, default: `skip`. Allowed values: `abort` (stop this agent's loop and leave the rest of its slice unaddressed), `skip` (move on to the next item; do not mark the source done), `mark-blocked` (move on and, when the source is mutable, replace `- [ ]` with `- [!]` for that item plus a one-line failure note appended to the same line).
- `{max_items}` — maximum number of items to address across all agents in this invocation; optional, default: unlimited. Items beyond the cap remain untouched in the source and are listed as deferred in the final report.
- `{dry_run}` — when `true`, run the full plan and (when `{test_command}` is provided) the verification step but produce no commits and make no changes to the worklist source; optional, default: `false`. The report explicitly labels each item that would have committed.
- `{stop_condition}` — explicit completion condition beyond "the assigned slice is exhausted"; optional. Evaluated per agent after each commit; satisfaction stops that agent's loop early.
- `{report_verbosity}` — final report detail level; optional, default: `summary`. Allowed values: `summary` (per-agent counts plus the aggregate) or `verbose` (everything in `summary` plus the per-item table and the full subject line of every commit).

## Success Criteria
- [ ] Parameters are validated before any worktree is created: `{mode}` is one of `interactive` / `non-interactive` / `force-approve-all`; `{parallelism}` and `{num_partitions}` are integers `>= 1`; if `{agent_model}` is a list its length equals `{parallelism}` or `{num_partitions}`; `{partition_strategy}`, `{retry_policy}`, and `{on_item_failure}` are restricted to their allowed value sets. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] The resolved `{worklist}` is normalized to a uniform internal list where every item carries a stable identifier, a description, and an optional done-when condition; items already marked done in the source (e.g., `- [x]`) are excluded from the loop and counted separately in the report.
- [ ] When `{parallelism} > 1`, exactly `{parallelism}` isolated worktrees are created from `{base_branch}`, each on its own branch derived from `{worktree_name}`, and the unchecked items are split into `{parallelism}` disjoint slices according to `{partition_strategy}` whose union is the full unchecked set (subject to `{max_items}`).
- [ ] Each agent addresses its slice sequentially: the next item only begins after the previous item's commit has landed or its failure has been handled per `{on_item_failure}`.
- [ ] Every addressed item produces exactly one git commit whose subject follows Conventional Commits 1.0.0 — `<type>[(scope)]: <description>` — and whose body cites the worklist source identifier and includes the item's done-when condition verbatim when one was present.
- [ ] In `interactive` mode, the user is asked to approve the plan once before any agent starts, and again per item before that item's commit is finalized; in `non-interactive` mode, only the initial plan approval is solicited and the loop then runs to completion without further questions; in `force-approve-all` mode, no approvals are solicited and the workflow proceeds with all defaults accepted.
- [ ] When the resolved `{worklist}` source is mutable (a writable file path), the calling agent updates the source in the calling worktree after each per-item commit lands: items committed are rewritten from `- [ ]` to `- [x]`, and items handled with `{on_item_failure}` = `mark-blocked` are rewritten to `- [!]` with a one-line failure note appended on the same line. When the source is immutable (chat reference, MCP endpoint without write API, inline items), the report states this explicitly and no in-place updates are attempted.
- [ ] When `{test_command}` is provided, it runs once per item between the edits and the commit, with `{item_id}` substituted; exit code `0` is recorded as pass and any other exit code triggers `{retry_policy}` and then `{on_item_failure}`.
- [ ] When `{dry_run}` is `true`, the workflow runs to the report step but no `git commit` is executed, the worklist source is not modified, and the report explicitly labels each item that would have committed.
- [ ] The final report lists, per agent: worktree path, branch, agent model, slice size, items committed (with commit SHAs and subject lines), items skipped or marked blocked (with reasons), and items left unaddressed if `{stop_condition}` triggered or `{on_item_failure}` = `abort` fired.
- [ ] Across the entire invocation, the count of new commits on the agent branches equals the count of items reported as committed; no item appears in more than one commit and no commit covers more than one item.

## Guardrails
- MUST validate `{worklist}`, `{mode}`, `{parallelism}`, `{num_partitions}`, `{agent_model}`, `{partition_strategy}`, `{retry_policy}`, and `{on_item_failure}` before creating any worktree; fail fast and create nothing on validation failure.
- MUST keep each spawned agent's execution isolated to its assigned worktree; spawned agents MUST NOT read, write, or run commands against the calling worktree or any sibling worktree, except for the single read of their assigned slice that the calling agent passes in via the agent prompt.
- MUST produce exactly one commit per addressed item; the commit subject MUST follow Conventional Commits 1.0.0 and the commit body MUST cite the worklist source identifier and (when present) the item's done-when condition verbatim.
- MUST honor the active `{mode}`: solicit per-commit approvals only in `interactive`, solicit a single plan approval in `non-interactive`, and solicit no approvals in `force-approve-all`.
- MUST NOT bundle multiple items into a single commit, split a single item across multiple commits, reorder items beyond what `{partition_strategy}` prescribes, or address items already marked done in the source.
- MUST NOT modify the worklist source for items the agent did not commit; the calling agent updates the source in the calling worktree only after the matching per-item commit lands (or, for `mark-blocked`, only after the item has finally failed).
- MUST NOT push, open PRs, create tags, rebase pre-existing branches, merge worktree branches into `{base_branch}`, or touch unrelated branches.
- MUST NOT recursively spawn nested worktree-task agents from inside an item-addressing loop.
- Scope: address a worklist by producing one commit per item across `{parallelism}` isolated worktrees forked from one `{base_branch}`, with optional source-file checkbox updates in the calling worktree. Out of scope: cross-item refactors, branch merging, remote operations, and editing files unrelated to the current item.

## Workflow
1. **Validate parameters.** Confirm `{mode}` is one of the three allowed values; `{parallelism}` and `{num_partitions}` are integers `>= 1`; `{agent_model}` (if a list) has length equal to `{parallelism}` or `{num_partitions}`; `{partition_strategy}`, `{retry_policy}`, and `{on_item_failure}` are within their allowed value sets. Abort with an explanatory error and no filesystem side effects on failure.
2. **Resolve `{worklist}`.** Detect the source kind in this order — file path, prior chat reference, MCP endpoint, inline items — and load it. Record the source kind and a stable source identifier (absolute path for files, a chat anchor for prior chat, the endpoint for MCP, or an invocation timestamp for inline) so the mutation step later knows whether the source is writable and what to cite in commit bodies.
3. **Normalize items.** Convert the loaded source into a uniform list where each item has fields `{ id, description, done_when, severity, source_anchor }` (with `done_when` and `severity` optional). Generate a stable identifier from the source anchor: a line range for files, a sequence index for chat / inline / MCP. Drop items already marked done.
4. **Filter and cap.** Apply `{max_items}` if set; record the number of items deferred and which items were deferred (preserving original order).
5. **Partition.** Split the remaining items into `{parallelism}` disjoint slices using `{partition_strategy}`. Record the slice for each agent index.
6. **Build the plan.** For each agent, list its slice (id + description), the assigned model, the worktree path, and the projected commit count. Compute aggregate totals (items normalized, items addressed, items deferred, items already done).
7. **Plan approval gate.** In `interactive` and `non-interactive` mode, present the plan and require explicit approval before continuing; in `force-approve-all` mode, log the plan and proceed without prompting.
8. **Resolve worktree environment.** Record the current branch as `{base_branch}` unless explicitly provided. Resolve the per-agent model assignment per the validated `{agent_model}` shape (scalar broadcast, length-`{parallelism}` per-agent, or length-`{num_partitions}` per-partition).
9. **Create worktrees.** For each `i` in `1..{parallelism}`, create a new branch off `{base_branch}` named after `{worktree_name}` (with `-{i}` suffix when `{parallelism} > 1`) and add a matching worktree via `git worktree add`.
10. **Run the per-agent loop.** Launch one agent per worktree concurrently across worktrees, but each agent runs its own slice strictly sequentially with these per-item steps:
    1. Pop the next unaddressed item from the slice and ingest its description and done-when condition from the agent prompt.
    2. Implement the change required to satisfy the item, scoped to files this item touches.
    3. If `{test_command}` is provided, substitute `{item_id}` and run it inside the worktree; capture stdout, stderr, and exit code.
    4. On test failure, apply `{retry_policy}` (zero, one, or one-with-feedback retries); on persistent failure, apply `{on_item_failure}` and either continue, abort the slice, or mark the item blocked.
    5. On success (or when `{test_command}` is unset), stage the changes and create exactly one commit. Resolve the subject as `<type>[(<scope>)]: <description>` where the type follows the conventional-commits decision framework; `<scope>` is `{commit_scope}` if set, otherwise the inferred scope, otherwise omitted; `<description>` is the item title rewritten in lowercase imperative mood with no trailing period and a length under 72 characters. The body contains the source identifier on one line, the item identifier on the next line, and the verbatim done-when condition (when present) on subsequent lines.
    6. In `interactive` mode, present the staged diff and the proposed commit message and require approval before the commit is finalized; in `non-interactive` and `force-approve-all` modes, finalize without prompting.
    7. Record the commit SHA, subject, and outcome (`committed` / `skipped` / `blocked` / `aborted`) in the agent's per-item ledger and emit it back to the calling agent.
    8. If `{stop_condition}` is provided and now satisfied, stop this agent's loop early.
11. **Mutate source after each commit (when mutable).** After every per-item ledger entry from any agent, the calling agent updates the worklist source in the calling worktree only: rewrite `- [ ]` to `- [x]` for committed items, and rewrite to `- [!] <reason>` for items recorded as blocked. Spawned agents do not edit the worklist source themselves. Skip this step entirely when the source is immutable.
12. **Aggregate.** Wait for every agent to finish. Collect per-agent terminal status, items committed (with SHAs and subjects), items skipped, items blocked, and items left unaddressed.
13. **Report.** Render the per-agent and overall summary using the Output Format below; verbosity follows `{report_verbosity}`. Do not merge worktree branches and do not delete worktrees.

## Output Format
Return a single response with the following named sections, in this order.

### Run Summary
- `Worklist source`: resolved kind (`file` / `chat` / `mcp` / `inline`) and identifier.
- `Mode`: `interactive` / `non-interactive` / `force-approve-all`.
- `Base branch`: resolved `{base_branch}`.
- `Parallelism`: `{parallelism}` (and `{num_partitions}` when different).
- `Partition strategy`: `{partition_strategy}`.
- `Items normalized`: total unchecked items found.
- `Items addressed`: counts of `committed` / `skipped` / `blocked` / `unaddressed`.
- `Items deferred by max_items`: count plus the deferred ids.
- `Dry run`: `true` or `false`.

### Per-Agent Results
One block per agent, in launch order:

- `Index`: 1-based agent index.
- `Worktree path`: absolute path.
- `Branch`: worktree branch name.
- `Agent model`: model identifier used.
- `Slice size`: number of items assigned.
- `Status`: `success` (entire slice committed), `partial` (slice fully decided but with skipped or blocked items), `aborted` (`{on_item_failure}` = `abort` fired and the rest of the slice was left unaddressed), or `incomplete` (the agent did not finish reporting).
- `Commits`: a numbered list of `<short-sha> — <subject>` lines, one per item committed (omit when empty in `summary` verbosity; always include in `verbose`).
- `Skipped / blocked`: per-item bullets in the form `<item_id> — <reason>` (omit when empty).
- `Unaddressed`: per-item bullets when `{stop_condition}` or `{on_item_failure}` = `abort` left items pending (omit when empty).

### Worklist Source Updates
- When the source is mutable: list every line that was rewritten in the calling worktree, with the before-and-after marker (`- [ ]` → `- [x]`, or `- [ ]` → `- [!] <reason>`).
- When the source is immutable: state `Source is immutable; no in-place updates were performed.`

### Final Notes
- Any guardrail tripwires that fired (e.g., abort on first failure, validation rejection, test retries exhausted).
- Any items deferred by `{max_items}` and the suggested follow-up invocation to address them.
- A reminder that no branches were merged and no worktrees were deleted by this command.
