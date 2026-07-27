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

## Ticket work runs through Backlog.md

Work items live in the repo-root [Backlog.md](https://github.com/MrLesk/Backlog.md)
project at `backlog/`, one Markdown task per item under `backlog/tasks/`. The
`ticket-create`, `ticket-execute`, and `ticket-update` skills all drive the
`backlog` CLI; none of them writes a task file directly, and neither should you.

The CLI is not installed in cloud (the Brewfile's `backlog-md` comes with
Homebrew, which the bootstrap skips). Install it with
`npm i -g backlog.md` when a task needs it. Reads are `backlog task list --plain`
and `backlog task view <id> --plain`; `backlog instructions <guide>` prints the
upstream task-creation, task-execution, and task-finalization workflows.

Statuses, priorities, and task types are per-project and live in
`backlog/config.yml`. This project configures the Conventional Commits
vocabulary for `types`, which differs from what `backlog init --defaults`
ships, so read accepted values from `backlog task create --help` rather than
assuming the upstream defaults. Some flags documented upstream, including
`--json` and `--append-plan`, are absent from older CLI builds; check `--help`
before relying on one.

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

Mirror entries are real files and directories, never symlinks. At least one
shipped skill-discovery implementation resolves a link and drops the entry when
the real path leaves the scanned directory, so a symlinked mirror is invisible
to it; `make mirrors-check` reports one as drift. The escape hatch for live
edits without a regenerate step is to install this repo as a plugin
marketplace: `.cursor-plugin/marketplace.json` and
`.claude-plugin/marketplace.json` point each plugin at
`./ai-coding/plugins/<name>`, so a client reads the source tree with no mirror
in between. `make symlink` is the home-scope alternative and re-introduces the
same symlink risk at user scope, so confirm the client still lists the skills
after running it.

Agent frontmatter stays inside the intersection all three tools accept:
`name`, `description`, and `mode: subagent`. Cursor ignores Claude-only fields,
while OpenCode folds unrecognized keys into provider model options and fails its
config load on a known key with the wrong type (Claude's comma-separated
`tools:` string, or a `color:` name outside its theme enum). Anything
tool-specific belongs in the body instructions instead.

See `README.md` for more information.
