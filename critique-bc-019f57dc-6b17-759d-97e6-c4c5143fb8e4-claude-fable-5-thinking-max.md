# Critique: `yliapis/dotfiles` (whole repository)

**Criteria applied:** quality — clarity, correctness, completeness, robustness;
determinism — reproducibility, idempotency, stability (the repo's default
`/critique` criteria)
**Runs:** 1 (parallel up to 1, model: `claude-fable-5-thinking-max`)
**Run id:** `bc-019f57dc-6b17-759d-97e6-c4c5143fb8e4`
**Corpus:** repository root at commit `8361983` (captured 2026-07-12)

## Summary

The sync tooling (`scripts/sync-coding-tools.sh`) is the strongest artifact —
strict mode, argument validation, backups, an audit log — while the bootstrap
path (`install.sh`, `refresh.sh`, `Makefile`) is the weakest: it behaves
differently depending on which of three documented entry points is used,
swallows errors, and on the README's own invocation path corrupts `.bashrc`
idempotency. Counts: 1 critical, 9 major, 9 minor, 6 nit. The biggest concern
is that the documented `source install.sh` flow, run from bash (a shell the
script explicitly supports), silently re-appends the shell-extras block on
every run — reproduced live during this critique.

## Scope and Method

- Read in full: `install.sh`, `refresh.sh`, `Makefile`, `README.md`,
  `AGENTS.md`, `.gitignore`, `Brewfile`, `snap_installs.sh`, `scripts/*`,
  `ai-coding/scripts/sync`, all of `home-config/`, the plugin/marketplace
  manifests, `ai-coding/templates/INDEX.md`, and the frontmatter of all 9
  commands and 10 skills.
- Skimmed only: `ai-coding/parameters/` (~95 archival/generated docs),
  `ai-coding/samples/` (~45 swarm-output archives), and the full bodies of
  commands and skills (see Open Questions).
- Two findings were reproduced live in a fresh Linux environment: the
  `make help` bootstrap failure and the `.bashrc` duplicate-append under
  bash-sourcing. Brewfile entries were checked against the Homebrew formulae
  API.

## Findings

### Critical

- **Determinism / idempotency** @ `install.sh:123-128` (1/1 runs)
  - Evidence: the re-run guard greps for a marker written with zsh-only
    `print`: `print '# dotfiles: shell extras (managed by
    dotfiles/install.sh)' >> "$DEFAULT_PROFILE_FILE"`. Reproduced under bash:
    `print: command not found`, and three consecutive runs appended three
    duplicate source lines to the profile.
  - Rationale: bash is an explicitly supported shell (lines 36–38) and
    `source install.sh` is the README's documented invocation, so for any
    bash user the marker is never written, the guard never matches, and
    `~/.bashrc` grows one duplicate block per re-run.

### Major

- **Robustness (error handling)** @ `install.sh:1-151` (1/1 runs)
  - Evidence: no `set -e`/`set -u` anywhere; the script ends unconditionally
    with `echo "dotfiles install complete"`.
  - Rationale: any failed step (brew install, `cp`, modular installers) is
    swallowed and the run still reports success, which also masked the
    `print` failures above.
- **Robustness (shell detection)** @ `install.sh:33-42` (1/1 runs)
  - Evidence: `if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" =
    "/opt/homebrew/bin/zsh" ]; then ... else echo "unsupported shell
    detected: $SHELL"; exit 1`.
  - Rationale: `$SHELL` is the login shell (not the running shell), and the
    allowlist omits standard paths like `/usr/bin/zsh` (Ubuntu's default zsh
    location) and `/usr/local/bin/bash`, so supported setups are rejected
    outright.
- **Correctness (internal contradiction)** @ `install.sh:82-87` vs
  `home-config/.shell_extras.sh:9-14` (1/1 runs)
  - Evidence: `darwin*) BREW_ROOT="/opt/homebrew"` with no `/usr/local`
    branch, while `.shell_extras.sh` explicitly probes both
    `/opt/homebrew/bin/brew` and `/usr/local/bin/brew`.
  - Rationale: on Intel macOS Homebrew installs to `/usr/local`, so the
    post-install `eval "$("$BREW_ROOT/bin/brew" shellenv)"` fails on a
    platform the rest of the repo deliberately supports.
- **Determinism / reproducibility** @
  `scripts/sync-coding-tools.sh:7-8,55-56,201-205` (1/1 runs)
  - Evidence: the header and `--help` promise a "deterministic snapshot of
    the repo at sync time", but the rsync invocations
    (`rsync -aL --itemize-changes`) pass no `--delete`.
  - Rationale: files removed or renamed in the repo persist forever at the
    destinations, so the synced state depends on the history of prior runs,
    not just the current repo — contradicting the stated contract.
