# Bootstrap Critique — `install.sh` + `Makefile`

- **Description:** scoped critique of the dotfiles bootstrap path
- **Model:** `claude-opus-5[1m]` (Opus 5, 1M context) — orchestrator and all 5 workers
- **Agent:** Claude Code `Agent` tool, `general-purpose` subagent type ×5
- **Command:** `/critique` (no arguments; `{context}` and `{num_experiments}` resolved interactively)
- **Captured at (UTC):** 2026-08-16T18:46:48Z
- **Session:** `2c787c8e-fbb2-40da-befd-31ba6fa895f2`
- **Corpus:** `install.sh` (343 lines) + `Makefile` (93 lines) at commit `9bbdad8`, clean working tree
- **Host:** Ubuntu 24.04.4 LTS, Linux 6.17.0-19-generic, `$SHELL=/bin/bash`
- **Toolchain observed:** zsh 5.9.2, bash 5.3.15, GNU Make 4.4.1, apt 2.8.3, Homebrew 6.0.17, git 2.55.0

---

## Methodology

`/critique` was invoked with no arguments. `{context}` is a required parameter, so
rather than guess, the orchestrator asked and the operator selected
**`install.sh` + Makefile** as the target and **5 runs / parallel 5** as the
replication factor. All other parameters fell to their defaults.

| Parameter | Value | Source |
|---|---|---|
| `{context}` | `install.sh`, `Makefile` | operator selection |
| `{criteria}` | default: quality + determinism | default (none supplied) |
| `{model}` | `claude-opus-5[1m]` | parent-agent default |
| `{num_experiments}` | 5 | operator selection |
| `{parallel}` | 5 | operator selection |
| `-i` / `--interactive` | absent | — |

**Validation.** `{num_experiments}` = 5 (integer ≥ 1) and `{parallel}` = 5
(integer in `1..5`) both passed before any run was scheduled.

**Dispatch.** Five `general-purpose` subagents received a byte-identical prompt in
a single parallel tool block (`run_in_background: false`), so the runs are
independent replications rather than a chain. No fallback to sequential execution
was needed. Workers were permitted to read sibling files (`README.md`,
`Brewfile`, `home-config/`, `scripts/`) for corroboration, but were constrained to
locate every finding inside the two target files. The prompt required each finding
to carry `{location, criterion, severity, evidence, rationale}` and forbade style
preferences, speculation, and patches.

**Aggregation.** Findings were merged on (location, criterion); near-duplicates
differing only in evidence wording were folded into one entry. Findings raised by
**≥3 of 5 runs** are reported under Findings; **1–2 of 5** under Divergent
Findings. Every entry records its agreement count. Where runs disagreed on
severity, the split is stated inline.

**Orchestrator verification.** Subagent claims were not taken on trust. The
orchestrator read both files in full before dispatch and independently reproduced
the load-bearing claims after aggregation:

| Claim | Probe | Result |
|---|---|---|
| `print` is zsh-only | `bash -c 'print hello'` | `command not found`, rc 127 |
| Empty `bash -c` succeeds | `bash -c "$(false)"` | rc 0 |
| zsh `nomatch` aborts whole script | zsh func with unmatched glob + trailing `echo` | `no matches found`, rc 1, trailing echo never ran |
| `brew bundle cleanup` semantics | `brew bundle cleanup --help` | "Uninstall all dependencies not present in the Brewfile"; `--force` skips the prompt |
| Makefile relative paths | `cd /tmp && make -f <abs>/Makefile sync-help` | `./scripts/sync-coding-tools.sh: No such file or directory`, Error 127 |
| Refresh skips the GUI gate | read `install.sh:288` vs `:310` | confirmed: `run_brewfile_if_gui` vs bare `run_brewfile` |
| Glob abort is live or latent | `ls scripts/` | **latent** — three `install-*.sh` present today |
| zsh location on this host | `command -v zsh` | `/home/linuxbrew/.linuxbrew/bin/zsh` — outside `detect_shell`'s allowlist |

One severity was adjusted against subagent consensus on the strength of that
verification: the `CLEAR_CACHE` naming finding was raised by 2/5 runs but promoted
into Findings after `brew bundle cleanup --help` confirmed the mass-uninstall
semantics.

### Run ledger

