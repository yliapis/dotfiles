---
id: TKT-022
title: 'Split llama.cpp: brew on Mac, official install.sh on Linux'
status: Done
assignee: []
created_date: '2026-09-08 04:02'
updated_date: '2026-09-08 04:03'
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
- [x] #1 Brewfile has brew "llama.cpp" if OS.mac? and no unguarded llama.cpp formula
- [x] #2 scripts/install-llama.cpp.sh exists and matches the scripts/install-*.sh glob used by install.sh
- [x] #3 The Linux script runs curl -LsSf https://llama.app/install.sh | sh (official CUDA-probing installer)
- [x] #4 The script skips with exit 0 on non-Linux (macOS uses Brewfile)
- [x] #5 The script skips with exit 0 when llama is already on PATH
- [x] #6 shellcheck and bash -n pass on the new script
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Gate Brewfile brew "llama.cpp" with if OS.mac?.
2. Add scripts/install-llama.cpp.sh matching install-tailscale.sh: skip non-Linux, skip when llama is on PATH, otherwise curl -LsSf https://llama.app/install.sh | sh.
3. Document the split in manage-packages managers.md and regenerate mirrors.
4. Verify shellcheck, Brewfile OS-gate eval, skip paths, and a live official installer run on Linux.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-09-08 on this Linux cloud VM (no NVIDIA GPU/CUDA toolkit).

- AC1: Brewfile:105 is brew "llama.cpp" if OS.mac?; no unguarded formula; no llama tap
- AC2: scripts/install-*.sh glob includes install-llama.cpp.sh
- AC3: script line is curl -LsSf https://llama.app/install.sh | sh; official script defines probe_cuda() first on Linux
- AC4: mocked uname -s Darwin -> skip, exit 0
- AC5: fake llama on PATH -> skip, exit 0; rerun after live install also skips
- AC6: bash -n and shellcheck clean
- Live install: official script probed CUDA, then ROCm, Vulkan, then CPU (avx/avx2/avx512). Installed llama 0.4.0-dev build 10826 to ~/.local/bin/llama. llama version and llama cli --help succeeded.
- make mirrors-check: in_sync=106

Log: /opt/cursor/artifacts/llama_cpp_install_split_verify.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Gated brew llama.cpp to macOS and added scripts/install-llama.cpp.sh so Linux uses https://llama.app/install.sh. That official installer probes CUDA first, then ROCm, Vulkan, and CPU. All six acceptance criteria have runtime evidence in llama_cpp_install_split_verify.log.
<!-- SECTION:FINAL_SUMMARY:END -->
