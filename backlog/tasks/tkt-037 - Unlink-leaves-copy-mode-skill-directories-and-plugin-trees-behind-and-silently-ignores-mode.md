---
id: TKT-037
title: >-
  Unlink leaves copy-mode skill directories and plugin trees behind, and
  silently ignores --mode
status: To Do
assignee: []
created_date: '2026-09-08 19:31'
labels:
  - sync
  - 'estimate:S'
  - critique-fable-2026-07-12
  - critique-composer-2026-07-12
  - critique-gpt-2026-07-31
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:91-99
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:86-93
  - >-
    docs/reports/repo-critique-agent-swarm-10-composer-2.5-fast-2026-07-12T21-46-35Z-bc-019f5848.md:157
  - >-
    docs/reports/repo-critique-openai-gpt-5.6-terra-pro-2026-07-31T23-24-17Z.md:37-41
  - 'scripts/sync-coding-tools.sh:94-97'
  - 'scripts/sync-coding-tools.sh:441-513'
  - 'scripts/sync-coding-tools.sh:522'
priority: medium
type: fix
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The copy-mode branch of `unlink_one` only removes regular files (`-f "$src" && -f "$dst"`), but skills are synced as directories, and the plugin block handles only a symlinked plugin directory. The advertised reverse operation therefore cannot restore a clean prior state after a copy sync. `--unlink` also takes precedence over `--mode` without saying so.

### Evidence (main @ 225cbf2, 2026-09-08)

- Reproduced: copy sync then `--unlink --targets cursor` left 18 skill directories and `~/.cursor/plugins/local/ai-coding` in place (commands were removed).
- `scripts/sync-coding-tools.sh:453-462` copy-mode removal requires `-f`; `:505-512` plugin unlink handles `-L` only.
- `scripts/sync-coding-tools.sh:94-97` usage: "remove copies that match the repo sources, restoring from the newest backup".
- `scripts/sync-coding-tools.sh:522` the `UNLINK` branch runs first regardless of `MODE`; usage does not document that `--mode` is ignored with `--unlink`.

### Provenance

Fable 2026-07-12 (major), Composer 2026-07-12 (major, 2/10; nit 1/10), GPT 2026-07-31 (high, remediation step 2).

### Scope

- `scripts/sync-coding-tools.sh` `unlink_one`, `unlink_tool`, usage text. Reuse the ownership manifest from the prune ticket if it lands first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After a copy sync, --unlink removes every synced skill directory whose contents match the source (diff -r or manifest) and the copied plugin tree, and restores backups where they exist
- [ ] #2 A destination skill directory that differs from its source is left in place and reported, matching the existing file rule
- [ ] #3 Usage text states how --unlink interacts with --mode, or the combination is rejected with exit 2
<!-- AC:END -->
