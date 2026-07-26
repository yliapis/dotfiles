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
which installs `zsh`, `rsync`, and `shellcheck` so the repo's scripts and
`make` targets are runnable on a fresh VM. Cursor is the wired-up provider
today, via [`.cursor/environment.json`](.cursor/environment.json).
