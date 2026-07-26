# Repo Critique — dotfiles

- **Description:** repo-critique
- **Model:** moonshotai-kimi-k3
- **Captured at (UTC):** 2026-07-26T21:59:17Z
- **Session:** 618ef9cd-7c9f-4af4-b367-febb3a249bb1

---

# Critique: dotfiles repository (repo-wide)

**Context:** `/Users/yliapis/src/dotfiles` — full repository. Loaded and analyzed: `README.md`, `AGENTS.md`, `Makefile`, `install.sh`, `refresh.sh`, `snap_installs.sh`, `Brewfile`, `.gitignore`, `scripts/` (all 3), `.cursor/environment.json`, `.cursor/scripts/cloud-agent-bootstrap.sh`, `home-config/.shell_extras.sh`, `docs/README.md`. Verified live: `make mirrors-check`, `shellcheck`, `zsh -n`/`bash -n`, BSD/GNU flag probe. Skimmed as data, not audited line-by-line: `ai-coding/plugins/` bodies (75 mirrored items verified byte-in-sync), `ai-coding/{indexes,parameters,samples,trajectories}`, `prompts/`, `home-config/{.cursor/mcp.json,.tmux.conf,.vimrc}`.

**Criteria applied:** Quality (clarity, correctness, completeness, robustness) + Determinism (reproducibility, idempotency, stability) — the default criteria set.
**Runs:** 1 (parallel up to 1, model: moonshotai/kimi-k3)

## Summary

