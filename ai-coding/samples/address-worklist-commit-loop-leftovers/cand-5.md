# Address Worklist Commit Loop

## Task
Address each unchecked item in a polymorphic worklist by making the code changes the item describes, creating exactly one Conventional Commits 1.0.0-style git commit per item, and marking the item done in the source — looped over every unchecked item in `{worklist}`. When `{parallelism}` is greater than `1`, partition the unchecked items disjointly across that many isolated git worktrees, and have each worktree's agent run the same per-item loop strictly sequentially over its assigned slice.

## Parameters
- `{worklist}` — source of work items to address; required. Accepts any of:
  - a path to a markdown file with `- [ ]` checkbox items (optionally with `Where:` / `Why:` / `Done when:` subfields underneath each item);
  - a reference to prior chat content (e.g., `chat:above`, `chat:<message-id>`, or a free-form phrase such as "the action items I described above" the workflow can resolve);
  - an MCP endpoint URI (e.g., `mcp://<server>/<resource>`) that returns a list of work items;
  - an inline list embedded in the invocation itself (one item per line, optionally prefixed `- [ ]`).
  The workflow normalizes every shape into a uniform internal worklist before any agent begins.
- `{mode}` — interaction policy across the run; required. Allowed values:
  - `interactive` — the user approves the overall plan AND every per-item commit before it is created.
  - `non-interactive` — the user approves the overall plan exactly once; the loop then runs silently to completion, with failures handled by `{on_failure}` instead of further prompts.
  - `force-approve-all` — no approvals are requested at any point; every default (the overall plan and every per-item commit) is accepted automatically.
- `{parallelism}` — number of isolated git worktrees across which to PARTITION the unchecked items; optional, default: `1`. MUST be an integer `>= 1`. When `1`, all items are addressed sequentially in the calling worktree with no fan-out. When greater than `1`, each agent owns a disjoint slice of items and addresses its slice strictly sequentially — one item, one commit, at a time.
- `{num_partitions}` — number of partitions for grouping `{agent_model}`; optional, default: same as `{parallelism}`. MUST be an integer `>= 1` and MUST evenly divide `{parallelism}`. A partition is a contiguous slice of `{parallelism} / {num_partitions}` agents that share one model from `{agent_model}`.
- `{agent_model}` — model(s) to use for the per-worktree agents; optional, default: the parent agent's model. Accepts a single identifier (broadcast to every agent), a list of length `{parallelism}` (one per agent positionally), or a list of length `{num_partitions}` (one per partition, broadcast to every agent within the partition).
- `{partition_strategy}` — how normalized items are assigned to the `{parallelism}` agent slots; optional, default: `contiguous`. Allowed values:
  - `contiguous` — slice the normalized item order into evenly-sized blocks, distributing any remainder to the lowest-indexed slots.
  - `round-robin` — item `i` (zero-based) is assigned to agent `i mod {parallelism}`.
  - `severity-first` — when the source carries leading severity headings (`critical` / `high` / `medium` / `low`), group items by severity (highest first) and apply `contiguous` within each group.
  - `dependency-order` — preserve source order and assign with `contiguous`; chosen when later items reference earlier ones.
