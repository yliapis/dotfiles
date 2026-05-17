# Address Worklist Commit Loop

## Task
Iterate through a worklist of action items, addressing each item end-to-end and recording the result as exactly one Conventional Commits-formatted git commit, optionally fanning out across multiple isolated git worktrees so disjoint slices of items run concurrently while items within each slice are addressed strictly sequentially.

## Parameters
- `{worklist}` — source of action items; required. Accepts any of: a filesystem path to a worklist document (for example a markdown file containing `- [ ]` checkbox items, optionally with `Where` / `Why` / `Done-when` subfields under each item); a reference to prior chat content (for example "the action items I described above"); an MCP server endpoint or registered tool identifier that returns a list of work items; or a list of items supplied inline after the parameter token. Items already marked done in the source (for example `- [x]` in markdown) are excluded during normalization.
- `{mode}` — approval cadence for the run; required. Allowed values: `interactive` (the user approves the normalized plan AND each per-item commit before it is created); `non-interactive` (the user approves the plan ONCE, then the loop runs silently to completion without further approvals); `force-approve-all` (no approvals are requested at any point; every default, including the plan, is accepted automatically).
- `{parallelism}` — number of agents to run concurrently, each in its own worktree, with the worklist items partitioned disjointly across them and addressed sequentially within each slice; optional, default: `1`. MUST be an integer `>= 1`; otherwise the workflow fails before any worktree is created.
- `{num_partitions}` — number of partitions across which `{agent_model}` is distributed; optional, default: same as `{parallelism}`. MUST be an integer `>= 1`. When set together with an iterable `{agent_model}`, the workflow raises an error unless `{agent_model}` provides a full iteration or a correctly-sized iterable slice for the partitions.
- `{agent_model}` — model(s) to use for the worktree agent(s); optional, default: the parent agent's model. Accepts a single model identifier (broadcast to every agent) or a list of identifiers whose length MUST equal `{parallelism}` (mapped positionally by index).
- `{base_branch}` — branch to fork the worktree(s) from when `{parallelism} > 1`; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name_prefix}` — base name for the worktree directories and branches when `{parallelism} > 1`; optional, default: a filesystem-safe kebab-case slug derived from the worklist source. A 1-based suffix (`-1`, `-2`, …) is appended per agent.
- `{partition_strategy}` — how unaddressed items are distributed across agents; optional, default: `contiguous`. Allowed values: `contiguous` (each agent owns a contiguous run of items in source order), `round-robin` (items distributed one-by-one cyclically), `interleaved` (deterministic shuffle by item id, then contiguous slice).
- `{commit_scope}` — Conventional Commits scope inserted into every per-item commit subject (rendered as `<type>({commit_scope}): <title>`); optional, default: unset (no scope).
- `{per_item_test_command}` — shell command run inside the agent's worktree after the per-item changes are staged but before the commit is created; optional. Exit code `0` counts as pass; any other exit code counts as fail and triggers the retry / failure policy below.
- `{max_retries_per_item}` — additional attempts permitted per item after the first failure, where failure means the agent reported failure, `{per_item_test_command}` exited non-zero, or the item's `done-when` condition did not hold; optional, default: `1`. The working tree is reset (`git reset --hard HEAD && git clean -fd`) between attempts.
- `{on_failure}` — policy applied once an item exhausts its retries; optional, default: `skip`. Allowed values: `skip` (leave the item un-addressed, record it in the report, advance to the next item), `abort` (stop the loop for the owning agent, leave already-landed commits in place), `continue` (record a placeholder commit with subject `chore({commit_scope}): wip <item title>` whose body explains the failure cause, then advance).
- `{max_items}` — hard cap on the number of items any single agent may address; optional, default: unbounded.
- `{dry_run}` — flag; when set, the workflow emits the normalized plan and exits without creating worktrees, modifying files, producing commits, or mutating the worklist source. Optional, default: absent.

## Success Criteria
- [ ] Every parameter is validated before any worktree is created or any worklist source is mutated: `{worklist}` resolves to a non-empty list of unaddressed normalized items; `{mode}` is exactly one of `interactive` / `non-interactive` / `force-approve-all`; `{parallelism}` and `{num_partitions}` are integers `>= 1`; if `{agent_model}` is a list its length equals `{parallelism}`; if `{num_partitions}` is set together with an iterable `{agent_model}` the iterable is either a full iteration or a correctly-sized slice for the partitions; `{max_retries_per_item}` is an integer `>= 0`; `{on_failure}` is exactly one of `skip` / `abort` / `continue`; `{partition_strategy}` is exactly one of `contiguous` / `round-robin` / `interleaved`. Validation failure aborts with an explanatory error naming the offending parameter and produces no filesystem side effects.
- [ ] The worklist is normalized into a uniform internal shape regardless of source: each item carries a stable identifier, a title used to derive the commit subject, an optional longer description, an optional done-when condition, and a source reference pointing back to the original location (file path + line range, MCP item id, chat message anchor, or inline-list ordinal). Items already marked done in the source are excluded.
- [ ] When `{parallelism} = 1`, no worktree is created and the single agent addresses every unaddressed item sequentially in the current working tree.
- [ ] When `{parallelism} > 1`, exactly `{parallelism}` isolated worktrees are created from `{base_branch}`, each on its own branch derived from `{worktree_name_prefix}`, and the unaddressed items are partitioned disjointly across them according to `{partition_strategy}` such that every unaddressed item is assigned to exactly one agent.
- [ ] Each agent addresses its assigned items strictly sequentially: an item finishes (committed, skipped, placeholder-committed, or terminally failed) before the next item in its slice begins.
- [ ] Each successfully addressed item produces exactly one git commit on its owning agent's branch, with a Conventional Commits 1.0.0 subject composed of a type derived from the item's changes, `{commit_scope}` in parentheses when set (omitted otherwise), and the item's title after the colon; a body referencing the item's source reference and (when present) the item's done-when condition; and footers `Worklist-source:` (the resolved source reference) and `Worklist-item-id:` (the normalized item id).
- [ ] When `{per_item_test_command}` is provided, it is executed inside the agent's worktree after the per-item changes are staged but before the commit is created; a non-zero exit code suppresses the commit, resets the working tree, and triggers the retry / failure policy.
- [ ] After an item's commit lands, the worklist source is mutated to mark that item done when the source supports it: a markdown `- [ ]` matching the item is rewritten to `- [x]` in place, MCP sources receive their configured done-marking call, and immutable sources (prior chat content, inline lists) are recorded in a per-agent state file `.address-worklist-commit-loop-state.json` written at the worktree root.
- [ ] In `interactive` mode, the user explicitly approves the normalized plan before any worktree is created and explicitly approves each per-item commit before it is created.
- [ ] In `non-interactive` mode, the user explicitly approves the normalized plan exactly once before any worktree is created, after which no further questions are asked and per-item commits are created automatically.
- [ ] In `force-approve-all` mode, no questions are asked at any point; the workflow proceeds with every default and creates per-item commits automatically.
- [ ] When an item exhausts `{max_retries_per_item}`, the `{on_failure}` policy is applied exactly as specified (`skip` advances, `abort` halts the owning agent, `continue` records a `chore({commit_scope}): wip <title>` placeholder commit) and the failure cause, attempt count, and last `{per_item_test_command}` output tail (when applicable) are recorded in the final report.
- [ ] When `{dry_run}` is set, the final reply contains the normalized plan and the resolved partition assignment, no worktrees are created, no files outside the calling working tree are written, no commits are produced, and the worklist source is not mutated.
- [ ] The final report enumerates, per item, the item id, owning branch, terminal status, resulting commit SHA when applicable, attempt count, and a one-line note; and per agent, the assigned slice size and the counts of committed, skipped, failed, and placeholder items.

## Guardrails
- MUST validate every parameter listed above before creating any worktree, mutating any worklist source, or launching any agent; fail fast and write nothing on validation failure.
- MUST keep each agent's execution isolated to its assigned worktree when `{parallelism} > 1`; agents MUST NOT read, write, or run commands against the calling working tree or any sibling worktree.
- MUST produce exactly one git commit per successfully addressed item; multi-commit drafts MUST be squashed before the final commit lands.
- MUST follow Conventional Commits 1.0.0 for every commit subject this command produces, selecting the type from the actual changes (`feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `style`, `revert`) and inserting `{commit_scope}` when set.
- MUST reset the working tree between retry attempts so a failed attempt leaves no staged or unstaged residue before the next attempt begins.
- MUST mutate the worklist source to mark an item done only after that item's commit has landed on the agent's branch; mutation MUST NOT precede the commit.
- MUST NOT modify worklist items that this invocation did not address.
- MUST NOT skip the plan-approval step in `interactive` or `non-interactive` mode; only `force-approve-all` bypasses it.
- MUST NOT ask the user any question in `non-interactive` mode after plan approval, or in `force-approve-all` mode at any point.
- MUST NOT push branches, open pull requests, create tags, rebase pre-existing branches, or touch branches other than the ones this invocation created.
- MUST NOT recursively fan out: agents launched under `{parallelism} > 1` run with `{parallelism} = 1` and MUST NOT spawn further agents.
- Scope: address one `{worklist}` end-to-end across up to `{parallelism}` sibling worktrees forked from one `{base_branch}`, producing one commit per addressed item plus optional placeholder commits under the `continue` failure policy. Out of scope: merging worktree branches back, pushing, opening PRs, creating tags, generating new worklists, and modifying worklist items the invocation did not address.

