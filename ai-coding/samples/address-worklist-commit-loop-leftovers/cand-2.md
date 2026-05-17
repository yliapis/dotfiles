# Address Worklist Commit Loop

## Task
Iterate over a normalized worklist of unfinished work items, dispatch each item to a sequential addressing loop (single agent or partitioned across worktrees), and produce exactly one Conventional Commits-style git commit per addressed item, marking the source as done when it is mutable. The command bridges a list of "things to do" and a series of small, reviewable commits.

## Parameters
- `{worklist}` — source of work items; required. Accepts one of: a file path (markdown with `- [ ]` checkboxes, optionally with `Where` / `Why` / `Done-when` subfields under each item); a reference to prior chat content (e.g., `chat:above` or a quoted excerpt of the items the user described in the conversation); an MCP endpoint URI of the form `mcp://<server>/<list-tool>?<query>` that returns a list of work items; or an inline block introduced with `inline:` followed by newline-separated items. Items already marked done (`- [x]` in markdown, `status: done` for MCP responses, or equivalent) MUST be skipped during normalization.
- `{mode}` — approval semantics for the run; required. Allowed values:
  - `interactive` — the user approves the rendered plan, then approves each individual commit (subject plus `git diff --staged`) before it is created.
  - `non-interactive` — the user approves the plan once at the start, then the loop runs to completion without further approvals; per-item failures are handled automatically by `{on_failure}` and reported at the end.
  - `force-approve-all` — no approval prompts are emitted at any point; every default (plan, commit subject, failure handling) is accepted automatically.
