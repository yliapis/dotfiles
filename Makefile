# Makefile -- propagate AI-coding artifacts from this dotfiles repo into the
# user's home directory so Cursor and Claude Code can pick them up.
#
# Sources (under this repo, do not modify by hand here):
#   ai-coding/plugins/ai-coding/commands/*.md          slash commands
#   ai-coding/plugins/ai-coding/skills/<name>/SKILL.md skills
#   ai-coding/{marketplace.json,.claude-plugin,.cursor-plugin}
#                                                      plugin / marketplace metadata
#
# Destinations are listed below as variables; override on the command line to
# retarget, e.g. `make sync CURSOR_COMMANDS_DST=/tmp/cmds`.
#
# Quick start:
#   make help        list all targets
#   make dry-run     simulate the sync (no writes)
#   make status      show which paths are out of sync
#   make sync        sync to all configured tools (default goal)
#   make -j sync     same, parallel-safe
#   make clean       remove just the artifacts this Makefile manages

SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := sync

# -- source paths -----------------------------------------------------------

REPO_ROOT       := $(CURDIR)
SRC_COMMANDS    := $(REPO_ROOT)/ai-coding/plugins/ai-coding/commands
SRC_SKILLS      := $(REPO_ROOT)/ai-coding/plugins/ai-coding/skills
SRC_MARKETPLACE := $(REPO_ROOT)/ai-coding

# -- destination paths (override-friendly) ---------------------------------

CURSOR_COMMANDS_DST    := $(HOME)/.cursor/commands
CURSOR_SKILLS_DST      := $(HOME)/.cursor/skills-cursor
CURSOR_PLUGIN_DST      := $(HOME)/.cursor/plugins/local/ai-coding

CLAUDE_COMMANDS_DST    := $(HOME)/.claude/commands
CLAUDE_SKILLS_DST      := $(HOME)/.claude/skills
CLAUDE_MARKETPLACE_DST := $(HOME)/.claude/plugins/marketplaces/yliapis-dotfiles

# -- rsync invocation -------------------------------------------------------
#
# `-L` dereferences symlinks (the .claude-plugin/.cursor-plugin marketplace.json
# entries are symlinks to ../marketplace.json; we want real files at the dest).
# `--itemize-changes` prints one line per change so `dry-run` and `status` are
# useful. `dry-run` and `status` re-invoke `make sync` with RSYNC overridden.

RSYNC ?= rsync -aL --itemize-changes

# Item lists derived from the source tree -- used by `clean` so we only remove
# files this Makefile is responsible for (siblings in the destination dirs are
# left alone).

