# Subagent Tree (Category E)

Covers everything that describes the *shape* of the subagent fan-out: the kind of subagent dispatched, the per-slot prompt and operating constraints, and the depth/branching of nested fan-outs.

`subagent_model` is *also* a subagent-tree concept, but lives in `models.md` because that's where all model/diversity controls cluster. This file cross-references it.

---

## `subagent_type`

**Aliases:** `slot_type`, `agent_kind`.
**Definition:** The role/personality of the subagent dispatched into one slot; selects which tool inventory, system prompt, and default constraints apply.
**Type:** enum: `explore` | `shell` | `general_purpose` | `best_of_n_runner` | `critic` | `synthesizer` | `agent`.
**Default:** `general_purpose`.
**Rename rationale (multi-depth):** none — this is always a *per-slot* concept. The flat angle keeps the `subagent_` prefix for consistency with other slot-layer params.
**Consumed by:** `worktree-task-agent` implicitly launches `agent`-type subagents; future `refine-best-of-n` would set `critic` or `synthesizer` for selection slots.
**Example:**

```
subagent_type: agent              # broadcast: every slot is an editing agent
subagent_type: ["agent", "agent", "agent", "critic"]   # one critic among three agents
```

---

## `subagent_prompt`

**Aliases:** `slot_prompt`.
**Definition:** The *full* prompt template handed to one subagent slot at launch; usually composed from `subagent_task`, `subagent_input`, `subagent_context`, `focus_hints`, and `guardrails`.
**Type:** string per slot, OR a scalar broadcast to every slot.
**Default:** when unset, the orchestrator composes the prompt from the canonical layer parameters above using its built-in template.
**Rename rationale (multi-depth):** distinct from `subagent_input` (raw user payload relayed in) and `subagent_task` (the slot's job); `subagent_prompt` is the *fully assembled* string the model actually sees.
**Consumed by:** `worktree-task-agent` (the launcher builds this); future fan-out commands that want explicit per-slot prompts.
**Example:**

```
subagent_prompt[0]: "Complete `{subagent_task}`. Focus: {focus_hints[0]}. Constraints: {guardrails}."
```

---

## `subagent_constraints`

**Aliases:** `slot_constraints`.
**Definition:** Bundle of operational guardrails applied to a single subagent slot: tool allowlist, network policy, filesystem scope, write permission.
**Type:** structured object with sub-fields `tool_allowlist`, `network_policy`, `file_scope`, `write_policy`. See the four parameters below.
**Default:** when unset, the slot inherits the orchestrator's permissions verbatim.
**Rename rationale (multi-depth):** the orchestrator's own constraints are described in `guardrails`; `subagent_constraints` is the *narrower* per-slot version. Distinct names make the inheritance contract explicit.
**Consumed by:** `worktree-task-agent` (implicitly: each subagent is confined to its worktree); future sandboxed best-of-N runners.
**Example:**

```
subagent_constraints:
  tool_allowlist: ["Read", "Grep", "Glob"]
  network_policy: "denied"
  file_scope: "{subagent_context}"
  write_policy: "none"
```

---

## `tool_allowlist`

**Aliases:** `allowed_tools`.
**Definition:** Explicit list of tool names a subagent may invoke; calls to any other tool are rejected before dispatch.
**Type:** list of tool-name strings. Empty list means "no tools" (analysis-only). Sentinel `["*"]` means "all tools the orchestrator has".
**Default:** `["*"]`.
**Rename rationale (multi-depth):** layer-neutral conceptually but lives in subagent-tree because it is only meaningfully *set* at the subagent layer (the orchestrator's tools come from the host environment).
**Consumed by:** subagent launcher; `subagent_constraints.tool_allowlist`.
**Example:**

```
tool_allowlist: ["Read", "Grep", "Glob"]    # read-only critic
tool_allowlist: ["*"]                        # full editing agent
```

---

## `network_policy`

**Aliases:** `net_policy`.
**Definition:** Whether and how the subagent may make outbound network calls.
**Type:** enum: `denied` | `allowed` | `domain_allowlist`. When `domain_allowlist`, a sibling list field `network_allowlist: ["github.com", ...]` MUST be supplied.
**Default:** `denied` for `critic`/`explore` subagents; `allowed` for `agent`/`shell` subagents.
**Rename rationale (multi-depth):** none.
**Consumed by:** subagent launcher; `subagent_constraints.network_policy`.
**Example:**

```
network_policy: domain_allowlist
network_allowlist: ["registry.npmjs.org", "github.com"]
```

---

## `file_scope`

**Aliases:** `path_scope`, `fs_scope`.
**Definition:** Filesystem subtree a subagent is allowed to read and (subject to `write_policy`) write to. Reads or writes outside this subtree are rejected.
**Type:** glob expression or directory path. May be a list of multiple allowed roots.
**Default:** the slot's worktree path (when running inside `worktree-task-agent`); the workspace root otherwise.
**Rename rationale (multi-depth):** none.
**Consumed by:** subagent launcher; `subagent_constraints.file_scope`.
**Example:**

```
file_scope: "/Users/me/.cursor/worktrees/{worktree_name}-{slot_index}/**"
```

---

## `write_policy`

**Aliases:** `mutability`.
**Definition:** Whether and where a subagent may write to disk.
**Type:** enum: `none` | `scoped` | `unrestricted`. `scoped` confines writes to `file_scope`.
**Default:** `scoped`.
**Rename rationale (multi-depth):** none.
**Consumed by:** subagent launcher; `subagent_constraints.write_policy`.
**Example:**

```
write_policy: none           # read-only critic
write_policy: scoped         # editing agent confined to its worktree
```

---

## `depth`

**Aliases:** `tree_depth`, `levels`.
**Definition:** Number of nesting levels in the subagent tree (orchestrator counts as level 0). `depth = 1` is the standard one-level fan-out; `depth = 2` means subagents themselves fan out.
**Type:** integer.
**Allowed values:** `int_range: "[0, 4]"` (4 is a soft ceiling to keep traces tractable).
**Default:** `1`.
**Rename rationale (multi-depth):** none — this *describes* the multi-depth tree rather than being a parameter that varies by depth.
**Consumed by:** future nested fan-out runners; not yet exercised in this repo.
**Example:**

```
depth: 1     # orchestrator → slots
depth: 2     # orchestrator → slots → sub-slots
```

---

## `fan_out`

**Aliases:** `branching_factor`.
**Definition:** Number of children each parent in the subagent tree spawns. At level 1 this equals `outer_k`; at level 2 it equals `inner_k`.
**Type:** integer, or list of integers of length `depth` (one entry per level).
**Allowed values:** `int_range: ">= 1"` per entry.
**Default:** `1`.
**Rename rationale (multi-depth):** the scalar form is a uniform branching factor; the list form encodes the per-level shape. Distinct from `outer_k`/`inner_k`, which are the level-specific names — `fan_out` is the tree-level abstraction.
**Consumed by:** future nested fan-out runners.
**Example:**

```
depth: 2
fan_out: [4, 2]    # 4 outer slots, each with 2 inner slots = 8 leaves
```