- `{parallelism}` — number of sibling worktree agents to launch for ITEM PARTITIONING (not best-of-N); optional, default: `1`. MUST be an integer `>= 1`. The normalized worklist is split into `{parallelism}` disjoint slices and each agent processes its slice SEQUENTIALLY, one item at a time. When `{parallelism}` is `1`, the loop runs in the calling worktree with no fan-out.
- `{num_partitions}` — number of partitions used for `{agent_model}` assignment; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` and MUST divide `{parallelism}` evenly. When set together with an iterable `{agent_model}`, the iterable MUST be either a full per-agent iteration of length `{parallelism}` or a correctly-sized per-partition iteration of length `{num_partitions}`.
- `{agent_model}` — model(s) to use for each addressing agent; optional, default: parent agent's model. Accepts a single identifier (broadcast to every agent) or a list of identifiers mapped per agent (length `{parallelism}`) or per partition (length `{num_partitions}`).
- `{base_branch}` — branch from which to fork worktrees and against which final per-agent diffs are computed; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `{partition_strategy}` — how items are distributed across slices when `{parallelism} > 1`; optional, default: `contiguous`. Allowed values: `contiguous` (split index-order into N runs of approximately equal size), `round-robin` (deal items by index modulo N), `severity-balanced` (interleave items grouped by severity label so each slice receives a roughly equal share of high-severity items; falls back to `contiguous` when severity labels are absent).
- `{verify_command}` — shell command run inside the worktree after each commit to verify the item's `Done-when` condition; optional. Exit code `0` counts as verified; any other exit code counts as failed and triggers `{on_failure}`. The command receives `$WORKLIST_ITEM_ID`, `$WORKLIST_ITEM_DONE_WHEN`, and `$WORKLIST_COMMIT_SHA` in the environment.
- `{on_failure}` — what to do when an item's addressing or verification fails; optional, default: `abort`. Allowed values: `abort` (stop the agent's slice, leave preceding commits in place, mark remaining items as `aborted`), `skip` (reset the working tree to `HEAD`, leave no commit for the failing item, continue with the next item), `revert` (run `git reset --hard HEAD~1` to drop the failing item's commit, continue with the next item).
- `{max_items}` — safety cap on how many items any single agent will address before stopping; optional, default: unbounded. When set, MUST be a positive integer; remaining items are reported as `skipped-by-cap`.
- `{commit_scope}` — Conventional Commits scope applied to every commit subject (e.g., `auth`, `api`); optional. When an item carries its own scope hint (e.g., a `[auth]` prefix in the item title or an explicit `scope:` subfield), the item-level scope wins over `{commit_scope}`.
- `{dry_run}` — when `true`, render the plan and per-agent slice assignments and exit without creating worktrees, commits, or source mutations; optional, default: `false`.

## Success Criteria
- [ ] Parameter validation runs before any worktree is created: `{parallelism}` and `{num_partitions}` are integers `>= 1`; `{num_partitions}` divides `{parallelism}` evenly; `{agent_model}` (if a list) has length equal to either `{parallelism}` or `{num_partitions}`; `{mode}` is one of `interactive` / `non-interactive` / `force-approve-all`; `{on_failure}` is one of `abort` / `skip` / `revert`; `{partition_strategy}` is one of `contiguous` / `round-robin` / `severity-balanced`; `{max_items}` (when set) is a positive integer. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] The worklist is normalized into an internal list where each item carries a stable identifier (e.g., `worklist://<source>#<anchor-or-index>`), a one-line description, the verbatim `Done-when` condition (when present), an optional severity label, an optional scope hint, and a back-reference to the source. Items already marked done are excluded from the normalized list and reported in the plan with status `skipped-already-done`.
- [ ] When `{worklist}` resolves to an MCP endpoint, the endpoint is queried exactly once at the start of the run, the response is cached for the duration of the run, and any subsequent re-queries (e.g., to record completion) reuse the same item identifiers from the cache.
- [ ] The plan presented to the user lists every normalized item with: index, item id, slice / agent, projected commit subject, severity, scope, has-done-when. The plan also reports the resolved partition strategy, `{on_failure}` policy, per-agent model assignment, and whether the source is mutable.
- [ ] In `interactive` mode, the user is asked to approve the plan as a whole and, for each item, to approve the commit subject and `git diff --staged` before `git commit` runs.
- [ ] In `non-interactive` mode, the plan approval is requested exactly once at the start; after approval, no further user input is requested for the duration of the run.
- [ ] In `force-approve-all` mode, no approval prompts are emitted at any point in the workflow, including plan approval.
- [ ] Exactly one git commit is produced per successfully addressed item; the commit subject follows Conventional Commits 1.0.0 (e.g., `fix(auth): resolve token refresh race`); the commit body includes a `Worklist: <source>#<item-id>` footer and, when the item has a `Done-when` condition, a `Done-when: <verbatim done-when>` footer.
- [ ] When `{parallelism}` is `1`, all commits land on the calling branch in the order produced by `{partition_strategy}` applied to a single slice.
- [ ] When `{parallelism}` is greater than `1`, exactly `{parallelism}` isolated worktrees are created off `{base_branch}`, each on its own branch derived from the command name with a 1-based index suffix, and each agent's commits land only on its own branch.
- [ ] The union of all per-agent slices equals the unchecked, normalized worklist, and the intersection of any two slices is empty.
- [ ] When `{verify_command}` is provided, it is executed inside the worktree after each commit; the exit code and a brief output tail are recorded per item; a non-zero exit code triggers `{on_failure}` with phase `verify`.
- [ ] When the worklist source is a writable file, the `- [ ]` → `- [x]` mutation for an addressed item is staged alongside that item's code changes so both land in the same commit; when the source is an MCP endpoint exposing a `mark-done` tool, the tool is called once per item after its commit succeeds.
- [ ] When the worklist source is immutable (chat content, read-only file, or MCP endpoint without a `mark-done` tool), no mutation is attempted and the report explicitly states `Source is immutable; no mutation attempted.`
- [ ] When `{dry_run}` is `true`, no worktrees, branches, commits, or source mutations are created, and the reply contains the plan and per-agent slice assignments only.
- [ ] The final report lists, per agent: worktree path, branch, agent model, slice contents, per-item status (`committed`, `skipped-already-done`, `skipped-by-failure-policy`, `skipped-by-cap`, `aborted`, `verify-failed`), each commit SHA, the resolved `{on_failure}` action when applicable, and the `{verify_command}` exit code and tail when applicable.

