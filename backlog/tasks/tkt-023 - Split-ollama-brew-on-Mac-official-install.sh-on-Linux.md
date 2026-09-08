---
id: TKT-023
title: 'Split ollama: brew on Mac, official install.sh on Linux'
status: Done
assignee: []
created_date: '2026-09-08 04:18'
updated_date: '2026-09-08 04:18'
labels: []
dependencies: []
references:
  - 'https://ollama.com/install.sh'
  - 'https://formulae.brew.sh/formula/ollama'
  - 'https://github.com/Homebrew/homebrew-core/issues/260946'
priority: medium
type: feat
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split ollama install like llama.cpp and Tailscale: Homebrew formula on macOS (Metal on Apple Silicon), official https://ollama.com/install.sh on Linux (NVIDIA CUDA). Remove the opt-in all-OS ensure_ollama path so Mac brew and the Linux script do not fight.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brewfile has brew "ollama" if OS.mac? and no unguarded ollama formula or ollama-app cask
- [x] #2 scripts/install-ollama.sh exists and matches the scripts/install-*.sh glob used by install.sh
- [x] #3 The Linux script runs curl -fsSL https://ollama.com/install.sh | sh
- [x] #4 The script skips with exit 0 on non-Linux (macOS uses Brewfile)
- [x] #5 The script skips with exit 0 when ollama is already on PATH
- [x] #6 install.sh no longer runs the all-OS official installer or honors INSTALL_OLLAMA
- [x] #7 shellcheck and bash -n pass on the new script; zsh -n passes on install.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add brew "ollama" if OS.mac? next to llama.cpp.
2. Add scripts/install-ollama.sh matching install-llama.cpp.sh / install-tailscale.sh.
3. Remove INSTALL_OLLAMA and ensure_ollama from install.sh.
4. Document the split in manage-packages managers.md and regenerate mirrors.
5. Verify shellcheck, Brewfile OS-gate eval, skip paths, and the official installer URL.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-09-08 on this Linux cloud VM (no NVIDIA GPU). Live official installer was not run: it needs root and a systemd unit.

- AC1: Brewfile:106 is brew "ollama" if OS.mac?; no unguarded formula; no ollama-app cask; no extra tap. formulae.brew.sh: name=ollama tap=homebrew/core disabled=false deprecated=false stable=0.33.3; bottles include arm64_sonoma/sequoia/tahoe and linux. cask ollama=404; cask ollama-app exists and was not added. Mock OS eval: mac requests ollama, linux does not.
- AC2: scripts/install-*.sh glob includes install-ollama.sh
- AC3: script line is curl -fsSL https://ollama.com/install.sh | sh
- AC4: mocked uname -s Darwin -> skip, exit 0
- AC5: fake ollama on PATH -> skip, exit 0
- AC6: install.sh has no INSTALL_OLLAMA, ensure_ollama, or ollama.com
- AC7: bash -n and shellcheck clean on scripts/install-ollama.sh; zsh -n clean on install.sh
- Official install.sh (15902 bytes) detects NVIDIA via nvidia-smi/lspci/lshw and prints NVIDIA GPU installed
- make mirrors-check: in_sync=106

Log: /opt/cursor/artifacts/ollama_install_split_verify.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Gated brew ollama to macOS and added scripts/install-ollama.sh so Linux uses https://ollama.com/install.sh. Removed the all-OS INSTALL_OLLAMA path. All seven acceptance criteria have runtime evidence in ollama_install_split_verify.log.
<!-- SECTION:FINAL_SUMMARY:END -->
