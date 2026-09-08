---
id: TKT-043
title: copy_home_config overwrites $HOME files with no backup and no reversal path
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
updated_date: '2026-09-08 21:40'
labels:
  - install
  - home-config
  - 'estimate:S'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-opus-2026-08-16
  - critique-visual-2026-07-24
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:174-180
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:145
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:211
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:219
  - 'install.sh:118-126'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:481-545'
priority: medium
type: fix
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`cp -af "$src_dir/." "$HOME/"` replaces `~/.vimrc`, `~/.tmux.conf`, `~/.shell_extras.sh`, and `~/.cursor/mcp.json` wholesale on every install with no backup, although `sync-coding-tools.sh` already has a backup convention under `~/.dotfiles-backup/<UTC-timestamp>/`. `mcp.json` is merge-worthy JSON: any MCP servers the user added locally are destroyed. Files removed from `home-config/` survive in `$HOME` forever, and `make unlink` / `make clean` cannot reverse any of it.

### Evidence (main @ 225cbf2, 2026-09-08)

- `install.sh:118-126` `copy_home_config`; `:124` prints "(overwriting)".
- `home-config/.cursor/mcp.json` is one of four managed files.
- `scripts/sync-coding-tools.sh:319-339` implements timestamped backups for symlink mode.
- `Makefile:95-98` `unlink`/`clean` only call the sync script.

### Provenance

Fable 2026-07-12 (minor), Composer 2026-07-12 (minor 1/10), Opus 2026-08-16 (divergent 2/5 and 1/5).

### Scope

- `install.sh` `copy_home_config`; header and README wording for what `make unlink` does not reverse.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Before overwriting, any pre-existing $HOME file that differs from its home-config/ source is copied to ~/.dotfiles-backup/<UTC-timestamp>/<relative-path>
- [ ] #2 The install log names each backed-up file
- [ ] #3 The header and README state that home-config/ files are overwritten (with backup) and that make unlink does not remove them
<!-- AC:END -->
