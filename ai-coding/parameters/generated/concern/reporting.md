# Concern: Reporting

> **Responsibility:** Declare *what the final response shows*, *how loud it is*, and *what level of evidence accompanies it*. Reporting is the user-visible surface of the run; it does not change what the agent did, it changes what the agent communicates back.
>
> **Primary parameters:** `verbosity`, `require_diff`, `include_terminal_log`

## Why this concern exists

Two prompts producing the same artifact may legitimately want very different report shapes: a one-line "done, here's the merged branch" vs. a detailed per-candidate report with diffs and per-criterion findings. Bundling these knobs in their owning concerns would scatter the reporting surface — `require_diff` would land in I/O, `verbosity` would land in lifecycle, `include_terminal_log` would land in robustness. Putting them together lets a prompt author tune "how loud" in one place.

This concern is intentionally small. Most reporting structure is fixed by each command's `## Output Format`; these three parameters are the user-tunable dials on top of that fixed structure.

## Parameters

### `verbosity`

**Aliases:** `loudness`, `detail_level`
**Definition:** How much detail the final response includes per result.
**Type:** Enum: `terse | normal | verbose | debug`. Each level is a superset of the level above.
**Default:** `normal`.

**Values:**

- `terse` — headline only (status + 1-line summary per candidate; no diffs, no rationale).
- `normal` — per-candidate block as defined by the command's `## Output Format`.
- `verbose` — adds rationale for every selection decision, per-criterion findings broken out, and reasons for skipped candidates.
- `debug` — adds raw tool invocations, model identifiers, seeds, partial outputs from hung agents, and the full validation trace.

**Cross-refs:**

- [`require_diff` (this file)](#require_diff) — orthogonal; `verbosity=terse` plus `require_diff=true` still emits diffs but no per-candidate prose.
- [`include_terminal_log` (this file)](#include_terminal_log) — implicitly enabled at `verbosity=debug`.
- [`output_format` (io.md)](./io.md#output_format) — shape of the serialization; `verbosity` controls depth, `output_format` controls form.

**Example:** `/worktree-task-agent task=X parallelism=4 verbosity=verbose` — the per-worktree report includes the merge recommendation rationale and gating reasons even for skipped candidates.

---

### `require_diff`

**Aliases:** `show_diff`, `include_diff`
**Definition:** Whether the report includes a `git diff` (or candidate-vs-baseline diff) for every candidate that produced changes.
**Type:** `boolean`.
**Default:** `true` for `/worktree-task-agent` (mandated by its Output Format); `false` for read-only commands like `/critique`.

**Cross-refs:**

- [`compare_against` (selection.md)](./selection.md#compare_against) — when set, diffs are candidate-vs-baseline; otherwise they're per-candidate `git diff base_branch..<branch>`.
- [`auto_save_winner` (lifecycle.md)](./lifecycle.md#auto_save_winner) — paired by convention so the user can audit what was promoted.
- [`verbosity` (this file)](#verbosity) — orthogonal.
- [`output_format` (io.md)](./io.md#output_format) — diffs are rendered inside the chosen `output_format` (a fenced ` ```diff ` block in markdown, a `diff` field in JSON).

**Example:** `/meta-prompt refine=existing.md n_candidates=3 require_diff=true compare_against=existing.md` — each refined candidate shows the diff against the original prompt.

---

### `include_terminal_log`

**Aliases:** `with_logs`, `attach_stdout`
**Definition:** Whether the report includes a tail of the terminal / tool output for each candidate.
**Type:** `boolean | int` — `false` to omit, `true` for a default tail (last ~40 lines), integer for a custom tail size in lines.
**Default:** `false`.

**Cross-refs:**

- [`verbosity` (this file)](#verbosity) — `verbosity=debug` implicitly sets `include_terminal_log=true` if unset.
- [`test_command` (constraints.md)](./constraints.md#test_command) — when set, the report's per-candidate "Verification" section tails `test_command` output (governed by this parameter when present).
- [`hang_policy` (robustness.md)](./robustness.md#hang_policy) — hung-candidate tails are especially useful for diagnosing why a candidate hung; pair `hang_policy=ignore` with `include_terminal_log=true` for triage.

**Example:** `/worktree-task-agent task=X parallelism=8 include_terminal_log=100` — each candidate report includes the last 100 lines of tool output, useful for debugging flaky test commands.
