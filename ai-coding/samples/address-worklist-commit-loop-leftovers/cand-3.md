# Address Worklist Commit Loop

## Task
Iterate over a polymorphic worklist of unfinished work items, address each unchecked item with an isolated agent, produce exactly one Conventional Commits commit per addressed item, and mark each item complete in its source. Optionally split items across sibling worktree agents that run in parallel; each agent processes its slice strictly sequentially, one item and one commit at a time.

## Parameters
- `{worklist}` — source of work items; required. Accepted forms: a file path (e.g., a markdown file with `- [ ]` checkbox items, optionally with `Where` / `Why` / `Done-when` subfields, optionally grouped by severity headings), a reference to prior chat content describing items (e.g., "the action items I described above"), an MCP server endpoint that exposes a list of items, or inline items in the invocation itself. The source is normalized into a uniform internal worklist before any work begins; items already marked done (e.g., `- [x]`) are excluded.
- `{mode}` — approval semantics; required. Allowed values: `interactive` (user approves the overall plan AND every individual commit before it is created), `non-interactive` (user approves the plan exactly once, then the loop runs silently to completion without further approval calls), `force-approve-all` (no approval calls are made for any decision; every default is accepted automatically, including the plan).
- `{parallelism}` — number of sibling agents to run concurrently, each in its own worktree, each owning a disjoint slice of the unchecked items; optional, default: `1`. MUST be an integer `>= 1`. Validation runs before any worktree is created. Each agent processes its slice sequentially; parallelism here partitions items across agents, never duplicates an item across agents.
- `{num_partitions}` — number of item partitions; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` and MUST divide `{parallelism}` evenly when the two differ; each partition is then assigned to a contiguous slice of `{parallelism} / {num_partitions}` agents that share one model. When set together with an iterable `{agent_model}`, the workflow raises an error unless `{agent_model}` provides a full iteration or a correctly-sized slice for the partitions.
- `{agent_model}` — model(s) to use for the worktree agent(s); optional, default: the parent agent's model. Accepts a single model identifier (broadcast to every agent), a list of identifiers of length `{parallelism}` (mapped positionally by agent index), or a list of length `{num_partitions}` (mapped positionally by partition and broadcast within the partition).
- `{base_branch}` — branch each worktree is forked from; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name}` — base name for each worktree directory and branch; optional, default: kebab-case slug derived from the worklist source identifier. A 1-based index suffix (`-1`, `-2`, …) is appended per agent when `{parallelism}` > 1.
- `{verify_command}` — shell command run inside the worktree once the agent reports an item complete, before any worklist mutation, staging, or commit for that item; optional. Exit code `0` counts as pass; any other exit code triggers `{failure_policy}` and prevents the commit for that item. The string may include `{item_id}`, `{item_title}`, and `{done_when}` substitutions.
- `{failure_policy}` — how to react when an item fails (agent error, `{verify_command}` non-zero, unmet `done-when`, or merge conflict while staging the commit); optional, default: `retry-then-skip`. Allowed values: `abort` (stop this agent's slice on first failure), `skip` (record the failure and move to the next item), `retry-then-skip` (one retry, then `skip`), `retry-then-abort` (one retry, then `abort`). A retry resets the worktree to the pre-attempt commit and re-runs the same item once with the same agent.
- `{max_items}` — maximum number of items each agent is allowed to address in one invocation; optional, default: unlimited. Counted per slice, not globally. Items past the cap are recorded as deferred.
- `{dry_run}` — when `true`, render the normalized worklist, the per-agent partition assignment, and the planned commit subject for each item, then stop without creating worktrees, launching agents, mutating the source, or producing any commit; optional, default: `false`.
- `{partition_strategy}` — algorithm for splitting unchecked items across agents when `{parallelism}` > 1; optional, default: `round-robin`. Allowed values: `round-robin` (item at zero-based index `i` is assigned to agent `(i mod parallelism) + 1`; balances heterogeneous workloads), `contiguous` (each agent gets a contiguous slice of size `ceil(items / parallelism)`; preserves source order within a slice), `severity` (items grouped by severity heading in the source are distributed so each agent gets at most one severity bucket where possible; items without a severity grouping fall back to `round-robin`).
- `{commit_scope}` — Conventional Commits scope used in every commit subject, overriding any derived scope; optional, default: derived per item from the item's source context — the severity heading the item lives under, then the directory or file mentioned in `Where`, then the worklist file basename — and omitted from the subject when no scope can be derived.

## Success Criteria
- [ ] `{parallelism}`, `{num_partitions}`, `{agent_model}`, and `{mode}` are validated before any worktree is created: `{parallelism}` and `{num_partitions}` are integers `>= 1`, `{num_partitions}` divides `{parallelism}` evenly when they differ, `{agent_model}` (when a list) has length `{parallelism}` or `{num_partitions}`, and `{mode}` is exactly one of `interactive`, `non-interactive`, `force-approve-all`. Validation failure aborts with an explanatory error and zero filesystem side effects.
- [ ] `{worklist}` is normalized into a uniform internal representation before any worktree is created; each normalized item carries at minimum a stable identifier, a title, a description, and (when present) a `done-when` condition plus a source pointer used for mutation. Items already marked done (e.g., `- [x]`) are excluded and never assigned to any agent.
- [ ] Exactly `{parallelism}` isolated worktrees are created off `{base_branch}` (or the current branch when omitted), each on its own branch derived from `{worktree_name}`, with the unchecked items split across them by `{partition_strategy}` into disjoint slices whose union equals the normalized worklist (minus any items deferred by `{max_items}`).
- [ ] In `interactive` mode the user is asked to approve the overall plan once AND to approve every individual commit before it is created. In `non-interactive` mode the user is asked to approve the plan exactly once, after which the loop runs to completion without further approval calls. In `force-approve-all` mode zero approval calls are made and every default — including plan acceptance — is treated as approved.
- [ ] Each agent processes its slice strictly sequentially: work on item `i+1` does not begin until item `i` has either committed or been recorded as failed under `{failure_policy}`.
- [ ] Exactly one git commit is produced per addressed item; the commit subject follows Conventional Commits 1.0.0 (`<type>[(scope)]: <description>` in imperative mood, lowercase first word, under 72 characters, no trailing period), the description is derived from the item title, and the commit body includes a `Worklist:` line pointing at the worklist source (file path and line range, chat reference, or MCP endpoint id) and, when present, a `Done-when:` line repeating the item's `done-when` condition.
- [ ] When `{worklist}` is a mutable source (e.g., a markdown file with `- [ ]` checkboxes), every successfully addressed item is updated in the source (`- [ ]` → `- [x]`) inside the worktree before the next item begins, and the source mutation is included in that item's single commit.
- [ ] When `{verify_command}` is provided, it runs exactly once per item between agent completion and commit creation; its captured exit code and a short output tail are recorded per item. A non-zero exit code triggers `{failure_policy}` and prevents the commit for that item.
- [ ] `{failure_policy}` is honored per item: `abort` stops the agent's slice on first failure; `skip` records the failure and moves on; `retry-then-skip` and `retry-then-abort` retry the item exactly once before applying `skip` or `abort` respectively. Failed items are never marked done in the source.
- [ ] When `{dry_run}` is `true`, no worktree is created, no agent is launched, no commit is produced, and the worklist source is not mutated; the only side effect is the rendered plan in the final report.
- [ ] The final report includes, per agent: worktree path, branch, agent model, partition assignment, and a per-item table with item id, item title, terminal status (`committed`, `skipped`, `aborted`, or `pending` when `{dry_run}`), planned or actual commit subject, verification exit code (or `n/a`), and commit SHA (or `n/a`).

## Guardrails
- MUST validate `{parallelism}`, `{num_partitions}`, `{agent_model}` shape, and `{mode}` before creating any worktree; fail fast and create nothing on validation failure.
- MUST normalize `{worklist}` and confirm at least one unchecked item exists before creating any worktree; abort with an explanatory error and no filesystem side effects when the normalized worklist is empty.
- MUST keep each agent's work isolated to its assigned worktree; agents MUST NOT read, write, or run commands against the calling worktree, the original working tree, or any sibling worktree.
- MUST produce exactly one commit per addressed item; agents MUST NOT batch multiple items into a single commit, MUST NOT split a single item across multiple commits, and MUST NOT commit while another item in the same slice is still in progress.
- MUST mark an item done in the source only after its commit has landed inside the worktree; agents MUST NOT mark an item done if its commit was skipped or aborted.
- MUST honor `{mode}` approval semantics exactly: `interactive` asks for the plan AND every per-item commit, `non-interactive` asks for the plan only, `force-approve-all` asks nothing.
- MUST NOT recursively fan out: each agent processes its slice in-loop and MUST NOT launch additional worktree agents.
- MUST NOT push, open PRs, create tags, rebase, or touch any branch other than each agent's own worktree branch.
- MUST NOT mutate the worklist source from more than one agent simultaneously; when `{parallelism}` > 1 and the source is mutable, each agent mutates only the source rows for the items in its own slice.
- Scope: this command consumes one `{worklist}` source and produces up to one commit per unchecked item, distributed across up to `{parallelism}` sibling worktrees. Out of scope: merging worktree branches back into `{base_branch}`, deleting worktrees, pushing branches, opening pull requests, modifying items beyond marking them done.

## Workflow
1. Validate parameters. Confirm `{parallelism}` and `{num_partitions}` are integers `>= 1`, `{num_partitions}` divides `{parallelism}` evenly when they differ, `{agent_model}` (when a list) has length `{parallelism}` or `{num_partitions}`, and `{mode}` is one of the three allowed values. Abort with an explanatory error and no filesystem side effects on failure.
2. Normalize `{worklist}` into a list of items, each carrying `{id, title, description, done_when, source_pointer}`. Resolve the source by type: read the file path and parse `- [ ]` items plus subfields; pull from the named chat reference; call the MCP endpoint; or parse the inline items from the invocation text. Drop items already marked done. Abort if the result is empty.
3. Resolve `{base_branch}` (default: current branch) and `{worktree_name}` (default: kebab-case slug derived from the worklist source identifier).
4. Resolve the per-agent model assignment by broadcasting a scalar `{agent_model}` to every agent, zipping a length-`{parallelism}` list positionally by agent index, or expanding a length-`{num_partitions}` list across each partition's contiguous agent slice.
5. Partition the normalized items into `{parallelism}` disjoint slices using `{partition_strategy}`. Cap each slice at `{max_items}` when set; items past the cap are recorded as deferred and excluded from the plan.
6. Render the plan: per agent, the slice contents, the partition strategy used, the assigned model, and the planned Conventional Commits subject for each item. When `{mode}` is `interactive` or `non-interactive`, ask the user to approve the plan once; when `{mode}` is `force-approve-all`, treat the plan as approved without asking.
7. If `{dry_run}` is `true`, stop here and emit the plan in the Output Format below; do not create worktrees, launch agents, produce commits, or mutate the source.
8. For each agent slot `i` in `1..{parallelism}`, create a new branch off `{base_branch}` named after `{worktree_name}` (with `-{i}` suffix when `{parallelism}` > 1) and add a matching worktree via `git worktree add`.
9. Launch each agent inside its worktree, on its assigned model, with its slice and the resolved `{mode}`, `{verify_command}`, `{failure_policy}`, `{commit_scope}`, and `{worklist}` source pointer.
10. Per item, inside each agent, sequentially: address the item to satisfy its `done-when` (or, when absent, the item description); run `{verify_command}` once when provided; apply `{failure_policy}` if verification fails or the agent reports failure; on success, mutate the worklist source if mutable, stage the item's changes plus the worklist mutation together, derive the Conventional Commits subject from the item title and resolved scope, ask for per-commit approval when `{mode}` is `interactive`, then create the commit.
11. After each agent finishes its slice (by exhausting items, hitting `{max_items}`, or aborting under `{failure_policy}`), collect per-item status and commit SHAs.
12. Render the final per-agent report using the Output Format below.

## Output Format
Return a single response with these named sections, in this order:

### Run Summary
- `Worklist source`: resolved identifier (file path, chat reference, MCP endpoint id, or `inline`).
- `Normalized items`: total count of unchecked items after normalization.
- `Base branch`: resolved `{base_branch}`.
- `Parallelism`: `{parallelism}`.
- `Partitions`: `{num_partitions}`.
- `Partition strategy`: `{partition_strategy}`.
- `Mode`: `interactive`, `non-interactive`, or `force-approve-all`.
- `Failure policy`: `{failure_policy}`.
- `Dry run`: `true` or `false`.
- `Counts`: committed / skipped / aborted / deferred.

### Agent Slices
One block per agent, in launch order:

- `Index`: 1-based agent index.
- `Worktree path`: absolute path (or `n/a` when `{dry_run}`).
- `Branch`: worktree branch name (or `n/a` when `{dry_run}`).
- `Agent model`: model identifier used.
- `Partition`: partition index assigned to this agent.
- `Slice`: 1-based item indices owned by this agent.

#### Items
A table with one row per item in slice order, with these columns: item id, title, status (`committed`, `skipped`, `aborted`, or `pending` when `{dry_run}`), commit subject (planned when `{dry_run}` or failed, actual otherwise), verify exit code (or `n/a`), commit SHA (or `n/a`). When an item has failure detail (retry count, verify output tail, abort reason), include it as a sub-bullet below the table.

### Plan Notes
Include only the sub-bullets that have content; omit this section entirely when all sub-bullets would be empty.

- Items deferred by `{max_items}`, listed with id and title.
- Items dropped during normalization because they were already done, listed with id and title.
- Approval calls skipped because of `{mode}`, with the reason.
