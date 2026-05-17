#!/usr/bin/env python3
"""Sync AI-coding artifacts (commands, skills) from this dotfiles repo into
per-tool home-directory locations for Cursor, Claude Code, and any future tool.

The mapping lives in the top-level :data:`TARGETS` dict; adding a new tool is a
single entry, no other code changes required.

Change detection is SHA256-based with a manifest fast-path: the manifest stores
the last-synced SHA256 and source mtime per destination, so files whose source
mtime is unchanged skip hashing entirely. The manifest also lets ``--dry-run``
show accurate decisions without writing anything.

Stdlib only. Python 3.9+.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
import os
import shutil
import sys
import time
from collections.abc import Iterable
from pathlib import Path
from typing import Literal, Optional

REPO_ROOT = Path(__file__).resolve().parent

# Sync configuration.
#
# Each entry is {src, dst, kind}:
#   - ``src`` is a repo-relative path to a directory of source artifacts.
#   - ``dst`` is the destination directory (``~`` is expanded).
#   - ``kind`` is one of:
#       - ``"files"``: ``src`` contains leaf files to mirror flat into ``dst``
#         (e.g. a flat dir of ``*.md`` slash-command files).
#       - ``"dirs"``: ``src`` contains subdirectories; each subdirectory tree is
#         mirrored under ``dst`` (e.g. ``skills/<name>/SKILL.md``).
#
# In both cases, the full relative path of every leaf file under ``src`` is
# preserved beneath ``dst``. The ``kind`` field is retained as a declarative
# hint and for future per-kind behaviour without code edits at call sites.
#
# To add a third tool (e.g. OpenCode), append another top-level key with its
# own list of entries -- no other code edits are required.
TARGETS: dict[str, list[dict[str, str]]] = {
    "cursor": [
        {
            "src": "ai-coding/plugins/ai-coding/commands",
            "dst": "~/.cursor/commands",
            "kind": "files",
        },
        {
            "src": "ai-coding/plugins/ai-coding/skills",
            "dst": "~/.cursor/skills-cursor",
            "kind": "dirs",
        },
    ],
    "claude": [
        {
            "src": "ai-coding/plugins/ai-coding/commands",
            "dst": "~/.claude/commands",
            "kind": "files",
        },
        {
            "src": "ai-coding/plugins/ai-coding/skills",
            "dst": "~/.claude/skills",
            "kind": "dirs",
        },
    ],
}

MANIFEST_PATH = Path.home() / ".cache" / "dotfiles" / "sync-manifest.json"
MANIFEST_VERSION = 1

Mode = Literal["copy", "symlink"]


@dataclasses.dataclass
class Counts:
    synced: int = 0
    skipped: int = 0
    errors: int = 0


@dataclasses.dataclass
class ManifestEntry:
    src: str
    sha256: str
    src_mtime: float
    synced_at: str
    mode: Mode

    def to_dict(self) -> dict[str, object]:
        return dataclasses.asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, object]) -> "ManifestEntry":
        return cls(
            src=str(data["src"]),
            sha256=str(data["sha256"]),
            src_mtime=float(data["src_mtime"]),
            synced_at=str(data["synced_at"]),
            mode=str(data.get("mode", "copy")),  # type: ignore[arg-type]
        )


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_manifest(path: Path, *, rebuild: bool) -> dict[str, ManifestEntry]:
    if rebuild or not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        print(f"warning: could not read manifest {path}: {exc}", file=sys.stderr)
        return {}
    files = data.get("files", {}) if isinstance(data, dict) else {}
    out: dict[str, ManifestEntry] = {}
    for dst_key, entry in files.items():
        if isinstance(entry, dict):
            try:
                out[dst_key] = ManifestEntry.from_dict(entry)
            except (KeyError, ValueError, TypeError):
                continue
    return out


def write_manifest(path: Path, entries: dict[str, ManifestEntry]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": MANIFEST_VERSION,
        "last_sync_at": _now_iso(),
        "files": {k: v.to_dict() for k, v in sorted(entries.items())},
    }
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    tmp.replace(path)


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime())


def iter_leaf_files(src_dir: Path) -> Iterable[Path]:
    """Yield every regular file beneath ``src_dir`` (recursive)."""
    for root, _dirs, files in os.walk(src_dir):
        root_path = Path(root)
        for name in files:
            f = root_path / name
            if f.is_file() and not f.is_symlink():
                yield f
            elif f.is_symlink():
                # follow symlinks if they resolve to a file (skip dangling)
                try:
                    if f.resolve(strict=True).is_file():
                        yield f
                except OSError:
                    continue


def needs_sync(
    src: Path,
    dst: Path,
    mode: Mode,
    manifest_entry: Optional[ManifestEntry],
) -> tuple[bool, str, Optional[str]]:
    """Return (needs_sync, reason, src_sha_if_computed).

    ``src_sha_if_computed`` is returned so the caller can avoid recomputing it
    when updating the manifest after a sync.
    """
    src_stat = src.stat()
    src_mtime = src_stat.st_mtime

    if mode == "symlink":
        # For symlinks, the dst is "correct" iff it's a symlink to src.
        if dst.is_symlink() and os.fspath(dst.readlink()) == os.fspath(src):
            return False, "symlink already points to src", None
        return True, "symlink missing or wrong target", None

    # copy mode: try manifest fast-path first.
    if (
        manifest_entry is not None
        and manifest_entry.mode == "copy"
        and abs(manifest_entry.src_mtime - src_mtime) < 1e-6
        and dst.exists()
        and not dst.is_symlink()
    ):
        return False, "manifest fast-path (mtime unchanged)", None

    src_sha = sha256_of(src)
    if dst.exists() and not dst.is_symlink():
        try:
            dst_sha = sha256_of(dst)
        except OSError:
            return True, "dst unreadable; will overwrite", src_sha
        if dst_sha == src_sha:
            return False, "sha256 match", src_sha
        return True, "sha256 mismatch", src_sha
    return True, "dst missing", src_sha


def perform_sync(
    src: Path,
    dst: Path,
    mode: Mode,
    *,
    dry_run: bool,
) -> None:
    if dry_run:
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        if dst.is_dir() and not dst.is_symlink():
            shutil.rmtree(dst)
        else:
            dst.unlink()
    if mode == "symlink":
        os.symlink(src, dst)
    else:
        shutil.copy2(src, dst)


def sync_entry(
    tool: str,
    entry: dict[str, str],
    *,
    mode: Mode,
    dry_run: bool,
    verbose: bool,
    manifest: dict[str, ManifestEntry],
    counts: Counts,
) -> None:
    src_dir = (REPO_ROOT / entry["src"]).resolve()
    dst_dir = Path(os.path.expanduser(entry["dst"]))

    if not src_dir.is_dir():
        print(
            f"error: [{tool}] source not found: {src_dir}",
            file=sys.stderr,
        )
        counts.errors += 1
        return

    if verbose:
        print(f"[{tool}] {entry['kind']}: {src_dir} -> {dst_dir}")

    for src_file in sorted(iter_leaf_files(src_dir)):
        rel = src_file.relative_to(src_dir)
        dst_file = dst_dir / rel
        dst_key = os.fspath(dst_file)
        try:
            needed, reason, precomputed_sha = needs_sync(
                src_file, dst_file, mode, manifest.get(dst_key)
            )
        except OSError as exc:
            print(
                f"error: [{tool}] could not inspect {src_file}: {exc}",
                file=sys.stderr,
            )
            counts.errors += 1
            continue

        if not needed:
            counts.skipped += 1
            if verbose:
                tag = "[dry-run skip]" if dry_run else "[skip]"
                print(f"  {tag} {dst_file}  ({reason})")
            continue

        action = "symlink" if mode == "symlink" else "copy"
        tag = f"[dry-run {action}]" if dry_run else f"[{action}]"
        print(f"  {tag} {src_file} -> {dst_file}  ({reason})")

        try:
            perform_sync(src_file, dst_file, mode, dry_run=dry_run)
        except OSError as exc:
            print(
                f"error: [{tool}] failed to sync {src_file} -> {dst_file}: {exc}",
                file=sys.stderr,
            )
            counts.errors += 1
            continue

        counts.synced += 1
        if not dry_run:
            sha = precomputed_sha if precomputed_sha is not None else sha256_of(src_file)
            manifest[dst_key] = ManifestEntry(
                src=os.fspath(src_file),
                sha256=sha,
                src_mtime=src_file.stat().st_mtime,
                synced_at=_now_iso(),
                mode=mode,
            )


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="sync-coding-tools",
        description=(
            "Sync AI-coding commands and skills from this dotfiles repo "
            "into per-tool home-directory locations (Cursor, Claude Code, ...)."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show actions without modifying the filesystem or manifest.",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print a decision line for every file (including skips).",
    )
    parser.add_argument(
        "--targets",
        default="",
        help=(
            "Comma-separated tool names to sync (default: all). "
            f"Known: {','.join(sorted(TARGETS))}."
        ),
    )
    parser.add_argument(
        "--mode",
        choices=("copy", "symlink"),
        default="copy",
        help="Materialize files as copies (default) or symlinks.",
    )
    parser.add_argument(
        "--rebuild-manifest",
        action="store_true",
        help="Ignore any cached manifest and re-hash every file.",
    )
    return parser.parse_args(argv)


def resolve_targets(selected: str) -> list[str]:
    if not selected.strip():
        return list(TARGETS)
    requested = [t.strip() for t in selected.split(",") if t.strip()]
    unknown = [t for t in requested if t not in TARGETS]
    if unknown:
        raise SystemExit(
            f"unknown --targets: {', '.join(unknown)}. "
            f"Known: {', '.join(sorted(TARGETS))}."
        )
    return requested


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    tools = resolve_targets(args.targets)
    mode: Mode = args.mode

    manifest = load_manifest(MANIFEST_PATH, rebuild=args.rebuild_manifest)
    counts = Counts()

    print(
        f"sync-coding-tools: mode={mode} "
        f"dry_run={int(args.dry_run)} targets={','.join(tools)}"
    )
    print(f"sync-coding-tools: repo_root={REPO_ROOT}")
    print(f"sync-coding-tools: manifest={MANIFEST_PATH}")

    for tool in tools:
        for entry in TARGETS[tool]:
            sync_entry(
                tool,
                entry,
                mode=mode,
                dry_run=args.dry_run,
                verbose=args.verbose,
                manifest=manifest,
                counts=counts,
            )

    if not args.dry_run and counts.errors == 0:
        write_manifest(MANIFEST_PATH, manifest)

    print(
        f"sync-coding-tools: {counts.synced} files synced, "
        f"{counts.skipped} skipped (up to date), {counts.errors} errors"
    )
    return 1 if counts.errors > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
