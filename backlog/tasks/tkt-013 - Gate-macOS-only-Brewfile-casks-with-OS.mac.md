---
id: TKT-013
title: Gate macOS-only Brewfile casks with OS.mac?
status: Done
assignee: []
created_date: '2026-08-16 17:10'
updated_date: '2026-08-16 17:11'
labels: []
dependencies: []
priority: medium
type: feat
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
GUI_INSTALL=1 make install on Linux still evaluates every macOS GUI cask. Homebrew then prints Skipping cask <name> (requires macOS) for each one (Arc, browsers, Slack, Docker Desktop, iTerm2, and the rest of the GUI list).

Add an if OS.mac? gate on those macOS-only casks so Linux brew bundle never requests them. Keep Linux-capable CLI casks unguarded: claude-code, codex, cursor, devin-cli, gcloud-cli, font-jetbrains-mono-nerd-font.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every macOS-only GUI cask in Brewfile is behind if OS.mac? (postfix or block)
- [x] #2 Linux-capable CLI casks stay unguarded: claude-code, codex, cursor, devin-cli, gcloud-cli, font-jetbrains-mono-nerd-font
- [x] #3 Existing formula and tap OS gates stay (telnet, net-tools, tailscale, whatcable tap)
- [x] #4 A Linux Brewfile evaluation does not request the GUI casks that currently print Skipping cask (requires macOS)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add if OS.mac? to every macOS-only GUI cask and to cask_args appdir.
2. Leave Linux-capable CLI casks and all formulas as they are.
3. Evaluate the Brewfile with a mock OS.mac?/OS.linux? DSL on Linux and macOS and compare requested casks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-08-16 on this worktree with a mock Brewfile DSL that honors postfix if OS.mac? / if OS.linux?.

- AC1: every GUI cask from the Linux skip list has if OS.mac?; cask_args appdir is also gated
- AC2: unguarded casks are exactly claude-code, codex, cursor, devin-cli, gcloud-cli, font-jetbrains-mono-nerd-font
- AC3: telnet (mac), net-tools (linux), tailscale formula (linux), tailscale-app (mac), whatcable tap+cask (mac) unchanged
- AC4: Linux evaluation requests none of the GUI casks; main still requested all of them

Logs: /opt/cursor/artifacts/brewfile_os_gate_eval.log, /opt/cursor/artifacts/brewfile_os_gate_before_after.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Gated macOS-only Brewfile casks with if OS.mac? so Linux GUI_INSTALL=1 no longer requests GUI apps. Linux-capable CLI casks stay unguarded. All four acceptance criteria have runtime evidence in brewfile_os_gate_eval.log.
<!-- SECTION:FINAL_SUMMARY:END -->
