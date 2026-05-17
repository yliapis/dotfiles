# Task / Intent (Category A)

Covers parameters that describe *what work is to be performed*, *what raw input the user supplied*, and *what artifact the work operates on*.

Under the flat-shared-dictionary angle, every multi-depth meaning of `task`, `input`, and `context` gets its own canonical name (one definition per name). The base-inventory shorthand `task`, `input`, `context` is **not** a valid canonical name in this ontology — pick the layer-specific variant.

---

## `command_task`

**Aliases (deprecated under this angle):** `task` (when used at the slash-command / orchestrator layer).
**Definition:** The work the top-level slash command is responsible for completing end-to-end.
**Type:** free-form string (one paragraph, imperative voice). Often resolved from `command_input` plus the command's own `## Task` section.
**Default:** required for every command.
**Rename rationale (multi-depth):** the same English word `task` is used inside subagent specs and inside skill triggers; collapsing them caused real ambiguity in `worktree-task-agent.md` (where `{task}` is *the shared command task each subagent must complete*, not a per-slot task). Splitting forces the author to say which layer they mean.
**Consumed by:** every command. Examples: `meta-prompt`'s "produce a structured task prompt", `critique`'s "produce a structured report of findings", `worktree-task-agent`'s "launch agents to complete X".
**Example:**

```
command_task: "Critically analyze {command_context} against {command_criteria} and produce a structured report of findings."
```

---

## `subagent_task`

**Aliases (deprecated under this angle):** `task` (when used at the subagent / slot layer), `slot_task`, `agent_task`.
**Definition:** The work assigned to *one* subagent slot inside a fan-out, which is usually `command_task` broadcast, sliced, or specialized per slot.
**Type:** free-form string per slot, OR a string that broadcasts to every slot.
**Default:** when omitted, broadcast `command_task` verbatim to every slot.
**Rename rationale (multi-depth):** the subagent layer is the level where `focus_hints`, `subagent_model`, and `subagent_prompt` attach. Treating "what the slot does" as a distinct parameter from `command_task` lets you write `subagent_task[i] = command_task + focus_hints[i]` cleanly.
**Consumed by:** the fan-out workflow inside `worktree-task-agent.md` (per-slot agent instructions) and any future `refine-best-of-n`.
**Example:**

```
command_task: "Refine the prompt at {command_context}."
subagent_task[0]: "Refine the prompt at {command_context}. Focus angle: tighten guardrails."
subagent_task[1]: "Refine the prompt at {command_context}. Focus angle: clarify parameters."
```

---

## `skill_trigger`

**Aliases (deprecated under this angle):** SKILL frontmatter `description`, `task` (when describing what activates a skill), `skill_when`.
**Definition:** The natural-language predicate that decides whether a skill loads and applies on this turn.
**Type:** free-form string (one to three sentences). Lives in skill frontmatter.
**Default:** required for every skill.
**Rename rationale (multi-depth):** skills do not have an executable `task`; they have a *trigger condition* the orchestrator pattern-matches against the current request. Reusing `task` here mixed up "what to do" with "when to do it".
**Consumed by:** every SKILL.md frontmatter `description` field. Examples: `conventional-commits` triggers on "user asks to commit changes"; `minimal-diffs` triggers on "user asks to edit, modify, refactor, or fix any file".
**Example:**

```
skill_trigger: "Format git commit messages following Conventional Commits 1.0.0 specification. Use when the user asks to commit changes."
```

---

## `command_input`

**Aliases (deprecated under this angle):** `input` (when the user payload is for the slash command itself).
**Definition:** The free-form text the user typed after the slash command invocation, before any structured parsing.
**Type:** raw string. May be empty.
**Default:** empty string when the command was invoked with no payload.
**Rename rationale (multi-depth):** `input` was also used informally for "what we pass into a subagent"; splitting the names removes ambiguity. `command_input` is always the *user's* string, never a downstream relay.
**Consumed by:** `meta-prompt` (`{input}` is everything after `/meta-prompt`). Any command that branches on user payload.
**Example:**

```
User types: /meta-prompt save as /pr-review: review a PR for security issues
command_input = "save as /pr-review: review a PR for security issues"
```

---

## `subagent_input`

**Aliases (deprecated under this angle):** `input` (when relayed into a subagent), `slot_input`.
**Definition:** The free-form text passed into one subagent slot at launch; typically derived from `command_input` and per-slot overrides.
**Type:** string per slot, or scalar broadcast.
**Default:** when omitted, broadcast `command_input` verbatim to every slot.
**Rename rationale (multi-depth):** the subagent receives an *already-resolved* payload that may differ from the raw `command_input` (e.g., trimmed, augmented with `focus_hints`, or replaced wholesale by an aggregator). Distinct name = no confusion about which string is in scope.
**Consumed by:** the fan-out launcher in `worktree-task-agent.md`; future `refine-best-of-n`.
**Example:**

```
command_input: "review this PR"
subagent_input[0]: "review this PR. Angle: security."
subagent_input[1]: "review this PR. Angle: performance."
```

---

## `command_context`

**Aliases (deprecated under this angle):** `context` (when referring to the artifact the slash command operates on).
**Definition:** The artifact (file, directory, URL, or inline payload) the top-level command reads and analyzes or transforms.
**Type:** one of `file` | `directory` | `glob` | `url` | `inline` (see `io.md` for shape variants).
**Default:** required when the command's job is to operate on an artifact (e.g., `critique`); optional or omitted for commands whose work is purely synthesis from `command_input` (e.g., `meta-prompt` in CREATE mode).
**Rename rationale (multi-depth):** when a command fans out, each subagent slot might operate on a *slice* of `command_context` (per-partition slice, per-file slice). Distinct names keep "what the user pointed at" separate from "what slot i actually loaded".
**Consumed by:** `critique` (`{context}`); any reader-style command.
**Example:**

```
command_context: file:./src/auth/login.ts
command_context: directory:./docs/rfcs
command_context: inline:"function add(a, b) { return a + b }"
```

---

## `subagent_context`

**Aliases (deprecated under this angle):** `context` (when referring to a single slot's artifact), `slot_context`, `partition_context`.
**Definition:** The artifact a single subagent slot operates on; may be the full `command_context` broadcast, or a slice produced by a partitioning step.
**Type:** same shape options as `command_context` (`file` | `directory` | `glob` | `url` | `inline`), per slot.
**Default:** when omitted, broadcast `command_context` verbatim to every slot.
**Rename rationale (multi-depth):** partitioned fan-outs (`outer_partitions > 1`) explicitly need a way to say "slot 3 only sees these 4 files of the input directory". Without a distinct name, the partitioning contract is unstateable.
**Consumed by:** any command that combines `outer_k > 1` with partitioned input. Worked through in `trajectory.md` (open question on `num_partitions` semantics).
**Example:**

```
command_context: directory:./src
outer_k: 4
outer_partitions: 2
subagent_context[0]: glob:./src/auth/**
subagent_context[1]: glob:./src/payments/**
subagent_context[2]: glob:./src/auth/**      # second replicate of partition 0
subagent_context[3]: glob:./src/payments/**  # second replicate of partition 1
```
