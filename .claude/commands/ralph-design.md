# Ralph Design

## Task
Invoke `/ralph-design {domain}` to run the `designer` skill in step-by-step walkthrough mode: walk one trait's enumerated design walkthrough a step at a time, user-in-the-loop, with optional per-round fan-out to explore variants in parallel.

This command is a preset, not a second implementation. It pins the walkthrough motion and the interactive, write-to-disk defaults that make the loop useful out of the box; the skill owns the trait map, the knob inventory, the round vocabulary, the validation rules, and the output format.

## Preset
The command pins these skill knobs; any of them can be overridden inline on the invocation.

| Knob | Preset value | Why |
|---|---|---|
| `mode` | `walkthrough` | Pinned; the command exists to select this motion. Not overridable — use `/designer` for `propose`. |
| `traits` | `[declarative]` | The default trait this loop walks. Override with `traits=[deterministic]` or any other registered trait. |
| `approval` | `interactive` | The loop is user-in-the-loop by default: each round offers `accept` / `refine` / `fork` / `back` / `done`. |
| `stop_condition` | `user-signals-done` | The loop exits when the user chooses `done`. |
| `persistence` | `codebase` | The working artifact and its per-round snapshots are written to disk. Override with `persistence=chat` for a draft-only run. |

Everything else — `artifact_path`, `use_worktree`, `base_branch`, `worktree_name`, `fan_out`, `agent_model`, `max_iterations`, `depth`, `audience`, `deliverable_shape` — takes the skill's own default unless overridden.

## Parameters
- `{domain}` — the domain the artifact models, named in the user's own words (e.g., `feature flags`, `RBAC policies`, `CI pipelines`); required. Forwarded as the skill's `target`.
- Any additional `key=value` tokens are forwarded verbatim to the skill and validated there, overriding the preset above.

## Success Criteria
- [ ] The `designer` skill is read at its canonical `skills/designer/SKILL.md` path and invoked with `mode=walkthrough`, `target={domain}`, and the preset knobs above, with inline tokens overriding any preset other than `mode`.
- [ ] Round structure, principle selection, the `accept` / `refine` / `fork` / `back` / `done` vocabulary, snapshots, worktree handling, stop-condition evaluation, and report shape all come from the skill; this command contributes only the parsed `{domain}` and the preset.
- [ ] An invocation with an empty `{domain}` aborts with an explanatory error before the skill is invoked, and produces zero filesystem side effects.
- [ ] Overriding a preset with an inapplicable value (for example `approval=non-interactive` while leaving `stop_condition=user-signals-done`) surfaces as the skill's own validation error, not a second set of checks here.

## Guardrails
- MUST delegate to the `designer` skill; MUST NOT reimplement, inline, or paraphrase the skill's knob inventory, round vocabulary, workflow, validation rules, or output format.
- MUST let inline `key=value` tokens override every preset except `mode`, which is pinned.
- MUST NOT select the trait by file path. The retired `{design_skill}` parameter is replaced by the skill's `traits` knob: pass `traits=[deterministic]`, not a path to a trait card.
- Scope: parse a domain and dispatch it to the `designer` skill in `walkthrough` mode with interactive, write-to-disk defaults. Out of scope: composing multiple traits in one loop (use `/designer` for that), generating downstream code, publishing the artifact, and merging the skill's worktree branch.

## Workflow
1. Parse the invocation: collect any `key=value` tokens; the remaining free-form text is `{domain}`. Abort with an explanatory error if `{domain}` is empty.
2. Resolve the preset above, applying inline overrides for every knob except `mode`.
3. Invoke the `designer` skill with `mode=walkthrough target={domain}` plus the resolved knobs.
4. Emit the skill's report unchanged.

## Choosing a Trait
Registered traits live in the skill's `## Trait Map`, next to the trait cards under `skills/designer/traits/`. Pass one with `traits=[<name>]`; no change to this command is needed when a trait is added or removed.
