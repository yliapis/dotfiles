# Parameter Ontology — Flat Shared Dictionary

**Angle:** flat shared dictionary (1 of 8). Single namespace, every parameter has exactly one canonical definition. When the same conceptual name has different meanings across layers, the name is **split** so each unique meaning gets a unique canonical name. Disambiguation is paid for once, in naming.

**Why this angle:** zero ambiguity. A reader who sees `subagent_test_command` in any command, skill, or trajectory note knows it refers to the per-slot pass/fail check inside one worktree, full stop — no namespace traversal, no contextual disambiguation. A grep for `outer_k` reliably finds every call site of the outer-layer replication count, even across commands that previously called it `{num_experiments}` or `{parallelism}` or `{n_candidates}`. Searchability and write-once-mean-once are the headline wins.

**What you pay for it:** more names to learn, combinatorial growth as layers proliferate, and inheritance contracts (e.g., "`subagent_task` defaults to `command_task`") have to be re-documented per parameter rather than implied structurally. See *Trade-offs vs. other angles* at the bottom of this file.

---

## File index

| File | Base category | Purpose |
|---|---|---|
| `task.md` | A. Task / Intent | What work is performed, what raw input the user gave, what artifact is operated on. |
| `io.md` | B. File I/O | Shape of inputs (file/dir/glob/url/inline), declared content formats, persistence paths. |
| `constraints.md` | C. Constraints | Judgment rubric, MUST/MUST NOT scope, done-when predicates, test commands, `int_range` and `file_type` formalisms. |
| `replication.md` | D. Replication / Parallelism | How many slots run, how concurrently, how they partition, how many must succeed. |
| `subagent-tree.md` | E. Subagent tree | Per-slot subagent type, prompt, operational constraints; nested fan-out depth/branching. |
| `models.md` | F. Models / Diversity | Per-layer model choice; diversity dials (focus hints, seeds, temperature). |
| `selection.md` | G. Selection / Aggregation | How the orchestrator picks, ranks, merges, or compares slot results. |
| `isolation.md` | H. Isolation / Workspace | Sandboxing mechanism, branch / worktree layout, cleanup policy. |
| `lifecycle.md` | I. Lifecycle / Persistence | Auto-save, merge mode, merge count, apply strategy, conflict policy. |
| `robustness.md` | J. Robustness / Recovery | Timeouts, hang policies, retry policies at each layer, failure classification. |
| `reporting.md` | K. Reporting | Per-layer verbosity, evidence inclusion, section / severity taxonomies. |

---

## Canonical rename map (multi-depth → flat)

Every base-inventory parameter whose meaning shifts across layers gets one canonical name per unique meaning. Aliased base names are listed in each parameter file under **Aliases (deprecated under this angle)** so migration is mechanical.

| Base name | Flat-angle canonical name(s) | Layer split |
|---|---|---|
| `task` | `command_task`, `subagent_task`, `skill_trigger` | orchestrator / per-slot / skill activation predicate |
| `input` | `command_input`, `subagent_input` | raw user payload / per-slot relayed payload |
| `context` | `command_context`, `subagent_context` | the artifact the command points at / the slice one slot loads |
| `criteria` | `command_criteria`, `finding_criterion` | the rubric (plural) / one tag on one finding (singular) |
| `stop_condition` | `command_stop_condition`, `subagent_stop_condition` | "the run is done" / "this slot is done" |
| `test_command` | `command_test_command`, `subagent_test_command` | post-aggregation check / per-slot check inside a worktree |
| `format` | `input_format`, `output_format` | shape of incoming bytes / shape of returned bytes |
| `save_path` | `command_save_path`, `subagent_save_path` | final user-facing write / per-slot intermediate write |
| `k` / `n_candidates` / `num_experiments` | `outer_k`, `inner_k` | top-level replication count / per-slot replication count |
| `parallel` / `parallelism` | `command_parallel`, `subagent_parallel` | orchestrator concurrency cap / per-slot concurrency cap |
| `num_partitions` | `outer_partitions` | only one layer is exercised today; prefixed for forward compatibility |
| `model` / `agent_model` | `command_model`, `subagent_model` | orchestrator's own model / per-slot model |
| `seed` | `command_seed`, `subagent_seed` | orchestrator RNG / per-slot model seed |
| `temperature` | `command_temperature`, `subagent_temperature` | orchestrator sampling / per-slot sampling |
| `timeout` | `command_timeout`, `subagent_timeout` | total wall-clock budget / per-slot budget |
| `retry_policy` | `command_retry_policy`, `subagent_retry_policy` | orchestrator retry / per-slot retry |
| `verbosity` | `command_verbosity`, `subagent_verbosity` | user-facing reply depth / per-slot captured depth |

