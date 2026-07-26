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

## AI coding tools

[`ai-coding/`](ai-coding/README.md) holds the skills and slash commands, grouped
into five Claude Code plugins and served from a marketplace at the repo root.
Install them into Claude Code directly:

```sh
/plugin marketplace add yliapis/dotfiles
/plugin install writing@yliapis-dotfiles
```

For Cursor, OpenCode, and Codex, which have no marketplace, `make sync` mirrors
the same content into their home directories. See
[`ai-coding/README.md`](ai-coding/README.md) for the layout and both sync
scripts.
