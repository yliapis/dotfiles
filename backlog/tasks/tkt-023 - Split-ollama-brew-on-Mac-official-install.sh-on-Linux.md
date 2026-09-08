---
id: TKT-023
title: 'Split ollama: brew on Mac, official install.sh on Linux'
status: In Progress
assignee: []
created_date: '2026-09-08 04:18'
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
- [ ] #1 Brewfile has brew "ollama" if OS.mac? and no unguarded ollama formula or ollama-app cask
- [ ] #2 scripts/install-ollama.sh exists and matches the scripts/install-*.sh glob used by install.sh
- [ ] #3 The Linux script runs curl -fsSL https://ollama.com/install.sh | sh
- [ ] #4 The script skips with exit 0 on non-Linux (macOS uses Brewfile)
- [ ] #5 The script skips with exit 0 when ollama is already on PATH
- [ ] #6 install.sh no longer runs the all-OS official installer or honors INSTALL_OLLAMA
- [ ] #7 shellcheck and bash -n pass on the new script; zsh -n passes on install.sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add brew "ollama" if OS.mac? next to llama.cpp.
2. Add scripts/install-ollama.sh matching install-llama.cpp.sh / install-tailscale.sh.
3. Remove INSTALL_OLLAMA and ensure_ollama from install.sh.
4. Document the split in manage-packages managers.md and regenerate mirrors.
5. Verify shellcheck, Brewfile OS-gate eval, skip paths, and the official installer URL.
<!-- SECTION:PLAN:END -->
