# Address Worklist Commit Loop

## Task
Iterate through every unchecked item in a polymorphic `{worklist}`, addressing each item as a single isolated change with exactly one Conventional Commits commit per item, optionally fanning the items out across multiple isolated worktrees so disjoint slices are addressed concurrently while each slice is processed sequentially.

The command normalizes any supported worklist source into one internal item shape, enforces a per-item verify-then-commit lifecycle, and (when the source is mutable) marks completed items in the source as part of the same commit so re-running the command is idempotent on the slice that already shipped.

## Parameters
- `{worklist}` — required. The work-item source. Accepts any of:
  - a filesystem path to a markdown file containing `- [ ]` / `- [x]` checkbox items (indented subfields under each item such as `Where:`, `Why:`, and `Done-when:` are captured when present);
  - a reference to prior chat content (e.g., `"the action items I described above"`); the agent resolves the reference to the latest matching block in the active chat and parses it with the same rules as a markdown source;
  - an MCP server endpoint that responds to a `list` operation returning items with at minimum `id` and `title` and an optional `done_when` field;
  - one or more inline items supplied directly in the invocation, separated by newlines or `;`.
- `{mode}` — required. Exactly one of:
  - `interactive` — the user approves the overall plan AND every individual commit before it is created; verification failures pause for guidance.
  - `non-interactive` — the user approves the plan exactly once; the loop then runs to completion without further approvals and applies `{on_failure}` automatically.
  - `force-approve-all` — no approval is requested at any point; the plan and every per-item default are accepted automatically, and `{on_failure}` is applied automatically.
- `{parallelism}` — number of isolated worktrees to launch, each owning a disjoint slice of unchecked items and processing its slice sequentially (one item at a time). Optional, default: `1`. MUST be an integer `>= 1`; validation runs before any worktree is created. When `1`, no worktree is created and the loop runs in the calling worktree.
- `{num_partitions}` — number of model-assignment partitions over the `{parallelism}` worktrees. Optional, default: same as `{parallelism}`. MUST be an integer `>= 1` that divides `{parallelism}` evenly. When set together with an iterable `{agent_model}`, the workflow raises an error unless `{agent_model}` provides a full per-agent iteration (length `{parallelism}`) or a correctly-sized per-partition iteration (length `{num_partitions}`).
- `{agent_model}` — model(s) to use for the worktree agent(s). Optional, default: the parent agent's model. Accepts a single identifier (broadcast to every agent), a list of length `{parallelism}` (mapped positionally by agent index), or a list of length `{num_partitions}` (mapped positionally by partition, broadcast to the agents inside each partition).
- `{base_branch}` — branch to fork each worktree from. Optional, default: current branch (`git rev-parse --abbrev-ref HEAD`). Ignored when `{parallelism}` is `1`.
- `{partition_strategy}` — how the unchecked items are distributed across the `{parallelism}` slices. Optional, default: `contiguous`. Allowed values:
  - `contiguous` — preserve source order; assign contiguous chunks of `ceil(N / parallelism)` items per slice.
  - `round-robin` — interleave items by index modulo `{parallelism}`.
  - `severity-weighted` — balance the sum of severity weights across slices using weights `critical=4`, `major=3`, `minor=2`, `nit=1`. Rejected at validation when any item lacks a severity field.
- `{verify_command}` — shell command template run inside each agent's worktree before that item is committed. Optional. The template may reference `{{item.id}}`, `{{item.title}}`, `{{item.done_when}}`, and `{{item.source_ref}}`. Exit code `0` counts as pass; any other exit code counts as fail and triggers `{on_failure}`. When absent, the agent self-evaluates the item's `done_when` text and records the evidence in the report.
- `{on_failure}` — policy applied to an item whose implementation or `{verify_command}` fails. Optional. Default: `abort` when `{mode}` is `interactive`; `mark-blocked` for `non-interactive` and `force-approve-all`. Allowed values:
  - `abort` — stop the agent immediately; later items in the slice remain `pending`.
  - `skip` — discard staged changes for the item and continue the slice without a commit or source writeback.
  - `mark-blocked` — discard staged changes, record the failure reason, leave the source unchanged, and continue the slice.
- `{commit_scope}` — Conventional Commits scope applied to every commit subject. Optional, default: derived per item, preferring the most-changed top-level directory in the item's diff, then any explicit `Where:` subfield, then the kebab-case of the item title's first noun phrase.
- `{commit_type}` — Conventional Commits type applied to every commit subject. Optional, default: derived per item (`fix` when the item title starts with verbs such as `fix`, `resolve`, or `prevent`; `docs` when changes are limited to `*.md` or `docs/*`; `refactor` when the item describes restructuring; `feat` otherwise).
- `{worklist_writeback}` — how completed items are reflected back into a mutable `{worklist}` source. Optional, default: `auto`. Allowed values:
  - `auto` — toggle `- [ ]` to `- [x]` for markdown sources, call the MCP `mark_done` operation for MCP sources, no-op for inline and chat-reference sources.
  - `disabled` — never mutate the source.
  - `summary-comment` — for markdown sources only, append a single per-run summary block at the end of the file instead of toggling individual checkboxes.
