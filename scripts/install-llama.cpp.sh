#!/usr/bin/env bash
# install-llama.cpp.sh — Linux llama.cpp via the official installer
# (https://llama.app/install.sh). That script probes CUDA first, then
# ROCm, Vulkan, and CPU, and installs the matching prebuilt `llama`
# binary. Idempotent; safe to re-run from install.sh (picked up by the
# scripts/install-*.sh glob). macOS uses Brewfile brew "llama.cpp".

set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "[install-llama.cpp] not Linux; skipping (macOS uses Brewfile brew \"llama.cpp\")"
  exit 0
fi

if command -v llama >/dev/null 2>&1; then
  echo "[install-llama.cpp] llama already on PATH; skipping"
  exit 0
fi

echo "[install-llama.cpp] installing via https://llama.app/install.sh"
curl -LsSf https://llama.app/install.sh | sh
