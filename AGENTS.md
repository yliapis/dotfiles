# AGENTS.md

## Cursor Cloud specific instructions

Dotfiles + AI-coding tooling repo. Shell scripts install dotfiles and mirror
`ai-coding/` commands + skills into the Cursor and Claude home locations.

Cloud agent setup is defined in `.cursor/environment.json`, which runs
`.cursor/scripts/cloud-agent-bootstrap.sh` at VM boot: it apt-installs `zsh`,
`rsync`, and `shellcheck`, then runs `scripts/sync-coding-tools.sh` to mirror
commands + skills into `~/.cursor` and `~/.claude`. Homebrew, the Brewfile,
and ollama are intentionally not installed in cloud (headless VM; slow boots);
run `./install.sh` manually only if a task needs them. Run `make help` for
details on sync and other targets.

See `README.md` for more information.
