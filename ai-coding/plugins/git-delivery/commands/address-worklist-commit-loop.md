# Address Worklist Commit Loop

## Task
Iterate through every unaddressed item in a polymorphic `{worklist}` and produce exactly one Conventional Commits 1.0.0 commit per addressed item. When `{parallelism} > 1`, partition the unaddressed items disjointly across that many isolated git worktrees; each agent processes its slice strictly sequentially (one item, one commit, at a time). When the worklist source is in-repo and writable, the `- [ ]` → `- [x]` flip is staged INTO the same commit as the item's edits so the source's done-state is atomic with the work that produced it, and re-running against the same source is idempotent on the slice that already shipped.

## Parameters
- `{worklist}` — work-item source; required. Accepts any of:
  - a filesystem path to a markdown file with `- [ ]` checkbox items (indented subfields under each item such as `Where:` / `Why:` / `Done-when:` are captured when present; optional severity headings `Critical` / `Major` / `Minor` / `Nit` are captured as the item's `severity`);
  - a reference to prior chat content (e.g., `"the action items I described above"`); the agent resolves the reference to the most recent matching block and parses it with the same rules as a markdown source;
  - an MCP server endpoint exposing a `list` operation that returns items with at minimum `id` and `title` plus optional `done_when`, `severity`, and `module` fields, and optionally a `mark-done` operation for writeback;
  - one or more inline items in the invocation itself, separated by newlines or `;`.
  Items the source already marks done (`- [x]` in markdown, `done` in MCP) are excluded during normalization.
- `{mode}` — approval cadence; required. Allowed values: `interactive` (user approves the dispatch plan AND each per-item commit before it is created), `non-interactive` (user approves the plan ONCE, then the loop runs silently to completion), `force-approve-all` (no approvals at any point; every default — including the plan — is accepted automatically).
- `{parallelism}` — number of isolated worktrees to launch, each owning a disjoint slice of unaddressed items processed strictly sequentially; optional, default: `1`. MUST be an integer `>= 1`. When `1`, no worktree is created and the loop runs in the calling worktree.
- `{num_partitions}` — number of model-assignment partitions over the `{parallelism}` worktrees; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` and MUST evenly divide `{parallelism}`. When set together with an iterable `{agent_model}`, the iterable MUST be either a full per-agent iteration (length `{parallelism}`) or a per-partition iteration (length `{num_partitions}`).
- `{agent_model}` — model(s) for the worktree agent(s); optional, default: the parent agent's model. Accepts a single identifier (broadcast to every agent), a list of length `{parallelism}` (per agent by index), or a list of length `{num_partitions}` (per partition, broadcast within).
- `{base_branch}` — branch each worktree is forked from when `{parallelism} > 1`; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name}` — base name for the worktree directories and branches when `{parallelism} > 1`; optional, default: a kebab-case slug derived from the `{worklist}` source identifier. A 1-based index suffix (`-1`, `-2`, …) is appended per agent.
- `{partition_strategy}` — how unaddressed items are distributed across `{parallelism}` slices; optional, default: `round-robin`. Allowed values:
  - `round-robin` — item at zero-based index `i` is assigned to agent `(i mod parallelism) + 1`; balances heterogeneous item costs.
  - `contiguous` — preserve source order; agent `i` gets a contiguous chunk of roughly `ceil(N / parallelism)` items.
  - `severity-balanced` — distribute items so each slice carries comparable severity load using weights `critical=4`, `major=3`, `minor=2`, `nit=1`; validation rejects this strategy when any item lacks a `severity` field.
- `{commit_scope}` — Conventional Commits scope inserted into every per-item commit subject; optional, default: derived per-item from (in order) the item's `Where:` subfield, the nearest severity / section heading slug above the item, the MCP `module` field when present, the worklist source basename. When no scope can be derived, the subject omits the parenthetical.
- `{verify_command}` — shell command run inside the agent's worktree after each item's edits are staged but BEFORE the commit is created; optional. Exit code `0` counts as pass; any non-zero exit suppresses the commit, resets the working tree (`git reset --hard HEAD && git clean -fd`), and triggers `{on_failure}`. The command runs with `WORKLIST_ITEM_ID`, `WORKLIST_ITEM_TITLE`, `WORKLIST_ITEM_DONE_WHEN` (empty when absent), and `WORKLIST_ITEM_SOURCE_REF` exported in the environment.
- `{on_failure}` — policy applied when an item's implementation, `{verify_command}`, or commit creation fails; optional. Default depends on `{mode}`: `abort` for `interactive` (preserve the user's intent to review every commit), `retry-once-then-skip` for `non-interactive` and `force-approve-all`. Allowed values:
  - `abort` — stop the agent's slice; remaining items in the slice are reported as `aborted`.
  - `skip` — record the failure and advance to the next item without a commit.
  - `retry-once-then-skip` — re-attempt the item once with the captured failure output injected as additional context, then apply `skip` on a second failure.
  - `mark-blocked` — rewrite the source's `- [ ]` for that item to `- [!] <one-line reason>` and continue. Valid only when the source is an in-repo writable markdown file; validation rejects this value for other source kinds.
