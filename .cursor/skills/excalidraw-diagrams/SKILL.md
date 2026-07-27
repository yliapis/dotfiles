---
name: excalidraw-diagrams
description: Generate hand-drawn Excalidraw diagrams (architecture, flowcharts, sequence diagrams, sketches) with the excalidraw MCP server. Use when asked to draw, diagram, sketch, visualize, or update anything with Excalidraw or "this MCP", or to produce committable .svg/.excalidraw/.png diagram files or excalidraw.com share links. Covers starting the server, the read_me → create_view tool flow, checkpoint-based edits, and headless export.
---

# Drawing diagrams with the excalidraw MCP

Uses the [excalidraw MCP](https://github.com/excalidraw/excalidraw-mcp) served at `http://localhost:3001/mcp` (stateless streamable HTTP; `PORT` env overrides). Runtime build/serve lives in the sibling [excalidraw-agent](https://github.com/yliapis/excalidraw-agent) checkout (`EXCALIDRAW_AGENT_ROOT` overrides discovery). Model-facing tools:

| Tool | Purpose |
| --- | --- |
| `read_me` | Returns the authoritative element-format cheat sheet. Call once, before drawing. |
| `create_view` | Renders a diagram from `elements` — a JSON array passed **as a string**. Returns a `checkpointId`. |
| `export_to_excalidraw` | Uploads a serialized `.excalidraw` scene, returns an excalidraw.com share URL. |

`save_checkpoint` and `read_checkpoint` are widget-internal — never call them directly.

Script paths below are relative to this skill directory (project mirror: `.cursor/skills/excalidraw-diagrams/`; after `make sync`: `~/.cursor/skills/excalidraw-diagrams/`).

## 1. Start the server

```bash
scripts/serve.sh
```

Idempotent: probes the endpoint, otherwise runs `make run` in the excalidraw-agent checkout in the background and waits. The first run bootstraps pnpm/node and builds the vendored server, which can take several minutes. Set `EXCALIDRAW_AGENT_ROOT` when the checkout is not a sibling of the current git root (or under `~/src/excalidraw-agent`).

Two ways to call the tools:

- **Native MCP tools** — while the server runs and the host exposes an `excalidraw` MCP server (e.g. Cursor via a workspace `.cursor/mcp.json` pointing at `http://localhost:3001/mcp`). Prefer this when the tools appear in your tool list.
- **`scripts/call-tool.py`** — direct JSON-RPC over HTTP for environments that don't hot-load MCP servers (e.g. cloud agents). Handles the SSE response framing for you.

## 2. Learn the element format

Call `read_me` once per conversation and follow it — it is the authoritative reference (colors, labeled shapes, arrows/bindings, `cameraUpdate`, sizing rules, worked examples):

```bash
scripts/call-tool.py read_me
```

Essentials: every element needs a unique `id`; prefer `label: { "text": ... }` on shapes/arrows over separate text elements; bind arrows with `startBinding`/`endBinding` (`elementId` + `fixedPoint`); start with a `cameraUpdate` pseudo-element and keep cameras 4:3 (400×300 … 1600×1200); fontSize ≥ 16 for labels; no emoji.

## 3. Draw

Author the elements array with a small generator script (easier to tweak coordinates than hand-editing JSON) and write it compactly to a file, e.g. `/tmp/elements.json`. Then:

```bash
scripts/call-tool.py create_view --arg-file elements=/tmp/elements.json
```

- `elements` must be the JSON array serialized as a string — the scripts do this for you; with native MCP tools pass the array as a string argument.
- Input limit is 5 MB; the response includes a `checkpointId` for follow-ups.
- Order matters for the streaming animation: emit `cameraUpdate` → shape → its label/arrows → next shape, not all shapes then all labels.

## 4. Iterate

To edit an existing diagram instead of redrawing, start the next `create_view` elements array with:

```json
[{"type":"restoreCheckpoint","id":"<checkpointId>"}, {"type":"delete","ids":"a1,b2"}, ...new elements...]
```

Never reuse a deleted element's id. When a user asks to change a diagram they may have edited in the widget's fullscreen mode, read the widget context first if your host exposes it.

## 5. Export committable artifacts

`create_view` renders in the chat widget only. To produce files for the repo:

```bash
node scripts/export-scene.mjs /tmp/elements.json docs/my-diagram
```

Writes `docs/my-diagram.svg` (vector, embeddable in the README), `docs/my-diagram.excalidraw` (editable scene), and `docs/my-diagram.png` (raster). It replays the widget's own pipeline (`convertToExcalidrawElements` → `exportToSvg` → `serializeAsJSON`) in headless Chrome; requires a Chrome/Chromium binary (`CHROME_PATH` to override detection) and network access to esm.sh. Pseudo-elements (`cameraUpdate`, `delete`, `restoreCheckpoint`) are filtered out, so the export shows the final full scene.

**Always do visual QA**: open/view the exported `.png` and check for overlapping labels, arrows crossing text, and truncated edges before committing. Fix coordinates in your generator and re-export.

For a shareable link, upload the exported scene:

```bash
scripts/call-tool.py export_to_excalidraw --arg-file json=docs/my-diagram.excalidraw
```

Returns a `https://excalidraw.com/#json=...` URL (content is uploaded to excalidraw's public sharing backend — skip for sensitive diagrams).

## Pitfalls

- **Invalid JSON in `elements`** (comments, trailing commas) is rejected — generate with a real JSON serializer, never by hand-concatenation.
- **Checkpoints are ephemeral** (temp files server-side, pruned after ~100): if a `restoreCheckpoint` id is not found, redraw from scratch.
- **Element overlap** is the most common quality bug: keep 20–30 px gaps, size boxes ≥ 120×60, and check the PNG.
- **Server not reachable**: re-run `scripts/serve.sh`; if a stale `excalidraw-mcp-server` tmux session is stuck, `tmux kill-session -t excalidraw-mcp-server` and retry. Missing checkout → clone excalidraw-agent and set `EXCALIDRAW_AGENT_ROOT`.
