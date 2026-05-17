# Address Worklist Commit Loop

## Task

Walk through every unchecked item in a polymorphic `{worklist}` and produce exactly one Conventional Commits 1.0.0 commit per addressed item. When `{parallelism}` is greater than `1`, partition the unchecked items disjointly across that many isolated git worktrees; each agent processes its slice strictly sequentially (one item, one commit, at a time). When the worklist source is a writable markdown file, the `- [ ]` → `- [x]` flip is staged INTO the same commit as the item's edits so the source's done-state is atomic with the work that produced it.

## Parameters

- `{worklist}` — source of work items; required. Accepts any of:
  - a filesystem path to a markdown file with `- [ ]` checkbox items (optionally with `Where:` / `Why:` / `Done-when:` subfields, optionally grouped under `Critical` / `Major` / `Minor` / `Nit` severity headings);
  - a reference to prior chat content (e.g., "the action items I described above");
  - an MCP server endpoint URI that exposes a `list` operation returning items and optionally a `mark-done` operation;
  - inline items embedded in the invocation itself.
  Every source is normalized into the same internal item shape; items already marked done in the source (`- [x]` in markdown, server-reported done in MCP) are excluded before any agent runs.

- `{mode}` — approval policy for the run; required. Allowed values:
  - `interactive` — the user approves the rendered plan AND every per-item commit before it is created.
  - `non-interactive` — the user approves the plan exactly once; the loop then runs to completion without further approvals, with failures handled automatically by `{on_failure}`.
  - `force-approve-all` — no approvals are requested at any point; every default (plan, commit subject, failure handling) is accepted automatically.

- `{parallelism}` — number of isolated worktrees to launch, each owning a disjoint slice of unchecked items processed SEQUENTIALLY one item at a time; optional, default: `1`. MUST be an integer `>= 1`. When `1`, no worktree is created and the loop runs in the calling worktree.

