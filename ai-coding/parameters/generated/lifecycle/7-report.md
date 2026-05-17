# Stage 7 — Report

**Position in lifecycle:** final stage. Runs after **persist** (or in place of it for read-only commands).

**Purpose:** render the run for human consumption — the user-facing recap of what happened, why, with diffs / findings / verification results attached. Report is pure formatting; every fact it cites was produced by an earlier stage.

**Flows in:** outputs from every prior stage — `slot_status`, `slot_artifact`, `slot_log_tail`, `slot_test_exit_code`, `slot_evaluation`, `convergence_record`, `gate_result`, `selection_set`, `selection_rationale`, `persistence_record`.
**Flows out:** the chat reply, the file at `report_destination`, or both. Nothing observable changes about the repo state.

**Skipped when:** never — even silent commands emit a one-line "done" report.

**Key invariant:** report is **side-effect-free on repo state.** It may write a report *file* (via `report_destination`), but that file is not part of the commit / artifact set persist owns; it's a recap.

---

## Parameters whose primary semantic lives in report

### `report_template`

**Aliases:** `template`, `report_skeleton`
**Definition:** A markdown skeleton (or path to one) defining the report's exact section ordering and headers.
**Stages:** report (consumed).
**Depth:** outer.
**Type:** `source_ref` — file path (`file_type ∈ {.md}`) or inline markdown.
**Default:** the command-specific Output Format section of the command prompt (e.g. `critique.md`'s `# Critique: …` skeleton, `worktree-task-agent.md`'s `### Run Summary` / `### Worktree Results` / etc.).

**Example:**

```
{report_template} = file:./templates/security-review-report.md
```

### `report_destination`

**Aliases:** `report_to`, `report_out`
**Definition:** Where the rendered report goes.
**Stages:** report (applied).
**Depth:** outer.
**Type:** enum `chat | file | both`. When `file` or `both`, requires a destination path (typically derived: `<save_path>.report.md` or `./.ai-coding-artifacts/<run-id>.md`).
**Default:** `chat`.

**Example:**

```
{report_destination} = both
{report_destination} = file
```

---

## Parameters consumed in report (canonical homes elsewhere)

| Parameter             | Home    | What report does with it                                                  |
| --------------------- | ------- | ------------------------------------------------------------------------- |
| `verbosity`           | input   | controls section depth: `silent` (1 line) → `full` (every finding, every log) |
| `require_diff`        | input   | when true, embeds the per-slot `git diff` block                          |
| `include_terminal_log`| input   | when truthy, appends slot log tails of the requested length              |
| `output_format`       | input   | governs the *serialization* of the file written to `report_destination` (markdown / json / diff / raw) |
| `severity_scale`      | evaluate | drives the per-severity bucket ordering ("Critical", "Major", "Minor", "Nit") |
| `convergence_record`  | evaluate | splits "Findings" from "Divergent Findings" sections                    |
| `selection_rationale` | select  | rendered as "Merge Recommendation" / "Selection" section                |
| `persistence_record`  | persist | rendered as the "Persistence" / "Outcome" section                       |
| `slot_artifact`, `slot_log_tail`, `slot_test_exit_code` | execute | embedded per-slot when verbosity allows |

---

## Verbosity contract

`verbosity` is the master report dial. The canonical mapping:

| verbosity   | Report shape                                                                              |
| ----------- | ----------------------------------------------------------------------------------------- |
| `silent`    | single line: "done — N succeeded, M failed, K merged" (or the error)                     |
| `summary`   | Run Summary section only; no per-slot detail                                              |
| `normal`    | Run Summary + per-slot Status + Diff (when `require_diff`) + final recommendation       |
| `full`      | Everything above + per-slot logs (`include_terminal_log = true`) + every divergent finding |

Per-stage parameter interactions:
   - `verbosity = silent` overrides `require_diff = true` (no diff in a one-liner).
   - `verbosity = full` implies `include_terminal_log = true` if unset.

---

## Report sections — canonical ordering

Most commands' Output Format sections map cleanly onto the per-stage outputs report receives:

1. **Run Summary** — from input + plan params (resolved task, parallelism, model, base branch) + execute stats (succeeded / failed / incomplete counts).
2. **Per-Slot / Per-Candidate Results** — from execute (`slot_status`, `slot_artifact`, `slot_log_tail`) + evaluate (`slot_evaluation`).
3. **Findings / Critique** (analysis commands) — from evaluate (`slot_evaluation.findings`, bucketed by `severity_scale`) + `convergence_record`.
4. **Merge / Selection Recommendation** — from select (`selection_rationale`).
5. **Persistence / Outcome** — from persist (`persistence_record`).
6. **Open Questions / Gaps** — from any stage that flagged ambiguity (e.g. `critique.md`: "When `{context}` is ambiguous … the report names the gap explicitly in an Open Questions section instead of guessing.").
7. **Merge Prompt** (interactive mode only) — solicits the next user action; technically a fragment of select's interactive contract, rendered by report.

---

## Cross-stage notes

- **Report is non-authoritative.** If a fact in the report disagrees with the underlying stage output, the stage output wins. Report MAY truncate (per `worktree-task-agent.md`: "truncated above ~400 lines with `... (truncated, K lines omitted)` when oversized") but MUST NOT silently rewrite values.
- **Inner vs. outer report scope.** Subagents typically emit a *structured* artifact (JSON-like fields), not a rendered report — the outer command renders. When subagents *do* emit reports (e.g. critique's per-run findings list), the outer renderer concatenates / merges them; their verbosity is decoupled.
- **Report and persist are the two stages most often confused.** Rule of thumb: if it leaves a file the user will edit / share / commit, it's persist. If it leaves a file the user will *read once and discard*, it's report. A test report on disk is a report-stage artifact; a generated source file is a persist-stage artifact.
- **Report has no `parallel` parameter.** Rendering is single-threaded and fast; the parallelism of upstream stages does not propagate here.
