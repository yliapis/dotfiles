# Concern: Task / Intent

> **Responsibility:** Declare *what the agent is supposed to accomplish*. Every prompt has at least one parameter from this concern, either named `task` (an imperative), `input` (raw user text the prompt must reshape into a task), or `context` (an artifact the task operates on).
>
> **Primary parameters:** `task`, `input`, `context`

## Why this concern exists

The Task concern owns the *verb* of an invocation. Other concerns answer *how many*, *with which model*, *under what constraints*, *and where the output goes*, but they all presuppose that the agent already knows *what it's trying to do*. Separating "what" from "how" is what makes the rest of the ontology composable: every command picks exactly one Task-shape (a single `task`, raw `input`, or a referenced `context` artifact) and then layers other concerns on top.

The three primaries are deliberately *not* a free-text catch-all. They model three distinct relationships between the user's words and the agent's plan:

- `task` — the user has stated the goal as an imperative the agent must execute.
- `input` — the user has handed the agent free-form text whose *first job* is to be classified or reshaped (HELP vs CREATE vs REFINE in `/meta-prompt`).
- `context` — the user has handed the agent an *artifact under analysis*; the verb is implicit ("analyze") and the artifact is the noun.

A command that mixes two of these (e.g. a `task` over a `context`) declares both, and downstream concerns (selection, reporting) reference both unambiguously.

## Parameters

### `task`

**Aliases:** —
**Definition:** The imperative goal the agent must complete end-to-end during this invocation.
**Type:** `string` (free-text natural language; may include markdown).
**Default:** `required`.

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | Required free-text following the slash command. The full goal of the run. |
| **subagent** | Forwarded verbatim to each spawned child unless the parent slices it (e.g. per-partition sub-tasks). When the parent slices, each child receives a *narrowed* `task` and the parent records the slicing rule in its report. |
| **skill** | Skills do not own `task`; they reference the calling command's `task` to decide whether the skill applies (the trigger description matches against `task` intent). |

**Cross-refs:**

- [`stop_condition` (constraints.md)](./constraints.md#stop_condition) — the explicit "done" condition layered on top of the implicit "task done".
- [`focus_hints` (models.md)](./models.md#focus_hints) — per-candidate angles that *narrow* the task differently across replicas.
- [`subagent_prompt` (subagent-tree.md)](./subagent-tree.md#subagent_prompt) — the literal prompt text a parent feeds to a child; usually derived from `task` but may be augmented.

**Example:** `/worktree-task-agent task="Refactor the auth middleware to use the new SessionStore API and update affected tests."` — the entire imperative is supplied as `task`; child agents inherit it unmodified.

---

### `input`

**Aliases:** `raw_input`, `user_text`
**Definition:** Raw user-supplied text whose first job is to be classified or reshaped into a task, rather than executed directly.
**Type:** `string` (may be empty).
**Default:** required for commands that treat user text as data (`/meta-prompt`); not applicable elsewhere.

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | Everything the user typed after the slash command. May be empty (triggers HELP mode in `/meta-prompt`). |
| **subagent** | Not typically forwarded; the parent resolves `input` into a concrete `task` before spawning children. If forwarded, it represents the parent's own raw text, not a child instruction. |
| **skill** | Skills referencing `input` treat it as a pre-classification blob; classification logic lives in the calling command's workflow, not the skill. |

**Cross-refs:**

- [`task` (this file)](#task) — the post-classification, post-reshape form of `input`.
- [`save_path` (io.md)](./io.md#save_path) — `/meta-prompt` infers `save_path` *from* `input` ("save this as /foo").

**Example:** `/meta-prompt save as /pr-review: review a PR for security issues` — `input` is the entire string after `/meta-prompt`; the command parses it for save intent and a task description.

---

### `context`

**Aliases:** `artifact`, `subject`
**Definition:** The artifact the task operates on (a file, directory, URL, inline blob), supplied as data rather than as an instruction.
**Type:** `string | path | url | inline-blob` (resolved by `io.md` resolvers).
**Default:** `required` for commands whose verb is implicit-over-an-artifact (`/critique`); not applicable for commands that supply both a verb and a target inline.

**Multi-depth:**

| Layer | Semantics |
|---|---|
| **command** | A reference (path / URL) or inline blob the command analyzes. The command resolves it via `io.md` and records what was loaded and what was skipped. |
| **subagent** | Each child analyzing the same `context` receives it by reference (path) when possible; large blobs are passed by reference to keep child token budgets small. |
| **skill** | Skills reference `context` to decide their own scope (e.g. a "static analysis" skill scopes its lints to files inside `context`). |

**Cross-refs:**

- [`file` / `directory` / `glob` / `url` / `inline` (io.md)](./io.md#file) — the resolver families that materialize `context` into bytes.
- [`format` (io.md)](./io.md#format) — declared or inferred MIME-style category for the resolved `context`.
- [`criteria` (constraints.md)](./constraints.md#criteria) — the judgment criteria applied *to* `context`.
- [`file_type` (constraints.md)](./constraints.md#file_type) — extension restriction enforced on `context` resolution.

**Example:** `/critique context=./src/auth/ criteria=./criteria/security.md` — `context` resolves to a directory, which `io.md`'s `directory` resolver walks; the criteria from `constraints.md` are applied to it.
