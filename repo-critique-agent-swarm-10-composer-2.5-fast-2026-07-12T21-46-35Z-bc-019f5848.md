# Critique: `yliapis/dotfiles` (whole repository)

**Criteria applied:** quality — clarity, correctness, completeness, robustness;
determinism — reproducibility, idempotency, stability (default `/critique` criteria)
**Runs:** 10 (parallel up to 7, model: `composer-2.5-fast`)
**Run id:** `bc-019f5848-6b71-73bb-a338-341cfa8c9a9f`
**Corpus:** repository root at commit `e1a908b` (captured 2026-07-12)

## Swarm Decision

- **Verdict:** `swarm` (adapted to read-only `/critique` replication; no worktrees)
- **Triggers fired:** T4 (independent exploration adds signal), T6 (user explicitly requested fan-out)
- **Pattern:** `none`
- **Rationale:** User invoked `/agent-swarm 100 /critique`; critique is read-only so orchestration mapped `{num_agents}=100` → `{num_experiments}` and bypassed `worktree-task`.

### Swarm Plan (adapted)

| Field | Requested | Executed |
|---|---|---|
| `num_agents` / `num_experiments` | 100 | 10 |
| `parallel_agents` / `parallel` | 100 (default) | 7 |
| `cost_cap` | unset | unset |
| Downscope reason | Search tier (>8) without `{cost_cap}`; full 100-run fan-out would exceed practical token/wall-clock bounds for a single cloud session | |

**Partitioning:** seven independent critique workers (bootstrap, sync, commands, skills, home-config, parameters wiki, plugin manifests) plus three orchestrator live verifications (`make help`, bash `source install.sh`, shell-extras sourcing).

## Summary

The repository's sync tooling (`scripts/sync-coding-tools.sh`) remains the best-engineered surface — strict mode, validation, audit logging — while the bootstrap path (`install.sh`, `refresh.sh`, Makefile) is still the weakest link: three documented entry points behave differently, errors are swallowed, and bash users hit zsh-only constructs. Counts across 10 runs: **2 critical**, **22 major**, **18 minor**, **8 nit**. The biggest concern is unchanged from prior critiques: `install.sh:126-128` uses zsh-only `print` while bash is explicitly supported and README documents `source install.sh`, breaking idempotency. A new critical-adjacent finding from this swarm: **`make help` fails on Linux without zsh** (`/usr/bin/env: 'zsh': No such file or directory`), reproduced live. Plugin/marketplace copy-mode sync deploys metadata without the `plugins/` tree, so marketplace-relative paths break after copy sync.

## Findings

### Critical

- **Determinism / idempotency** @ `install.sh:126-128` (2/10 runs)
  - Evidence: `print '' >> "$DEFAULT_PROFILE_FILE"` and `print '# dotfiles: shell extras…'`; bash-sourcing leaves marker unwritten
  - Rationale: README's documented `source install.sh` path under bash never writes the grep guard, so each re-run appends duplicate shell-extras blocks.

- **Correctness** @ `README.md:6` (2/10 runs)
  - Evidence: `source install.sh` — when sourced, `$0` is the parent shell name, not the script path, so `DOTFILES_ROOT` resolves from cwd
  - Rationale: Users not already `cd`'d into the repo get wrong paths or silent mis-installation.

### Major

- **Robustness** @ `install.sh:1-151` (2/10 runs)
  - Evidence: no `set -e`/`set -u`; unconditional `echo "dotfiles install complete"`
  - Rationale: Failed brew/apt/cp/installer steps are swallowed and the run still reports success.

- **Robustness** @ `install.sh:33-41` (2/10 runs)
  - Evidence: shell allowlist omits `/usr/bin/zsh`, `/usr/local/bin/bash`, etc.; uses login `$SHELL` not running shell
  - Rationale: Common Ubuntu/macOS paths are rejected despite claimed bash/zsh support.

- **Correctness** @ `install.sh:54` (1/10 runs)
  - Evidence: `sudo apt install --update curl` — `apt install` has no standard `--update` flag
  - Rationale: Linux curl bootstrap likely fails before the rest of install runs.

- **Correctness** @ `install.sh:83-84` vs `home-config/.shell_extras.sh:9-14` (2/10 runs)
  - Evidence: `darwin*) BREW_ROOT="/opt/homebrew"` only; `.shell_extras.sh` probes both `/opt/homebrew` and `/usr/local`
  - Rationale: Intel macOS Homebrew at `/usr/local` breaks post-install brew activation.

