# Boolean Parameters

Every parameter whose **type** is a strict 2-valued boolean.

For grouping by meaning instead of type, see `semantic-aliases.md`.

## Type formalism: `bool`

- **Domain:** `{true, false}`.
- **Default coercion at the input boundary** (commands MUST normalize at
  parse time and use the canonical `true` / `false` everywhere internally):

  | Truthy inputs                                  | Falsy inputs                                  |
  |------------------------------------------------|-----------------------------------------------|
  | `true`, `True`, `TRUE`, `yes`, `y`, `on`, `1`  | `false`, `False`, `FALSE`, `no`, `n`, `off`, `0` |

  Any other string MUST be rejected with an explanatory error and no side
  effects. There is no implicit default to either pole.

- **Tri-state note:** when a third "unset / inherit" state is meaningful (e.g.
  `delete_worktree` inherits the command default if omitted), the type is
  `optional<bool>`. The catalog flags this where it applies.

---

## Catalog

Each entry: typed name; 1-sentence definition; default (or `required` /
`unset`); layer (command / subagent / skill); ≥1 example.

### `auto_save_winner`

- **Semantic aliases:** `auto_save_winner`, `persist_winner`.
- **Definition:** When the command produces multiple candidates and a clear
  winner is selected, persist the winner without asking.
- **Default:** `false` (always ask).
- **Layer:** command (`meta-prompt.md`, proposed in `trajectory.md`).
- **Example:**

  ```text
  /meta-prompt n_candidates=4 auto_save_winner=true save_path=.cursor/commands/foo.md
  ```

### `require_diff`

- **Semantic aliases:** `require_diff`, `emit_diff`.
- **Definition:** Emit a unified diff against the baseline alongside each
  candidate or result.
- **Default:** `false`.
- **Layer:** command (`meta-prompt.md` refine mode per `trajectory.md`,
  `worktree-task-agent.md` per-worktree report).
- **Example:**

  ```text
  /meta-prompt refine ./prompts/foo.md n_candidates=3 require_diff=true
  ```

### `include_terminal_log`

- **Semantic aliases:** `include_terminal_log`, `include_logs`,
  `attach_terminal`.
- **Definition:** Include captured terminal output in the reporting payload
  (alongside the diff and summary), instead of just summarizing it.
- **Default:** `false`.
- **Layer:** command (verbose reporting), subagent (when surfacing logs to
  its parent).
- **Example:**

  Useful when debugging a flaky `{test_command}` in
  `worktree-task-agent.md` — pair with `verbosity=verbose` from
  `enum-params.md`.

### `delete_worktree`

- **Semantic aliases:** `delete_worktree`, `cleanup_worktree`.
- **Definition:** Remove a worktree directory and delete its branch after a
  successful merge.
- **Default:** `true` (per `worktree-task-agent.md`).
- **Layer:** command.
- **Example:**

  ```text
  /worktree-task-agent delete_worktree=false task="..."
  ```

  Useful when the user wants to keep the worktree around for follow-up work
  even after a merge.

### `dry_run`

- **Semantic aliases:** `dry_run`, `plan_only`, `no_op`.
- **Definition:** Show what the command would do (parameters resolved, plan
  laid out, files that would change) without performing any side effect.
- **Default:** `false`.
- **Layer:** command.
- **Example:**

  ```text
  /worktree-task-agent dry_run=true parallelism=4 task="..."
  ```

  Prints the resolved plan; no worktrees are created.

### `force`

- **Semantic aliases:** `force`, `skip_confirmation`, `override`.
- **Definition:** Bypass non-destructive safety prompts. MUST NOT bypass
  guardrails marked `MUST NOT` in any command spec — those still apply.
- **Default:** `false`.
- **Layer:** command.
- **Example:**

  ```text
  /worktree-task-agent merge_mode=auto force=true task="..."
  ```

  Skips the "are you sure you want auto-merge?" confirmation; still enforces
  the merge guardrails (clean test, no conflicts) from
  `worktree-task-agent.md`.

### `interactive`

- **Semantic aliases:** `interactive`.
- **Definition:** Shorthand for `merge_mode=interactive` (or equivalent
  user-pick semantics) when a consumer takes a single bool instead of the
  full `merge_mode` enum from `enum-params.md`.
- **Default:** `true` (most consumers default to interactive).
- **Layer:** command.
- **Example:** `/some-command interactive=false` ⇒ auto behavior end-to-end.

### `verbose`

- **Semantic aliases:** `verbose`.
- **Definition:** Shorthand for `verbosity=verbose` when a consumer takes a
  single bool instead of the full `verbosity` enum.
- **Default:** `false`.
- **Layer:** command, subagent.
- **Example:** `/critique verbose=true context=README.md`.

### `quiet`

- **Semantic aliases:** `quiet`, `silent`.
- **Definition:** Shorthand for `verbosity=quiet`. Mutually exclusive with
  `verbose`; setting both MUST raise a validation error.
- **Default:** `false`.
- **Layer:** command, subagent.

---

## Mutually-exclusive sets

Some bool parameters are pairwise exclusive. Commands MUST validate at parse
time:

| Set A      | Set B      | Note                                         |
|------------|------------|----------------------------------------------|
| `verbose`  | `quiet`    | Use `verbosity` enum if both polarities needed. |
| `interactive=true` | `merge_mode=auto` | Resolve the enum form; reject conflict. |

---

## Cross-references

- For `optional<bool>` (inherit / unset semantics), see the **Tri-state note**
  above plus the parent enum in `enum-params.md` when one exists.
- For list-of-bool (per-candidate flags), see `list-params.md`.
- Semantic-name lookup: `semantic-aliases.md`.