- **Correctness / completeness (unlink)** @
  `scripts/sync-coding-tools.sh:346-357` vs `372-375,378-385` (1/1 runs)
  - Evidence: the copy-mode removal branch requires regular files
    (`[[ -n "$src" && -f "$src" && -f "$dst" ]]`), but skills are synced as
    directories (`for d in "$SRC_SKILLS"/*(N/)`), and the plugin unlink block
    handles only the symlink case.
  - Rationale: `--unlink` after a copy-mode sync silently leaves every skill
    directory and the plugin directory in place, contradicting the documented
    behavior "remove copies that match the repo sources".
- **Clarity / correctness (duplicate implementations)** @
  `ai-coding/scripts/sync:131-135` vs `scripts/sync-coding-tools.sh:135` and
  `Makefile:6-9` (1/1 runs)
  - Evidence: `ai-coding/scripts/sync` maps `cursor:skill` to
    `$HOME/.cursor/skills` while `sync-coding-tools.sh` uses
    `$HOME/.cursor/skills-cursor`; the Makefile calls `sync-coding-tools.sh`
    "the single source of truth"; no entry point references
    `ai-coding/scripts/sync`.
  - Rationale: two shipped sync implementations disagree on the Cursor skills
    destination, so which home layout is authoritative cannot be determined
    from the repo.
- **Robustness (bootstrap ordering)** @ `Makefile:11-12`, `README.md:12-15`,
  `AGENTS.md:8-9` (1/1 runs)
  - Evidence: `SHELL := /bin/zsh`; reproduced on a fresh Linux box:
    `make help` → `make: /bin/zsh: No such file or directory ... Error 127`.
    zsh is only installed via the Brewfile (`brew "zsh"`), which
    `install.sh:95-100` skips on Linux unless `GUI_INSTALL=1`.
  - Rationale: the entry point both README and AGENTS.md tell users to run
    first fails on any machine without `/bin/zsh`, and the repo's own install
    flow never installs zsh on the default Linux path — a circular
    dependency, even though `make help` needs nothing beyond POSIX sh.
- **Robustness (shell startup errors)** @ `home-config/.shell_extras.sh:27-32`
  with `install.sh:95-100,113,131` (1/1 runs)
  - Evidence: `source <(fzf --"$_dotfiles_shell")` and
    `eval "$(starship init "$_dotfiles_shell")"` run unguarded, yet fzf and
    starship come only from the Brewfile, which is skipped on Linux without
    `GUI_INSTALL=1`; install.sh still copies the file and wires it into the
    profile.
  - Rationale: on the default Linux path every new interactive shell emits
    `command not found` errors from the managed snippet.
- **Correctness / robustness** @ `refresh.sh:15-26` (1/1 runs)
  - Evidence: no `set -e`; `brew bundle --file="$DOTFILES_ROOT/Brewfile"` and
    `brew upgrade --cask --greedy` run unconditionally, with no OS or
    `GUI_INSTALL` gate.
  - Rationale: this contradicts `install.sh`'s explicit "skipped on non-macOS
    unless GUI_INSTALL=1" gate, and on Linux the cask upgrade fails while the
    script continues and exits with whatever the last step returned, masking
    partial failure.

### Minor

- **Correctness (inconsistent gating)** @ `install.sh:63-69` vs
  `install.sh:94-100` (1/1 runs)
  - Evidence: `sudo apt-get install tilix` (a GUI terminal emulator) runs
    unconditionally on Linux, without `-y`, while GUI installs from the
    Brewfile are gated behind `GUI_INSTALL=1`.
  - Rationale: the GUI gate is applied inconsistently, and the missing `-y`
    blocks unattended runs at an interactive prompt.
- **Robustness (portability)** @ `install.sh:54` (1/1 runs)
  - Evidence: `sudo apt install --update curl`.
  - Rationale: `--update` is only accepted by recent apt (2.8.3 accepts it),
    so on older still-supported releases the curl bootstrap fails at the
    exact moment it is needed.
- **Robustness (edge case)** @ `scripts/sync-coding-tools.sh:201` vs `284`
  (1/1 runs)
  - Evidence: copy mode globs `"$SRC_COMMANDS"/*.md` without the `(N)`
    nullglob qualifier that symlink mode uses (`*.md(N)`).
  - Rationale: an empty commands directory aborts copy mode with zsh's "no
    matches found" under `set -e`, while symlink mode handles the same case
    cleanly.
- **Completeness (documentation)** @ `README.md:1-16` (1/1 runs)
  - Evidence: the entire README documents only `source install.sh` and
    `make help`; `GUI_INSTALL`, `INSTALL_OLLAMA`, `CLEAR_CACHE`,
    `RERUN_INSTALL`, `REFRESH_BREWFILE`, and `REFRESH_SCRIPTS` appear nowhere
    user-facing.
  - Rationale: every behavioral knob of the two main scripts is discoverable
    only by reading their source.
- **Completeness (orphaned script)** @ `snap_installs.sh:1-11` (1/1 runs)
  - Evidence: no reference from `install.sh`, `refresh.sh`, `Makefile`, or
    `README.md` (only a historical diff under `ai-coding/samples/`);
    `refresh.sh:41-42` still says `# TODO: add snap refresh script`; also
    `[ -z $SNAP_PATH ]` is unquoted.
  - Rationale: the script is unreachable from any documented flow, and the
    unquoted test only works by accident of `test`'s one-argument semantics.
