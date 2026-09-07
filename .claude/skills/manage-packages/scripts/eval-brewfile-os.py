#!/usr/bin/env python3
"""Evaluate postfix OS.mac? / OS.linux? gates on a Brewfile.

Cloud VMs often have no Homebrew. Recent package PRs compared requested
brew/cask/tap/vscode/mas lines under a mock mac vs linux OS instead of
running `brew bundle`. This script is that check.

It is line-oriented on purpose: this repo's Brewfile uses postfix
`if OS.mac?` / `if OS.linux?`, not Ruby `if` blocks. A full Ruby eval
would need a Homebrew DSL.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

DECL = re.compile(
    r"^\s*(?P<kind>tap|brew|cask|vscode|mas)\s+(?P<rest>.+?)\s*$"
)
# No trailing \b: `?` is non-word, so `\b` after it never matches.
GATE_MAC = re.compile(r"\bif OS\.mac\?")
GATE_LINUX = re.compile(r"\bif OS\.linux\?")


def gate_allows(line: str, os_name: str) -> bool:
    has_mac = bool(GATE_MAC.search(line))
    has_linux = bool(GATE_LINUX.search(line))
    if has_mac and has_linux:
        return False
    if has_mac:
        return os_name == "mac"
    if has_linux:
        return os_name == "linux"
    return True


def iter_requested(text: str, os_name: str, kind_filter: str):
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        match = DECL.match(line)
        if not match:
            continue
        kind = match.group("kind")
        if kind_filter != "all" and kind != kind_filter:
            continue
        if not gate_allows(line, os_name):
            continue
        yield lineno, kind, line.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", required=True, help="Brewfile or Brewfile.mas path")
    parser.add_argument("--os", required=True, choices=("mac", "linux"))
    parser.add_argument(
        "--kind",
        default="all",
        choices=("all", "tap", "brew", "cask", "vscode", "mas"),
    )
    args = parser.parse_args()

    path = Path(args.file)
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"error: cannot read {path}: {exc}", file=sys.stderr)
        return 2

    for lineno, kind, line in iter_requested(text, args.os, args.kind):
        print(f"{lineno}\t{kind}\t{line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
