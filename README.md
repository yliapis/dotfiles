# dotfiles

run installation with the following command:

```sh
source install.sh
```

## Makefile

Common tasks are wrapped in a `Makefile`. List all targets with:

```sh
make help
```

## Commands and skills

`ai-coding/plugins/<plugin>/{commands,skills}/` is the only place to edit a
command or skill. Two scripts fan those out:

- [`scripts/sync-project-mirrors.sh`](scripts/sync-project-mirrors.sh)
  (`make mirrors`) regenerates the repo-root `.cursor/`, `.claude/`, and
  `.opencode/` mirrors that agent tools scan while this repo is the open
  project. It writes real copies, because those tools do not follow symlinks
  when indexing which skills to offer the agent — symlinked skills are
  readable by path but never auto-attach. `make mirrors-check` fails when the
  mirrors drift from the plugins.
- [`scripts/sync-coding-tools.sh`](scripts/sync-coding-tools.sh) (`make sync`)
  mirrors the same sources into the home directories that make them available
  in every repo: `~/.cursor/skills`, `~/.claude/skills`,
  `~/.config/opencode/skills`, and the matching `commands` directories.

## Cloud Agents

Cloud coding agents boot via the provider-agnostic
[`.cursor/scripts/cloud-agent-bootstrap.sh`](.cursor/scripts/cloud-agent-bootstrap.sh),
which installs `zsh`, `rsync`, and `shellcheck` so the repo's scripts and
`make` targets are runnable on a fresh VM. Cursor is the wired-up provider
today, via [`.cursor/environment.json`](.cursor/environment.json).