Every other base-inventory parameter (`guardrails`, `selection_mode`, `ranker`, `aggregator`, `compare_against`, `isolation`, `base_branch`, `worktree_name`, `worktree_root`, `cleanup_policy`, `merge_mode`, `merge_count`, `auto_save_winner`, `relaunch_on_hang_after`, `hang_policy`, `require_diff`, `include_terminal_log`, `min_successes`, the I/O shape primitives, the `int_range` and `file_type` formalisms, etc.) is layer-neutral in current usage and keeps its short name.

**Rule for adding a new parameter under this angle:**
1. If the concept varies by layer, pick the layer prefix (`command_`, `subagent_`, `outer_`, `inner_`, `input_`, `output_`, etc.) up front. Document the unused layer variants too (e.g., reserve `inner_X` even if not yet consumed).
2. If the concept is layer-neutral, use the short name.
3. Never use a bare name (`task`, `model`, `criteria`, ...) inside this ontology — those are reserved as aliases that point at the canonical layer-specific names, to make grep / migration easy.

---

## Worked example 1 — `critique.md` rewritten against this ontology

**Original parameters** (from `ai-coding/plugins/ai-coding/commands/critique.md` lines 6–11):

> `{context}`, `{criteria}`, `{model}`, `{parallel}`, `{num_experiments}`

**Rewritten using flat-angle canonical names:**

```markdown
## Parameters
- `{command_context}` — the artifact to analyze (see `io.md` for shape options: `file` | `directory` | `url` | `inline`). Required. file_type: ["*"].
- `{command_criteria}` — the rubric to evaluate against (see `constraints.md`). Optional, default: inline:"clarity, correctness, completeness, robustness, reproducibility, idempotency, stable outputs across runs".
- `{subagent_model}` — model for each analysis run (see `models.md`). Optional, default: broadcasts `{command_model}` (the parent agent's model).
- `{command_parallel}` — max concurrent analysis threads (see `replication.md`). Optional, default: `1`. int_range: ">= 1".
- `{outer_k}` — number of independent analysis runs (see `replication.md`; renamed from `{num_experiments}`). Optional, default: `1`. int_range: ">= 1".

## Implicit ontology bindings (not user-settable; documented for the reader)
- output_format: report             # see io.md
- selection_mode: synthesize         # findings are merged across runs, not picked
- severity_taxonomy: ["critical", "major", "minor", "nit"]    # see reporting.md
- report_sections: ["Summary", "Findings", "Divergent Findings", "Open Questions"]
- finding_criterion: required on every emitted finding       # see constraints.md
```

**Effects of the rewrite:**
- `{model}` → `{subagent_model}`: makes explicit that this is the per-run (subagent-layer) model, not the parent orchestrator's model. The default sentence now says "broadcasts `{command_model}`" instead of "the parent agent's model", which is the same idea expressed in ontology terms.
- `{num_experiments}` → `{outer_k}`: aligns with `worktree-task-agent.md` and any future fan-out command, so the same word means the same thing across the repo.
- `{parallel}` → `{command_parallel}`: distinguishes it from a hypothetical `{subagent_parallel}` if a single analysis run ever fans out internally.
- `{criteria}` → `{command_criteria}` (the rubric set); the singular `{finding_criterion}` is reserved for the per-finding tag, removing the long-standing ambiguity in the success criterion "every finding names the specific criterion from `{criteria}` it relates to".

---

## Worked example 2 — `worktree-task-agent.md` rewritten against this ontology

**Original parameters** (from `ai-coding/plugins/ai-coding/commands/worktree-task-agent.md` lines 6–17):

> `{task}`, `{base_branch}`, `{worktree_name}`, `{delete_worktree}`, `{merge_mode}`, `{test_command}`, `{agent_model}`, `{parallelism}`, `{num_partitions}`, `{stop_condition}`

**Rewritten using flat-angle canonical names:**