## Workflow
1. **Validate parameters.** Confirm `{worklist}` is provided; `{mode}` is one of the three allowed values; `{parallelism}` and `{num_partitions}` are integers `>= 1`; `{agent_model}` shape is valid for the resolved `{parallelism}` and `{num_partitions}`; `{max_retries_per_item}` is an integer `>= 0`; `{on_failure}` is one of `skip` / `abort` / `continue`; `{partition_strategy}` is one of `contiguous` / `round-robin` / `interleaved`. Abort with an explanatory error and no filesystem side effects on validation failure.
2. **Resolve and normalize `{worklist}`.** Detect the source type (filesystem path → checkbox-markdown parser; chat reference → prior-message extractor; MCP endpoint or tool identifier → tool invocation; inline → parse the trailing items). Build the normalized item set with `id`, `title`, `description`, `done_when`, `source_ref`; drop items whose source already marks them done; assign deterministic ids (slugified title plus a short hash of `source_ref`) when the source does not supply one.
3. **Partition items.** Apply `{partition_strategy}` over the normalized list to produce `{parallelism}` disjoint slices, capped per slice by `{max_items}` when set. Record the per-agent assignment for the plan output.
4. **Present plan and obtain approval.** Render the normalized plan (items per slice, resolved parameters, partition strategy, per-item test command summary, on-failure policy, retry budget). In `interactive` or `non-interactive` mode, ask the user once whether to proceed; in `force-approve-all` mode, proceed without asking. If `{dry_run}` is set, emit the plan as the final reply and stop.
5. **Resolve per-agent model assignment** by broadcasting a scalar `{agent_model}` to every agent, zipping a list of length `{parallelism}` positionally by index, or zipping a partition-sized list across the `{num_partitions}` groups.
6. **Create worktrees (only when `{parallelism} > 1`).** For each `i` in `1..{parallelism}`, create a new branch off `{base_branch}` named `{worktree_name_prefix}-{i}` and add a matching worktree via `git worktree add`.
7. **Launch one agent per slice.** Dispatch the agents concurrently with their assigned model and slice, instructing each agent to address its items strictly sequentially using the per-item loop in step 8. When `{parallelism} = 1`, the calling agent itself runs the loop in the current working tree.
8. **Per-item loop (inside each agent).** For each item in the agent's slice, in assignment order:
   a. Apply the item's changes inside the agent's worktree.
   b. Stage the changes (`git add -A`).
   c. Run `{per_item_test_command}` when set; capture exit code and a tail of stdout/stderr.
   d. When the item supplies an executable `done_when` condition, evaluate it and capture the result.
   e. If staging is empty, the test command exited non-zero, or `done_when` is unmet, reset the working tree (`git reset --hard HEAD && git clean -fd`) and retry while retries remain; once exhausted, apply `{on_failure}` (`skip` advances to the next item; `abort` halts the agent leaving prior commits intact; `continue` records a placeholder commit with subject `chore({commit_scope}): wip <item title>` and a body summarizing the failure).
   f. On success, create exactly one commit with a Conventional Commits 1.0.0 subject (type derived from the changes, `{commit_scope}` inserted when set, item title verbatim after the colon), a body referencing the item's `source_ref` and `done_when` condition when present, and footers `Worklist-source: <source_ref>` and `Worklist-item-id: <id>`.
   g. In `interactive` mode, request explicit user approval of the prepared commit message and staged diff before creating the commit; in `non-interactive` and `force-approve-all` modes, create the commit automatically.
   h. After the commit lands, mutate the worklist source to mark the item done: rewrite the matching `- [ ]` to `- [x]` for markdown sources, call the configured done-marking endpoint for MCP sources, or append the item id (with the resulting commit SHA) to `.address-worklist-commit-loop-state.json` for immutable sources.