| Run | Agent ID | Findings | Subagent tokens | Tool calls | Duration |
|---|---|---|---|---|---|
| 1 | `a49c63bccc3249667` | 24 | 84,727 | 25 | 8m 40s |
| 2 | `a314fb682afb8b68e` | 24 | 85,442 | 24 | 8m 44s |
| 3 | `abc73939d5026f149` | 24 | 76,226 | 21 | 7m 18s |
| 4 | `aa7c636a8647f343e` | 24 | 88,847 | 24 | 9m 01s |
| 5 | `a0e35fa73f88e61e9` | 26 | 78,179 | 20 | 7m 32s |
| **Total** | — | **122 raw → 37 merged** | **413,421** | **114** | **~9m 01s wall** |

### Convergence profile

| Agreement | Count | Disposition |
|---|---|---|
| 5/5 | 13 | Findings |
| 4/5 | 5 | Findings |
| 3/5 | 6 | Findings |
| 2/5 | 6 | Divergent (1 promoted on verification) |
| 1/5 | 7 | Divergent |

Thirteen findings reproduced in every independent run. Notably, **no run reported
a clean criterion** — all seven named sub-checks (clarity, correctness,
completeness, robustness, reproducibility, idempotency, stability) produced at
least one substantiated defect in all five runs.

Three runs also recorded explicitly *cleared* suspicions, retained here because
they bound the result: `brew upgrade --cask --greedy-latest` exits 0 on Linux
rather than erroring; `Brewfile` ends with a newline, so the line-274
concatenation is not a syntax hazard; `cp -af "$src_dir/."` does not clobber
`~/.zshrc`/`~/.bashrc`, since `home-config/` contains only `.cursor/`,
`.shell_extras.sh`, `.tmux.conf`, and `.vimrc`; and the line-274 process
substitution does work with Homebrew 6.0.17.

---

# Critique: `install.sh` + `Makefile` (dotfiles bootstrap)

**Criteria applied:** Quality (clarity, correctness, completeness, robustness) ·
Determinism (reproducibility, idempotency, stability) — the default `/critique`
criteria set.
**Runs:** 5 (parallel up to 5, model: `claude-opus-5[1m]`)

## Summary

All five runs independently converged on the same structural picture: the file's
documented primary entry point (`source install.sh`, per `README.md:6`) is
incompatible with its own zsh-only implementation, and its failure-propagation is
applied inconsistently between the two modes. 26 findings survived majority
agreement — 2 critical, 13 major, 9 minor, 2 nit — plus 11 minority findings. The
biggest concern is `cleanup_brew_cache` (`install.sh:270`): a name and doc string
promising cache reclamation that actually invokes an unprompted mass uninstall,
fed by a process substitution whose `cat` exit status is structurally
unobservable.

## Findings

### Critical

