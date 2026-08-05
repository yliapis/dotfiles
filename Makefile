# Makefile — thin convenience wrapper so `make install`, `make refresh`,
# `make sync`, `make sync-cursor`, `make symlink`, `make mirrors`,
# `make mirrors-check`, `make skills-index`, `make skills-index-check`,
# `make commands-index`, `make commands-index-check`, `make dry-run`,
# `make status`, `make unlink`, `make clean`, `make sync-help`, and `make help`
# (default) all work without the user having to remember the flag set.
#
# Three scripts do the work, and this Makefile only translates target names into
# their invocations:
#
#   scripts/sync-coding-tools.sh    home-dir sync: the single source of truth
#                                   for copy-mode (rsync) and symlink-mode
#                                   logic, the audit log, and --unlink.
#   scripts/sync-project-mirrors.sh repo-root project mirrors: regenerates
#                                   {.cursor,.claude,.opencode}/{commands,
#                                   skills,agents} from ai-coding/plugins/.
#   scripts/gen-artifact-index.sh   ai-coding/indexes/<kind>.md: regenerates the
#                                   skills or commands census from
#                                   ai-coding/plugins/.

# GNU Make ignores $SHELL from the environment and defaults to /bin/sh.
# Honor the user's login shell when make's SHELL was not set on the command line.
ifneq ($(origin SHELL),command line)
SHELL := $(shell printf '%s' "$${SHELL:-/bin/sh}")
endif
.SHELLFLAGS := -eu -c
.DEFAULT_GOAL := help

SCRIPT := ./scripts/sync-coding-tools.sh
MIRROR_SCRIPT := ./scripts/sync-project-mirrors.sh
INDEX_SCRIPT := ./scripts/gen-artifact-index.sh

.PHONY: help install refresh sync-help sync sync-cursor sync-claude sync-opencode symlink symlink-cursor symlink-claude symlink-opencode dry-run status unlink clean mirrors mirrors-check skills-index skills-index-check commands-index commands-index-check

install:        ## Run initial dotfiles install (./install.sh)
	@./install.sh

refresh:        ## Run ./install.sh --refresh
	@./install.sh --refresh

help:  ## Print Makefile targets (GNU Make owns make -h / make --help; use make sync-help for the sync script)
	@printf 'Usage: make [TARGET]\n'
	@printf '(make -h and make --help are handled by GNU Make itself; use make sync-help for the sync script only.)\n\nTargets:\n'
	@awk 'BEGIN {FS = ":.*## "} \
	      /^[a-zA-Z][a-zA-Z0-9_-]*:.*## / {printf "  %-20s %s\n", $$1, $$2}' \
	      $(MAKEFILE_LIST)

sync-help:      ## Print sync script usage (same as ./scripts/sync-coding-tools.sh -h / --help)
	@$(SCRIPT) --help

sync:           ## Copy-sync everything to all configured tools
	@$(SCRIPT)

sync-cursor:    ## Copy-sync only Cursor targets
	@$(SCRIPT) --targets cursor

sync-claude:    ## Copy-sync only Claude targets
	@$(SCRIPT) --targets claude

sync-opencode:  ## Copy-sync only OpenCode targets
	@$(SCRIPT) --targets opencode

mirrors:        ## Regenerate the repo-root project mirrors from ai-coding/plugins
	@$(MIRROR_SCRIPT)

mirrors-check:  ## Fail if a project mirror drifted from its source (no writes)
	@$(MIRROR_SCRIPT) --check

skills-index:   ## Regenerate ai-coding/indexes/skills.md from ai-coding/plugins
	@$(INDEX_SCRIPT) --kind skills

skills-index-check: ## Fail if the skills index drifted from ai-coding/plugins (no writes)
	@$(INDEX_SCRIPT) --kind skills --check

commands-index: ## Regenerate ai-coding/indexes/commands.md from ai-coding/plugins
	@$(INDEX_SCRIPT) --kind commands

commands-index-check: ## Fail if the commands index drifted from ai-coding/plugins (no writes)
	@$(INDEX_SCRIPT) --kind commands --check

symlink:        ## Symlink-sync everything (edits in the repo go live)
	@$(SCRIPT) --mode symlink

symlink-cursor: ## Symlink-sync only Cursor targets
	@$(SCRIPT) --mode symlink --targets cursor

symlink-claude: ## Symlink-sync only Claude targets
	@$(SCRIPT) --mode symlink --targets claude

symlink-opencode: ## Symlink-sync only OpenCode targets
	@$(SCRIPT) --mode symlink --targets opencode

dry-run:        ## Show what `make sync` would do (no filesystem writes)
	@$(SCRIPT) --dry-run

status:         ## Show what is out-of-sync between repo and home
	@$(SCRIPT) --dry-run --verbose

unlink:         ## Reverse a previous sync (remove symlinks/copies; restore backups)
	@$(SCRIPT) --unlink

clean: unlink   ## Alias for `make unlink`
