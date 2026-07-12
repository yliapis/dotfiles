# Ralph Design

## Task
Run an interactive ralph-loop that walks the design walkthrough enumerated by `{design_skill}` one step at a time to produce that skill's declared deliverable for `{domain}`, with optional per-round fan-out via `worktree-task` to explore variants in parallel.

The loop is user-in-the-loop by default: each round drafts an update for the current walkthrough step, presents it, and accepts one of `accept` / `refine` / `fork` / `back` / `done`. A leading **step 0** lets the user choose which named principles from the skill to anchor the rest of the loop to. The artifact's persistence is mode-dependent: `chat` keeps everything in-conversation; `codebase` writes the artifact to disk and, by default, does so inside a dedicated git worktree so the calling working tree is never silently mutated.

## Parameters
- `{domain}` — the domain the artifact models, named in the user's own words (e.g., `feature flags`, `RBAC policies`, `CI pipelines`); required.
- `{design_skill}` — repo-relative path to the design skill that supplies the principles list and the design walkthrough this loop walks; optional, default: `.cursor/skills/declarative-design/SKILL.md`. The command reads this file at invocation time; round count, step names, principle names, and the final deliverable's shape are sourced from it.
- `{mode}` — approval cadence; optional, default: `interactive`. Allowed values:
  - `interactive` — user is asked at every round; `{stop_condition}` defaults to `user-signals-done`.
  - `non-interactive` — user approves the plan once; the loop auto-accepts every per-round draft until `{stop_condition}` fires. Requires `{stop_condition}` to be set to a value other than `user-signals-done`.
  - `force-approve-all` — no approvals at any point, not even on the plan. Requires `{stop_condition}` to be set to a value other than `user-signals-done`.
- `{stop_condition}` — explicit exit condition for the loop; optional, default: `user-signals-done`. Allowed values:
  - `user-signals-done` — the loop exits only when the user chooses `done`. Valid only in `interactive` mode.
  - `all-steps-complete` — exits once every walkthrough step (in declared order, with no later `back` rewinding past it) has been the subject of a round ending in `accept` or `fork`.
  - `validation-pass` — exits once the deliverable's declared validation rules all pass against the deliverable's worked instance.
  - `max-rounds:<n>` — exits after `<n>` rounds, where `<n>` is a positive integer. Distinct from `{max_iterations}`, which is a safety cap, not a stop condition.
- `{persistence}` — where the working artifact lives between rounds; optional, default: `codebase`. Allowed values:
  - `chat` — draft only; no file is created, modified, or staged at any point, including snapshots. `{use_worktree}` MUST be `false`.
  - `codebase` — the working artifact is written to `{artifact_path}` after every accepted round and rewritten on `back` rewinds; snapshots are written to `{artifact_path}.snapshots/`.
- `{artifact_path}` — repo-relative file path the working artifact is written to when `{persistence} = codebase`; optional, default: `schemas/<kebab-domain>.md`, where `<kebab-domain>` is a kebab-case slug of `{domain}`. Overwritten round by round (no append).
- `{use_worktree}` — whether disk writes for `{persistence} = codebase` happen inside a dedicated worktree; optional, default: `true` when `{persistence} = codebase`, otherwise `false`. When `true`, the loop creates the worktree before its first write and routes every subsequent write into it; the calling working tree is never touched.
- `{base_branch}` — branch the worktree is forked from when `{use_worktree} = true`; optional, default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `{worktree_name}` — name of the worktree directory and branch when `{use_worktree} = true`; optional, default: a kebab-case slug derived from `{domain}`, prefixed with `ralph-design/`.
- `{fanout_default_n}` — default number of sibling variants spawned via `worktree-task` when the user picks `fork` at a round and supplies no explicit count; optional, default: `4`. MUST be an integer `>= 2`.
- `{agent_model}` — model identifier passed through to `worktree-task` for fan-out agents; optional, default: the parent agent's model. Broadcast to every spawned agent within a `fork`.
- `{max_iterations}` — hard safety cap on total rounds across the loop's lifetime, including rounds repeated via `refine` and `back`; optional, default: `50`. When reached, the loop halts with terminal state `iteration-cap-hit` regardless of `{stop_condition}`.

