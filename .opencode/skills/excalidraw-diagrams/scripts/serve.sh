#!/usr/bin/env bash
# Ensure the excalidraw MCP server is serving.
#
# Usage: serve.sh [TIMEOUT_SECONDS]   (default 900 — first run builds the server)
# Env:   PORT (default 3001)
#        EXCALIDRAW_AGENT_ROOT — checkout of yliapis/excalidraw-agent that
#        vendors third_party/excalidraw-mcp and exposes `make run`.
#
# Idempotent: exits 0 immediately if the server already responds. Otherwise
# starts `make run` in a background tmux session (fallback: nohup) and waits.
set -euo pipefail

PORT="${PORT:-3001}"
URL="http://localhost:${PORT}/mcp"
TIMEOUT="${1:-900}"
SESSION="excalidraw-mcp-server"
LOG="/tmp/excalidraw-mcp-server.log"

resolve_agent_root() {
  if [ -n "${EXCALIDRAW_AGENT_ROOT:-}" ]; then
    printf '%s\n' "$EXCALIDRAW_AGENT_ROOT"
    return 0
  fi

  local candidate toplevel sibling
  for candidate in "$PWD" "$(pwd -P)"; do
    if [ -f "$candidate/Makefile" ] && [ -d "$candidate/third_party/excalidraw-mcp" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    if [ -f "$toplevel/Makefile" ] && [ -d "$toplevel/third_party/excalidraw-mcp" ]; then
      printf '%s\n' "$toplevel"
      return 0
    fi
    sibling="$(dirname -- "$toplevel")/excalidraw-agent"
    if [ -f "$sibling/Makefile" ] && [ -d "$sibling/third_party/excalidraw-mcp" ]; then
      printf '%s\n' "$sibling"
      return 0
    fi
  fi

  for candidate in \
    "$HOME/src/excalidraw-agent" \
    "$HOME/excalidraw-agent"; do
    if [ -f "$candidate/Makefile" ] && [ -d "$candidate/third_party/excalidraw-mcp" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

probe() {
  curl -s -m 5 -X POST "$URL" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"serve-probe","version":"1.0.0"}}}' \
    2>/dev/null | grep -q '"serverInfo"'
}

if probe; then
  echo "excalidraw MCP already serving at $URL"
  exit 0
fi

if ! REPO_ROOT="$(resolve_agent_root)"; then
  echo "error: cannot find excalidraw-agent checkout (needs Makefile + third_party/excalidraw-mcp)" >&2
  echo "hint: clone https://github.com/yliapis/excalidraw-agent and set EXCALIDRAW_AGENT_ROOT" >&2
  exit 1
fi

if command -v tmux >/dev/null 2>&1; then
  TMUX=(tmux)
  [ -f /exec-daemon/tmux.portal.conf ] && TMUX=(tmux -f /exec-daemon/tmux.portal.conf)
  if "${TMUX[@]}" has-session -t "=$SESSION" 2>/dev/null; then
    echo "tmux session '$SESSION' already exists — waiting for it to come up (it may still be building)"
  else
    echo "Starting excalidraw MCP server ('make run' in tmux session '$SESSION' from $REPO_ROOT)..."
    "${TMUX[@]}" new-session -d -s "$SESSION" -c "$REPO_ROOT" -- "${SHELL:-bash}" -l
    "${TMUX[@]}" send-keys -t "$SESSION:0.0" "PORT=$PORT make run 2>&1 | tee $LOG" C-m
  fi
else
  echo "Starting excalidraw MCP server ('make run' via nohup from $REPO_ROOT; log: $LOG)..."
  (cd "$REPO_ROOT" && PORT="$PORT" nohup make run >"$LOG" 2>&1 &)
fi

echo "First run bootstraps pnpm/node and builds the server — this can take several minutes."
for i in $(seq 1 "$TIMEOUT"); do
  if probe; then
    echo "excalidraw MCP serving at $URL"
    exit 0
  fi
  if [ $((i % 15)) -eq 0 ]; then
    echo "  waiting (${i}s): $(tail -n 1 "$LOG" 2>/dev/null | tr -d '\r' | cut -c1-120)"
  fi
  sleep 1
done

echo "error: server did not come up within ${TIMEOUT}s — check $LOG" >&2
echo "hint: a stuck session can be reset with: tmux kill-session -t $SESSION" >&2
exit 1