## Guardrails
- MUST validate `{parallelism}`, `{num_partitions}`, `{agent_model}`, `{mode}`, `{on_failure}`, `{partition_strategy}`, and `{max_items}` before creating any worktree; fail fast and create nothing on validation failure.
- MUST partition the unchecked worklist into disjoint slices: every item appears in exactly one slice, and the union of all slices equals the unchecked worklist.
- MUST process each agent's slice strictly sequentially: an agent MUST NOT start item `i+1` until item `i` has either produced a commit or been resolved by `{on_failure}`.
- MUST keep each agent's work isolated to its assigned worktree; agents MUST NOT read, write, or run commands against the calling worktree or any sibling worktree.
- MUST produce exactly one git commit per successfully addressed item; bundling multiple items into one commit, squashing items together, or amending a previous item's commit is prohibited.
- MUST format every commit subject per Conventional Commits 1.0.0 and include the `Worklist:` footer (and `Done-when:` footer when the item carried one) in the commit body for traceability.
- MUST NOT request user approval in `non-interactive` mode (beyond the single up-front plan approval) or in `force-approve-all` mode (at any point).
- MUST NOT mutate an immutable source; when mutation is impossible, record `Source is immutable; no mutation attempted.` in the report rather than failing the item.
- MUST NOT push, open pull requests, create tags, rebase pre-existing branches, or touch any branch other than `{base_branch}` and the per-agent worktree branches created by this invocation.
- MUST NOT recursively launch worktree agents from inside a per-agent slice run; only the calling agent is allowed to fan out.
- MUST NOT attempt cross-worktree synchronization of source mutations; when `{parallelism} > 1`, each agent mutates its own worktree-local copy of the source independently, and reconciling those mutations into a single branch is left to the user.
- Scope: this command processes one `{worklist}` end-to-end into a series of single-item commits across at most `{parallelism}` sibling worktrees forked from one `{base_branch}`. Out of scope: PR creation, branch merging, item generation, prioritization, cross-item refactoring, and any work that does not correspond to a single normalized worklist item.

