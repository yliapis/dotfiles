# Misc leftovers archive

Two miscellaneous historical artifacts archived during the worktree-cleanup pass:

## dual-licensing/
The `dual-licensing-apache-ccby` branch added `CONTRIBUTING.md` (and patched
`.gitignore` + `Brewfile`) as part of an aborted dual-licensing exploration.
Preserved here:
- `CONTRIBUTING.md` — the proposed contributor doc verbatim
- `full.diff` — the complete diff vs main (includes Brewfile/gitignore tweaks)

## dotfiles-pre-symlink-3c99292.diff
Four identical detached-HEAD worktrees (i8mfY, k3yBl, KNpHD, p10et) all sat at
commit `3c99292 fix: update net-tools to only install on linux platforms`, the
era before `.cursor/commands` and `.cursor/skills` were converted to symlinks.
This single diff captures their cumulative state vs main (mostly directory
shape differences in `.cursor/`).

Source branches/worktrees have been deleted.