- `{max_items}` — upper bound on the number of items each agent will address before stopping. Optional, default: unlimited.
- `{dry_run}` — when truthy, the calling agent emits the resolved plan, per-item proposed commit subjects and bodies, and slice assignments without creating worktrees, writing files, or committing. Optional, default: `false`.

## Success Criteria
- [ ] Parameter validation runs and completes before any worktree is created: `{worklist}` resolves to a parseable source; `{mode}` is one of the three allowed values; `{parallelism}` and `{num_partitions}` are integers `>= 1` with `{num_partitions}` dividing `{parallelism}` evenly; `{agent_model}` shape matches `{parallelism}` or `{num_partitions}` when iterable; `{partition_strategy}` is among the allowed values (and `severity-weighted` is rejected when items lack a severity field); `{on_failure}` and `{worklist_writeback}` are among their allowed values. Any failure aborts with an explanatory message and zero filesystem side effects (no worktrees, no commits, no source mutation).
- [ ] The normalized worklist contains every unchecked item from the source and zero items that the source already marked done (`- [x]` in markdown, server-reported done in MCP). Each normalized item carries a stable `id`, a `title`, an optional `done_when`, an optional `severity`, and a `source_ref` back-pointer to the originating location.
- [ ] When `{parallelism} > 1`, the union of every agent's slice equals the normalized item list exactly, every item appears in exactly one slice, and each agent processes its slice sequentially (one item finished before the next item starts).
- [ ] When `{mode}` is `interactive`, the user is asked to approve the overall plan AND, separately, every individual commit before it is created; verification failures pause for guidance. When `{mode}` is `non-interactive`, the user is asked exactly once (plan approval) and the loop runs without further approvals afterward. When `{mode}` is `force-approve-all`, no approval is requested at any point.
- [ ] Each successfully addressed item produces exactly one git commit on its agent's branch — no more, no less. The commit subject follows Conventional Commits 1.0.0 (`<type>[(<scope>)]: <description>`, lowercase imperative description, no trailing period, `<= 72` characters). The commit body contains the item's title, the `Done-when:` text verbatim when the item provided one, and a `Worklist: <source_ref>` footer.
- [ ] When `{worklist_writeback}` is `auto` and the source is mutable, every committed item is marked done in the source within the same agent's worktree as part of the same single commit produced for that item (markdown `- [ ]` toggled to `- [x]` on the recorded line; MCP `mark_done` called exactly once per committed item). When `{worklist_writeback}` is `disabled`, the source is never mutated. When `{worklist_writeback}` is `summary-comment` for a markdown source, a single summary block is appended at the end of the file as part of the agent's final commit instead of toggling individual checkboxes.
- [ ] When `{verify_command}` is provided, it is executed once per item inside the agent's worktree on the code-only delta before any source writeback is staged; its exit code is captured; no commit for that item is created when the exit code is non-zero; the `{on_failure}` policy is then applied.
- [ ] The final per-agent report lists every item the agent owned with status `committed`, `blocked`, `skipped`, or `pending`. For `committed` items it includes the commit SHA, the commit subject, and the verification exit code (or `n/a`). For `blocked` and `skipped` items it includes the failure reason. The overall summary lists totals per status and per agent.
- [ ] When `{dry_run}` is truthy, no worktree is created, no commit is produced, no source is mutated, and no per-slice agent is dispatched; the calling agent emits the plan, the per-item proposed commit subjects and bodies, and the resolved slice assignments as the entire final report.
- [ ] Re-running the command against the same `{worklist}` after a successful run with `{worklist_writeback}` set to `auto` normalizes to zero items (the slice already shipped is idempotently skipped).