- **Completeness** @ `install.sh:1-151` vs `AGENTS.md:5-6` (2/10 runs)
  - Evidence: AGENTS.md says install mirrors ai-coding tooling; `install.sh` never calls `scripts/sync-coding-tools.sh`
  - Rationale: Documented setup contract is incomplete for a fresh install via the primary entry point.

- **Stability** @ `install.sh:95-100` vs `refresh.sh:17-18` (1/10 runs)
  - Evidence: install skips Brewfile on Linux unless `GUI_INSTALL=1`; refresh always runs `brew bundle`
  - Rationale: Install and refresh follow inconsistent platform gates.

- **Robustness** @ `refresh.sh:1-46` (1/10 runs)
  - Evidence: no strict mode; unconditional `brew upgrade` / `brew upgrade --cask --greedy`
  - Rationale: Headless Linux without Homebrew fails hard on refresh despite install skipping casks.

- **Robustness** @ `Makefile:34-36` / `scripts/sync-coding-tools.sh:1` (1/10 runs, live verified)
  - Evidence: `make help` invokes sync script; `/usr/bin/env: 'zsh': No such file or directory`
  - Rationale: Makefile help path requires zsh on PATH; default Linux cloud images lack it.

- **Determinism / reproducibility** @ `scripts/sync-coding-tools.sh:7-8,55-56,201-205` (2/10 runs)
  - Evidence: promises "deterministic snapshot" but rsync uses `-aL --itemize-changes` with no `--delete`
  - Rationale: Removed/renamed repo files persist at destinations; synced state depends on sync history.

- **Determinism / idempotency** @ `scripts/sync-coding-tools.sh:52,201-205` (2/10 runs)
  - Evidence: "Idempotent; safe to re-run" but copy mode never deletes destination-only artifacts
  - Rationale: Repeated copy sync converges to a superset, not an exact mirror of current repo.

- **Correctness** @ `scripts/sync-coding-tools.sh:346-356,372-376` (2/10 runs)
  - Evidence: `--unlink` copy branch requires `-f "$src" && -f "$dst"`; skills are directories synced at L205
  - Rationale: Copy-mode skill directories are never eligible for `--unlink` removal.

- **Completeness** @ `scripts/sync-coding-tools.sh:378-385` (2/10 runs)
  - Evidence: plugin unlink handles symlink case only; no copy-mode plugin tree removal
  - Rationale: `--unlink` after copy sync cannot reverse plugin artifacts.

- **Robustness** @ `scripts/sync-coding-tools.sh:1,32-33,111,284` (2/10 runs)
  - Evidence: `#!/usr/bin/env zsh`; zsh-only `${0:A}`, `print`, `(N)` globs throughout
  - Rationale: Script fails under bash or environments without zsh before any sync logic runs.

- **Correctness** @ `scripts/sync-coding-tools.sh:207-215` vs `ai-coding/marketplace.json:6-11` (1/10 runs)
  - Evidence: copy sync rsyncs marketplace JSON only, not `ai-coding/plugins/`; marketplace declares `pluginRoot: "./plugins"`
  - Rationale: After copy sync, marketplace-relative paths point at directories never deployed.

- **Determinism / reproducibility** @ `ai-coding/marketplace.json` triplicate copies (1/10 runs)
  - Evidence: three byte-identical marketplace JSON files; historical symlinks replaced by regular files
  - Rationale: Single source of truth lost; edits can update one copy and miss others.

- **Completeness** @ `ai-coding/parameters/coverage.md` (2/10 runs)
  - Evidence: indexes ten skills + four no-parameter skills; repo has eleven skills; `file-dump` absent
  - Rationale: Parameter wiki scope statement is false for at least one live skill with six declared parameters.

- **Correctness** @ `ai-coding/parameters/README.md:88` (1/10 runs)
  - Evidence: Quick map lists `trait_map` used by "designer, designer-controller"; controller has no `trait_map` knob
  - Rationale: Wiki misstates which artifacts expose the parameter.

- **Completeness** @ `ai-coding/skills/agent-swarm/SKILL.md#Parameters` (2/10 runs)
  - Evidence: Workflow step 6 passes "verbatim `{task}`" but `{task}` is undeclared in Parameters
  - Rationale: Primary work payload has no caller contract.