## Success Criteria
- [ ] Parameter validation completes before the skill file is read, any worktree is created, or any file is written: `{mode}` ∈ {`interactive`, `non-interactive`, `force-approve-all`}; `{persistence}` ∈ {`chat`, `codebase`}; `{stop_condition}` takes an allowed shape; `{fanout_default_n} >= 2`; `{max_iterations} >= 1`; `non-interactive` and `force-approve-all` MUST NOT use `{stop_condition} = user-signals-done`; `{persistence} = chat` MUST NOT use `{use_worktree} = true`. Validation failure aborts with an explanatory error and zero filesystem side effects.
- [ ] `{design_skill}` resolves to a readable repo-relative file under `.cursor/skills/`; `~/`, `$HOME`, absolute paths outside the repo, and machine-specific home directories are rejected before any read. The file is `Read` once at invocation time, before any round runs.
- [ ] The principle list rendered at step 0 is sourced from the first `## …Principles` section of the resolved skill (by header match), and the walkthrough step list rendered as rounds 1..N is sourced from the skill's `## Design Walkthrough` section in declared order — falling back, when that header is absent, to the first H2 section whose body is an ordered enumeration of named items (each `**bold name**` or `### <Name>` becomes a step, matching `designer-controller`'s Walkthrough Header Resolution), and aborting with an explanatory error when neither matches; neither list is inlined, hard-coded, or paraphrased into this command.
- [ ] Step 0 runs before step 1: the user is presented with the skill's principle names and selects a subset (or accepts all). The selection is recorded once and persists across the rest of the loop, and appears in the final report.
- [ ] Every round ending in `accept` or `fork` produces a snapshot of the working artifact tagged by round index and step slug (`refine` attempts and `back` rewinds do not snapshot). When `{persistence} = codebase`, snapshots are written to `{artifact_path}.snapshots/<round>-<step-slug>.md`; when `{persistence} = chat`, snapshots are held in memory only.
- [ ] In `interactive` mode, every round prompts the user with the choices `accept` / `refine` / `fork` / `back` / `done`. `accept` applies the draft, snapshots, and advances. `refine` takes the user's feedback and redrafts the same step without advancing. `fork` dispatches `worktree-task`, presents the variants' artifact files, and applies the user's pick before advancing. `back` rewinds to a user-named earlier step's snapshot and resumes forward step-by-step from the next step. `done` exits the loop with the current artifact.
- [ ] In `non-interactive` and `force-approve-all` modes, every per-round draft is auto-accepted; the loop never asks `refine` / `fork` / `back` / `done` mid-loop. `non-interactive` still requires plan approval at the start; `force-approve-all` skips that approval too.
- [ ] When `fork` is invoked, the loop dispatches `worktree-task` with `parallelism = <n>` (the user-supplied count for the round or `{fanout_default_n}`), `base_branch =` the iterator's current branch, and a task that runs **only the current walkthrough step** on a copy of the working artifact at `{artifact_path}`. Fan-out agents MUST NOT recurse: `worktree-task` is invoked with `parallelism = 1` from inside each spawned agent, and spawned agents MUST NOT invoke `/ralph-design`.
- [ ] After fan-out completes, the orchestrator reads each variant's artifact file from its worktree, presents every variant's proposed update side by side as fenced diffs, asks the user to pick exactly one, copies that variant's artifact content into the iterator's worktree, snapshots, and advances. Discarded variants' worktrees are left in place per `worktree-task`'s own merge/cleanup policy.
- [ ] When `{persistence} = codebase` and `{use_worktree} = true`, the worktree is created via `git worktree add` off `{base_branch}` before the first disk write; every write to `{artifact_path}` and every snapshot write happens inside that worktree; the calling working tree's working directory and index are never modified.
- [ ] When `{persistence} = chat`, no file is created, modified, or staged at any point, including snapshots; chat-mode runs are zero-side-effect on the filesystem.
- [ ] `{stop_condition}` is evaluated at the end of every round, after any chosen update is applied. The first satisfied condition halts the loop. `{max_iterations}` is evaluated independently and halts the loop with terminal state `iteration-cap-hit` when reached, regardless of `{stop_condition}`.
- [ ] The final deliverable matches the deliverable section of the resolved `{design_skill}` (for `declarative-design`: a schema, at least one worked instance, and the explicit validation-rules list). It is rendered inline in the final report and, when `{persistence} = codebase`, written verbatim to `{artifact_path}`.