The newer tooling layer is disciplined: `make mirrors-check` verifies clean (75 entries, zero drift), shellcheck is clean except one info-level hit, all scripts pass syntax checks, and `sync-project-mirrors.sh` / `cloud-agent-bootstrap.sh` are explicitly idempotent with deterministic ordering (`LC_ALL=C sort`) and collision aborts. The older install/refresh layer carries most of the risk: 8 major findings, led by the home-dir sync never converging destinations to the repo (no `--delete`, no flattened-name collision detection), documented contracts that are violated in practice (`--dry-run` writes; `source install.sh` kills the user's shell on any error), and unpinned execute-from-URL installers. Also 5 minor and 4 nit findings. Biggest single concern: `sync-coding-tools.sh` copy mode silently accumulates stale files and shadowed names across all three AI-tool home directories while claiming the repo is source-of-truth.

## Findings

### Major

- **Correctness** @ `install.sh:54` (1/1 runs)
  - Evidence: `sudo apt install --update curl`
  - Rationale: `apt install` has no `--update` option (update is a separate subcommand) and no `-y`, so the only branch that bootstraps curl on Linux either errors on an unknown option or blocks on an interactive prompt — the sibling bootstrap uses the correct `sudo -E apt-get update && sudo -E apt-get install -y` pattern (`.cursor/scripts/cloud-agent-bootstrap.sh:29-30`), and the file itself switches to `apt-get` two case-branches later (`install.sh:67`).

- **Robustness** @ `install.sh:23,27,41,58,107,121` + `README.md:5-7` (1/1 runs)
  - Evidence: README instructs `source install.sh`; install.sh contains six `exit 1` error paths.
  - Rationale: under the documented invocation every error path terminates the user's interactive login shell, and `Makefile:30-31` (`@./install.sh`) executes instead of sourcing, so the two documented entry points have materially different failure semantics.

- **Idempotency** @ `scripts/sync-coding-tools.sh:216,240,244,249` (1/1 runs)
  - Evidence: `RSYNC_BASE=(rsync -aL --itemize-changes)` — no `--delete`; header lines 6-8 claim copy mode is "deterministic, source-of-truth is the dotfiles repo at the moment of the last run."
  - Rationale: commands/skills/agents deleted from `ai-coding/plugins/` persist forever in `~/.cursor`, `~/.claude`, and `~/.config/opencode`, so identical repo input yields different home-dir state depending on run history, and `--unlink` cannot clean it up because it only iterates current sources (lines 430-447) and only removes copies that still match a source (lines 409-419).

- **Correctness** @ `scripts/sync-coding-tools.sh:50-52,240` vs `scripts/sync-project-mirrors.sh:13-15,117-136` (1/1 runs)
  - Evidence: home-dir sync flattens `"$SRC_PLUGINS"/*/commands/*.md` from every plugin into one destination with rsync last-write-wins; the mirror script aborts because "a name may be claimed by only one plugin; a collision aborts rather than letting one plugin silently shadow another."
  - Rationale: two plugins claiming one flattened name silently shadow each other in all three home-dir tool installs — the exact behavior the repo's sibling script treats as fatal, with no warning to the user.

- **Correctness** @ `scripts/sync-coding-tools.sh:79,239,243,248,306,207` + `Makefile:78` (1/1 runs)
  - Evidence: usage promises `--dry-run` will "Show actions without writing" and `make dry-run` advertises "(no filesystem writes)", yet `mkdir -p "$cmds_dst"` (and skills/agents equivalents) and `mkdir -p "${dst:h}"` in `link_one` run unconditionally, and `trap 'append_log $?' EXIT` appends to `~/.cache/dotfiles/sync.log` on dry runs ("Every run appends one line", line 96).
  - Rationale: the documented no-side-effects contract is violated on every dry run — destination directories get created and the audit log mutates — and the script's own help text is internally contradictory about it.

- **Robustness** @ `install.sh` (whole file) (1/1 runs)
  - Evidence: no `set -e` / `pipefail` anywhere, while every other script in the repo uses `set -euo pipefail` (`sync-coding-tools.sh:41`, `sync-project-mirrors.sh:27`, `cloud-agent-bootstrap.sh:17`, `install-doc-tools.sh:5`); the script ends with `echo "dotfiles install complete"` unconditionally.
  - Rationale: a failed Homebrew installer, failed `brew bundle`, or failed modular installer is sailed past and the run still reports success, leaving a partially provisioned machine indistinguishable from a good one.

- **Robustness** @ `home-config/.shell_extras.sh:29-31` vs `install.sh:95-100,113-131` (1/1 runs)
  - Evidence: `source <(fzf --"$_dotfiles_shell")` and `eval "$(starship init "$_dotfiles_shell")"` run unconditionally, but install.sh skips the Brewfile that installs fzf/starship on non-macOS unless `GUI_INSTALL=1` while still copying home-config and wiring the source line into the profile on every platform.
  - Rationale: on the supported Linux path every new login shell emits command-not-found errors from the managed snippet, and the graceful-degradation pattern already exists four lines up (the guarded brew lookup, lines 7-17) but wasn't applied.

- **Stability** @ `install.sh:81,147` (1/1 runs)
  - Evidence: `bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` and `curl -fsSL https://ollama.com/install.sh | $SHELL`.
  - Rationale: both fetch and execute unpinned remote scripts at HEAD, so identical repo input produces different installed systems depending on what those URLs serve on run day, and the pipe-to-shell pattern precludes any integrity verification.

### Minor

- **Reproducibility** @ `Brewfile` (all entries), `.gitignore:1-2`, `scripts/install-doc-tools.sh:16,19` (1/1 runs)
  - Evidence: no formula or cask is version-pinned; `.gitignore` excludes `Brewfile.lock.json` with "we don't necessarily want to pin versions"; `uv tool install --upgrade docling-slim` / `--upgrade 'markitdown[all]'`.
  - Rationale: two installs from the same commit on different days provision different tool versions (`brew bundle` does not consume the lock file anyway), an acknowledged trade-off in-repo but a genuine gap against the reproducibility criterion.

- **Completeness** @ `snap_installs.sh` (whole file), `refresh.sh:41-42` (1/1 runs)
  - Evidence: refresh.sh contains only `# TODO: add snap refresh script`; nothing invokes `snap_installs.sh`; shellcheck reports SC2086 for `if [ -z $SNAP_PATH ]` (line 5) — the repo's only lint hit.
  - Rationale: the snap installer is dead code carrying the repo's only shellcheck defect, and snap-based installs drift entirely outside the managed refresh loop.

- **Idempotency** @ `scripts/sync-coding-tools.sh:282-290,199-205` (1/1 runs)
  - Evidence: `backup_dir="$BACKUP_ROOT/$ts"` with `ts="$(date -u +%Y-%m-%dT%H-%M-%SZ)"` at one-second resolution; no pruning of `~/.dotfiles-backup/` or of the append-only audit log.
  - Rationale: two symlink-mode runs within the same second share one backup directory (second `mv` collides into it), and repeated runs accumulate backups and log lines without bound, so artifact state is not stable across runs.

- **Robustness** @ `install.sh:63-69` (1/1 runs)
  - Evidence: `sudo apt-get install tilix` runs for every `linux-gnu*` host, without `-y` and without a preceding `apt-get update`.
  - Rationale: the branch installs a GUI terminal emulator on headless servers where it cannot be used, blocks on an interactive confirmation prompt, and fails outright on stale apt metadata.

- **Correctness** @ `scripts/sync-coding-tools.sh:337-341` vs `scripts/sync-project-mirrors.sh:17-20` (1/1 runs)
  - Evidence: the mirror script bans symlinked entries because "at least one shipped client resolves a link and drops the entry when the real path leaves the scanned directory," yet symlink mode links skill directories into `~/.cursor/skills`, `~/.claude/skills`, and `~/.config/opencode/skills`.
  - Rationale: if that client behavior applies to home-dir skill roots (the comment is not scoped to repo mirrors), then `--mode symlink` produces skills invisible to that client — the repo's own documented knowledge undermines the mode's premise.

### Nit

- **Clarity** @ `install.sh:3` (1/1 runs)
  - Evidence: `echo "begining dotfiles install"`.
  - Rationale: misspelling ("beginning") in the first user-visible line of the primary entry point.

- **Correctness** @ `Brewfile:103-104` (1/1 runs)
  - Evidence: `# set system python3 as 3.12` annotating `brew "python@3.12"`.
  - Rationale: the formula is keg-only and changes nothing about "system python3," so the comment overstates the effect of the line it documents.

- **Robustness** @ `install.sh:8` (1/1 runs)
  - Evidence: `GUI_INSTALL=${1:-$GUI_INSTALL}`.
  - Rationale: when sourced (the README-documented invocation) or re-sourced from `refresh.sh:16`, a stray positional parameter in the surrounding shell silently becomes the GUI-install flag.

- **Clarity** @ `scripts/install-doc-tools.sh:14` (1/1 runs)
  - Evidence: `# Docling (IBM, MIT) — primary PDF->MD engine; best 2026 benchmark.`
  - Rationale: an unsourced, time-relative performance claim that cannot be verified and silently ages as the benchmark year recedes.

## Open Questions

- Linux-only branches (`apt`, tilix, snap, ollama) were analyzed statically from a macOS host and could not be executed; the `apt install --update` finding rests on apt's documented CLI surface rather than an observed failure.
- Does the symlink-drop client behavior noted in `sync-project-mirrors.sh:17-20` also apply to home-dir skill roots (`~/.cursor/skills`)? The answer decides whether the symlink-mode finding is minor or major.
- Is the dry-run audit-log append intentional? The usage text contradicts itself (line 79 "without writing" vs lines 95-97 "Every run appends one line"), so the correct fix direction is unclear.
- `Brewfile.lock.json` is present in the working tree yet gitignored; is it intended to play any reproducibility role, or is it purely incidental?
- `ai-coding/{indexes,parameters,samples,trajectories}` and the 75 mirrored plugin items were verified byte-in-sync but not individually audited; findings about their internal content are out of scope for this run.