## Guardrails
- MUST validate every parameter (including `{parallelism}`, `{num_partitions}`, `{agent_model}` shape, `{mode}`, `{partition_strategy}` against item shape, `{on_failure}`, and `{worklist_writeback}`) before creating any worktree or mutating any file; fail fast and create nothing on validation failure.
- MUST treat one item as exactly one commit. MUST NOT bundle multiple items into a single commit. MUST NOT split one item across multiple commits; stage every change for the item together and create a single commit.
- MUST NOT amend, rebase, squash, or otherwise rewrite the history of commits produced by previous items in the same loop run; the loop is forward-only.
- MUST skip every item the source already marks done at the moment the worklist is normalized; rerunning the command against the same source MUST be idempotent on the already-committed slice.
- MUST keep each spawned agent isolated to its assigned worktree; agents MUST NOT read, write, or run commands against the calling worktree, the original working tree, or any sibling worktree.
- MUST NOT commit an item whose `{verify_command}` exited non-zero or whose `done_when` self-check could not be evidenced; apply the configured `{on_failure}` policy instead.
- MUST NOT mutate the worklist source for items that did not produce a commit on the agent's branch; writeback is gated on a successful commit.
- MUST treat the worklist source as read-only (force `{worklist_writeback}` to `disabled` and report the override) when the source resolves to a path outside the agent's worktree, an immutable MCP endpoint, an inline list, or a chat reference.
- MUST NOT push branches, open pull requests, create tags, merge worktree branches, or touch any branch other than the per-agent branch it was assigned. Branch merging back into `{base_branch}` is delegated to a separate workflow.
- MUST follow Conventional Commits 1.0.0 for every commit subject; the body is plain prose wrapped at 72 columns and ends with a `Worklist: <source_ref>` footer, plus a `Done-when: <text>` line when the item carried one.
- Scope: in scope is parsing one `{worklist}`, partitioning its unchecked items across up to `{parallelism}` isolated worktrees, committing exactly one change per item per worktree, and writing back to a mutable source within that same commit. Out of scope: merging worktree branches back into `{base_branch}`, pushing, opening PRs, creating tags, addressing items not present in the original normalized worklist, refactoring code beyond what each individual item requires, and resolving cross-agent merge conflicts on the worklist source after fan-out.

## Workflow
1. **Parse the invocation.** Extract `{worklist}`, `{mode}`, `{parallelism}`, `{num_partitions}`, `{agent_model}`, `{base_branch}`, `{partition_strategy}`, `{verify_command}`, `{on_failure}`, `{commit_scope}`, `{commit_type}`, `{worklist_writeback}`, `{max_items}`, and `{dry_run}` from the user's input. Apply documented defaults for any parameter the user did not set.
2. **Validate parameters.** Confirm every constraint in the Guardrails and Success Criteria sections. Abort with an explanatory error and zero filesystem side effects on any validation failure.
3. **Resolve and normalize the worklist.** Dispatch on the type of `{worklist}`:
   - **File path:** read the file, walk every `- [ ]` / `- [x]` line, drop the `[x]` items, and for each `[ ]` line capture the title from the same line plus any indented `Where:` / `Why:` / `Done-when:` subfields. Record the section heading hierarchy as `severity` when a heading matches `Critical` / `Major` / `Minor` / `Nit`. Use `<path>:<line>` as the `source_ref` and the line number as the id seed.
   - **Chat reference:** locate the most recent matching block in the active chat before the invocation; parse it with the same rules as a markdown source. Use `chat:<anchor>` as the `source_ref`.
   - **MCP endpoint:** call the endpoint's `list` operation; map each returned object to an internal item by `id`, `title`, `done_when`, and `severity` when present; filter out any item the server marks complete. Use the MCP URI plus item id as the `source_ref`.
   - **Inline:** split the inline text on newlines or `;` into one item per chunk; assign sequential ids (`inline-1`, `inline-2`, …) and `source_ref` `inline-<i>`.
   - Record the source kind so subsequent steps dispatch writebacks correctly.
