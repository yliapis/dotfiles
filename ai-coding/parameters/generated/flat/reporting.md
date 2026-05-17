# Reporting (Category K)

Covers *how much* the command says in its final reply, *what raw evidence* it includes, and *what shape* the per-slot report takes.

`output_format` (in `io.md`) sets the overall artifact shape; the parameters here govern the *content depth* of the reply at each layer.

Under the flat angle, `verbosity` splits by layer so a quiet command can still ask its subagents to be verbose internally (for log capture) without polluting the user-facing reply.

---

## `command_verbosity`

**Aliases (deprecated under this angle):** `verbosity` (at the orchestrator layer), `reply_verbosity`.
**Definition:** Detail level of the orchestrator's final user-facing reply.
**Type:** enum: `quiet` | `normal` | `verbose`.
  - `quiet`: bottom-line only — selected artifact and 1-line rationale; no per-slot detail.
  - `normal`: bottom-line + per-slot summary (status, score, 1-2 sentences).
  - `verbose`: everything in `normal` plus full per-slot diff and terminal tail.
**Default:** `normal`.
**Rename rationale (multi-depth):** the orchestrator-layer verbosity is what the user *sees*; subagent-layer verbosity is what gets *captured* per slot. Decoupling them lets you set `command_verbosity: quiet` while still running `subagent_verbosity: verbose` for replayable logs.
**Consumed by:** every command's reporter; `critique` and `worktree-task-agent` currently behave as if it were `normal`.
**Example:**

```
command_verbosity: quiet      # bottom-line only
command_verbosity: verbose    # full diffs + logs in the reply
```

---

## `subagent_verbosity`

**Aliases (deprecated under this angle):** `verbosity` (at the slot layer), `agent_verbosity`.
**Definition:** Detail level the orchestrator demands from each subagent slot when it reports back.
**Type:** enum: `quiet` | `normal` | `verbose` per slot, OR scalar broadcast.
**Default:** `normal`.
**Rename rationale (multi-depth):** see `command_verbosity`.
**Consumed by:** subagent launcher / reporter contract; reserved.
**Example:**

```
subagent_verbosity: verbose      # capture full reasoning per slot
```

---

## `require_diff`

**Aliases:** `include_diff`, `diff_required`.
**Definition:** Whether the orchestrator MUST emit a fenced ` ```diff ` block per slot showing that slot's changes relative to `base_branch`.
**Type:** boolean.
**Default:** `true` for fan-out commands that produce code edits (matches `worktree-task-agent.md`); `false` for analysis-only commands like `critique`.
**Rename rationale (multi-depth):** layer-neutral. Introduced in `trajectory.md` as an explicit flag.
**Consumed by:** `worktree-task-agent` (implicitly `true`); future `refine-best-of-n`.
**Example:**

```
require_diff: true
```

---

## `include_terminal_log`

**Aliases:** `include_log`, `attach_tail`.
**Definition:** Whether the orchestrator MUST include a per-slot terminal-log tail in the report (for debugging tool failures, hangs, or test output).
**Type:** boolean, OR integer (number of lines to tail; `0` = none, `-1` = full log).
**Default:** `false` for successful slots; `true` (last 50 lines) for failed/incomplete slots.
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** `worktree-task-agent` reporter; future runners.
**Example:**

```
include_terminal_log: true       # always attach last 50 lines
include_terminal_log: 200        # last 200 lines per slot
include_terminal_log: -1         # full log per slot
```

---

## `severity_taxonomy`

**Aliases:** `severity_set`.
**Definition:** The ordered list of severity labels findings may carry; cross-command convention for the reporter.
**Type:** ordered list of strings. Default ordering is highest-severity first.
**Default:** `["critical", "major", "minor", "nit"]` (matches `critique.md`).
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** `critique` reporter; any future evaluation command.
**Example:**

```
severity_taxonomy: ["blocker", "major", "minor"]    # ship-gate audit
```

---

## `report_sections`

**Aliases:** `sections`.
**Definition:** Ordered list of named sections the reporter MUST render in the final reply; lets callers extend or trim the default structure without rewriting the command.
**Type:** ordered list of section identifiers; identifiers come from the command's `## Output Format`.
**Default:** the command-defined ordering (e.g., `critique.md` uses `[Summary, Findings, Divergent Findings, Open Questions]`).
**Rename rationale (multi-depth):** layer-neutral.
**Consumed by:** any reporter that supports section toggling.
**Example:**

```
report_sections: ["Summary", "Findings"]              # drop divergent + open questions
report_sections: ["Run Summary", "Worktree Results", "Merge Recommendation"]   # worktree-task-agent default minus the prompt
```