9. **Aggregate and report.** After all agents finish (success, abort, or natural slice exhaustion), collect per-item and per-agent statuses and emit the final report using the Output Format below.

## Output Format
Return a single response with the following named sections, in this order.

### Run Summary
- `Worklist source`: resolved `{worklist}` and detected source type.
- `Mode`: `interactive`, `non-interactive`, or `force-approve-all`.
- `Parallelism`: resolved `{parallelism}`.
- `Partition strategy`: resolved `{partition_strategy}`.
- `Base branch`: resolved `{base_branch}` (or `n/a` when `{parallelism} = 1`).
- `On-failure policy`: resolved `{on_failure}` with the retry budget `{max_retries_per_item}`.
- `Totals`: items committed / skipped / failed / placeholder.

### Per-Agent Results
One block per agent, in launch order, with these fields:
- `Index`: 1-based agent index.
- `Worktree path`: absolute path (or `n/a` when `{parallelism} = 1`).
- `Branch`: branch name (or `n/a` when `{parallelism} = 1`).
- `Agent model`: model identifier used.
- `Assigned items`: count of items in the slice.
- `Per-status counts`: committed / skipped / failed / placeholder.

### Per-Item Results
A single table grouped by agent, in addressed order, with columns:

| Item id | Title | Owning branch | Status | Commit SHA | Attempts | Notes |
| ------- | ----- | ------------- | ------ | ---------- | -------- | ----- |

Where `Status` is `committed`, `skipped`, `failed`, or `placeholder`; `Commit SHA` is the short SHA when `Status` is `committed` or `placeholder`, otherwise `-`; `Notes` is a one-line summary that, for non-success rows, includes the last `{per_item_test_command}` exit code and a short stdout/stderr tail.

### Worklist Source Mutations
- The set of items marked done in the worklist source (file path + line range for markdown, MCP item id for MCP, or `.address-worklist-commit-loop-state.json` entries for immutable sources).
- The set of items left unmarked, each with a one-line reason.

### Next Steps
- Suggested follow-up invocations (for example, re-run with a wider `{max_retries_per_item}`, address skipped items in a new invocation, or inspect failed items by branch).
