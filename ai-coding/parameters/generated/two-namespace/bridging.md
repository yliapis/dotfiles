# Cross-Namespace Bridging

This file is the catalogue of how every parameter in this ontology is
**read on the opposite side** of the command-vs-skill divide. It is the
single index a reader can scan to answer two questions:

1. "I see this command parameter — what is the skill-side equivalent (if
   any)?"
2. "I see this skill parameter — what does it mean in a command context (if
   anything)?"

Where a parameter is genuinely one-sided, the entry says so explicitly and
gives the reason. Where a parameter has a meaningful counterpart, the entry
links to it. This is what the [README](./README.md) calls "bridging notes"
— short cross-references that prevent the two-namespace split from
hiding genuinely cross-cutting concepts.

> See also: [`shared-core.md`](./shared-core.md) for the canonical
> definitions of cross-namespace params, [`command-params.md`](./command-params.md)
> for command-only params, [`skill-params.md`](./skill-params.md) for
> skill-only params, [`overrides.md`](./overrides.md) for subagent
> re-bindings.

---

## 1. Shared-core parameters (the lossless bridge)

These parameters live in shared-core precisely because they have meaningful
readings on both sides. Each row reproduces the bridging note from
[`shared-core.md`](./shared-core.md) in compact form.

| parameter | command-side reading | skill-side reading |
|---|---|---|
| `task` | the imperative work the agent must complete (`worktree-task-agent.md` `{task}`) | the kind of task that activates the skill (encoded in `description`) |
| `input` | text following the slash-command (`meta-prompt.md` `{input}`) | n/a — skills read parent context, not a discrete `input` |
| `context` | explicit param: file / dir / url / inline (`critique.md` `{context}`) | implicit — the file or commit under work at activation |
| `file` | input source or output destination | the file under edit |
| `directory` | bulk input or output root | scope hint ("applies to files under X") |
| `glob` | multi-file input selector | applicability expressed as a glob |
| `url` | fetched and treated as `{context}` | rarely consumed; usually cited under `references` |
| `inline` | inline `{context}` or `{criteria}` | the snippet the user just pasted |
| `format` | governs parsing and rendering | declares the shape of `hand_off` content |
| `save_path` | where the produced artifact is written | where the skill's hand-off is saved (usually n/a) |
| `output_format` | the literal `## Output Format` section | the `hand_off` schema |
| `criteria` | explicit rubric for `critique.md`-style commands | implicit rubric baked into the skill body |
| `guardrails` | explicit `## Guardrails` section | MUST / MUST NOT clauses embedded in the body |
| `stop_condition` | explicit completion predicate | implicit — "trigger no longer applies" |
| `test_command` | shell command run inside the execution context | usually a verify step inside the skill's `## Workflow` |
| `file_type` | validates input/output paths against extension whitelist | declares the file kinds the skill governs via `applies_to_artifacts` |
| `int_range` | bounds integer params like `{parallelism}`, `{depth}` | bounds skill params like `precedence` (rare) |
| `verbosity` | governs report detail (concise / normal / verbose) | governs how chatty the skill is in its response |

---

## 2. Command-only parameters (skill-side: usually "consult parent")

These parameters exist only in command contexts. The right-hand column
answers "what does this look like from a skill's perspective?" — almost
always "n/a; the skill cannot set this; if a skill needs to influence it,
the skill MUST hand off to a command that does set it."

| parameter | skill-side reading |
|---|---|
| `parallelism` | n/a; consult parent. A skill that wants concurrent enforcement must hand off to a command. |
| `n_candidates` | n/a; a skill produces a single deterministic output per activation. |
| `num_experiments` | n/a; same reason as `n_candidates`. |
| `num_partitions` | n/a; consult parent. |
| `subagent_type` | n/a; skills cannot spawn subagents. |
| `subagent_model` | n/a; consult parent. Skills are model-agnostic. |
| `subagent_prompt` | n/a; the skill's body IS its prompt. See `skill-params.md` → `description`. |
| `subagent_constraints` | implicitly fulfilled by the skill's `## Guardrails`. |
| `depth` | n/a; skills do not orchestrate subagents. |
| `fan_out` | n/a. |
| `model` | n/a; the active model is whatever model the parent agent is running on. |
| `focus_hints` | n/a; the skill's `description` + `decision_framework` already encode its angle. |
| `seed` | n/a. |
| `temperature` | n/a; the parent agent's sampling temperature governs the skill's invocation. |
| `selection_mode` | n/a; skills produce a single output deterministically. |
| `min_successes` | n/a. |
| `ranker` | n/a; a skill CAN be invoked as a ranker but is not parameterized as one itself. |
| `aggregator` | n/a; same as `ranker`. |
| `compare_against` | a skill's `references` list can serve as comparison material, but not as a parameter. |
| `isolation` | n/a; a skill can declare in its body that it MUST be invoked under isolation but cannot set the isolation mode itself. |
| `base_branch` | n/a; consult parent. |
| `worktree_name` | n/a. |
| `worktree_root` | n/a. |
| `cleanup_policy` | n/a. |
| `auto_save_winner` | n/a. |
| `merge_mode` | n/a. |
| `merge_count` | n/a. |
| `delete_worktree` | n/a. |
| `timeout` | n/a. |
| `relaunch_on_hang_after` | n/a. |
| `retry_policy` | n/a. |
| `hang_policy` | n/a. |
| `require_diff` | n/a. |
| `include_terminal_log` | n/a. |
| `test_command_per_worker` | n/a. |

