# AGENTS.md

## Cursor Cloud specific instructions

Dotfiles + AI-coding tooling repo. Shell scripts install dotfiles and mirror
`ai-coding/` commands + skills into the Cursor, Claude, and OpenCode home
locations.

Cloud agent setup is defined in `.cursor/environment.json`, which runs the
provider-agnostic `.cursor/scripts/cloud-agent-bootstrap.sh` at VM boot to
apt-install `zsh`, `rsync`, and `shellcheck` so the repo's scripts are
runnable. Homebrew, the Brewfile, and ollama are intentionally not installed
in cloud (headless VM; slow boots); run `./install.sh` manually only if a task
needs them. Run `make help` for details on sync and other targets.

## Project command/skill mirrors

Repo-root `.cursor/{commands,skills}/`, `.claude/{commands,skills}/`, and
`.opencode/{commands,skills}/` are flattened per-item symlink mirrors of
`ai-coding/plugins/*/{commands,skills}`. When adding, renaming, or removing a
command or skill, regenerate all six mirrors from the repo root:

```sh
for tool in .cursor .claude .opencode; do
  mkdir -p "$tool/commands" "$tool/skills"
  for f in ai-coding/plugins/*/commands/*.md; do ln -sfn "../../$f" "$tool/commands/$(basename "$f")"; done
  for d in ai-coding/plugins/*/skills/*/; do d="${d%/}"; ln -sfn "../../$d" "$tool/skills/$(basename "$d")"; done
done
```

Remove any leftover symlinks for deleted artifacts by hand
(`find -L .cursor .claude .opencode -type l` lists broken ones).

See `README.md` for more information.