- `{max_consecutive_failures}` — per-agent circuit breaker; optional, default: unbounded. When set and an agent records this many consecutive non-`committed` items, the agent halts its slice regardless of `{on_failure}` and the slice is reported as `circuit-broken`. The counter resets to zero on each successful commit.
- `{worklist_writeback}` — how completed items are marked done in the source; optional, default: `auto`. Allowed values:
  - `auto` — for an in-repo writable markdown source, the `- [ ]` is rewritten to `- [x]` and staged INTO the same commit as the item's other changes; MCP sources receive a post-commit `mark-done` call when the endpoint exposes one; otherwise (chat reference, inline list, MCP without `mark-done`, or an out-of-worktree file) the entry is appended to `.address-worklist-commit-loop-state.json` at the worktree root.
  - `always` — require source mutation; validation rejects this value when the resolved source is not writable.
  - `never` — never mutate the source; useful for audit / read-only runs.
- `{max_items}` — hard cap on the total number of items the loop addresses across all agents; optional, default: unlimited. Items beyond the cap remain unaddressed in the source and are listed as `deferred (cap-hit)` in the report.
- `{dry_run}` — flag; when `true`, emit the dispatch plan and exit without creating worktrees, modifying files, running `{verify_command}`, producing commits, or mutating the source. Honored even in `force-approve-all`. Optional, default: `false`.

