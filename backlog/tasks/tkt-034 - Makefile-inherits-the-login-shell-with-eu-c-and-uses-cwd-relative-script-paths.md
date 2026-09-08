---
id: TKT-034
title: >-
  Makefile inherits the login shell with -eu -c and uses cwd-relative script
  paths
status: To Do
assignee: []
created_date: '2026-09-08 19:30'
labels:
  - makefile
  - 'estimate:XS'
  - critique-opus-2026-08-16
dependencies: []
references:
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:182-184
  - >-
    docs/reports/bootstrap-critique-agent-swarm-5-claude-opus-5-1m-2026-08-16T18-46-48Z.md:196
  - 'Makefile:25-35'
priority: medium
type: fix
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Makefile deliberately overrides GNU Make's fixed `/bin/sh` with the operator's login shell and then hardcodes `.SHELLFLAGS := -eu -c`, flags a non-POSIX shell does not accept. Identical invocations succeed or fail on the value of `$SHELL`, and this repo's own Brewfile installs fish. Recipe paths are relative to the process cwd, so `make -f <abs>/Makefile <target>` from another directory fails.

### Evidence (main @ 225cbf2, 2026-09-08)

- `Makefile:27-29` `SHELL := $(shell printf '%s' "$${SHELL:-/bin/sh}")` unless SHELL was set on the command line; `Makefile:30` `.SHELLFLAGS := -eu -c`.
- Opus report: two runs verified `SHELL=<fish> make` fails every target with `fish: -eu: unknown option`. `Brewfile:19` installs fish.
- `Makefile:33-35` `SCRIPT := ./scripts/...`. Reproduced: `cd /tmp && make -f /workspace/Makefile mirrors-check` -> `Error 127`.
- `make help` itself now works under `/bin/sh` (the earlier `SHELL := /bin/zsh` finding is fixed).

### Provenance

Opus bootstrap critique 2026-08-16 (major, 5/5; relative paths minor, 3/5).

### Scope

- `Makefile` shell selection block and the three `*_SCRIPT` variables.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 SHELL=/usr/bin/fish make help (or any non-POSIX $SHELL) runs the recipes successfully; the Makefile pins a POSIX shell for recipes
- [ ] #2 make -f /path/to/repo/Makefile mirrors-check from an unrelated cwd succeeds (paths derived from $(dir $(lastword $(MAKEFILE_LIST))) or equivalent)
- [ ] #3 make mirrors-check skills-index-check commands-index-check still pass from the repo root
<!-- AC:END -->
