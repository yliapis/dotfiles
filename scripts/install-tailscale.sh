#!/usr/bin/env bash
# install-tailscale.sh — Linux Tailscale via the official installer
# (https://tailscale.com/install.sh). On Ubuntu/Debian that script adds
# Tailscale's apt repo and installs the package. Idempotent; safe to
# re-run from install.sh (picked up by the scripts/install-*.sh glob).
# macOS uses the Brewfile cask tailscale-app instead.

set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "[install-tailscale] not Linux; skipping (macOS uses Brewfile cask tailscale-app)"
  exit 0
fi

if command -v tailscale >/dev/null 2>&1; then
  echo "[install-tailscale] tailscale already on PATH; skipping"
  exit 0
fi

echo "[install-tailscale] installing via https://tailscale.com/install.sh"
curl -fsSL https://tailscale.com/install.sh | sh