- **Cross-skill consistency** @ `agent-swarm` ↔ `worktree-task` per-partition dispatch (2/10 runs)
  - Evidence: parent expects partition-length `{agent_model}`; child requires length `{parallelism}` (= `{num_agents}`)
  - Rationale: `per-partition` model mix dispatch is ambiguous and can fail child validation.

- **Cross-skill consistency** @ `designer-controller` vs `agent-swarm` worktree policy (1/10 runs)
  - Evidence: designer-controller runs `git worktree add` directly; agent-swarm forbids re-implementing worktree mechanics
  - Rationale: Two orchestration skills use opposite strategies for the same side effect.

- **Correctness** @ `ai-coding/commands/meta-prompt.md:7` vs `:22-23` (1/10 runs)
  - Evidence: Task allows clarifying question always; Success Criteria forbid questions when `-i` absent
  - Rationale: Non-interactive invocations have contradictory ask/abort rules.

- **Correctness** @ `ai-coding/commands/wrap-up.md:47` vs `:58-59` (1/10 runs)
  - Evidence: guardrail forbids questions unless `-i`; workflow requires prompts when `{rollup}=interactive`
  - Rationale: `{rollup}=interactive` without `-i` triggers forbidden user prompts.

- **Robustness** @ `home-config/.shell_extras.sh:27-32` (2/10 runs, live verified)
  - Evidence: unconditional `source <(fzf …)` and `eval "$(starship init …)"` with no guards; live shell emits `command not found`
  - Rationale: Default Linux install skips Brewfile; managed shell startup errors on every login.

- **Determinism** @ `home-config/.cursor/mcp.json:4-5,11-12` (1/10 runs)
  - Evidence: `"command": "uvx"` with unpinned `docling-mcp` / `markitdown-mcp`
  - Rationale: MCP tool surface drifts at runtime without any repo change.

### Minor / Nit

- **Clarity** @ `README.md:6` vs `Makefile:24` — two entry points (`source` vs execute) with different semantics (2/10)
- **Stability** @ `install.sh:135-139`, `refresh.sh:33-38` — unordered `install-*.sh` glob (2/10)
- **Idempotency** @ `install.sh:102-110` — unconditional `cp -af` overwrites local edits (1/10)
- **Completeness** @ `Makefile:23-27` — `make install` does not chain sync (1/10)
- **Robustness** @ `scripts/sync-coding-tools.sh:201` vs `:284` — copy mode lacks `(N)` nullglob on commands glob (1/10)
- **Idempotency** @ `scripts/sync-coding-tools.sh:259-261` — symlink idempotency compares unresolved `readlink` (1/10)
- **Correctness** @ `ai-coding/parameters/coverage.md:212-218` — stale trajectory-snapshot token defaults (1/10)
- **Completeness** @ `ai-coding/commands/critique.md:7` vs `:33` — URL `{context}` undeclared in workflow (1/10)
- **Completeness** @ `ai-coding/commands/save-session-state.md:15` vs `:45-48` — `{include_sections}` never filters gather (1/10)
- **Completeness** @ `ai-coding/commands/soft-shutdown.md:13` vs `:38-50` — `-i` never used after parse (1/10)
- **Cross-skill consistency** @ skill structural schemas — orchestration vs prose-only skills (1/10)
- **Determinism** @ `home-config/.tmux.conf:15,19` — clock/hostname in status bar (1/10)
- **Quality** @ `home-config/.tmux.conf:2` — `default-terminal "xterm-256color"` inside tmux (1/10)
- **Clarity** @ `install.sh:3` — "begining" typo (2/10)
- **Clarity** @ `scripts/sync-coding-tools.sh:64-68,395-397` — `--mode` ignored when `--unlink` set, undocumented (1/10)
- **Nit** @ `ai-coding/marketplace.json:13` — static `0.1.0` with no bump policy (1/10)
- **Nit** @ `agent-swarm` Events — `member.progress` references undefined worktree-task heartbeat (1/10)
- **Nit** @ `ai-coding/skills/file-dump` vs `trajectory-snapshot` — `{date}` vs `{datetime_timestamp}` token naming (1/10)

## Divergent Findings

Findings raised by only one partition run (1/10) but not corroborated elsewhere in this swarm:

