# AGENTS.md

## Cursor Cloud specific instructions

Dotfiles + AI-coding tooling repo. Shell scripts install dotfiles and mirror
`ai-coding/` commands, skills, and agents into the Cursor, Claude, and OpenCode
home locations.

Cloud agent setup lives in `ai-coding/hooks/`. Both wired-up providers run the
provider-agnostic `ai-coding/hooks/cloud-agent-bootstrap.sh` at VM boot to
apt-install `zsh`, `rsync`, and `shellcheck` so the repo's scripts are runnable,
plus the Backlog.md CLI (`backlog`) so the tasks in `backlog/` are workable —
from npm, brew, or bun, whichever the image ships. Cursor runs it through the
`install` command in `.cursor/environment.json`, and Claude Code through the
`SessionStart` hook in `.claude/settings.json`, which runs the
`ai-coding/hooks/session-start.sh` adapter. Homebrew, the Brewfile, and ollama
are intentionally not installed in cloud (headless VM; slow boots); run
`./install.sh` manually only if a task needs them. Run `make help` for details
on sync and other targets.

When npm's global prefix is not user-writable (common in cloud VMs), the
bootstrap installs `backlog` into `~/.local` via `NPM_CONFIG_PREFIX`; login
shells pick it up from `~/.profile`'s `~/.local/bin` PATH entry.

There is no compiled app or test framework — the deliverables are shell
scripts, so the lint/test/build/run loop maps to `make` and `shellcheck`:
lint with `shellcheck` on the bash scripts (`scripts/sync-project-mirrors.sh`,
`scripts/gen-artifact-index.sh`, `ai-coding/hooks/*.sh`) and `zsh -n` on the
zsh scripts (`install.sh`, `scripts/sync-coding-tools.sh`, which shellcheck
rejects with SC1071); test with the drift checks `make mirrors-check`,
`make skills-index-check`, `make commands-index-check`; build by regenerating
with `make mirrors` / `make skills-index` / `make commands-index` (a clean
`git status` afterward means no drift); run the actual product with
`make sync` (or `make dry-run` / `make status` first), which mirrors
commands/skills/agents into the Cursor, Claude, and OpenCode home dirs and
appends an audit line to `~/.cache/dotfiles/sync.log`.

## Backlog.md ticket set

The repo's canonical work-item set is the [Backlog.md](https://github.com/MrLesk/Backlog.md)
project at `backlog/`. One Markdown task per item lives under `backlog/tasks/`.
Route every interaction through the `backlog` CLI (`backlog task list --plain`,
`backlog task view <id> --plain`); never hand-edit `tasks/*.md` or `config.yml`.
Read `backlog/AGENTS.md` before create, execute, or update work: it routes to
the `ticket-crud` and `ticket-execute` skills and states the execution contract.

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

The same script generates a tenth mirror on different rules: `.claude/hooks/`
from the flat, non-plugin-scoped `ai-coding/hooks/*.sh`, and only for Claude
Code, since it is the one tool that discovers hooks by path inside its config
directory. Cursor reads the same source through an arbitrary path in
`.cursor/environment.json` and gets no mirror. Adding a hook means dropping a
`.sh` into `ai-coding/hooks/` and running `make mirrors`; registering it with
Claude Code is a separate edit to `.claude/settings.json`, which is hand-written
and not generated.

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