- **Robustness (missing files) / Idempotency** @ `install.sh:270-276` (3/5 runs; 2 of the 3 rated critical)
  - Evidence: `brew bundle cleanup --force \` / `      --file=<(cat "$DOTFILES_ROOT/Brewfile" "$DOTFILES_ROOT/Brewfile.mas")`
  - Rationale: Neither Brewfile's existence is checked and a process substitution discards `cat`'s exit code, so a wrong `DOTFILES_ROOT` (reachable via the `install.sh:41` defect below) or a partial checkout hands a truncated or empty manifest to a command whose own help reads "Uninstall all dependencies not present in the Brewfile" with `--force` suppressing the confirmation prompt — verified independently by two runs as 0 bytes with outer `rc=0`.

- **Robustness (malformed input)** @ `install.sh:60-72` (5/5 runs; 2 rated critical, 3 major)
  - Evidence: `    *)` / `      break` / `      ;;` … `GUI_INSTALL=${1:-$GUI_INSTALL}`
  - Rationale: The parser breaks on the first unrecognized token and assigns it to `GUI_INSTALL` with no validation, so `./install.sh --help` and any `--refresh` typo both fall through to a full `do_bootstrap` — `sudo apt-get install tilix`, the Homebrew installer, and `cp -af home-config/. $HOME/` over the user's dotfiles — with no usage path and no diagnostic; `./install.sh 1 --refresh` additionally discards `--refresh` outright, making mode selection order-dependent.

### Major

- **Idempotency** @ `install.sh:121-127` (5/5 runs)
  - Evidence: `print '# dotfiles: shell extras (managed by dotfiles/install.sh)' >> "$DEFAULT_PROFILE_FILE"`
  - Rationale: `print` is a zsh builtin absent from bash (confirmed: rc 127), so on the README's documented `source install.sh` path from bash — this machine's `$SHELL` is `/bin/bash` — the marker comment is never written while the `printf` source line at 126 is, permanently defeating the `grep -qF` guard at line 121 and appending a duplicate source line to `~/.bashrc` on every run; three runs reproduced unbounded growth.

- **Robustness (empty input)** @ `install.sh:92-93` (5/5 runs)
  - Evidence: `for script in "$DOTFILES_ROOT/scripts"/install-*.sh; do` / `    [ -f "$script" ] || continue`
  - Rationale: `[ -f … ] || continue` is a bash idiom that is dead code under this file's zsh shebang, because zsh's default `nomatch` makes an unmatched glob a fatal error that aborts the entire script from inside the function — confirmed, with the statement after the call never executing, meaning an empty `scripts/` dir would skip `ensure_ollama` and the failure summary entirely. Currently latent: `scripts/` holds three `install-*.sh` files today.

- **Correctness (internal contradiction) / failure propagation** @ `install.sh:292` vs `install.sh:320` (5/5 runs)
  - Evidence: bootstrap calls bare `  run_install_scripts`; refresh calls `    run_step "install scripts" run_install_scripts`
  - Rationale: `run_install_scripts` computes and returns `$failed` (line 100), but bootstrap discards it and there is no `set -e`, so a failed `scripts/install-*.sh` leaves `REFRESH_FAILURES` empty and `make install` prints "dotfiles install complete" and exits 0 — directly contradicting the header comment at lines 76-77, "do_bootstrap and do_refresh report the collected names and exit non-zero." Two runs noted the asymmetry extends to most bootstrap steps: only 2 of 12 pass through `run_step`.

- **Robustness / Stability (ambient environment)** @ `install.sh:149-158` (5/5 runs)
  - Evidence: `  if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/opt/homebrew/bin/zsh" ]; then`
  - Rationale: Detection is an exact-match allowlist of four absolute paths that omits `/usr/bin/zsh` (Ubuntu's package), `/usr/local/bin/zsh` (Intel-Mac Homebrew), and `/home/linuxbrew/.linuxbrew/bin/zsh` — confirmed to be the only zsh on this machine, and exactly what this repo's own `brew "zsh"` Brewfile line produces — so making the repo's own zsh your login shell causes `exit 1` "unsupported shell detected".

- **Correctness / Robustness** @ `install.sh:206-211` (5/5 runs)
  - Evidence: `    darwin*)    BREW_ROOT="/opt/homebrew" ;;`
  - Rationale: Intel macOS installs Homebrew to `/usr/local`, so `eval "$("$BREW_ROOT/bin/brew" shellenv)"` evaluates nothing, brew never reaches PATH, and every later brew step fails for an unrelated-looking reason — an internal contradiction, since `home-config/.shell_extras.sh` (installed by this same script) correctly probes all three prefixes.

- **Robustness (failure propagation) / Stability (network)** @ `install.sh:205` (4/5 runs)
  - Evidence: `  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
  - Rationale: A failed `curl` makes the substitution empty and `bash -c ""` exits 0 (confirmed), so `ensure_homebrew` reports success with no Homebrew present and the unguarded `disable_brew_analytics` on the next line then fails obscurely; the `HEAD` reference is also unpinned, so identical invocations execute different installer code over time.

- **Correctness (docs vs. behavior)** @ `install.sh:309-311` vs header `install.sh:28-29` (3/5 runs)
  - Evidence: `      run_step "brew bundle" run_brewfile` — where bootstrap at line 288 uses `run_brewfile_if_gui`
  - Rationale: Refresh calls the ungated `run_brewfile` directly, so the documented `GUI_INSTALL` contract ("on Linux set to 1 … to run it") holds only in install mode — a Linux box deliberately bootstrapped without `GUI_INSTALL` gets the entire Brewfile applied by its first `make refresh`. Call-site asymmetry confirmed by the orchestrator.

- **Correctness / Robustness (failure propagation)** @ `install.sh:306-307` with `install.sh:295-298` (3/5 runs)
  - Evidence: `  if [[ "$RERUN_INSTALL" == "1" ]]; then` / `    do_bootstrap`
  - Rationale: `do_bootstrap` ends in `exit 1` when any step failed, and `exit` inside a called function terminates the script, so `RERUN_INSTALL=1 ./install.sh --refresh` with one failed step silently skips `cleanup_brew_cache`, `upgrade_brew`, `sync_coding_tools`, and `run_install_scripts` (lines 315-321) and reports "dotfiles **install** finished with failures" — delivering strictly less than a plain refresh.

- **Robustness (failure propagation)** @ `install.sh:107, 119, 139, 143, 157, 177, 297, 304, 328` (4/5 runs)
  - Evidence: `    echo "unsupported shell detected: $SHELL"` / `    exit 1`
  - Rationale: `install.sh:5` and `README.md:6` name `source install.sh` the primary entry point, but `exit` unwinds past function scope and terminates the sourcing shell, so any of nine error paths — including the success-with-failures summary at line 297 — closes the user's terminal instead of returning an error; three runs reproduced this in both zsh and bash.

- **Correctness (docs vs. behavior) / Reproducibility** @ `install.sh:41` (4/5 runs)
  - Evidence: `DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"`
  - Rationale: Under bash, `$0` in a sourced file is `bash`, so `dirname` yields `.` and `DOTFILES_ROOT` silently becomes the caller's cwd — verified by three runs sourcing from `/`, `/tmp`, and `/etc` — meaning the documented entry point works only by accident when the user happens to be standing in the repo root, and otherwise mis-resolves every `$DOTFILES_ROOT/…` path including the destructive cleanup above.

- **Stability (shell drift) / Reproducibility** @ `install.sh:252` (5/5 runs)
  - Evidence: `  curl -fsSL https://ollama.com/install.sh | $SHELL`
  - Rationale: A `#!/bin/sh` upstream installer is piped into the user's *login* shell, which `detect_shell` explicitly permits to be zsh, where unquoted scalars are not word-split — one run traced this to a concrete divergence in the fetched script's `for NEED in $NEEDS` and `for MODULE in $MODULES` loops (the latter writing to `/etc/modules-load.d/` as root); `$SHELL` is also unquoted and the URL unpinned.

- **Stability (ambient environment) / Reproducibility** @ `Makefile:25-28` (5/5 runs)
  - Evidence: `SHELL := $(shell printf '%s' "$${SHELL:-/bin/sh}")` / `.SHELLFLAGS := -eu -c`
  - Rationale: This deliberately reverses GNU Make's fixed-`/bin/sh` guarantee while hardcoding `-eu -c`, flags a non-POSIX login shell does not accept — two runs verified `SHELL=<fish> make` failing *every* target with `fish: -eu: unknown option`, and this repo's own Brewfile installs fish — so identical invocations succeed or fail purely on the operator's `$SHELL`, and behave differently in cron/CI where `SHELL` is unset.

- **Clarity (unambiguous naming)** @ `install.sh:270-276` and header `install.sh:35` (2/5 runs, both major — promoted on orchestrator verification)
  - Evidence: `cleanup_brew_cache() {` / `  if [[ "$CLEAR_CACHE" == "1" ]]; then` / header: `CLEAR_CACHE=0          Refresh only: brew bundle cleanup --force when 1.`
  - Rationale: The variable name, the function name, and the header line all describe reclaiming a download cache (`brew cleanup`), but `brew bundle cleanup --help` confirms the command uninstalls every formula and cask absent from the Brewfile — so a user enabling this to free disk space triggers an unprompted mass uninstall instead.

### Minor

- **Idempotency / Robustness** @ `install.sh:182-189` (5/5 runs) — `sudo apt-get install tilix` runs on every Linux bootstrap with no `command -v` guard (unlike every sibling `ensure_*`), no `-y` (so unattended runs block on apt's `[Y/n]` prompt), no `GUI_INSTALL` gate despite being a GUI app, and no mention in the header's mode summary at lines 14-16.
- **Stability (tool version drift)** @ `install.sh:171-179` (5/5 runs) — `sudo apt install --update curl` uses apt's own self-disclaimed unstable CLI ("apt does not have a stable CLI interface. Use with caution in scripts.", reproduced on apt 2.8.3, where `--update` is not listed under `apt install --help`), omits `-y`, and is inconsistent with `ensure_tilix`'s stable `apt-get` twelve lines later.
- **Completeness** @ `Makefile:1-6` (5/5 runs) — The header enumerates the target set exhaustively but omits `sync-claude` and `sync-opencode`, both real `.PHONY` targets at lines 59-63 that `make help` prints.
- **Correctness (internal contradiction)** @ `Makefile:8-9` (4/5 runs) — "Three scripts do the work" precedes a list of three, yet the two targets listed first in the same header (`install`, `refresh`, lines 37-41) invoke a fourth, `./install.sh` — the only target that writes to `$HOME` and invokes `sudo`.
- **Reproducibility** @ `Makefile:31-33, 38, 41` (3/5 runs) — Recipe paths are relative to process cwd rather than `$(dir $(lastword $(MAKEFILE_LIST)))`; confirmed that `make -f <abs>/Makefile sync-help` from `/tmp` fails with `./scripts/sync-coding-tools.sh: No such file or directory`, Error 127.
- **Correctness (docs vs. code) / Clarity** @ `install.sh:113-114` (3/5 runs) — Two false claims: `detect_shell` sets exactly one `DEFAULT_PROFILE_FILE` so only one rc file is ever wired (contradicting both this comment and `home-config/.shell_extras.sh:2`), and no "per-shell extras file" exists — the entrypoint derives a shell *name* inline rather than dispatching to a file.
- **Completeness** @ `install.sh:43-49` vs `225, 338` (3/5 runs) — `BREW_BUNDLE_MAS` is the only documented env var omitted from the `${VAR:-…}` normalization block, so it is the one variable read while genuinely unset — fatal the moment the file is sourced into a shell with `nounset`, which is exactly the documented entry point.
- **Stability (ambient environment)** @ `install.sh:58` (3/5 runs) — `export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1` persists into the caller's interactive session on the documented `source` path, so every later hand-typed `brew upgrade` in that terminal silently behaves differently; the variable is also absent from the header's env-var block despite the 8-line justification above it.
- **Correctness (internal contradiction)** @ `install.sh:270-276` vs `228-231` (2/5 runs, grouped with the critical finding at the same location) — `run_brewfile_mas` explicitly skips `Brewfile.mas` off macOS, but `cleanup_brew_cache` concatenates that same file unconditionally, feeding `mas "Boom3D", id: 1233048948` into a Linux cleanup run.

### Nit

- **Clarity (naming)** @ `install.sh:74, 83, 295-296` (5/5 runs) — `REFRESH_FAILURES` is the shared accumulator for both modes; line 296 prints "dotfiles **install** finished with failures" out of a variable named for refresh.
- **Clarity / Correctness** @ `install.sh:137-140` (4/5 runs) — Both zsh and bash always set `OSTYPE`, so the `""` branch is unreachable, and its remedy ("try sourcing this script") points at the exact path where the adjacent `exit 1` calls kill the user's shell.

## Divergent Findings

Raised by one or two runs; each is substantiated but did not reach majority.

- **Robustness / Idempotency** @ `install.sh:103-111` (2/5) — `cp -af "$src_dir/." "$HOME/"` destroys pre-existing `~/.vimrc`, `~/.tmux.conf`, `~/.cursor/mcp.json` with no backup, where `scripts/sync-coding-tools.sh` stages `$HOME/.dotfiles-backup/<UTC-timestamp>/`; it also never prunes, so a file deleted from `home-config/` survives in `$HOME` forever and two machines at the same commit diverge by install history.
- **Robustness (partial access)** @ `install.sh:255-259` (2/5) — A present-but-non-executable `sync-coding-tools.sh` (restrictive umask, `core.fileMode=false`, noexec mount) makes the core refresh action a silent no-op that `run_step` records as success; inconsistent with `run_install_scripts`, which invokes via `bash "$script"` and needs no exec bit.
- **Robustness (malformed input)** @ `install.sh:334` with header `install.sh:27` (2/5) — `MODE` is documented as an enum but never validated, so `MODE=Refresh` or `MODE=typo` falls through to the destructive bootstrap.
- **Stability** @ `install.sh:304` (2/5) — `cd "$DOTFILES_ROOT"` occurs only in `do_refresh`, leaving a sourcing shell permanently chdir'd into the repo.
- **Clarity** @ `Makefile:92` (2/5) — `clean: unlink` inverts the universal convention: it deletes synced files from `$HOME` rather than build artifacts from the repo.
- **Completeness** @ `install.sh:13-18` (1/5) — The mode summary omits three real side effects of the default path: `ensure_curl`, `ensure_tilix`, and `disable_brew_analytics` (which mutates a global brew setting on every run).
- **Completeness** @ `install.sh:1` (1/5) — The 39-line header never states that zsh must already exist for the bootstrap to run, while going out of its way to auto-install curl; zsh is provisioned only by the Brewfile this script must already be running to apply.
- **Robustness (failure visibility)** @ `install.sh:96, 106, 118, 138, 142, 156, 176, 296, 327` (1/5) — Every diagnostic including "Error:" lines goes to stdout, so `make install 2>err.log` yields an empty error channel; `scripts/install-doc-tools.sh` uses `>&2` correctly.
- **Correctness (internal contradiction)** @ `Makefile:11-15` vs `89-92` (1/5) — `make install` performs its own home-dir sync outside the script the header calls "the single source of truth", so `make unlink`/`clean` cannot reverse the `cp -af` or the rc-file append.
- **Correctness (docs vs. behavior)** @ `install.sh:72` with `22-24` (1/5) — `${1:-…}` falls back on empty as well as unset, so `./install.sh ""` cannot deliberately clear an inherited `GUI_INSTALL=1`.
- **Robustness (variable scoping)** @ `install.sh:92` (1/5) — `script` is the only loop variable not declared `local` (contrast `local failed=0` one line above), so on the documented `source` path it clobbers any `script` variable in the caller's shell.

## Open Questions

- **Intended entry point.** `install.sh:5` and `README.md:6` document `source install.sh`, but the file is written as an executable zsh script (`print`, `exit`, `$0`, `cd`). Five findings above (`install.sh:41`, `:58`, `:121-127`, the nine `exit` sites, `:304`) exist only on the sourced path and vanish on the `./install.sh` path. Whether sourcing is still a supported contract, or vestigial documentation, determines whether those are bugs or dead docs — nothing in the context resolves it.
- **Target platform breadth.** Several findings (Intel macOS `/usr/local`, `/usr/bin/zsh`, fish as a login shell) assume the repo intends to support machines beyond the author's own. If the supported set is exactly "Apple Silicon macOS + Ubuntu with `$SHELL=/bin/bash`", the `detect_shell` and `BREW_ROOT` findings drop to nit. The repo states no supported-platform matrix.
- **Criteria scope.** The default criteria set contains no security category, so `curl | $SHELL`, `bash -c "$(curl …)"`, and the unpinned/unchecksummed `HEAD` fetches were evaluated only for reproducibility and stability, not for supply-chain exposure. Re-running with explicit security criteria would judge those lines differently.
- **`--interactive` behavior.** `{context}` was unresolvable from the invocation (no arguments given), so the orchestrator asked rather than guessed, even though `-i` was absent. The skill's success criteria say a non-interactive run asks no clarifying questions and surfaces ambiguities here instead — but that rule presumes a resolved `{context}`, and a required parameter with no value leaves nothing to analyze. Flagged as a genuine tension in the `/critique` prompt itself.

## Prior-art cross-reference

Two findings here were already reported by earlier critique runs committed to this
directory, and remain unfixed:

| Finding | Also reported in |
|---|---|
| `print` breaks idempotency under bash-sourced install | `repo-critique-agent-swarm-10-…-2026-07-12T21-46-35Z` (critical, 2/10, located at `install.sh:126-128` before line drift) |
| `DOTFILES_ROOT` resolves from cwd when sourced | same report (critical, 2/10, located at `README.md:6`) |
| `install.sh` has no strict error policy; reports completion after failures | `repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z` (medium) — its recommendation also flags that sourced execution needs return-aware error handling, matching this report's `exit`-in-sourced-shell finding |

The 5-run replication raised both `print` and `DOTFILES_ROOT` at 5/5 and 4/5
agreement respectively, versus 2/10 in the earlier wider swarm — consistent with a
narrower `{context}` concentrating attention rather than with any change to the
code, which is unmodified at those lines.

---

**Guardrails observed.** Analysis was read-only; no file under analysis was
modified. Findings only — no patches proposed, no edits applied, per the
`/critique` scope rule. All five runs executed in parallel as requested; no
fallback to sequential execution occurred.
