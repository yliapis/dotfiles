# Models / Diversity (Category F)

Covers the *which model runs where* parameters and the *how to vary across slots* parameters (focus hints, seeds, temperature). Diversity is the second axis of fan-out — alongside replication count — and every diversity dial gets a layer prefix here.

---

## `command_model`

**Aliases (deprecated under this angle):** `model` (when referring to the parent orchestrator's model).
**Definition:** The model running the slash command itself, i.e., the orchestrator that dispatches subagents, collects their results, and writes the final reply.
**Type:** model identifier string (e.g., `gpt-5`, `claude-4.7-opus`, `gemini-2.5-pro`).
**Default:** the host environment's currently active model (typically inherited from the chat session).
**Rename rationale (multi-depth):** `critique.md`'s `{model}` is actually used for *each analysis run* (subagent layer), not the orchestrator. Reusing `model` for both was a quiet source of confusion when defaults were inherited; the flat split eliminates it.
**Consumed by:** any command that explicitly distinguishes the orchestrator's model from the subagents' models. Not yet exercised by existing commands.
**Example:**

```
command_model: claude-4.7-opus
```

---

## `subagent_model`

**Aliases (deprecated under this angle):** `model` (when referring to per-slot models), `agent_model`, `slot_model`.
**Definition:** Model assigned to one subagent slot; may be a scalar broadcast to every slot, or a list of length `outer_k` mapped positionally.
**Type:** scalar model identifier string, OR a list of identifiers with length equal to `outer_k`. When `outer_partitions > 1`, the iterable-shape contract from `worktree-task-agent.md` applies: the list MUST be either a full iteration across all slots, or a correctly-sized slice across partitions.
**Default:** broadcast `command_model`.
**Rename rationale (multi-depth):** see `command_model`. Also unifies `worktree-task-agent.md`'s `{agent_model}` and `critique.md`'s `{model}` under one canonical name.
**Consumed by:** `critique` (renamed from `{model}`), `worktree-task-agent` (renamed from `{agent_model}`).
**Example:**

```
subagent_model: gpt-5                                                    # broadcast
subagent_model: ["gpt-5", "claude-4.7-opus", "gemini-2.5-pro", "gpt-5"]  # per-slot
```

---

## `focus_hints`

**Aliases:** `angle_hints`, `slot_hints`, `diversity_hints`.
**Definition:** Per-slot hint strings appended to `subagent_task` or `subagent_prompt` to steer each slot toward a *different angle* of the same task; primary mechanism for inducing diversity when `subagent_model` is uniform.
**Type:** list of strings with length equal to `outer_k`.
**Default:** unset (slots are interchangeable replicates).
**Rename rationale (multi-depth):** introduced in `trajectory.md` as a refinement-angle list. Always per-slot; the `_hints` suffix already implies plurality, no layer prefix needed.
**Consumed by:** future `refine-best-of-n` (`meta-prompt` companion); reserved by fan-out commands.
**Example:**

```
outer_k: 3
focus_hints: ["tighten guardrails", "clarify parameters", "improve workflow steps"]
```

---

## `command_seed`

**Aliases (deprecated under this angle):** `seed` (at the orchestrator layer).
**Definition:** Deterministic random seed for the orchestrator's *own* choices (e.g., shuffling slot order, randomized partition assignment).
**Type:** integer.
**Allowed values:** `int_range: ">= 0"`.
**Default:** unset (non-deterministic).
**Rename rationale (multi-depth):** the orchestrator's seed is independent from any subagent's seed; they govern different RNG streams.
**Consumed by:** any orchestrator that randomizes scheduling, partitioning, or tie-breaking.
**Example:**

```
command_seed: 42
```

---

## `subagent_seed`

**Aliases (deprecated under this angle):** `seed` (at the slot layer).
**Definition:** Per-slot model seed; passed through to the underlying inference call when supported.
**Type:** integer per slot, OR a scalar broadcast.
**Allowed values:** `int_range: ">= 0"` per entry.
**Default:** unset (model defaults).
**Rename rationale (multi-depth):** see `command_seed`. Also: per-slot seeds let you reproduce one specific candidate from a fan-out without re-running the whole batch.
**Consumed by:** subagent launcher; any model backend that exposes a seed.
**Example:**

```
outer_k: 4
subagent_seed: [101, 102, 103, 104]    # reproducible per slot
```

---

## `command_temperature`

**Aliases (deprecated under this angle):** `temperature` (at the orchestrator layer).
**Definition:** Sampling temperature for the orchestrator's *own* model calls (e.g., when it writes the final aggregation reply).
**Type:** float.
**Allowed values:** real interval `[0.0, 2.0]` (model-dependent upper bound; orchestrator clamps to model's actual max).
**Default:** model default (typically `1.0`).
**Rename rationale (multi-depth):** the orchestrator's temperature and a subagent's temperature affect different outputs (the final reply vs. each candidate); reusing one name made it impossible to dial them independently.
**Consumed by:** orchestrator inference calls.
**Example:**

```
command_temperature: 0.2     # tight final-reply formatting
```

---

## `subagent_temperature`

**Aliases (deprecated under this angle):** `temperature` (at the slot layer).
**Definition:** Sampling temperature applied per subagent slot; primary diversity dial when models are uniform.
**Type:** float per slot, OR a scalar broadcast.
**Allowed values:** real interval `[0.0, 2.0]` per entry.
**Default:** model default.
**Rename rationale (multi-depth):** see `command_temperature`.
**Consumed by:** subagent launcher; any model backend.
**Example:**

```
outer_k: 4
subagent_temperature: [0.2, 0.7, 1.0, 1.3]   # explicit diversity ladder
```
