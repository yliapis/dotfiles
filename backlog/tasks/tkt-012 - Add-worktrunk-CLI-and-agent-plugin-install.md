---
id: TKT-012
title: Add worktrunk CLI and agent plugin install
status: Done
assignee: []
created_date: '2026-08-14 22:55'
updated_date: '2026-08-14 22:57'
labels: []
dependencies: []
references:
  - 'https://github.com/max-sixty/worktrunk'
  - 'https://github.com/yliapis/dotfiles/pull/73'
priority: medium
type: feat
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Follow-up to PR #73 (herdr plugin install). Add Worktrunk (https://github.com/max-sixty/worktrunk), the Homebrew-packaged git worktree CLI for parallel AI agent workflows.

Install path matches upstream (brew install worktrunk && wt config shell install) but keeps bash/zsh init in the managed shell extras file instead of mutating ~/.zshrc. Agent plugins install through scripts/install-worktrunk-plugins.sh, the same install-*.sh glob as install-herdr-plugins.sh.

Gemini extensions and the Claude statusline write user-local settings and stay as relocate notes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brewfile lists brew "worktrunk" in the development tooling / git section
- [x] #2 home-config/.shell_extras.sh inits wt for bash and zsh when wt is on PATH (wt config shell init)
- [x] #3 scripts/install-worktrunk-plugins.sh exists and matches the scripts/install-*.sh glob used by install.sh
- [x] #4 The script runs wt config plugins <target> install --yes for claude, codex, and opencode when that CLI is on PATH
- [x] #5 The script skips with exit 0 when wt is not on PATH, and skips a target when its CLI is missing
- [x] #6 shellcheck and bash -n pass on the new script; zsh -n passes on home-config/.shell_extras.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add brew "worktrunk" next to git/lazygit in the Brewfile.
2. Add a command -v wt guard and eval "$(wt config shell init "$_dotfiles_shell")" in home-config/.shell_extras.sh.
3. Add scripts/install-worktrunk-plugins.sh that skips when wt is missing, skips each target when its CLI is missing, and otherwise runs wt config plugins <target> install --yes for claude, codex, and opencode.
4. Verify with shellcheck, bash -n, zsh -n, the install.sh glob, a missing-wt skip, and a mocked wt plus mocked CLIs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-08-14 on this worktree.

- bash -n and shellcheck: clean on scripts/install-worktrunk-plugins.sh
- zsh -n: clean on home-config/.shell_extras.sh
- install.sh glob matches scripts/install-worktrunk-plugins.sh alongside install-doc-tools.sh and install-herdr-plugins.sh
- Brewfile has brew "worktrunk" at the git tooling block; formulae.brew.sh reports name=worktrunk, stable=0.74.0
- PATH without wt: skip, exit 0
- wt present, no agent CLIs: skip claude/codex/opencode, exit 0
- mocked wt + mocked claude/codex/opencode: exactly three `wt config plugins <target> install --yes` calls
- mocked wt + only claude: one claude install, skip the others
- real wt v0.74.0: `wt config shell init bash|zsh` parse clean; eval with wt on PATH defines a wt function; install script skips missing agent CLIs

Log: /opt/cursor/artifacts/worktrunk_install_tests.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added brew "worktrunk", bash/zsh wt shell init in home-config/.shell_extras.sh, and scripts/install-worktrunk-plugins.sh for Claude/Codex/OpenCode. All six acceptance criteria have runtime evidence in worktrunk_install_tests.log.
<!-- SECTION:FINAL_SUMMARY:END -->
