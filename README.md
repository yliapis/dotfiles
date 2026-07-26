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

## Cloud Agents

Cloud coding agents boot via the provider-agnostic
[`.cursor/scripts/cloud-agent-bootstrap.sh`](.cursor/scripts/cloud-agent-bootstrap.sh),
which installs `zsh`, `rsync`, and `shellcheck`, then syncs the ai-coding
commands + skills into the home locations. Cursor is the wired-up provider
today, via [`.cursor/environment.json`](.cursor/environment.json). Set
`SYNC_CLOUD_AGENT_BOOTSTRAP=1` when syncing (e.g. `make sync`) to also mirror
the bootstrap script itself into `~/.cursor/scripts/`.