```markdown
## Parameters
- `{command_task}` — the task each subagent must complete; required. (see `task.md`)
- `{base_branch}` — branch to fork worktrees from; optional, default: current branch. (see `isolation.md`)
- `{worktree_name}` — base name for worktree directory and branch; optional, default: kebab-case slug from `{command_task}`. (see `isolation.md`)
- `{delete_worktree}` — delete worktree after successful merge; optional, default: `true`. Prefer `{cleanup_policy}` for new commands. (see `isolation.md`)
- `{merge_mode}` — merge behavior after diffs are shown; optional, default: `interactive`. Allowed: `interactive` | `auto` | `dry_run`. (see `lifecycle.md`)
- `{subagent_test_command}` — shell command each subagent runs inside its worktree before the diff is presented; optional. Exit `0` = pass. (renamed from `{test_command}`; see `constraints.md`)
- `{subagent_model}` — model(s) for the worktree subagent(s); optional, default: broadcasts `{command_model}`. Scalar (broadcast) or list of length `{outer_k}` (positional). (renamed from `{agent_model}`; see `models.md`)
- `{outer_k}` — number of sibling worktrees to launch; optional, default: `1`. int_range: ">= 1". (renamed from `{parallelism}`; see `replication.md`)
- `{command_parallel}` — max concurrent worktrees at any moment; optional, default: equals `{outer_k}` (preserves today's "all launched together" behavior). MUST satisfy `command_parallel <= outer_k`. int_range: ">= 1". (separated out from `{parallelism}` so total count and execution cap can be set independently; see `replication.md`)
- `{outer_partitions}` — number of partitions over slots; optional, default: `1`. int_range: ">= 1". (renamed from `{num_partitions}`; see `replication.md`)
- `{subagent_stop_condition}` — per-slot completion predicate beyond "task implemented and verified"; optional. (renamed from `{stop_condition}`; see `constraints.md`)

## Implicit ontology bindings
- isolation: worktree                       # see isolation.md
- worktree_root: $HOME/.cursor/worktrees    # convention from the /worktree command
- cleanup_policy: derived from {delete_worktree}
- merge_count: one                          # current hard cap; see lifecycle.md
- apply_strategy: merge_no_ff               # current hard choice; see lifecycle.md
- on_merge_conflict: abort_and_report       # current hard policy; see lifecycle.md
- require_diff: true                        # see reporting.md
- subagent_type: agent                       # see subagent-tree.md
- subagent_constraints.file_scope: the slot's worktree path (one per slot)
- subagent_constraints.write_policy: scoped
```

**Effects of the rewrite:**
- `{task}` → `{command_task}`: makes the layer explicit. The original docstring says "the task each agent must complete" — which is *the command's* task, broadcast to every subagent — not a per-slot `{subagent_task}`. The rename surfaces that this is the orchestrator-level instruction.
- `{test_command}` → `{subagent_test_command}`: clarifies that this runs *inside each worktree*, not at the orchestrator level. A hypothetical future `{command_test_command}` (post-merge sanity check) wouldn't collide.
- `{agent_model}` → `{subagent_model}`: same canonical name as `critique.md`'s rewritten `{model}` → `{subagent_model}`, so the cross-command vocabulary now lines up.
- `{parallelism}` → `{outer_k}` + `{command_parallel}`: the original parameter conflated "total slots" and "max concurrent" because today they are equal. The flat angle splits them, which immediately enables a future "launch 8 but only 4 at once" configuration without API breakage.
- `{num_partitions}` → `{outer_partitions}`: the layer prefix is forward-looking — if a future command introduces nested fan-out partitioning, `{inner_partitions}` slots in cleanly.
- `{stop_condition}` → `{subagent_stop_condition}`: matches the per-slot scope already implied by the success criterion "each agent completes `{task}` (and `{stop_condition}` when provided) inside its own worktree".
- `{delete_worktree}` and `{merge_mode}` keep their names because they are layer-neutral. New commands SHOULD prefer `{cleanup_policy}` and `{merge_count}` over the boolean shortcut.

---

## How skills consume this ontology

Skills (`conventional-commits/SKILL.md`, `minimal-diffs/SKILL.md`) do not have parameter sections, but they still consume two ontology names:

- **`skill_trigger`** — the frontmatter `description` field that decides activation. Renamed from `task`/`description` so skills and commands speak the same vocabulary about "what causes work to happen". See `task.md`.
- **`guardrails`** — the MUST / MUST NOT / Scope content carried as the SKILL's body sections. Layer-neutral; same name as commands use. See `constraints.md`.

A future SKILL-frontmatter format extension could expose `output_format` (e.g., `output_format: diff` for code-style skills) and `severity_taxonomy` (for review-style skills) using the same canonical names — no special skill-side ontology needed.

---

## Trade-offs vs. other angles

The flat angle's design center is *one name → one meaning*. That single rule produces both its wins and its losses.

**Wins (vs. layered, tree-shaped, two-namespace):**
- A consumer can grep any canonical name and trust that every hit is the same concept. No path traversal (`command.task` vs. `subagent.task`), no namespace import statements.
- Migration from any of the existing command files is mechanical: replace `{X}` with the entry from the rename map and resolve which side of the split applies.
- Adding a new parameter rarely needs a meta-decision about where it lives.

**Losses (vs. layered / tree-shaped / two-namespace):**
- **Combinatorial growth at every layer.** Adding a third layer (e.g., `meta_orchestrator`) would require 17 more renames just to cover today's split parameters. A layered or tree-shaped ontology would absorb the new layer by adding one namespace.
- **Loses structural inheritance.** "`subagent_task` defaults to `command_task`" must be redocumented per parameter; nothing in the schema enforces or even hints at the pattern. The tree-shaped angle gets that inheritance for free.
- **Pressures readers to memorize prefixes.** A new contributor reading `subagent_temperature` has to know the `command_*`/`subagent_*` convention. Layered (`subagent.temperature`) makes the layer visually first-class without naming overhead.
