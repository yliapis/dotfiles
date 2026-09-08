#!/usr/bin/env bash
# install-ollama.sh — Linux Ollama via the official installer
# (https://ollama.com/install.sh). That script installs the NVIDIA
# CUDA-capable build. Idempotent; safe to re-run from install.sh
# (picked up by the scripts/install-*.sh glob). macOS uses Brewfile
# brew "ollama" (Metal on Apple Silicon).

set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "[install-ollama] not Linux; skipping (macOS uses Brewfile brew \"ollama\")"
  exit 0
fi

if command -v ollama >/dev/null 2>&1; then
  echo "[install-ollama] ollama already on PATH; skipping"
  exit 0
fi

echo "[install-ollama] installing via https://ollama.com/install.sh"
curl -fsSL https://ollama.com/install.sh | sh
