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
[`scripts/cloud-agent-bootstrap.sh`](scripts/cloud-agent-bootstrap.sh),
which installs `zsh`, `rsync`, and `shellcheck` so the repo's scripts and
`make` targets are runnable on a fresh VM. Two providers are wired up to it:

- **Cursor** — the `install` hook in
  [`.cursor/environment.json`](.cursor/environment.json).
- **Claude Code** — the `SessionStart` hook in
  [`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh),
  registered in [`.claude/settings.json`](.claude/settings.json). It no-ops
  unless `CLAUDE_CODE_REMOTE=true`, so local sessions stay untouched.
