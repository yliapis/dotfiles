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

Cursor Cloud Agents are configured via [`.cursor/environment.json`](.cursor/environment.json),
which runs [`.cursor/scripts/cloud-agent-bootstrap.sh`](.cursor/scripts/cloud-agent-bootstrap.sh)
at VM boot: it installs `zsh`, `rsync`, and `shellcheck`, then syncs the
ai-coding commands + skills into the home locations. Set
`SYNC_CLOUD_AGENT_BOOTSTRAP=1` when syncing (e.g. `make sync`) to also mirror
the bootstrap script itself into `~/.cursor/scripts/`.