## Guardrails
- MUST `Read` the file at `{design_skill}` and source step names, step order, principle names, and the deliverable's shape from it; MUST NOT inline, hard-code, or paraphrase those sections into this command or the emitted report.
- MUST treat step 0 (principle selection) as part of every loop; MUST NOT advance to step 1 until the user has either selected a subset of principles or explicitly accepted all of them.
- MUST keep the loop user-in-the-loop in `interactive` mode: every round asks for one of `accept` / `refine` / `fork` / `back` / `done` before mutating the artifact; MUST NOT silently apply a draft.
- MUST keep every disk write inside the dedicated worktree when `{use_worktree} = true`; MUST NOT touch the calling worktree's working tree or index for the artifact, its snapshots, or any fan-out scaffolding.
- MUST NOT mutate any file when `{persistence} = chat`, including snapshot files.
- MUST NOT bundle multiple walkthrough steps into a single round; one round addresses exactly one step (step 0 or one walkthrough step). `back` re-enters at a single named earlier step and resumes forward step-by-step from the step after it.
- MUST NOT recurse: fan-out agents dispatched through `worktree-task` MUST run with `parallelism = 1` and MUST NOT invoke `/ralph-design` or further fan out.
- MUST honor `{stop_condition}` exactly; MUST NOT exit the loop on any condition not declared in `{stop_condition}` or `{max_iterations}`.
- MUST NOT push, open PRs, merge branches, delete worktrees, create tags, or rebase pre-existing branches; the iterator's worktree and its branch are left in place for the user to review and merge separately, and fan-out worktrees are left to `worktree-task`'s own policy.
- Scope: walking one design skill's walkthrough for one `{domain}` to produce that skill's declared deliverable, optionally exploring per-round variants through `worktree-task`. Out of scope: composing multiple design skills in one loop (use `/designer` for trait composition), generating downstream code or types, publishing the artifact to a registry, and merging the iterator's worktree branch back into `{base_branch}`.

