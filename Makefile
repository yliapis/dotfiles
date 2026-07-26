# Makefile — thin convenience wrapper so `make install`, `make refresh`,
# `make sync`, `make sync-cursor`, `make symlink`, `make dry-run`,
# `make status`, `make unlink`, `make clean`, `make sync-help`, and `make help`
# (default) all work without the user having to remember the flag set.
#
# The script (scripts/sync-coding-tools.sh) is the single source of truth for both
# copy-mode (rsync) and symlink-mode logic, the audit log, and the
# --unlink reverse operation. This Makefile only translates target names
# to the equivalent `./scripts/sync-coding-tools.sh ...` invocations.

# GNU Make ignores $SHELL from the environment and defaults to /bin/sh.
# Honor the user's login shell when make's SHELL was not set on the command line.
ifneq ($(origin SHELL),command line)
SHELL := $(shell printf '%s' "$${SHELL:-/bin/sh}")
endif
.SHELLFLAGS := -eu -c
.DEFAULT_GOAL := help

SCRIPT := ./scripts/sync-coding-tools.sh

.PHONY: help install refresh sync-help sync sync-cursor sync-claude sync-opencode symlink symlink-cursor symlink-claude symlink-opencode dry-run status unlink clean

install:        ## Run initial dotfiles install (./install.sh)
	@./install.sh

refresh:        ## Brew bundle, upgrades, sync, and install-*.sh scripts (./refresh.sh)
	@./refresh.sh

help:  ## Print targets and sync script CLI (GNU Make owns make -h / make --help)
	@printf 'Usage: make [TARGET]\n'
	@printf '(make -h and make --help are handled by GNU Make itself; use make sync-help for the sync script only.)\n\nTargets:\n'
	@awk 'BEGIN {FS = ":.*## "} \
	      /^[a-zA-Z][a-zA-Z0-9_-]*:.*## / {printf "  %-16s %s\n", $$1, $$2}' \
	      $(MAKEFILE_LIST)
	@printf '\n--- scripts/sync-coding-tools.sh ---\n'
	@$(SCRIPT) --help

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