| Finding | Run | Notes |
|---|---|---|
| `install.sh:54` apt `--update` flag | bootstrap | Not re-checked in other partitions; plausible Linux-only |
| `install.sh:147` Ollama pipe to `$SHELL` | bootstrap | Not echoed by skills/commands runs |
| `merge-commit-push.md` detached HEAD default | commands | Command-only partition |
| `ralph-design.md` refine-round snapshot gap | commands | Command-only partition |
| `address-worklist-commit-loop.md` mark-blocked vs guardrail | commands | Command-only partition |
| Plugin `rules/` sync no-op | plugins | Plugin-only partition |
| `.vimrc` `silent!` suppresses failures | home-config | home-config-only |

These may still be valid; low agreement reflects partition-scoped reading, not necessarily false positives.

## Open Questions

1. **Full 100-run fan-out:** User requested `{num_agents}=100` (Search tier). Without `{cost_cap}`, agent-swarm policy requires user approval before downscaling; this run executed 10 experiments. Re-run with `{cost_cap}` or explicit approval for full convergence statistics.
2. **Plugin loader resolution:** Whether Cursor/Claude resolve `pluginRoot` relative to marketplace JSON directory or synced destination root was not verified against live IDE behavior — copy-mode breakage is inferred from path arithmetic.
3. **Brewfile formula availability:** Prior critique checked Homebrew API entries; this swarm did not re-verify every Brewfile pin.
4. **Command/skill bodies beyond frontmatter:** Several command files were analyzed structurally; not every workflow step was traced against live tool behavior.
5. **Intel macOS:** `BREW_ROOT` Intel path gap was not live-tested (cloud environment is Linux).

## Events

```jsonl
{"ts":"2026-07-12T21:42:00Z","type":"swarm.gate_decided","payload":{"verdict":"swarm","triggers_fired":["T4","T6"],"pattern":"none","adaptation":"critique-read-only-no-worktrees"}}
{"ts":"2026-07-12T21:42:05Z","type":"swarm.dispatched","payload":{"num_experiments_requested":100,"num_experiments_executed":10,"parallel":7,"partitions":["bootstrap","sync","commands","skills","home-config","parameters","plugins"]}}
{"ts":"2026-07-12T21:45:30Z","type":"member.completed","payload":{"slot":1,"partition":"bootstrap","status":"success","findings":28}}
{"ts":"2026-07-12T21:45:30Z","type":"member.completed","payload":{"slot":2,"partition":"sync","status":"success","findings":12}}
{"ts":"2026-07-12T21:45:30Z","type":"member.completed","payload":{"slot":3,"partition":"commands","status":"success","findings":30}}
{"ts":"2026-07-12T21:45:30Z","type":"member.completed","payload":{"slot":4,"partition":"skills","status":"success","findings":25}}
{"ts":"2026-07-12T21:45:30Z","type":"member.completed","payload":{"slot":5,"partition":"home-config","status":"success","findings":22}}
{"ts":"2026-07-12T21:45:30Z","type":"member.completed","payload":{"slot":6,"partition":"parameters","status":"success","findings":12}}
{"ts":"2026-07-12T21:45:30Z","type":"member.completed","payload":{"slot":7,"partition":"plugins","status":"success","findings":14}}
{"ts":"2026-07-12T21:46:00Z","type":"member.completed","payload":{"slot":8,"partition":"live-verify","status":"success","checks":["make-help-zsh-missing","bash-install-zstd","shell-extras-fzf-starship"]}}
{"ts":"2026-07-12T21:46:35Z","type":"swarm.done","payload":{"successes":10,"failures":0,"wall_clock_s":270,"floor_met":true,"convergent_critical":2,"convergent_major":15}}
```

## Recommendation

- **Action:** Address the two critical bootstrap issues first (`install.sh` bash/zsh portability and README sourcing semantics), then add `--delete` to copy-mode rsync or revise the deterministic-snapshot contract.
- **Mode convergence:** Bootstrap and sync partitions independently flagged idempotency and `--delete` gaps; skills and parameters partitions independently flagged wiki/catalog drift (`file-dump`, `{task}` undeclared).
- **Confidence:** `high` for critical/major bootstrap and sync findings (reproduced or multi-partition agreement); `medium` for plugin path resolution (not live-tested in IDE); `low` for single-partition command-level contradictions until cross-read.