## Workflow
1. **Parse and validate.** Extract every parameter, apply documented defaults, and confirm every Success Criteria validation rule. Abort on the first failure with an explanatory error and zero filesystem side effects.
2. **Resolve the design skill.** Reject any non-repo-relative path. `Read` the resolved `{design_skill}` file. Identify its first `## …Principles` section and capture the principle names. Identify its `## Design Walkthrough` section and capture each numbered step's name and slug in declared order — these become the loop's rounds 1..N. When no `## Design Walkthrough` header exists, fall back to the first H2 section whose body is an ordered enumeration of named items (per `designer-controller`'s Walkthrough Header Resolution); abort with an explanatory error when neither matches. Identify its `## Deliverable` section (or equivalent header) and capture the deliverable's declared artifacts.
3. **Render the plan.** Build a plan that lists: resolved parameters, skill path, principle names, ordered step names, persistence and worktree resolution, fan-out default, stop condition, and iteration cap. In `interactive` and `non-interactive` modes, present the plan and require approval; in `force-approve-all`, auto-accept.
4. **Set up persistence.** When `{persistence} = codebase` and `{use_worktree} = true`, create the worktree at `{worktree_name}` off `{base_branch}` via `git worktree add` and route every subsequent write into it. When `{persistence} = codebase` and `{use_worktree} = false`, write directly into the calling working tree. When `{persistence} = chat`, hold all artifact and snapshot state in memory only.
5. **Run step 0 (principle selection).** Present the captured principle names; in `interactive` mode, prompt for a subset (or accept-all); in non-interactive modes, accept all. Record the selection; snapshot.
6. **Loop the walkthrough.** For each step in declared order (and again on `back` rewinds), increment the round counter and:
   1. Draft an update to the working artifact scoped to the current step, anchored on the principles selected in step 0 and the artifact state so far.
   2. In `interactive` mode, present the draft and the artifact diff; prompt for one of `accept` / `refine` / `fork` / `back` / `done`:
      - `accept`: apply the draft, snapshot, advance.
      - `refine`: take the user's feedback, redraft, re-prompt (round counter still increments per attempt).
      - `fork`: ask for `<n>` (default `{fanout_default_n}`); dispatch `worktree-task` with `parallelism = <n>`, `base_branch =` the iterator's current branch, `merge_mode = interactive`, `agent_model =` resolved `{agent_model}`, and a `task` of "apply only the current walkthrough step's update to the working artifact at `{artifact_path}` and stop"; after the dispatched agents complete, read each variant's `{artifact_path}` content, present every variant's proposed update side by side as fenced diffs, ask the user to pick exactly one, copy the chosen variant's `{artifact_path}` content into the iterator's worktree, snapshot, advance.
      - `back`: ask which earlier step to return to; restore that step's snapshot as the working artifact (overwriting `{artifact_path}` when `{persistence} = codebase`); re-enter the loop at the step after the named one.
      - `done`: exit the loop; the current artifact is the final state.
     In non-interactive modes, behave as if `accept` was chosen every round.
   3. Snapshot the artifact after `accept` and after `fork` (post-variant-pick) with the round index and step slug.
   4. Evaluate `{stop_condition}` and `{max_iterations}`; halt the loop the first time either is satisfied, recording the terminal state.
7. **Compose the deliverable.** Assemble the final artifact matching the resolved design skill's declared deliverable. When `{persistence} = codebase`, write the deliverable verbatim to `{artifact_path}` (overwriting prior content) inside the worktree.
8. **Emit the report.** Produce the report per `## Output Format`. Do not merge the worktree branch and do not delete the worktree.

## Output Format
A single response with these named sections, in order. Omit any section whose body would be empty.

### Run Summary
- `Domain`: resolved `{domain}`.
- `Design skill`: resolved `{design_skill}` path.
- `Mode`: `interactive` / `non-interactive` / `force-approve-all`.
- `Stop condition`: resolved `{stop_condition}`.
- `Persistence`: `chat` or `codebase` (with `{artifact_path}` when `codebase`).
- `Worktree`: branch name and absolute path, or `n/a` when `{use_worktree} = false` or `{persistence} = chat`.
- `Iteration cap`: resolved `{max_iterations}`.
- `Terminal state`: `user-done` / `all-steps-complete` / `validation-pass` / `max-rounds-hit` / `iteration-cap-hit` / `plan-declined`. (Parameter-validation failures abort before any run, so no report is produced for them.)
- `Counts`: rounds run / accepted / refined / forked / backs / variants spawned / variants discarded.

### Selected Principles
A bullet list of principle names selected at step 0, in the order they appear in the skill file. Includes a sub-bullet `All principles selected.` when the user accepted the full list.

### Iteration Log
A table with one row per round, in execution order:

| Round | Step | Choice | Variants spawned | Snapshot |
|-------|------|--------|------------------|----------|

Each `Snapshot` cell is the snapshot file path (when `{persistence} = codebase`) or `(in-memory)` (when `{persistence} = chat`).

### Final Deliverable
The artifact assembled per the resolved design skill's declared deliverable, rendered inline. Sub-headings and code fences mirror the skill's deliverable section (for `declarative-design`: three subheadings — schema, worked instance, validation rules — each containing a fenced block).

### Persistence Result
- `Wrote artifact to`: absolute path inside the worktree (or `n/a` for chat mode).
- `Snapshots directory`: absolute path of `{artifact_path}.snapshots/` (or `n/a`).
- `Snapshot files`: bullet list of every snapshot file written, in round order.

### Worktree Result
Present this section only when `{use_worktree} = true`. One block:
- `Worktree path`: absolute path.
- `Branch`: `{worktree_name}`.
- `Base branch`: resolved `{base_branch}`.
- `Diff`: a fenced ` ```diff ` block containing `git diff {base_branch}..HEAD`, truncated above ~400 lines with `... (truncated, K lines omitted)` when oversized.

### Next Steps
- The iterator's worktree and its branch are left in place for the user to inspect, refine further, and merge separately.
- For `forked` rounds: sibling worktrees created by `worktree-task` are left in place per its own merge policy; their diffs are addressable via that command's own report.
- For `iteration-cap-hit` runs: suggested follow-up (raise `{max_iterations}` and rerun, or split the remaining steps into a second invocation against the persisted snapshots).
- A reminder that no branches were merged, no worktrees were deleted, and no remotes were touched.