- **Robustness (destructive overwrite)** @ `install.sh:102-110` with
  `home-config/.cursor/mcp.json` (1/1 runs)
  - Evidence: `cp -af "$src_dir/." "$HOME/"` — documented as "(overwrites)" —
    replaces `~/.cursor/mcp.json` wholesale.
  - Rationale: any MCP servers the user added locally are silently destroyed
    on each install; a merge-worthy JSON config is treated like an
    overwrite-safe dotfile.
- **Determinism / stability** @ `install.sh:81,147` and `.gitignore:1-2`
  (1/1 runs)
  - Evidence: `bash -c "$(curl -fsSL .../Homebrew/install/HEAD/install.sh)"`,
    `curl -fsSL https://ollama.com/install.sh | $SHELL`, and
    `Brewfile.lock.json` deliberately gitignored ("we don't necessarily want
    to pin versions").
  - Rationale: installed state depends on remote HEAD content and latest
    package versions at run time — a documented trade-off for the lockfile,
    but the ollama pipe additionally runs a remote script under whatever
    `$SHELL` happens to be instead of the `sh` it targets.
- **Correctness (duplicate entry)** @ `Brewfile:26-27` (1/1 runs)
  - Evidence: `brew "gpg"` and `brew "gpg2"` — both are aliases of the
    `gnupg` formula (verified against the Homebrew formulae API).
  - Rationale: the same package is listed twice under different names, which
    obscures intent and makes `brew bundle cleanup` reasoning harder.
- **Robustness (platform gating)** @ `Brewfile:66` vs `118-198` (1/1 runs)
  - Evidence: only `net-tools` carries an OS guard (`if OS.linux?`); the
    `mas` formula and ~40 casks are unguarded, yet `install.sh:95` runs this
    file on Linux whenever `GUI_INSTALL=1`.
  - Rationale: the one documented way to get GUI tooling on Linux feeds
    macOS-only entries to brew, so the path exists but cannot deliver most of
    what the section promises.

### Nit

- **Clarity (typo)** @ `install.sh:3` — Evidence:
  `echo "begining dotfiles install"`. Rationale: misspelling of "beginning"
  in the first line of user-facing output. (1/1 runs)
- **Clarity (stale comment)** @ `Makefile:1-4` — Evidence: the header
  enumerates targets but omits `sync-claude`, `symlink-cursor`, and
  `symlink-claude`, which exist at lines 43–53. Rationale: the
  self-description drifted from the target list it claims to summarize.
  (1/1 runs)
- **Completeness (stale metadata)** @ `ai-coding/marketplace.json:12` and
  `plugins/ai-coding/.plugin/plugin.json` — Evidence: "Skills and commands
  for AI-assisted coding (conventional-commits, meta-prompt)." Rationale: the
  catalog now holds 9 commands and 10 skills, so the two named examples
  misrepresent scope. (1/1 runs)
- **Correctness (inconsistent frontmatter)** @
  `ai-coding/skills/trajectory-snapshot/SKILL.md:1-4` and
  `worktree-task/SKILL.md:1-4` — Evidence: both lack the `license: MIT` field
  present in the other eight skills' frontmatter. Rationale: metadata
  conventions are applied inconsistently across the skill set. (1/1 runs)
- **Robustness (terminfo)** @ `home-config/.tmux.conf:2` — Evidence:
  `set -g default-terminal "xterm-256color"`. Rationale: tmux documentation
  expects `tmux-256color`/`screen-256color` inside tmux; `xterm-*` can
  degrade key handling and italics in some terminals. (1/1 runs)
- **Completeness (orphaned doc)** @ `prompts/editorial-standards.md` —
  Evidence: repo-wide search finds no reference to `prompts/` or
  `editorial-standards` from any command, skill, script, or doc. Rationale: a
  138-line style guide is unreachable from every documented flow, so its
  intended consumer is unclear. (1/1 runs)

## Open Questions

- **Coverage gap:** `ai-coding/parameters/` (~95 archival/generated docs),
  `ai-coding/samples/` (~45 swarm-output archives), and the full bodies of
  the 9 commands and 10 skills were skimmed for metadata consistency only,
  not exhaustively analyzed; a dedicated run on those trees may surface
  additional findings.
- **brew-bundle cask behavior on Linux** could not be verified in the
  analysis environment (no Homebrew installed), so whether `GUI_INSTALL=1` on
  Linux fails hard or merely skips the ~40 cask entries is unconfirmed; this
  affects the severity of the related minor finding.
- **Minimum apt version for `apt install --update`** was not confirmed beyond
  the analysis environment's apt 2.8.3 accepting it; the finding assumes
  older apt releases reject the flag.
- **Canonical Cursor skills destination** (`~/.cursor/skills-cursor` vs
  `~/.cursor/skills`) cannot be determined from the repo alone; resolving the
  duplicate-sync-implementation finding requires deciding which mapping
  current Cursor builds actually read.