## Success Criteria
- [ ] Parameter validation completes before any worktree is created or any file is touched: integer constraints for `{parallelism}` / `{num_partitions}` / `{max_items}` / `{max_consecutive_failures}`; even division of `{num_partitions}` into `{parallelism}`; `{agent_model}` shape matches `{parallelism}` or `{num_partitions}` when iterable; `{mode}` / `{partition_strategy}` / `{on_failure}` / `{worklist_writeback}` each take an allowed value; `{partition_strategy} = severity-balanced` requires every item to have a severity field; `{on_failure} = mark-blocked` requires an in-repo writable markdown source; `{worklist_writeback} = always` requires a writable source. Validation failure aborts with an explanatory error naming the offending parameter and zero filesystem side effects.
- [ ] The normalized worklist is a uniform internal list where every item carries a stable `id`, a `title`, an optional `description`, an optional `done_when`, an optional `severity`, and a `source_ref` back-pointer. Items the source already marks done are excluded and counted separately in the report. Duplicate `id`s across normalized items abort the invocation with an explanatory error before any worktree is created.
- [ ] When `{parallelism} > 1`, exactly `{parallelism}` isolated worktrees are created off `{base_branch}` (each on its own branch derived from `{worktree_name}`); the unaddressed items are partitioned via `{partition_strategy}` such that every item appears in exactly one slice and the union of slices equals the normalized list minus any items deferred by `{max_items}`; each agent processes its slice strictly sequentially.
- [ ] Each successfully addressed item produces exactly one git commit. The subject follows Conventional Commits 1.0.0 (`<type>[(<scope>)]: <description>`, lowercase imperative description, no trailing period, `<= 72` characters). The body contains the item's `Done-when:` text verbatim when present, plus the footers `Worklist-Source: <source_ref>` and `Worklist-Item-Id: <id>`.
- [ ] When `{verify_command}` is provided, it runs after staging the item's changes and before the commit, with the documented env vars exported; on non-zero exit the commit is suppressed, the working tree is reset, and `{on_failure}` is applied — no commit for that item is ever created.
- [ ] When `{worklist_writeback}` is `auto` and the source is in-repo and writable, the source mutation is staged into the SAME commit as the item's other changes. When the source is MCP with a `mark-done` tool, the tool is called exactly once per committed item. When the source is otherwise immutable, the entry is appended to `.address-worklist-commit-loop-state.json` at the worktree root.
- [ ] `{on_failure}` is honored deterministically per item: `abort` stops the slice; `skip` resets the working tree and continues; `retry-once-then-skip` retries once with the captured failure output injected; `mark-blocked` rewrites the source line to `- [!] <reason>`. Failed items are never marked done in the source.
- [ ] When `{max_consecutive_failures}` is set, an agent halts its slice the moment the consecutive-failure counter reaches the limit (status `circuit-broken`); the counter resets to zero on each successful commit.
- [ ] `{mode}` is honored exactly: `interactive` requires plan approval AND per-commit approval, `non-interactive` requires the plan approval only, `force-approve-all` requires nothing.
- [ ] When `{dry_run}` is `true`, no worktree is created, no file is touched, `{verify_command}` does not run, no commit is produced, and the source is not mutated; the final report contains only the rendered plan. Holds even under `force-approve-all`.
- [ ] Re-running the command against the same `{worklist}` after a successful run with `{worklist_writeback} = auto` and an in-repo writable source normalizes to zero unaddressed items.
- [ ] The plan and the final report both name every source file mutated by more than one slice under `Cross-branch conflicts predicted`, so the user can anticipate merge conflicts before any downstream merge.

## Guardrails
- MUST treat one item as exactly one commit. MUST NOT bundle multiple items into a single commit, split one item across multiple commits, or amend / rebase / squash prior items' commits; the loop is forward-only.
- MUST follow Conventional Commits 1.0.0 for every commit subject and include the `Worklist-Source:` and `Worklist-Item-Id:` footers in every commit body (plus the `Done-when:` line when the item supplied one). Items whose commit cannot be formatted (missing title, malformed scope) MUST trigger `{on_failure}` rather than be committed with placeholder text.
- MUST keep each spawned agent's execution isolated to its assigned worktree when `{parallelism} > 1`; agents MUST NOT read, write, or run commands against the calling worktree or any sibling worktree.
- MUST NOT mutate worklist items the loop did not successfully address in this invocation; partial-success runs leave unaddressed items untouched in the source.
- MUST NOT push, open PRs, create tags, rebase pre-existing branches, merge worktree branches, delete worktrees, or touch any branch other than the per-agent branch assigned to each slice.
- MUST NOT recursively fan out: agents launched under `{parallelism} > 1` run with `{parallelism} = 1` and MUST NOT spawn further worktrees.
- Scope: parsing one `{worklist}`, partitioning its unaddressed items across up to `{parallelism}` sibling worktrees forked from one `{base_branch}`, producing one commit per addressed item, and writing the source mutation into that same commit when feasible. Out of scope: merging worktree branches, pushing, opening PRs, creating tags, generating new worklists, addressing items not in the original normalized worklist, refactoring beyond what each item requires, and resolving cross-agent merge conflicts on the worklist source after fan-out.