---

## 3. Skill-only parameters (command-side: usually "Workflow / Output Format")

These parameters exist only in skill contexts. The right-hand column
answers "what does this look like from a command's perspective?" — usually
"the command's `## Workflow`, `## Output Format`, or `## Guardrails` body
plays a similar role, but is not formally factored out as a parameter."

| parameter | command-side reading |
|---|---|
| `name` | a command's identifier is its file path / slash-command name, not a frontmatter `name`. |
| `description` | a command's `## Task` statement plays a similar role but is consumed only after explicit invocation. |
| `license` | commands in this repo do not declare a per-artifact license. |
| `version` | commands have no version field; revision is tracked via git history. |
| `frontmatter_keys` | commands have no formal frontmatter schema. |
| `activation_trigger` | a command has no trigger — it is invoked explicitly. |
| `applicability_scope` | analogous to a command's `Scope:` line in `## Guardrails`. |
| `precondition` | analogous to a command's "Workflow → Resolve / Validate" step. |
| `trigger_keywords` | a command's slash-name is its only routing keyword. |
| `negative_trigger` | analogous to a command's `Scope: out of scope` clause. |
| `mandate_level` | commands are implicitly `required` within their invocation; there is no `recommendation` mode. |
| `hand_off` | the command's `## Output Format` section. |
| `delegation_mode` | commands always run as their own agent invocation; closest analog is `subagent_type`. |
| `applies_to_artifacts` | a command's `{file_type}` / `{glob}` parameters serve the parallel role. |
| `co_skills` | a command may invoke other commands but does not list them in metadata. |
| `precedence` | commands do not compete (the user picks one explicitly). |
| `examples` | a command's `## Output Format` section often includes an example; `meta-prompt.md` goes further with `## Help Message`. |
| `decision_framework` | a command's `## Workflow` steps already encode branching. |
| `references` | a command may cite references inline; no formal field. |
| `quality_checks` | a command's `## Success Criteria` plays the same role. |
| `decomposition_pattern` | a command's `## Workflow` is always a numbered linear sequence in today's format. |

---

## 4. Quick lookup: name collisions

A handful of names collide across namespaces with subtly different meanings.
Reading them through the bridge:

| collision | command meaning | skill meaning | bridge |
|---|---|---|---|
| `task` | the work to do | the kind of work that activates the skill | shared-core; bridging note resolves both. |
| `criteria` | explicit rubric | implicit body-baked rubric | shared-core. |
| `guardrails` | explicit section | embedded MUST clauses | shared-core. |
| `model` | the parent agent's LLM | n/a; skills are model-agnostic | command-only. |
| `output_format` | `## Output Format` section | `hand_off` schema | shared-core. |
| `description` | n/a | activation contract + summary | skill-only. |
| `name` | the file path / slash-name (implicit) | frontmatter id | skill-only. |
| `examples` | inline in Output Format | dedicated `## Examples` section | skill-only. |

When in doubt, the canonical home of a name is wherever its definition has
the most parameters and the deepest constraint surface. `task` lives in
shared-core because both readings constrain it; `model` lives in command-
params because only commands set it; `hand_off` lives in skill-params
because only skills declare it.

---

## 5. Anti-bridges (deliberately one-sided)

Some axes are deliberately one-sided and **should not** be bridged, even
though a naive reader might want to. Documenting these prevents future
authors from synthesizing fake equivalents.

- **`parallelism` ↔ skill-side concurrent activation:** A skill cannot be
  "activated in parallel" against itself — it activates once per context.
  The parent agent may consult multiple skills in parallel, but that is a
  routing decision, not a skill parameter.
- **`subagent_*` ↔ skill-side delegation:** `delegation_mode` covers WHO
  consumes the skill (inline-guidance vs. sub-agent vs. tool-execution),
  but does not parameterize how subagents are spawned, sized, or
  diversified. That remains command-only.
- **`merge_mode` ↔ skill-side application:** A skill's hand-off is always
  "applied" by the parent agent; there is no skill-side merge concept.
- **`auto_save_winner` ↔ skill-side persistence:** A skill that produces
  an artifact (like a commit message) hands it off; persistence is the
  parent's responsibility, not a skill parameter.
- **`license` ↔ command-side licensing:** Commands inherit the repo's
  license; there is intentionally no per-command license field.
