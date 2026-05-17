#!/usr/bin/env bash
# install-doc-tools.sh — Python CLI tools that convert documents to Markdown
# for LLM/RAG pipelines. Idempotent; safe to re-run from install.sh and refresh.sh.

set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
  echo "[install-doc-tools] uv not found on PATH; skipping (install Brewfile first)"
  exit 0
fi

echo "[install-doc-tools] installing doc->markdown CLI tools via uv"

# Docling (IBM, MIT) — primary PDF->MD engine; best 2026 benchmark
uv tool install --upgrade docling

# MarkItDown (Microsoft, MIT) — broadest format coverage (Office/audio/YT/etc.)
uv tool install --upgrade 'markitdown[all]'

# Marker (datalab-to, GPL) — opt-in; max-accuracy fallback, pulls ~2GB of
# PyTorch + Surya models on first run. Uncomment if you regularly hit
# tough PDFs where docling struggles.
# uv tool install --upgrade marker-pdf
