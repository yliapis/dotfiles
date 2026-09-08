---
id: TKT-046
title: >-
  Symlink sync mode is shipped but unverified against symlink-dropping skill
  discovery; backup dir and readlink details
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - sync
  - 'estimate:S'
  - critique-kimi-2026-07-26
  - critique-composer-2026-07-12
dependencies:
  - TKT-008
references:
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:66-68
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:74-76
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:100
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:148
  - 'scripts/sync-coding-tools.sh:319-358'
  - 'AGENTS.md:88-92'
priority: low
type: test
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`AGENTS.md` records that at least one shipped skill-discovery implementation drops a symlinked entry whose real path leaves the scanned directory, which is why the project mirrors are real files. `--mode symlink` links skill directories into `~/.cursor/skills`, `~/.claude/skills`, `~/.config/opencode/skills`, and `~/.agents/skills`, and the docs only say to "confirm the client still lists the skills after running it". Either that confirmation is recorded and the mode stays, or the mode goes.

### Evidence (main @ 225cbf2, 2026-09-08)

- `AGENTS.md:88-92` names the risk and asks the user to verify by hand.
- `scripts/sync-coding-tools.sh:376-382` links skill directories in symlink mode.
- `scripts/sync-coding-tools.sh:322` backup directory `ts` has one-second resolution, so two runs in one second collide; nothing prunes `~/.dotfiles-backup/` or the append-only `~/.cache/dotfiles/sync.log`.
- `scripts/sync-coding-tools.sh:345-346` compares the raw `readlink` value to `$src`, so a relative link to the same target is relinked every run.

### Provenance

Kimi 2026-07-26 (minor; open question), Composer 2026-07-12 (minor 1/10). Depends on TKT-008, which delivers the procedure for confirming a client lists skills.

### Scope

- `scripts/sync-coding-tools.sh` symlink mode and backups; `AGENTS.md` / `README.md` symlink-mode text.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Either a recorded observation (per the TKT-008 procedure) shows Cursor, Claude Code, and OpenCode listing all skills after --mode symlink, or --mode symlink and its documentation are removed
- [ ] #2 If kept: the backup directory name is unique per run, and the symlink idempotency check compares resolved paths
- [ ] #3 If kept: the header says how backups and the audit log are pruned, or that they are not
<!-- AC:END -->