## Workflow
1. **Parse and validate.** Extract every parameter, apply documented defaults, confirm every constraint in Success Criteria. Abort on the first failure with an explanatory error and zero filesystem side effects.
2. **Resolve and normalize `{worklist}`.** Dispatch on source kind:
   - **Filesystem path:** read the file, capture every `- [ ]` item with its indented subfields, record the section heading as `severity` when it matches `Critical` / `Major` / `Minor` / `Nit`, and use `<path>:<line>` as the `source_ref`. Drop `- [x]` items.
   - **Chat reference:** locate the most recent matching block in the active chat and parse it with the same rules as a markdown source; `source_ref` is `chat:<anchor>`; source is immutable.
   - **MCP endpoint:** call `list` once, cache the response, map each non-done entry to the internal shape, and record whether `mark-done` is exposed.
   - **Inline:** split the trailing items on newlines or `;`; assign sequential ids (`inline-1`, `inline-2`, …); source is immutable.
   Generate deterministic ids (slugified title plus a short hash of `source_ref`) when the source does not supply one. Abort with an explanatory error on duplicate ids.
3. **Filter and cap.** Apply `{max_items}` to the normalized list; record deferred items in their original order.
4. **Partition.** Apply `{partition_strategy}` to split the remaining items into `{parallelism}` disjoint slices. Resolve the per-agent model assignment from `{agent_model}` (scalar broadcast, length-`{parallelism}` per-agent, or length-`{num_partitions}` per-partition expanded across the partition's agents). Identify source files mutated by more than one slice and record them under `Cross-branch conflicts predicted`.
5. **Render and approve the plan.** Build the plan table (one row per item: index, slice, agent, item id, title, severity, proposed commit subject, has-done-when), and include resolved parameters, model assignment, source mutability, and the `Cross-branch conflicts predicted` set. In `interactive` and `non-interactive` modes, present the plan and require approval; in `force-approve-all` mode, auto-accept. When `{dry_run}` is `true`, emit the plan as the final report and stop (even under `force-approve-all`).
6. **Create worktrees and dispatch agents** (skip both when `{parallelism} = 1` and run the loop in the calling worktree). For each agent `i` in `1..{parallelism}`, create a branch off `{base_branch}` named `{worktree_name}-{i}`, add the worktree via `git worktree add`, and dispatch one agent inside that worktree with its slice and every per-item parameter.
7. **Per-item loop (sequential, inside each agent).** For each item in the agent's slice, in slice order:
   1. Apply the item's changes inside the agent's worktree, scoped strictly to what the item describes.
   2. When `{worklist_writeback}` is `auto` (and the source is in-repo and writable) or `always`, rewrite the matching `- [ ]` to `- [x]` on the recorded source line.
   3. Stage all changes (`git add -A`) — item edits plus the in-place writeback when applicable.
   4. Run `{verify_command}` when set with the documented env vars exported; capture exit code and a tail of stdout/stderr. On non-zero exit, reset the working tree (`git reset --hard HEAD && git clean -fd`), apply `{on_failure}`, increment the consecutive-failure counter, and (when `{max_consecutive_failures}` is set and reached) halt the slice as `circuit-broken`.
   5. Compose the commit subject as `<type>[(<scope>)]: <description>` (type per the Conventional Commits decision framework; scope per `{commit_scope}` or its per-item derivation; description = item title in lowercase imperative mood under 72 characters) and the body (item title, `Done-when:` line when present, `Worklist-Source:` and `Worklist-Item-Id:` footers).
   6. In `interactive` mode, present the staged diff with the proposed commit message and wait for approval; on decline, reset the working tree, record `commit-declined`, and continue. In `non-interactive` and `force-approve-all` modes, create the commit without prompting.
   7. Create the commit and record its SHA. Reset the consecutive-failure counter.
   8. When `{worklist_writeback}` is `auto` and the source is external (MCP, chat, inline, or out-of-worktree), perform the post-commit writeback (`mark-done` call or `.address-worklist-commit-loop-state.json` append).
8. **Aggregate and report.** After all agents finish (success, abort, circuit-broken, or cap-hit), collect per-agent and per-item statuses and emit the report below. Do not merge worktree branches.

## Output Format
A single response with these named sections, in order. Omit any section whose body would be empty.

### Run Summary
- `Worklist source`: resolved identifier and kind (`markdown-file` / `chat` / `mcp` / `inline`).
- `Source mutability`: `mutable` or `immutable (<reason>)`.
- `Mode`: `interactive` / `non-interactive` / `force-approve-all`.
- `Base branch`: resolved `{base_branch}` (or `n/a` when `{parallelism} = 1`).
- `Parallelism`: integer (with `Partitions: <N>` when `{num_partitions} != {parallelism}`).
- `Partition strategy`: resolved `{partition_strategy}`.
- `Failure policy`: resolved `{on_failure}` (with `Consecutive-failure limit: <N>` when `{max_consecutive_failures}` is set).
- `Writeback`: resolved `{worklist_writeback}`.
- `Counts`: items normalized / already-done / deferred / committed / blocked / skipped / aborted / circuit-broken / commit-declined.
- `Dry run`: `true` or `false`.

### Plan
A table with one row per normalized item:

| # | Slice | Agent | Item id | Title | Severity | Proposed commit subject | Has done-when |
|---|-------|-------|---------|-------|----------|-------------------------|---------------|

Reproduced before plan approval in `interactive` and `non-interactive` modes; the only output in `force-approve-all` plus `{dry_run}=true`.

### Per-Agent Results
One block per agent, in launch order:
- `Index`: 1-based agent index.
- `Worktree path`: absolute path (or `<calling worktree>` when `{parallelism} = 1`).
- `Branch`: branch name (or `<calling branch>` when `{parallelism} = 1`).
- `Agent model`: model identifier used.
- `Slice size`: number of items assigned.
- `Terminal state`: `completed`, `aborted (item=<id>)`, `circuit-broken (after <N> consecutive failures)`, or `cap-hit`.
- `Items`: rows of `item_id | status | commit_sha (short) | verify_exit | one-line note`, where `status` is `committed` / `skipped` / `blocked` / `aborted` / `commit-declined`. Sub-bullets carry retry detail or verification output tails.

### Worklist Source Mutations
- `Mutated in-commit`: rows for items whose source entry landed atomically with the item commit (file path + line + commit SHA).
- `Mutated post-commit`: rows for items where the writeback was a post-commit `mark-done` call or a `.address-worklist-commit-loop-state.json` append (source reference + commit SHA).
- `Not mutated`: rows for items whose source is immutable under the configured writeback (one-line reason each).

### Cross-Branch Conflicts Predicted
Listed only when `{parallelism} > 1` and at least one source path was mutated by more than one slice. One bullet per shared path: `<path>` plus the list of slice indices that touched it.

### Failures
Itemized list of every item whose status is not `committed`. For each: item id, owning agent index, status, last `{verify_command}` exit code when applicable, and a 1–3 sentence root-cause note quoting any failing output.

### Next Steps
- Per-agent branches and worktree paths left in place for the user to inspect or merge separately.
- For `skipped` / `commit-declined` items: suggested follow-up (rerun with adjusted `{on_failure}` or `{verify_command}`, or address manually).
- For `circuit-broken` slices: suggested follow-up (raise `{max_consecutive_failures}` and rerun, or address the root cause externally first).
- For `deferred (cap-hit)` items: suggested follow-up (raise `{max_items}` and rerun, or partition the remaining items into a separate invocation).
- A reminder that no branches were merged, no worktrees were deleted, and no remotes were touched.