- `{num_partitions}` — number of partitions used for `{agent_model}` assignment; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` and MUST evenly divide `{parallelism}`. When set together with an iterable `{agent_model}`, the iterable MUST be either a full per-agent iteration (length `{parallelism}`) or a per-partition iteration (length `{num_partitions}`).

- `{agent_model}` — model(s) for the worktree agent(s); optional, default: the parent agent's model. Accepts a single identifier (broadcast to every agent), a list of length `{parallelism}` (mapped positionally by agent), or a list of length `{num_partitions}` (mapped positionally by partition and broadcast within).

- `{base_branch}` — branch each worktree is forked from when `{parallelism}` is greater than `1`; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).

- `{worktree_name}` — base name for the worktree directories and branches when `{parallelism}` is greater than `1`; optional, default: a kebab-case slug derived from the `{worklist}` source identifier. A 1-based index suffix (`-1`, `-2`, …) is appended per agent.

- `{partition_strategy}` — how unchecked items are split across slices when `{parallelism}` is greater than `1`; optional, default: `contiguous`. Allowed values:
  - `contiguous` — preserve source order; agent `i` gets a contiguous chunk of roughly `ceil(N / parallelism)` items.
  - `round-robin` — item at zero-based index `i` is assigned to agent `(i mod parallelism) + 1`; balances heterogeneous item costs.
  - `severity-weighted` — distribute items using weights `critical=4`, `major=3`, `minor=2`, `nit=1` so each slice carries comparable severity load; falls back to `contiguous` when items lack a severity field and the fallback is recorded in the report.

- `{commit_scope}` — Conventional Commits scope applied to every commit subject; optional. When unset, scope is derived per item from (in order): the item's `Where:` subfield, the nearest severity / section heading slug above the item, the worklist source basename. When no scope can be derived, the subject omits the parenthetical.

- `{verify_command}` — shell command run inside the owning worktree after each item's edits are staged and before its commit is created; optional. Exit code `0` counts as pass; any non-zero exit triggers `{on_failure}`. The command runs with `WORKLIST_ITEM_ID`, `WORKLIST_ITEM_TITLE`, and `WORKLIST_DONE_WHEN` exported in the environment.

- `{on_failure}` — per-item failure policy when the item's edits, `{verify_command}`, or commit creation fails; optional, default: `retry-once-then-skip`. Allowed values:
  - `abort` — stop this agent's slice immediately; remaining items in the slice are reported as `unaddressed`.
  - `skip` — discard the item's staged and unstaged changes (`git reset --hard HEAD && git clean -fd`), record the failure, advance to the next item with no commit.
  - `retry-once-then-skip` — reset the working tree, re-attempt the item once with the captured failure output injected as additional context, then apply `skip` on a second failure.
  - `mark-blocked` — rewrite the source's `- [ ]` for that item to `- [!] <one-line reason>` and continue. Valid only when the source is a writable markdown file; validation rejects this value for other source kinds.

- `{worklist_writeback}` — whether to mutate the worklist source to mark items done; optional, default: `auto`. Allowed values:
  - `auto` — mutate when the source is writable in the agent's worktree (markdown `- [ ]` → `- [x]`, or MCP `mark-done` when exposed). For immutable sources (prior chat, inline, MCP without `mark-done`), no source mutation is attempted and a per-item record is appended to `.address-worklist-commit-loop-state.json` at the worktree root.
  - `always` — require mutation; validation aborts when the resolved source is not writable.
  - `never` — never mutate the source; useful for audit / read-only runs.

- `{max_items}` — hard cap on the number of items addressed across all agents in this invocation; optional, default: unlimited. Items beyond the cap remain unchecked in the source and are listed as `deferred` in the final report.

- `{dry_run}` — when `true`, normalize, validate, partition, and render the plan, then exit without creating worktrees, editing files, running `{verify_command}`, or creating commits; optional, default: `false`.

## Success Criteria

- [ ] All parameters are validated before any worktree is created, any file is touched, or `{verify_command}` is run: `{parallelism}` and `{num_partitions}` are integers `>= 1` with `{num_partitions}` evenly dividing `{parallelism}`; `{agent_model}` (when iterable) has length `{parallelism}` or `{num_partitions}`; `{mode}`, `{partition_strategy}`, `{on_failure}`, and `{worklist_writeback}` are restricted to their allowed value sets; `{on_failure} = mark-blocked` requires a writable markdown source; `{worklist_writeback} = always` requires a writable source. Validation failure aborts with an explanatory error naming the offending parameter and produces no filesystem side effects.

- [ ] `{worklist}` is normalized to a uniform internal list where every item carries a stable `id`, a `title`, an optional `description`, an optional `done_when`, an optional `severity`, and a `source_ref` back-pointer. Items already marked done in the source are excluded and counted separately in the report. Duplicate `id`s across normalized items abort the invocation with an explanatory error before any worktree is created.

- [ ] When `{parallelism}` is greater than `1`, exactly `{parallelism}` isolated worktrees are created off `{base_branch}`, each on its own branch derived from `{worktree_name}`, and the unchecked items are split into `{parallelism}` disjoint slices using `{partition_strategy}` whose union equals the normalized item list (minus items deferred by `{max_items}`).

- [ ] Each agent addresses its slice strictly sequentially: item `i+1` does not begin until item `i` has either produced a commit or been resolved under `{on_failure}`.

- [ ] Every addressed item produces exactly one git commit whose subject follows Conventional Commits 1.0.0 (`<type>[(<scope>)]: <description>`, lowercase imperative description, no trailing period, `<= 72` characters). The commit body includes the item's `Done-when:` text verbatim when one was present, plus the footers `Worklist-source: <source_ref>` and `Worklist-item-id: <id>`.

- [ ] When `{worklist_writeback}` resolves to `auto` and the source is a writable markdown file in the agent's worktree, the `- [ ]` → `- [x]` flip is staged INTO the same commit as the item's edits, so the source's done-state lands atomically with the work that produced it. When the source is an MCP endpoint with a `mark-done` tool, the tool is called exactly once per committed item.

- [ ] When the source is immutable (prior chat, inline list, read-only MCP), no source mutation is attempted and `{id, sha, status}` is appended to `.address-worklist-commit-loop-state.json` at the worktree root for every committed item.

- [ ] In `interactive` mode, the user is asked to approve the rendered plan once AND to approve each per-item commit (subject plus `git diff --staged`) before it is created. In `non-interactive` mode, the plan approval is requested exactly once and the loop then runs without further prompts. In `force-approve-all` mode, no approval is requested at any point.

- [ ] When `{verify_command}` is provided, it is run inside the owning worktree after the item's edits are staged and before the commit is created, with `WORKLIST_ITEM_ID`, `WORKLIST_ITEM_TITLE`, and `WORKLIST_DONE_WHEN` exported. Its exit code and a short output tail are recorded per item; non-zero triggers `{on_failure}`.

- [ ] `{on_failure}` is honored deterministically: `abort` stops the slice; `skip` resets the working tree and continues; `retry-once-then-skip` resets, re-attempts once with the captured failure output injected, and skips on a second failure; `mark-blocked` rewrites the source line to `- [!] <reason>` and continues. Failed items are never marked done in the source.

- [ ] When `{dry_run}` is `true`, no worktree is created, no file is mutated, no commit is produced, and the report contains only the rendered plan and per-agent slice assignment.

- [ ] Re-running the command against the same `{worklist}` after a successful run with `{worklist_writeback} = auto` normalizes to zero unchecked items (the slice already shipped is idempotently skipped).

- [ ] The final report lists, per agent: worktree path, branch, agent model, slice size, termination cause, and a per-item table with item id, title, status (`committed` / `skipped` / `blocked` / `aborted` / `unaddressed`), commit SHA (or `n/a`), `{verify_command}` exit code (or `n/a`), and a one-line note. The aggregate summary additionally lists items deferred by `{max_items}` and `Cross-branch conflicts predicted` (source files mutated by more than one agent).

## Guardrails

- MUST validate every parameter before creating any worktree, editing any file, running `{verify_command}`, or producing any commit; fail fast and leave the filesystem untouched on validation failure.

- MUST partition unchecked items disjointly when `{parallelism}` is greater than `1`; no item may be addressed by more than one agent.

- MUST address items strictly sequentially within each agent's slice; no parallel item processing within a single worktree.

- MUST produce exactly one git commit per successfully addressed item; agents MUST NOT bundle multiple items into one commit, split one item across multiple commits, or amend prior items' commits.

- MUST follow Conventional Commits 1.0.0 for every commit subject and include the `Worklist-source:` footer (and `Done-when:` line when present) in every commit body. Items whose commit cannot be formatted (missing title, malformed scope) MUST trigger `{on_failure}` rather than be committed with placeholder text.

- MUST keep each agent's work isolated to its assigned worktree when `{parallelism}` is greater than `1`; agents MUST NOT read, write, or run commands against the calling worktree or any sibling worktree.

- MUST mutate the worklist source only after the item's commit has landed inside the same worktree, and only for items the agent actually committed in this invocation.

- MUST honor `{mode}` literally: `interactive` requires per-commit approval, `non-interactive` requires a single plan approval and zero further prompts, `force-approve-all` issues no approval prompts at any stage.

- MUST NOT push, open pull requests, create tags, rebase pre-existing branches, merge worktree branches back into `{base_branch}`, delete worktrees, or touch any branch other than the per-agent worktree branches this invocation created.

- MUST NOT recursively launch worktree agents from inside an item-addressing loop; partitions are leaf workers.

- Scope: this command processes one `{worklist}`, partitions its unchecked items across up to `{parallelism}` isolated worktrees forked from one `{base_branch}`, and produces one commit per addressed item. Out of scope: branch merging, PR creation, pushing, tagging, item generation or prioritization, cross-item refactors, and reconciling cross-agent source mutations.

## Workflow

1. **Validate parameters.** Confirm allowed values for `{mode}`, `{partition_strategy}`, `{on_failure}`, and `{worklist_writeback}`; integer constraints for `{parallelism}`, `{num_partitions}`, and `{max_items}`; even division of `{num_partitions}` into `{parallelism}`; `{agent_model}` shape for the resolved counts; writability of the source when `{worklist_writeback} = always` or `{on_failure} = mark-blocked`. Abort with an explanatory error and no filesystem side effects on any failure.

2. **Resolve and normalize `{worklist}`.** Dispatch on source kind:
   - **Markdown file:** read the file, walk every `- [ ]` line, capture the title and any indented `Where:` / `Why:` / `Done-when:` subfields, record severity from the nearest matching heading (`Critical` / `Major` / `Minor` / `Nit`), and use `<path>:<line>` as the `source_ref`. Drop `- [x]` items.
   - **Prior chat reference:** locate the referenced block and parse with the same rules as a markdown source; `source_ref` is `chat:<anchor>`. Source is treated as immutable.
   - **MCP endpoint:** call the endpoint's `list` operation once, cache the response, and map each non-done entry to the internal shape; record whether the server exposes a `mark-done` tool.
   - **Inline:** parse the trailing items in the invocation body; assign sequential ids (`inline-1`, `inline-2`, …). Source is treated as immutable.
   Assign deterministic ids from `source_ref` plus a slug of the title where the source does not supply one. Abort with an explanatory error on duplicate ids.

3. **Filter and cap.** Apply `{max_items}` to the normalized list; record deferred items in their original order.

4. **Partition.** Apply `{partition_strategy}` to split the remaining items into `{parallelism}` disjoint slices. Resolve the per-agent model assignment from `{agent_model}` (scalar broadcast, length-`{parallelism}` per-agent, or length-`{num_partitions}` per-partition expanded across the partition's agents). Record any strategy fallback (e.g., `severity-weighted` → `contiguous` when severity is missing).

5. **Build and render the plan.** For each agent: slice contents (id + title + projected commit subject), assigned model, worktree path, and projected commit count. Include resolved `{partition_strategy}` (with fallback note when applicable), `{on_failure}`, `{worklist_writeback}`, source mutability, and aggregate counts (normalized / already-done / deferred / planned).

6. **Plan approval gate.** In `interactive` and `non-interactive` mode, present the plan and require explicit approval before continuing. In `force-approve-all` mode, log the plan and proceed. When `{dry_run}` is `true`, emit the plan as the entire final report and stop here.

7. **Create worktrees.** When `{parallelism}` is greater than `1`, for each `i` in `1..{parallelism}` create a branch off `{base_branch}` named after `{worktree_name}` with a `-{i}` suffix and add a matching worktree via `git worktree add`. When `{parallelism} = 1`, skip worktree creation and run the loop in the calling worktree.

8. **Run the per-item loop in each agent.** For every item in the slice, in slice order:
   1. Ingest the item's id, title, description, severity, `done_when`, and `source_ref`.
   2. Implement the change required by the item, scoped to files this item touches.
   3. Stage the implementation changes. When `{worklist_writeback}` is `auto` (and the source is a writable markdown file in this worktree) or `always`, also stage the `- [ ]` → `- [x]` flip for this item so the source mutation lands in the same commit as the implementation.
   4. If `{verify_command}` is set, run it inside the worktree with `WORKLIST_ITEM_ID`, `WORKLIST_ITEM_TITLE`, and `WORKLIST_DONE_WHEN` exported; capture exit code and a tail of stdout/stderr.
   5. On verification failure or implementation failure, apply `{on_failure}`: `abort` ends the slice; `skip` runs `git reset --hard HEAD && git clean -fd` and continues; `retry-once-then-skip` resets and retries this item once with the captured failure output injected as additional context, then skips on a second failure; `mark-blocked` (markdown sources only) rewrites the source line to `- [!] <reason>` and continues.
   6. Compose the commit subject as `<type>[(<scope>)]: <description>` where `<type>` is chosen per the Conventional Commits decision framework (`fix` for bug-style language, `feat` for additive, `docs` for documentation-only, `refactor` for restructuring, etc.); `<scope>` is `{commit_scope}` when set, otherwise derived per the parameter's documented inference order; `<description>` is the item title in lowercase imperative mood under 72 characters with no trailing period. Compose the body with the item's `Done-when:` text verbatim (when present) followed by the footers `Worklist-source: <source_ref>` and `Worklist-item-id: <id>`.
   7. In `interactive` mode, present the staged diff and the composed commit message and require approval before `git commit` runs; rejection treats the item as `skipped` and continues. In `non-interactive` and `force-approve-all` modes, commit without prompting.
   8. Record the commit SHA, status, `{verify_command}` exit code (when applicable), and a one-line note in the agent's per-item ledger.
   9. When the source is immutable, append `{id, sha, status}` to `.address-worklist-commit-loop-state.json` at the worktree root.

9. **Aggregate and report.** After every agent terminates (slice exhausted, `{max_items}` hit, `abort` fired), collect per-item ledgers and per-agent termination causes. Compute `Cross-branch conflicts predicted` by intersecting the file sets each agent's commits touched. Emit the final report using the Output Format below. Do not merge worktree branches and do not delete worktrees.

## Output Format

Return a single response with these named sections, in this order:

### Run Summary
- `Worklist source`: resolved source identifier and kind (`markdown-file` / `chat` / `mcp` / `inline`).
- `Source mutability`: `mutable` or `immutable (<reason>)`.
- `Mode`: `interactive` / `non-interactive` / `force-approve-all`.
- `Base branch`: resolved `{base_branch}` (or `n/a` when `{parallelism} = 1`).
- `Parallelism`: integer (with `Partitions: <N>` appended when `{num_partitions} != {parallelism}`).
- `Partition strategy`: resolved value, with a fallback note when one was applied.
- `Failure policy`: resolved `{on_failure}`.
- `Writeback`: resolved `{worklist_writeback}` and the effective writability of the source.
- `Counts`: items normalized / already-done / deferred / committed / blocked / skipped / aborted / unaddressed.
- `Dry run`: `true` or `false`.

### Plan
A table with one row per normalized item:

| # | Slice | Agent | Item id | Title | Severity | Proposed commit subject | Has done-when |
|---|-------|-------|---------|-------|----------|-------------------------|---------------|

The same table is reproduced in `interactive` and `non-interactive` modes before plan approval.

### Per-Agent Results
One block per agent, in launch order:

- `Index`: 1-based agent index.
- `Worktree path`: absolute path (or `<calling worktree>` when `{parallelism} = 1`).
- `Branch`: branch name (or `<calling branch>` when `{parallelism} = 1`).
- `Agent model`: model identifier used.
- `Slice size`: number of items assigned.
- `Termination`: `completed`, `aborted (item=<id>, reason)`, or `incomplete (no report returned)`.
- `Items`: table with one row per item containing `item_id | status | commit_sha (short) | verify_exit | one-line note`. Sub-bullets below the table carry any retry detail or verification output tail.

### Worklist Source Mutations
- For writable markdown sources: a fenced diff showing each `- [ ]` → `- [x]` (or `→ - [!]`) transition, annotated by item id and the commit SHA the mutation landed in.
- For MCP sources with a `mark-done` tool: a list of `(item id, mark-done response, commit SHA)` rows.
- For immutable sources: the literal sentence `Source is immutable; state captured in .address-worklist-commit-loop-state.json at each worktree root.`

### Cross-Branch Conflicts Predicted
Listed only when `{parallelism}` is greater than `1` and at least one source path was modified by more than one agent. One bullet per shared path: `<path>` plus the list of branches that touched it. Omitted entirely when no shared paths exist.

### Failures
Listed only when at least one item ended in `aborted`, `skipped`, or `blocked`. For each: item id, agent index, failure phase (`address` / `verify` / `commit` / `writeback`), the resolved `{on_failure}` action, and a one-sentence root-cause note grounded in the captured failure output.

### Next Steps
- Per-agent branches and worktree paths left in place for the user to inspect or hand off to a separate merge workflow.
- Items deferred by `{max_items}` with the suggested follow-up invocation to address them.
- A reminder that no branches were merged, no worktrees were deleted, and no remotes were touched.
