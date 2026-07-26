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
are flattened per-item mirrors of
`ai-coding/plugins/*/{commands,skills,agents}`. `ai-coding/plugins/` is the only
place to edit; every mirror entry is generated. After adding, renaming, or
removing a command, skill, or agent, regenerate all nine mirrors from the repo
root:

```sh
make mirrors        # regenerate, pruning entries whose source is gone
make mirrors-check  # no-write drift check; non-zero when a mirror is stale
```

Both wrap `scripts/sync-project-mirrors.sh`, which needs only bash and
coreutils. Two plugins claiming one flattened name abort the run instead of
shadowing each other.

Agent frontmatter stays inside the intersection all three tools accept:
`name`, `description`, and `mode: subagent`. Cursor ignores Claude-only fields,
while OpenCode folds unrecognized keys into provider model options and fails its
config load on a known key with the wrong type (Claude's comma-separated
`tools:` string, or a `color:` name outside its theme enum). Anything
tool-specific belongs in the body instructions instead.

See `README.md` for more information.
