# Skill auto-attach

A cloud agent run on commit `4bb0522` read `AGENTS.md` and was offered none of
the 15 skills this repo defines. This report records what was observed, what the
shipped agent runtime does, and the findings that follow from both. It proposes
work; it does not perform any.

## Method

Three sources of evidence back the findings below. The first is the run itself:
its session context carried `AGENTS.md` but no skill list, with all nine project
mirrors symlinked. The second is the repository, where `git ls-files -s` reports
mode `120000` for every mirror entry and the sync scripts were read directly.
The third is the shipped `cursor-agent` 2026.07.23 bundle, whose
skill-discovery and skill-root code was read from the installed JavaScript.

Reading a client bundle is weaker than reading a specification, so each finding
states what that code shows rather than what the product guarantees.

## Skill roots the runtime declares

The bundle enumerates project roots `.cursor/skills`, `.agents/skills`, and
conditionally `.claude/skills` and `.codex/skills`; the same four under `$HOME`
carry `scope: "user"`. One further root, `~/.cursor/skills-cursor`, carries
`scope: "builtin"` and `source: "builtin"`.

Two discovery implementations coexist. One stats a symlinked entry and keeps it
when the target is a directory. Another resolves the link and compares the real
path against the directory being scanned, skipping the entry when the real path
falls outside; its failure surfaces as `Path escapes plugin directory via
symlink`. Which of the two runs for a given client and context was not
determined, and the bundle does not say.

## Findings

- **Project skill mirrors depend on symlink resolution** @ `.cursor/skills/`
  - Evidence: `git ls-files -s .cursor/skills` reports mode `120000` for all 15 entries, each pointing at `../../ai-coding/plugins/<plugin>/skills/<name>`.
  - Evidence: `realpath .cursor/skills/stop-slop` resolves to `/workspace/ai-coding/plugins/writing/skills/stop-slop`, outside `/workspace/.cursor/skills`, so every mirror link leaves the directory a scanner would walk.
  - Evidence: The cloud agent run on this layout was offered zero of the 15 skills while its context still carried `AGENTS.md`, so the transport that delivers repository instructions worked while skill delivery did not.
  - Context: the same layout covers commands and agents, so a discovery path that skips links skips all 75 mirror entries rather than skills alone.
  - Rationale: one shipped discovery implementation keeps a symlinked skill directory and another drops any link whose real path leaves the scanned directory, so whether a skill reaches the agent depends on which implementation the client runs.
  - Where: `.claude/skills/`, `.opencode/skills/`, `.cursor/commands/`, `.cursor/agents/`
  - Done-when: No entry under any of the nine repo-root mirrors is a symlink, and `find .cursor .claude .opencode -maxdepth 2 -type l` prints nothing
  - Done-when: Each mirrored skill directory is byte-identical to its `ai-coding/plugins/*/skills/<name>` source
  - Done-when: `ai-coding/plugins/` remains the only location a maintainer edits
  - Depends on: Mirror regeneration is a hand-run loop with no prune or drift check
  - Severity: critical
  - Type: fix
  - Estimate: M

- **Mirror regeneration is a hand-run loop with no prune or drift check** @ `AGENTS.md`
  - Evidence: `AGENTS.md` asks the maintainer to paste a three-tool `for` loop over `ai-coding/plugins/*/{commands,skills,agents}` to rebuild all nine mirrors.
  - Evidence: The same section says to remove leftover symlinks for deleted artifacts by hand, so a renamed or deleted skill leaves a stale mirror entry until someone notices.
  - Evidence: No target, script, or check reports whether the mirrors currently match `ai-coding/plugins/`, so drift stays invisible until an agent silently misses a skill.
  - Context: flattening means one name may be claimed by only one plugin, and nothing currently detects a collision between two plugins.
  - Rationale: a mirror layout that only a pasted loop can reproduce cannot be verified in review, and that layout is what skill discovery depends on.
  - Where: `Makefile`, `scripts/`
  - Done-when: One committed script regenerates all nine mirrors from `ai-coding/plugins/` and is reachable from a `make` target
  - Done-when: The script prunes mirror entries whose source no longer exists
  - Done-when: The script exits non-zero with an explanatory message when two plugins claim the same flattened name
  - Done-when: A no-write check mode exits non-zero when any mirror has drifted from its source and is reachable from a `make` target
  - Done-when: The script runs on a VM that has neither zsh nor rsync installed
  - Severity: major
  - Type: feat
  - Estimate: M

- **Cursor user-scope skills sync into the builtin skill root** @ `scripts/sync-coding-tools.sh`
  - Evidence: `dest_skills_dir` returns `$HOME/.cursor/skills-cursor` for the cursor target.
  - Evidence: The shipped bundle registers `~/.cursor/skills-cursor` with `scope: "builtin"` and `source: "builtin"`, and registers `~/.cursor/skills` with `scope: "user"`.
  - Context: this target is what makes the skills available outside this repository, so the destination decides whether they appear in every other project.
  - Rationale: a global sync writes this repository's skills into a root the client treats as its own builtin content instead of registering them as user skills.
  - Done-when: A cursor-target sync writes each skill to `~/.cursor/skills/<name>/SKILL.md`
  - Done-when: The script records why `~/.cursor/skills-cursor` is not a destination so the value is not reverted later
  - Severity: major
  - Type: fix
  - Estimate: XS

