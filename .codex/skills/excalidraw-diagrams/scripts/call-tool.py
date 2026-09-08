#!/usr/bin/env python3
"""Call a tool on the excalidraw MCP server (JSON-RPC over streamable HTTP).

The server is stateless: every call is an independent POST, no initialize
handshake or session id required. Responses arrive as a single SSE event
(`data: {...}`), which this script unwraps.

Usage:
  call-tool.py list
  call-tool.py TOOL [--arg KEY=VALUE ...] [--arg-file KEY=PATH ...] [--url URL] [--raw]

Examples:
  call-tool.py read_me
  call-tool.py create_view --arg-file elements=/tmp/elements.json
  call-tool.py export_to_excalidraw --arg-file json=docs/my-diagram.excalidraw
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_URL = os.environ.get(
    "EXCALIDRAW_MCP_URL",
    f"http://localhost:{os.environ.get('PORT', '3001')}/mcp",
)
SERVE_HINT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "serve.sh")


def rpc(url: str, method: str, params: dict, timeout: int = 180) -> dict:
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode()
    except urllib.error.URLError as e:
        sys.exit(f"error: cannot reach {url} ({e}).\nStart the server first: {SERVE_HINT}")
    for line in body.splitlines():
        if line.startswith("data: "):
            return json.loads(line[len("data: "):])
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        sys.exit(f"error: unexpected non-JSON response:\n{body[:2000]}")


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("tool", help="tool name, or 'list' to list available tools")
    ap.add_argument("--arg", action="append", default=[], metavar="KEY=VALUE",
                    help="string argument for the tool (repeatable)")
    ap.add_argument("--arg-file", action="append", default=[], metavar="KEY=PATH",
                    help="set KEY to the contents of file PATH (repeatable)")
    ap.add_argument("--url", default=DEFAULT_URL, help=f"MCP endpoint (default {DEFAULT_URL})")
    ap.add_argument("--raw", action="store_true", help="print the full JSON-RPC response")
    a = ap.parse_args()

    if a.tool == "list":
        res = rpc(a.url, "tools/list", {})
        for tool in res["result"]["tools"]:
            desc = tool.get("description", "").strip().splitlines()
            print(f"{tool['name']}: {desc[0] if desc else ''}")
        return

    arguments = {}
    for kv in a.arg:
        key, sep, value = kv.partition("=")
        if not sep:
            sys.exit(f"error: --arg expects KEY=VALUE, got {kv!r}")
        arguments[key] = value
    for kv in a.arg_file:
        key, sep, path = kv.partition("=")
        if not sep:
            sys.exit(f"error: --arg-file expects KEY=PATH, got {kv!r}")
        with open(path) as f:
            arguments[key] = f.read()

    res = rpc(a.url, "tools/call", {"name": a.tool, "arguments": arguments})
    if a.raw:
        print(json.dumps(res, indent=2))
        return
    if "error" in res:
        sys.exit(f"JSON-RPC error: {json.dumps(res['error'])}")

    result = res["result"]
    for item in result.get("content", []):
        if item.get("type") == "text":
            print(item["text"])
    structured = result.get("structuredContent")
    if structured is not None:
        print(f"structuredContent: {json.dumps(structured)}", file=sys.stderr)
    if result.get("isError"):
        sys.exit(1)


if __name__ == "__main__":
    main()
