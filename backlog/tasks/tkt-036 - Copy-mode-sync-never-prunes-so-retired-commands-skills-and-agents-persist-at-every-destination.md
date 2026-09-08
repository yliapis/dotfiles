---
id: TKT-036
title: >-
  Copy-mode sync never prunes, so retired commands, skills, and agents persist
  at every destination
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - sync
  - 'estimate:M'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-kimi-2026-07-26
  - critique-gpt-2026-07-31
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:83-90
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:78-85
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:202-206
  - >-
    docs/reports/repo-critique-moonshotai-kimi-k3-2026-07-26T21-59-17Z-618ef9cd.md:32-34
  - >-
    docs/reports/repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z.md:31-35
  - 'scripts/sync-coding-tools.sh:7-9'
  - 'scripts/sync-coding-tools.sh:79'
  - 'scripts/sync-coding-tools.sh:247'
priority: medium
type: fix
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The header calls copy mode "deterministic, source-of-truth is the dotfiles repo at the moment of the last run" and the usage says "Idempotent", but `rsync -aL --itemize-changes` carries no pruning. Anything deleted or renamed under `ai-coding/plugins/` stays discoverable in `~/.cursor`, `~/.claude`, `~/.config/opencode`, and `~/.agents` forever, so destination state depends on sync history rather than the checked-out tree. `--unlink` cannot clean it because it iterates current sources only.

### Evidence (main @ 225cbf2, 2026-09-08)

- `scripts/sync-coding-tools.sh:247` `RSYNC_BASE=(rsync -aL --itemize-changes)`; no `--delete`, no manifest.
- Reproduced: after a copy sync, a planted `~/.cursor/commands/retired-command.md` and `~/.cursor/skills/retired-skill/` both survived a re-sync.
- `scripts/sync-coding-tools.sh:7-9` and `:79` state the deterministic / idempotent contract.
- `~/.cursor/commands` and `~/.cursor/skills` may also hold the user's own files, so a blanket `rsync --delete` would destroy content this repo never wrote (GPT recommendation: manifest-owned namespace, prune only owned entries).

### Provenance

Fable 2026-07-12 (major), Composer 2026-07-12 (major, 2/10, recommendation #2), Kimi 2026-07-26 (major), GPT 2026-07-31 (high, remediation step 2).

### Scope

- `scripts/sync-coding-tools.sh` copy mode. A manifest of synced paths (for example under `~/.cache/dotfiles/`) also serves the `--unlink` ticket.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After deleting a plugin command, skill directory, or agent file from ai-coding/plugins/ and re-running copy sync, the corresponding destination entry is removed at every selected target
- [ ] #2 Files at the same destination directories that this repo never wrote are left untouched (verified with a planted foreign file)
- [ ] #3 The header and usage wording describe the pruning rule and its ownership boundary
<!-- AC:END -->