COMMAND_FILES := $(notdir $(wildcard $(SRC_COMMANDS)/*.md))
SKILL_DIRS    := $(notdir $(wildcard $(SRC_SKILLS)/*))

# -- phony declarations -----------------------------------------------------

.PHONY: help sync sync-cursor sync-claude dry-run status clean
.PHONY: _sync-cursor-commands _sync-cursor-skills _sync-cursor-plugin
.PHONY: _sync-claude-commands _sync-claude-skills _sync-claude-marketplace

# -- public targets ---------------------------------------------------------

help:  ## Print available targets with one-line descriptions
	@printf 'Usage: make [TARGET] [VAR=value ...]\n\nTargets:\n'
	@awk 'BEGIN {FS = ":.*## "} \
	      /^[a-zA-Z][a-zA-Z0-9_-]*:.*## / {printf "  %-14s  %s\n", $$1, $$2}' \
	      $(MAKEFILE_LIST)
	@printf '\nKey paths:\n'
	@printf '  cursor commands     -> %s\n' "$(CURSOR_COMMANDS_DST)"
	@printf '  cursor skills       -> %s\n' "$(CURSOR_SKILLS_DST)"
	@printf '  cursor plugin       -> %s\n' "$(CURSOR_PLUGIN_DST)"
	@printf '  claude commands     -> %s\n' "$(CLAUDE_COMMANDS_DST)"
	@printf '  claude skills       -> %s\n' "$(CLAUDE_SKILLS_DST)"
	@printf '  claude marketplace  -> %s\n' "$(CLAUDE_MARKETPLACE_DST)"

sync: sync-cursor sync-claude  ## Sync everything to all configured tools (default)

sync-cursor: _sync-cursor-commands _sync-cursor-skills _sync-cursor-plugin  ## Sync only Cursor targets

sync-claude: _sync-claude-commands _sync-claude-skills _sync-claude-marketplace  ## Sync only Claude targets

dry-run:  ## Simulate the sync without writing (rsync --dry-run)
	@printf '==> DRY RUN (no writes)\n' >&2
	@$(MAKE) --no-print-directory sync RSYNC='rsync -aL --itemize-changes --dry-run'

status:  ## Show what is out-of-sync between repo and home (rsync -n -i)
	@printf '==> STATUS (out-of-sync items shown by rsync -i)\n' >&2
	@$(MAKE) --no-print-directory sync RSYNC='rsync -aLni --itemize-changes'

clean:  ## Remove the artifacts managed by this Makefile (FORCE=1 to skip prompt)
	@if [ "$(FORCE)" != "1" ]; then \
		printf 'About to remove these managed artifacts:\n' >&2; \
		for f in $(COMMAND_FILES); do \
			printf '  %s\n' "$(CURSOR_COMMANDS_DST)/$$f" >&2; \
			printf '  %s\n' "$(CLAUDE_COMMANDS_DST)/$$f" >&2; \
		done; \
		for d in $(SKILL_DIRS); do \
			printf '  %s\n' "$(CURSOR_SKILLS_DST)/$$d" >&2; \
			printf '  %s\n' "$(CLAUDE_SKILLS_DST)/$$d" >&2; \
		done; \
		printf '  %s\n' "$(CURSOR_PLUGIN_DST)" >&2; \
		printf '  %s\n' "$(CLAUDE_MARKETPLACE_DST)" >&2; \
		printf 'Continue? [y/N] ' >&2; \
		read confirm; \
		case "$${confirm:-}" in y|Y|yes|YES) ;; *) printf 'aborted\n' >&2; exit 1 ;; esac; \
	fi
	@printf '==> clean cursor commands\n' >&2
	@for f in $(COMMAND_FILES); do rm -f "$(CURSOR_COMMANDS_DST)/$$f"; done
	@printf '==> clean cursor skills\n' >&2
	@for d in $(SKILL_DIRS); do rm -rf "$(CURSOR_SKILLS_DST)/$$d"; done
	@printf '==> clean cursor plugin -> %s\n' "$(CURSOR_PLUGIN_DST)" >&2
	@rm -rf "$(CURSOR_PLUGIN_DST)"
	@printf '==> clean claude commands\n' >&2
	@for f in $(COMMAND_FILES); do rm -f "$(CLAUDE_COMMANDS_DST)/$$f"; done
	@printf '==> clean claude skills\n' >&2
	@for d in $(SKILL_DIRS); do rm -rf "$(CLAUDE_SKILLS_DST)/$$d"; done
	@printf '==> clean claude marketplace -> %s\n' "$(CLAUDE_MARKETPLACE_DST)" >&2
	@rm -rf "$(CLAUDE_MARKETPLACE_DST)"

# -- private per-tool / per-type targets -----------------------------------
#
# Each one is independent (distinct destination path) so `make -j` is safe.
# Replacing a bare symlink at the destination with a real directory is handled
# in `_sync-cursor-plugin`; the other destinations cannot conflict with a stale
# symlink today, but the same guard is cheap to add if that changes.

_sync-cursor-commands:
	@printf '==> sync cursor commands -> %s\n' "$(CURSOR_COMMANDS_DST)" >&2
	@mkdir -p "$(CURSOR_COMMANDS_DST)"
	@$(RSYNC) "$(SRC_COMMANDS)"/*.md "$(CURSOR_COMMANDS_DST)/"

_sync-cursor-skills:
	@printf '==> sync cursor skills -> %s\n' "$(CURSOR_SKILLS_DST)" >&2
	@mkdir -p "$(CURSOR_SKILLS_DST)"
	@$(RSYNC) "$(SRC_SKILLS)/" "$(CURSOR_SKILLS_DST)/"

_sync-cursor-plugin:
	@printf '==> sync cursor plugin metadata -> %s\n' "$(CURSOR_PLUGIN_DST)" >&2
	@if [ -L "$(CURSOR_PLUGIN_DST)" ]; then rm -f "$(CURSOR_PLUGIN_DST)"; fi
	@mkdir -p "$(CURSOR_PLUGIN_DST)/.cursor-plugin"
	@$(RSYNC) "$(SRC_MARKETPLACE)/marketplace.json" "$(CURSOR_PLUGIN_DST)/marketplace.json"
	@$(RSYNC) "$(SRC_MARKETPLACE)/.cursor-plugin/" "$(CURSOR_PLUGIN_DST)/.cursor-plugin/"

_sync-claude-commands:
	@printf '==> sync claude commands -> %s\n' "$(CLAUDE_COMMANDS_DST)" >&2
	@mkdir -p "$(CLAUDE_COMMANDS_DST)"
	@$(RSYNC) "$(SRC_COMMANDS)"/*.md "$(CLAUDE_COMMANDS_DST)/"

_sync-claude-skills:
	@printf '==> sync claude skills -> %s\n' "$(CLAUDE_SKILLS_DST)" >&2
	@mkdir -p "$(CLAUDE_SKILLS_DST)"
	@$(RSYNC) "$(SRC_SKILLS)/" "$(CLAUDE_SKILLS_DST)/"

_sync-claude-marketplace:
	@printf '==> sync claude marketplace metadata -> %s\n' "$(CLAUDE_MARKETPLACE_DST)" >&2
	@if [ -L "$(CLAUDE_MARKETPLACE_DST)" ]; then rm -f "$(CLAUDE_MARKETPLACE_DST)"; fi
	@mkdir -p "$(CLAUDE_MARKETPLACE_DST)/.claude-plugin"
	@$(RSYNC) "$(SRC_MARKETPLACE)/marketplace.json" "$(CLAUDE_MARKETPLACE_DST)/marketplace.json"
	@$(RSYNC) "$(SRC_MARKETPLACE)/.claude-plugin/" "$(CLAUDE_MARKETPLACE_DST)/.claude-plugin/"