- **Cloud bootstrap aborts when apt rejects the VM clock** @ `.cursor/scripts/cloud-agent-bootstrap.sh`
  - Evidence: The cloud install log records `E: Release file for http://archive.ubuntu.com/ubuntu/dists/noble-updates/InRelease is not valid yet (invalid for another 22h 55min 22s)` for five repositories.
  - Evidence: `/tmp/cursor/async-install/install-user.status` contained `100`, the apt exit code, so `set -e` ended the script at `apt-get update` before the install step ran.
  - Evidence: `command -v` found none of `zsh`, `rsync`, or `shellcheck` on the resulting VM, and `docs/reports/ticket-operations-engineering-loop-2026-07-26.md` records the same failure on an earlier run.
  - Context: every repo script except the mirror workflow runs under zsh, and the linter for a shell-script repository is one of the missing packages.
  - Rationale: a cloud VM whose clock sits behind the release-file validity window starts without any of the interpreters the repository's own scripts need.
  - Done-when: The bootstrap installs all three packages on a VM whose clock is a day behind real time
  - Done-when: Signature verification stays enabled and only the date window is relaxed
  - Severity: major
  - Type: fix
  - Estimate: XS

- **Two sync implementations disagree on the Cursor skills destination** @ `ai-coding/scripts/sync`
  - Evidence: `ai-coding/scripts/sync` maps `cursor:skill` to `$HOME/.cursor/skills` while `scripts/sync-coding-tools.sh` maps the same concept to `$HOME/.cursor/skills-cursor`.
  - Evidence: No `make` target, README section, or `AGENTS.md` line references `ai-coding/scripts/sync`, while the `Makefile` header calls `scripts/sync-coding-tools.sh` the single source of truth.
  - Evidence: `docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md` already recorded this disagreement as unresolved.
  - Rationale: two shipped scripts naming different Cursor skill destinations means the authoritative home layout cannot be settled by reading the repository.
  - Where: `scripts/sync-coding-tools.sh`
  - Done-when: Exactly one sync implementation ships, or the unreferenced one is deleted
  - Done-when: No two files in the repository name different Cursor skill destinations
  - Depends on: Cursor user-scope skills sync into the builtin skill root
  - Severity: minor
  - Type: refactor
  - Estimate: S

- **The committed skills index points at a path that no longer exists** @ `ai-coding/indexes/skills-2026-07-12.md`
  - Evidence: The index names `ai-coding/skills/` as its source root and lists 12 skills, while skills live under `ai-coding/plugins/*/skills/` and number 15.
  - Evidence: Every row of its path list, such as `ai-coding/skills/stop-slop/SKILL.md`, resolves to no file.
  - Context: the index describes itself as the parameter surface that de-slop commands enumerate, so the stale paths are consumed by tooling rather than read only by people.
  - Rationale: a hand-dated census rots whenever a skill is added or a plugin is split, and this one has already missed three skills and one directory move.
  - Done-when: An index lists all 15 skills at their current `ai-coding/plugins/*/skills/<name>/SKILL.md` paths
  - Done-when: The index is produced by a committed target, or is deleted in favour of a command that enumerates the skills directly
  - Severity: minor
  - Type: docs
  - Estimate: S

- **Nothing records why the mirrors cannot be symlinks** @ `README.md`
  - Evidence: `AGENTS.md` describes the mirrors as flattened per-item symlink mirrors and gives no indication that a discovery path may skip them.
  - Evidence: `README.md` documents `make help` and the cloud bootstrap but never mentions the project mirrors, so a reader cannot learn the layout from it.
  - Rationale: without the constraint written down, the next maintainer who prefers live edits reverts the layout and silently turns skill discovery off again.
  - Where: `AGENTS.md`
  - Done-when: Both files state the mirror layout, the regeneration command, and the drift-check command
  - Done-when: Both files state that a symlinked mirror entry is skipped by at least one discovery implementation, and name the escape hatch for a maintainer who wants live edits
  - Depends on: Project skill mirrors depend on symlink resolution
  - Severity: minor
  - Type: docs
  - Estimate: S

- **Skill auto-attach is never verified against a real client** @ `docs/`
  - Evidence: The only evidence gathered so far is filesystem shape plus inspection of the shipped bundle, and no client was observed listing the skills.
  - Evidence: Every `cursor-agent` command that would enumerate discovery returned `Error: Authentication required. Run 'agent login', pass --api-key/--auth-token, or set CURSOR_API_KEY/CURSOR_AUTH_TOKEN.` on the cloud VM.
  - Context: the repository ships skills for three separate clients, and only one of them was examined at all.
  - Rationale: a layout change justified by client behaviour stays unproven until a client is observed listing the skills, and the repository has no recorded procedure for checking that.
  - Done-when: A committed procedure states how to confirm a client lists all 15 skills
  - Done-when: One recorded observation shows a client listing them, from the Cursor skills panel or from a fresh cloud agent run that reports its skill list
  - Depends on: Project skill mirrors depend on symlink resolution
  - Severity: minor
  - Type: test
  - Estimate: S
