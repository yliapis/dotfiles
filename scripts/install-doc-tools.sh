#!/usr/bin/env bash
# install-doc-tools.sh — Python CLI tools that convert documents to Markdown
# for LLM/RAG pipelines. Idempotent; safe to re-run from install.sh.

set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
  echo "[install-doc-tools] uv not found on PATH; skipping (install Brewfile first)"
  exit 0
fi

echo "[install-doc-tools] installing doc->markdown CLI tools via uv"

install_uv_tool() {
  local spec="$1"
  if uv tool install --upgrade "$spec"; then
    return 0
  fi
  echo "[install-doc-tools] failed: uv tool install --upgrade $spec" >&2
  echo "[install-doc-tools] if Permission denied under ~/.local/share/uv/tools, reclaim with: sudo chown -R \"$USER\" \"$HOME/.local/share/uv/tools\"" >&2
  return 1
}

failed=0
# Docling (IBM, MIT) — primary PDF->MD engine; best 2026 benchmark.
# CLI entrypoint lives in `docling-slim` (depends on `docling` library).
install_uv_tool docling-slim || failed=1

# MarkItDown (Microsoft, MIT) — broadest format coverage (Office/audio/YT/etc.)
install_uv_tool 'markitdown[all]' || failed=1

# gpustat (wookayin, MIT) — NVIDIA GPU status/usage monitor.
install_uv_tool gpustat || failed=1

# Marker (datalab-to, GPL) — opt-in; max-accuracy fallback, pulls ~2GB of
# PyTorch + Surya models on first run. Uncomment if you regularly hit
# tough PDFs where docling struggles.
# install_uv_tool marker-pdf || failed=1
exit "$failed"