4. **Build the plan.** For every normalized item produce: the proposed Conventional Commits subject (using `{commit_type}` and `{commit_scope}` overrides when set, otherwise the documented per-item inference rules), the slice it will be assigned to under `{partition_strategy}`, the agent index that will own that slice, and the proposed commit body (title, `Done-when:` line when present, `Worklist:` footer).
5. **Plan approval.** Surface the plan (item count, per-slice item titles, proposed commit subjects, model per agent, target branches, writeback target). Based on `{mode}`: `interactive` and `non-interactive` ask for one approval here; `force-approve-all` auto-approves and proceeds.
6. **Resolve model assignment** by broadcasting a scalar `{agent_model}` to every agent, zipping a per-agent list positionally, or zipping a per-partition list across `{parallelism} / {num_partitions}` agents per partition. (Skip when `{parallelism}` is `1`.)
7. **Create worktrees and dispatch agents** (skip when `{parallelism}` is `1` and run the loop in the calling worktree). For each agent `i` in `1..{parallelism}`, create a branch off `{base_branch}` named from a kebab slug of the worklist plus `-{i}`, add the worktree via `git worktree add`, and dispatch one agent inside that worktree with: its slice of items, the resolved model, the inherited `{mode}` (with the plan-approval step already completed), and every per-item parameter (`{verify_command}`, `{on_failure}`, `{commit_scope}`, `{commit_type}`, `{worklist_writeback}`, `{max_items}`).
8. **Run the per-item loop inside each agent.** For every item in the agent's slice, in source order:
   1. Mark the item `in_progress` in the agent's local report.
   2. Implement the change required by the item, scoped strictly to what the item describes.
   3. Run `{verify_command}` (when provided) on the code-only delta and capture the exit code; otherwise self-evaluate the item's `done_when` text and record the evidence in the report.
   4. On failure, apply `{on_failure}` (`abort` stops the agent; `skip` discards staged changes and continues; `mark-blocked` discards staged changes, records the reason, and continues).
   5. On success, when `{worklist_writeback}` is `auto` and the source is mutable, mutate the source inside the agent's worktree (toggle the markdown checkbox on the recorded line, or call MCP `mark_done`). When `{worklist_writeback}` is `summary-comment`, accumulate the entry in an in-memory summary buffer instead.
   6. In `interactive` mode, present the combined diff (code change plus any in-place writeback) together with the proposed commit subject and body, and wait for per-item approval. In `non-interactive` and `force-approve-all` modes, proceed automatically.
   7. Stage every change (code plus in-place writeback) and create exactly one commit. Record the resulting commit SHA, mark the item `committed`, and proceed.
   8. Stop early if `{max_items}` has been reached or if `{on_failure} = abort` fired earlier in the slice.
9. **Finalize per-agent state.** When `{worklist_writeback}` is `summary-comment`, append the accumulated summary block to the worklist file and create one additional trailing commit dedicated to that summary (this commit is reported separately and does NOT count against the one-commit-per-item invariant).
10. **Collate.** Wait for all agents to finish (when `{parallelism} > 1`). Collect per-agent reports, aggregate per-status counts, and assemble the final report using the Output Format below. Do not merge worktree branches; leave each branch in place for the user to inspect or hand off to a separate merge workflow.
11. **Dry-run short-circuit.** When `{dry_run}` is truthy, skip steps 6–10 after step 5 produces the plan, and emit the plan plus per-item proposed commit subjects and slice assignments as the entire final report.

## Output Format
A single markdown report with the sections below, in this order. Omit any section whose body would be empty.

### Run Summary
- `Worklist`: resolved source (path, MCP URI, chat anchor, or `inline (N items)`).
- `Source kind`: `markdown-file`, `chat`, `mcp`, or `inline`.
- `Mode`: `interactive`, `non-interactive`, or `force-approve-all`.
- `Parallelism`: integer (with `Partitions: <N>` appended when `{num_partitions} != {parallelism}`).
- `Partition strategy`: `contiguous`, `round-robin`, or `severity-weighted`.
- `Writeback`: `auto`, `disabled`, `summary-comment`, or `forced-disabled (<reason>)`.
- `Items normalized`: integer (count of unchecked items after normalization).
- `Items committed / blocked / skipped / pending`: four integers summing to `Items normalized`.
- `Dry run`: `true` or `false`.

### Plan
A table with one row per normalized item:

| # | Slice | Agent | Item id | Title | Proposed commit subject | Done-when |
|---|-------|-------|---------|-------|--------------------------|-----------|

In `interactive` and `non-interactive` modes this block is also surfaced before plan approval. In `force-approve-all` and dry-run modes it appears only in the final report.

### Per-Agent Reports
One block per agent, in slice-index order:

- `Index`: 1-based agent index.
- `Worktree path`: absolute path (or `<calling worktree>` when `{parallelism}` is `1`).
- `Branch`: branch name.
- `Agent model`: model identifier used.
- `Slice size`: number of items assigned.
- `Items`: per-item rows of the form `<item id> | <status> | <commit SHA or "-"> | <verification exit code or "n/a"> | <one-line note>`.
- `Writeback`: `applied`, `disabled`, `summary-only`, or `n/a (immutable source)`.
- `Stopped early?`: `no` or `yes (<reason>)`.

### Failures
Itemized list of every item with status `blocked` or `skipped` (across all agents). For each: item id, agent index, last verification exit code (when applicable), and a 1–3 sentence root-cause note quoting any failing output. Omit when no items failed.

### Next Steps
- Per-agent branches and worktree paths left in place for the user to inspect or merge separately.
- For `blocked` items, the suggested follow-up action (rerun with adjusted `{verify_command}`, manual intervention, etc.).
- For `pending` items, the suggested rerun command targeting only the unfinished items (the same `{worklist}` and `{mode}`, narrowed by the writeback state).
