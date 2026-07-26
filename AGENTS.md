# AGENTS.md

## Cloud agent specific instructions

Dotfiles + AI-coding tooling repo. Shell scripts install dotfiles and mirror
`ai-coding/` commands + skills into the Cursor and Claude home locations.

Cloud agent setup runs the provider-agnostic
`scripts/cloud-agent-bootstrap.sh` at VM boot to apt-install `zsh`, `rsync`,
and `shellcheck` so the repo's scripts are runnable. Both providers call that
one script: Cursor via the `install` hook in `.cursor/environment.json`,
Claude Code via the `SessionStart` hook in `.claude/hooks/session-start.sh`
(registered in `.claude/settings.json`, and gated on `CLAUDE_CODE_REMOTE` so
it never fires on a local machine). Keep new provider wiring as a thin
delegation to the shared script rather than a second copy of the package list.

Homebrew, the Brewfile, and ollama are intentionally not installed in cloud
(headless VM; slow boots); run `./install.sh` manually only if a task needs
them. Run `make help` for details on sync and other targets.

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