## Workflow
1. **Validate parameters.** Confirm `{parallelism}` and `{num_partitions}` are integers `>= 1`; `{num_partitions}` divides `{parallelism}` evenly; `{agent_model}` (if a list) has length `{parallelism}` or `{num_partitions}`; `{mode}` / `{on_failure}` / `{partition_strategy}` are members of their allowed sets; `{max_items}` (if set) is a positive integer. Abort with no filesystem side effects on validation failure.
2. **Resolve `{base_branch}`.** Use the explicit value, otherwise capture the current branch.
3. **Load and normalize `{worklist}`.** Read from file, query the MCP endpoint, capture from chat reference, or parse the inline block. Strip items already marked done. For each remaining item assign a stable identifier (`worklist://<source>#<anchor-or-index>`), extract title, severity (when present), scope hint (when present), and `Done-when` condition (when present). Record whether the source is mutable and, for MCP sources, whether a `mark-done` tool is available.
4. **Partition.** Apply `{partition_strategy}` to split the normalized list into `{parallelism}` disjoint slices. Resolve the per-agent model assignment from `{agent_model}` (scalar broadcast, per-agent list, or per-partition list expanded across agents).
5. **Render the plan.** Present total item count, skipped count, per-slice assignment with projected commit subjects, resolved partition strategy, model per agent, `{on_failure}` policy, and source mutability.
6. **Plan approval.** In `interactive` and `non-interactive` mode, ask the user to approve or reject the plan. In `force-approve-all` mode, skip this step. If `{dry_run}` is `true`, stop here and emit only the plan section of the report.
7. **Create worktrees.** When `{parallelism}` is greater than `1`, create `{parallelism}` worktrees off `{base_branch}` via `git worktree add`, each on its own branch named `address-worklist-commit-loop-<i>` (1-based). When `{parallelism}` is `1`, operate in the calling worktree without creating any worktree.
8. **Address each slice.** Agents run in parallel across slices but each agent processes its slice strictly sequentially. For each item in slice order, until the slice is exhausted or `{max_items}` is reached:
   1. Read the item's identifier, title, scope hint, severity, and `Done-when` condition.
   2. Plan and implement the change inside the agent's worktree.
   3. Compose the commit subject as `<type>(<scope>): <imperative summary>`, where `<type>` is selected per the Conventional Commits decision framework (`fix` for bug-style language, `feat` for additive, `refactor` for restructuring, `docs` for documentation-only, etc.) and `<scope>` is the item's scope hint, else `{commit_scope}`, else omitted.
   4. **Mutate the source for writable files.** When the source is a writable file, stage the `- [ ]` → `- [x]` transition for this item alongside the item's code changes so both land in the same commit.
   5. Compose the commit body with the footers `Worklist: <source>#<item-id>` and (when present) `Done-when: <verbatim done-when>`.
   6. In `interactive` mode, show the commit subject and `git diff --staged` and ask for approval. In other modes, skip the prompt.
   7. Run `git commit`; record the resulting SHA.
   8. **Mutate the source for MCP endpoints.** If the source is an MCP endpoint with a `mark-done` tool and the commit succeeded, invoke the tool with the item's identifier.
   9. If `{verify_command}` is set, run it inside the worktree with `$WORKLIST_ITEM_ID`, `$WORKLIST_ITEM_DONE_WHEN`, and `$WORKLIST_COMMIT_SHA` exported; record the exit code and output tail.
   10. If any of step 8.2, 8.7, 8.8, or 8.9 failed, apply `{on_failure}`: `abort` stops the slice and marks remaining items `aborted`; `skip` runs `git reset --hard HEAD` (preserving prior commits) and continues with the next item; `revert` runs `git reset --hard HEAD~1` (dropping this item's commit) and continues with the next item.
9. **Aggregate and report.** Once all agents have completed or aborted, collect per-agent results and emit the report using the Output Format below. Do not merge any worktree branch.

## Output Format
Return a single response with these named sections, in this order:

### Run Summary
- `Worklist source`: resolved source identifier and mutability.
- `Mode`: `interactive` / `non-interactive` / `force-approve-all`.
- `Base branch`: resolved `{base_branch}`.
- `Parallelism`: `{parallelism}` (with `{num_partitions}` and `{partition_strategy}`).
- `Failure policy`: resolved `{on_failure}`.
- `Counts`: total items, skipped-already-done, planned, committed, failed.

### Plan
A table listing every planned item with one row per item containing: index, item id, slice / agent, projected commit subject, severity, scope, has-done-when.

### Slice Results
One block per agent, in launch order, each containing:
- `Index`: 1-based agent index.
- `Worktree path`: absolute path, or `(calling worktree)` when `{parallelism}` is `1`.
- `Branch`: worktree branch name.
- `Agent model`: model identifier used.
- `Slice size`: number of items assigned.
- `Items`: ordered list with one row per item containing item id, final status (`committed` / `skipped-already-done` / `skipped-by-failure-policy` / `skipped-by-cap` / `aborted` / `verify-failed`), commit SHA when committed, `{verify_command}` exit code when applicable, and a one-line note.

### Source Mutation
- For mutable file sources: a fenced diff of the source file showing each `- [ ]` → `- [x]` transition, annotated by item id.
- For MCP sources with a `mark-done` tool: a list of `(item id, mark-done response status)` rows.
- For immutable sources: the literal sentence `Source is immutable; no mutation attempted.`

### Failure Log
Present this section only when at least one item ended in `aborted`, `verify-failed`, or `skipped-by-failure-policy`. For each such item, list: item id, agent index, the resolved `{on_failure}` action, the failure phase (`address`, `commit`, `verify`, or `mutate`), and the error tail.
