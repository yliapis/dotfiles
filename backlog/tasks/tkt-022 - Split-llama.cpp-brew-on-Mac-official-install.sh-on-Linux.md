---
id: TKT-022
title: 'Split llama.cpp: brew on Mac, official install.sh on Linux'
status: In Progress
assignee: []
created_date: '2026-09-08 04:02'
updated_date: '2026-09-08 04:02'
labels: []
dependencies: []
references:
  - 'https://llama.app/docs/installation'
  - 'https://llama.app/install.sh'
  - 'https://github.com/ggml-org/llama-install.sh'
priority: medium
type: feat
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split llama.cpp install: keep Homebrew on macOS, and on Linux use the official llama.app/install.sh (https://github.com/ggml-org/llama-install.sh). That installer probes CUDA first, then ROCm, Vulkan, and CPU, and installs the matching prebuilt llama binary to ~/.local/bin. Same pattern as scripts/install-tailscale.sh.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Brewfile has brew "llama.cpp" if OS.mac? and no unguarded llama.cpp formula
- [ ] #2 scripts/install-llama.cpp.sh exists and matches the scripts/install-*.sh glob used by install.sh
- [ ] #3 The Linux script runs curl -LsSf https://llama.app/install.sh | sh (official CUDA-probing installer)
- [ ] #4 The script skips with exit 0 on non-Linux (macOS uses Brewfile)
- [ ] #5 The script skips with exit 0 when llama is already on PATH
- [ ] #6 shellcheck and bash -n pass on the new script
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Gate Brewfile brew "llama.cpp" with if OS.mac?.
2. Add scripts/install-llama.cpp.sh matching install-tailscale.sh: skip non-Linux, skip when llama is on PATH, otherwise curl -LsSf https://llama.app/install.sh | sh.
3. Document the split in manage-packages managers.md and regenerate mirrors.
4. Verify shellcheck, Brewfile OS-gate eval, skip paths, and a live official installer run on Linux.
<!-- SECTION:PLAN:END -->