- `{base_branch}` — branch to fork worktrees from when `{parallelism}` is greater than `1`; optional, default: the current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name}` — base name for worktree directories and branches when `{parallelism}` is greater than `1`; optional, default: a kebab-case slug derived from the `{worklist}` source name. A 1-based `-{i}` suffix is appended per agent.
- `{commit_scope}` — Conventional Commits scope to attach to every commit subject (e.g., `feat(<scope>): ...`); optional. When unset, scope is inferred per-item from the item's `Where:` subfield (when present) or omitted from the subject.
- `{verify_command}` — shell command run inside the owning worktree after each item's edits and before its commit; optional. Exit code `0` counts as the item's `Done when:` being satisfied; any non-zero exit code triggers `{on_failure}`. When omitted, the item's textual `Done when:` is the only verification gate and the agent decides whether it is satisfied.
- `{on_failure}` — per-item failure policy; optional, default: `abort`. Allowed values:
  - `abort` — stop this agent's loop immediately, do not commit the failing item, leave already-committed items intact.
  - `skip` — record the failure, do not commit the item, do not mark it done, advance to the next item.
  - `retry-then-skip` — retry up to `{max_retries}` additional times, then apply `skip` semantics.
- `{max_retries}` — per-item retry cap when `{on_failure}` is `retry-then-skip`; optional, default: `1`. MUST be an integer `>= 0`.
- `{max_consecutive_failures}` — circuit breaker that stops an agent's loop when it triggers; optional, default: `3`. MUST be an integer `>= 1`. Counts reset on the next succeeded item.
- `{worklist_writeback}` — whether to mutate the worklist source to mark items done; optional, default: `auto`. Allowed values:
  - `auto` — mutate only when the resolved source is writable (currently file-path sources with `- [ ]` checkbox syntax).
  - `always` — require mutation; abort during validation if the resolved source is not writable.
  - `never` — never mutate the source; useful for read-only or audit runs.
- `{max_items}` — cap on the number of unchecked items addressed in this invocation, applied after `{partition_strategy}`; optional, default: no cap. Items beyond the cap remain unchecked.
- `{dry_run}` — when `true`, normalize the worklist, validate every parameter, present the plan and the per-agent partition assignment, but do not create any worktrees, do not edit any files, and do not create any commits; optional, default: `false`. Honored even in `force-approve-all` mode.

## Success Criteria
- [ ] Every parameter is validated before any worktree is created or any file is touched: `{parallelism}` is an integer `>= 1`; `{num_partitions}` is an integer `>= 1` that evenly divides `{parallelism}`; `{agent_model}` (when a list) has length equal to `{parallelism}` or `{num_partitions}`; `{max_retries}` is an integer `>= 0`; `{max_consecutive_failures}` is an integer `>= 1`; `{mode}`, `{partition_strategy}`, `{on_failure}`, and `{worklist_writeback}` are each one of their allowed values. Validation failure aborts with an explanatory error and no filesystem side effects.
- [ ] `{worklist}` is resolved into a uniform internal list whose items each carry a stable identifier, a description, an optional acceptance / done-when condition, optional `Where:` / `Why:` subfields, and the original source location used for writeback. Items already marked done (e.g., `- [x]`) are excluded from the list before any agent runs.
- [ ] Duplicate stable identifiers across the normalized list cause an explanatory error before any agent runs.
- [ ] When `{parallelism}` is `1`, all unchecked items are addressed strictly sequentially in the calling worktree and no worktree fan-out occurs.
- [ ] When `{parallelism}` is greater than `1`, exactly `{parallelism}` isolated worktrees are created off `{base_branch}`, and the unchecked items are split across them according to `{partition_strategy}` such that every item is owned by exactly one worktree.
- [ ] Each agent addresses its assigned slice strictly sequentially: item `k+1` is not started until item `k` has either landed a commit or been recorded as failed or skipped under `{on_failure}`.
- [ ] Exactly one git commit is created per successfully addressed item, with a Conventional Commits 1.0.0 subject derived from the item's title; the commit body includes the worklist source reference, the item's stable identifier, and (when present) the item's `Done when:` condition.
- [ ] When `{verify_command}` is provided, it is run inside the owning worktree after each item's edits and before its commit, and its captured exit code is reported alongside that item in the final report.
- [ ] In `interactive` mode, the user approves the overall plan AND each per-item commit before it is created; in `non-interactive` mode, the user approves the plan exactly once and no further approvals are requested; in `force-approve-all` mode, no approvals are requested at any point.
- [ ] When `{worklist_writeback}` resolves to `auto` (and the source is writable) or `always`, every committed item is marked done in the original source; when the source is a tracked file in the same repository, the writeback edit is staged together with the item's work so the source mutation lands in the same commit as the work, preserving "one commit per addressed item." When `{worklist_writeback}` is `never`, the source is not modified.
- [ ] When `{worklist_writeback}` is `always` and the resolved source is not writable, the invocation aborts during validation, before any agent runs.
- [ ] When `{dry_run}` is `true`, no worktree is created, no file outside the worklist source is read more than once, no commit is created, and the reply includes the normalized worklist, the per-agent partition assignment, and the resolved parameter snapshot.
- [ ] An agent's loop terminates when its slice is exhausted, when `{on_failure}` is `abort` and an item fails, or when `{max_consecutive_failures}` consecutive items fail; the termination cause is reported per agent.
- [ ] The final report includes, per agent: worktree path and branch (or `n/a` when `{parallelism}` is `1`), assigned model, item count, succeeded / failed / skipped counts, the termination cause, and the ordered per-item result table with commit SHA, status, and (when applicable) `{verify_command}` exit code.

## Guardrails
- MUST validate every parameter before creating any worktree, editing any file, or contacting any MCP server beyond an initial read of the worklist source; fail fast and leave the filesystem untouched on validation failure.
- MUST partition items disjointly when `{parallelism}` is greater than `1`; no item may be addressed by more than one agent in a single invocation.
- MUST address items strictly sequentially within each agent's slice; no parallel item processing within a single worktree.
- MUST create exactly one git commit per addressed item, with a Conventional Commits 1.0.0 subject; MUST NOT bundle multiple worklist items into one commit, and MUST NOT split one worklist item across multiple commits.
- MUST NOT modify or re-process items already marked done (e.g., `- [x]`) in the source worklist.
- MUST honor `{on_failure}` exactly: `abort` stops the loop, `skip` advances without committing the failing item, `retry-then-skip` retries up to `{max_retries}` additional times before applying `skip` semantics.
- MUST trip the `{max_consecutive_failures}` circuit breaker per agent and stop that agent's loop when reached, even when `{on_failure}` would otherwise advance.
- MUST keep each agent's work isolated to its assigned worktree when `{parallelism}` is greater than `1`; agents MUST NOT read, write, or run commands against the calling worktree or any sibling worktree.
- MUST NOT push branches, open pull requests, create tags, or touch branches other than the one inside each agent's worktree.
- MUST NOT recursively launch worktree agents from inside a spawned agent.
- Scope: this command addresses items in a single `{worklist}` source within a single repository, produces one commit per addressed item, and optionally mutates the source. Out of scope: merging worktree branches together, synthesizing results across worktrees, pushing to remotes, opening PRs, generating new worklist items, and any work unrelated to the resolved items.

## Workflow
1. **Parse and validate parameters.** Confirm `{mode}`, `{partition_strategy}`, `{on_failure}`, and `{worklist_writeback}` are each one of their allowed values; `{parallelism}`, `{num_partitions}`, `{max_retries}`, and `{max_consecutive_failures}` are integers in their respective ranges; `{num_partitions}` evenly divides `{parallelism}`; `{agent_model}` (when a list) has length `{parallelism}` or `{num_partitions}`. Abort with an explanatory error and no filesystem side effects on failure.
2. **Resolve `{worklist}` into a uniform internal list.**
   - File path: parse markdown, extract every top-level `- [ ]` checkbox item, attach any `Where:` / `Why:` / `Done when:` lines underneath, and record the source line range so writeback can locate and flip the checkbox. Exclude items already marked `- [x]`.
   - Chat reference: locate the referenced chat block, parse identical syntax. Writeback is unavailable unless an explicit file destination is also provided.
   - MCP endpoint: call the endpoint once and map its returned items into the same uniform shape. Writeback availability depends on whether the server exposes a write API.
   - Inline: parse each non-empty line of the invocation body as one item; the description is the line minus any `- [ ]` prefix.
3. **Assign a stable identifier per item.** Derive it from the source (file path plus line range, MCP item id, or a hash of the normalized description) so identifiers survive reruns. Abort with an explanatory error if two normalized items collide on identifier.
4. **Resolve writeback availability.** Compare the resolved source against `{worklist_writeback}`: `auto` mutates only writable file-path sources; `always` aborts now if the resolved source is not writable; `never` skips mutation entirely.
5. **Build the plan.** Apply `{partition_strategy}` to assign every item to exactly one of `{parallelism}` agent slots. Apply `{max_items}` as a cap on the total addressed in this invocation. Snapshot the resolved parameter values together with the per-agent assignment.
6. **Get plan approval.** In `interactive` and `non-interactive` modes, present the plan and request one approval before continuing. In `force-approve-all` mode, proceed without asking. When `{dry_run}` is `true`, emit the plan and stop here.
7. **Resolve per-agent model assignment.** Broadcast a scalar `{agent_model}` to every agent, zip a list of length `{parallelism}` positionally, or zip a list of length `{num_partitions}` per partition.
8. **Provision worktrees** when `{parallelism}` is greater than `1`. For each `i` in `1..{parallelism}`, create a branch off `{base_branch}` named after `{worktree_name}` with a `-{i}` suffix and add a matching worktree via `git worktree add`. When `{parallelism}` is `1`, skip this step and operate inside the calling worktree.
9. **Run the per-item loop in each agent slot.** For each item in the agent's assigned slice, in order:
   1. Restate the item's description, stable identifier, and `Done when:` condition (when present).
   2. Make the code edits required to address the item.
   3. Run `{verify_command}` (when provided) inside the worktree and capture its exit code.
   4. On verification failure or inability to complete the item, apply `{on_failure}` (`abort`, `skip`, or `retry-then-skip` up to `{max_retries}` additional attempts) and increment this agent's consecutive-failure counter. If the counter reaches `{max_consecutive_failures}`, terminate this agent's loop regardless of `{on_failure}`.
   5. Stage only the files relevant to this item. When writeback is available and the source is a tracked file in the same repository, also stage the worklist mutation that flips this item to `- [x]` (or the source-appropriate equivalent) so the source mutation lands in the same commit as the work.
   6. In `interactive` mode, present the staged diff and request approval before running `git commit`; in `non-interactive` and `force-approve-all` modes, commit immediately. Build the commit subject as Conventional Commits 1.0.0 with the item's title as description and `{commit_scope}` (or the item's `Where:` subfield when present) as the scope. The commit body includes the worklist source reference, the stable identifier, and the `Done when:` condition when present.
   7. If the user rejects the commit in `interactive` mode, treat the item as skipped (do not commit, do not mark done) and advance to the next item.
   8. On a successful commit, reset this agent's consecutive-failure counter and, when the worklist source is non-tracked but writable (or chat / MCP with a write API), perform the writeback as a separate post-commit side effect.
10. **Aggregate results.** After every agent's loop terminates (by completion, abort, or circuit breaker), collect per-agent status, the per-item result table (status, commit SHA when present, verify exit code when applicable), and the final state of the worklist source.
11. **Emit the final report** using the Output Format below. Do not merge worktree branches and do not delete worktrees; both decisions remain with the user.

## Output Format
Return a single response with the following named sections, in this order:

### Run Summary
- `Worklist source`: original `{worklist}` reference and resolved shape (`file` / `chat` / `mcp` / `inline`).
- `Items resolved`: total unchecked items found, addressed in this invocation (after `{max_items}`), and the count of items skipped as already done.
- `Mode`: resolved `{mode}`.
- `Parallelism`: resolved `{parallelism}` and `{partition_strategy}`.
- `Writeback`: resolved policy (`auto` / `always` / `never`) and effective writability of the source.
- `Counts`: succeeded, failed, skipped, and aborted item counts, summed across agents.

### Plan
A table of every normalized item: stable identifier, agent slot, short title, and (when present) `Done when:` summary. Reprinted in the final report exactly as approved.

### Agent Results
One block per agent slot, in slot order:

- `Slot`: 1-based agent index.
- `Worktree path`: absolute path, or `n/a` when `{parallelism}` is `1`.
- `Branch`: branch name, or `n/a` when `{parallelism}` is `1`.
- `Model`: resolved model identifier.
- `Item counts`: assigned, succeeded, failed, skipped.
- `Termination`: `completed`, `aborted (on_failure=abort, item=<id>)`, or `aborted (circuit breaker tripped at item=<id>)`.
- `Items`: an ordered table of `{stable id, status, commit SHA or "—", verify exit code or "n/a", one-line note}`.

### Failures
Omitted when no items failed or were skipped. For each affected item: stable identifier, agent slot, failing step (`edit` / `verify` / `commit` / `writeback`), the captured error tail, and the action taken (`abort`, `skip`, or `retry-then-skip`).

### Worklist Writeback
- `Final state`: the post-run state of the worklist source, or a unified diff against the pre-run state when oversized.
- `Unchecked items remaining`: count plus the stable identifiers of every item left unchecked due to failure, skip, or `{max_items}` cap.
