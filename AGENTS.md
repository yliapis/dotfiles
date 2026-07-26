# AGENTS.md

## Cursor Cloud specific instructions

Dotfiles + AI-coding tooling repo. Shell scripts install dotfiles and mirror
`ai-coding/` commands + skills into the Cursor and Claude home locations.

Setup runs the repo's own `install.sh`. Run `make help` for details on sync and
other targets.

## Project command/skill mirrors

Repo-root `.cursor/{commands,skills}/` and `.claude/{commands,skills}/` are
flattened per-item symlink mirrors of `ai-coding/plugins/*/{commands,skills}`.
When adding, renaming, or removing a command or skill, regenerate all four
mirrors from the repo root:

```sh
for tool in .cursor .claude; do
  mkdir -p "$tool/commands" "$tool/skills"
  for f in ai-coding/plugins/*/commands/*.md; do ln -sfn "../../$f" "$tool/commands/$(basename "$f")"; done
  for d in ai-coding/plugins/*/skills/*/; do d="${d%/}"; ln -sfn "../../$d" "$tool/skills/$(basename "$d")"; done
done
```

Remove any leftover symlinks for deleted artifacts by hand
(`find -L .cursor .claude -type l` lists broken ones).

See `README.md` for more information.
