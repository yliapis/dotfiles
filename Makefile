# Makefile — thin convenience wrapper around sync-coding-tools.sh so
# `make sync`, `make sync-cursor`, `make symlink`, `make dry-run`,
# `make status`, `make unlink`, `make clean`, `make sync-help`, and `make help` all work
# without the user having to remember the flag set.
#
# The script (sync-coding-tools.sh) is the single source of truth for both
# copy-mode (rsync) and symlink-mode logic, the audit log, and the
# --unlink reverse operation. This Makefile only translates target names
# to the equivalent `./sync-coding-tools.sh ...` invocations.

SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := sync

SCRIPT := ./sync-coding-tools.sh

.PHONY: help sync-help sync sync-cursor sync-claude symlink symlink-cursor symlink-claude dry-run status unlink clean

help:  ## Print targets and sync script CLI (GNU Make owns make -h / make --help)
	@printf 'Usage: make [TARGET]\n'
	@printf '(make -h and make --help are handled by GNU Make itself; use make sync-help for the sync script only.)\n\nTargets:\n'
	@awk 'BEGIN {FS = ":.*## "} \
	      /^[a-zA-Z][a-zA-Z0-9_-]*:.*## / {printf "  %-16s %s\n", $$1, $$2}' \
	      $(MAKEFILE_LIST)
	@printf '\n--- sync-coding-tools.sh ---\n'
	@$(SCRIPT) --help

sync-help:      ## Print sync-coding-tools.sh usage (same as ./sync-coding-tools.sh -h / --help)
	@$(SCRIPT) --help

sync:           ## Copy-sync everything to all configured tools (default)
	@$(SCRIPT)

sync-cursor:    ## Copy-sync only Cursor targets
	@$(SCRIPT) --targets cursor

sync-claude:    ## Copy-sync only Claude targets
	@$(SCRIPT) --targets claude

symlink:        ## Symlink-sync everything (edits in the repo go live)
	@$(SCRIPT) --mode symlink

symlink-cursor: ## Symlink-sync only Cursor targets
	@$(SCRIPT) --mode symlink --targets cursor

symlink-claude: ## Symlink-sync only Claude targets
	@$(SCRIPT) --mode symlink --targets claude

dry-run:        ## Show what `make sync` would do (no filesystem writes)
	@$(SCRIPT) --dry-run

status:         ## Show what is out-of-sync between repo and home
	@$(SCRIPT) --dry-run --verbose

unlink:         ## Reverse a previous sync (remove symlinks/copies; restore backups)
	@$(SCRIPT) --unlink

clean: unlink   ## Alias for `make unlink`
