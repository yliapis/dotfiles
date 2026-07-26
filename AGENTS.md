# AGENTS.md

## Cursor Cloud specific instructions

Dotfiles + AI-coding tooling repo. Shell scripts install dotfiles and mirror
`ai-coding/` commands, skills, and agents into the Cursor, Claude, and OpenCode
home locations.

Cloud agent setup is defined in `.cursor/environment.json`, which runs the
provider-agnostic `.cursor/scripts/cloud-agent-bootstrap.sh` at VM boot to
apt-install `zsh`, `rsync`, and `shellcheck` so the repo's scripts are
runnable. Homebrew, the Brewfile, and ollama are intentionally not installed
in cloud (headless VM; slow boots); run `./install.sh` manually only if a task
needs them. Run `make help` for details on sync and other targets.

## Project command/skill/agent mirrors

Repo-root `.cursor/{commands,skills,agents}/`,
`.claude/{commands,skills,agents}/`, and `.opencode/{commands,skills,agents}/`
are flattened per-item symlink mirrors of
`ai-coding/plugins/*/{commands,skills,agents}`. When adding, renaming, or
removing a command, skill, or agent, regenerate all nine mirrors from the repo
root:

```sh
for tool in .cursor .claude .opencode; do
  mkdir -p "$tool/commands" "$tool/skills" "$tool/agents"
  for f in ai-coding/plugins/*/commands/*.md; do ln -sfn "../../$f" "$tool/commands/$(basename "$f")"; done
  for d in ai-coding/plugins/*/skills/*/; do d="${d%/}"; ln -sfn "../../$d" "$tool/skills/$(basename "$d")"; done
  for f in ai-coding/plugins/*/agents/*.md; do ln -sfn "../../$f" "$tool/agents/$(basename "$f")"; done
done
```

Remove any leftover symlinks for deleted artifacts by hand
(`find -L .cursor .claude .opencode -type l` lists broken ones).

Agent frontmatter stays inside the intersection all three tools accept:
`name`, `description`, and `mode: subagent`. Cursor ignores Claude-only fields,
while OpenCode folds unrecognized keys into provider model options and fails its
config load on a known key with the wrong type (Claude's comma-separated
`tools:` string, or a `color:` name outside its theme enum). Anything
tool-specific belongs in the body instructions instead.

See `README.md` for more information.
