---
name: manage-packages
description: "Add, delete, or update packages in this dotfiles repo's Brewfile, Brewfile.mas, snap installs, uv tool installs, vscode extensions, or other package manifests. Default mode opens a GitHub PR, merges it into main, and stops. Use when the user asks to add a brew formula or cask, remove a package, rename or retarget a Brewfile pin, edit snap installs, or change a package-manager manifest."
license: MIT
---

# Manage Packages

## Task

Apply a set of `{packages}` operations (`add`, `delete`, `update`) to the
package manifests in this repository, verify each change the way recent
Brewfile PRs did, then finish in `{mode}`. `{mode}=pr` (default) opens a
GitHub PR, merges it into `main`, and stops.

This skill is for the `yliapis/dotfiles` repo only. It composes
`conventional-commits` and `minimal-diffs` from the `git-operations` plugin.
Read [references/managers.md](references/managers.md) before the first edit.

## Parameters

- `{packages}` — required list of operations. Accept YAML, JSON, or
  unambiguous inline text (`add utm; delete messenger; update claude-code ->
  claude-code@latest`). Each record has:
  - `name` — package token (required)
  - `action` — `add` | `delete` | `update` (required)
  - `manager` — `auto` | `brew` | `mas` | `snap` | `uv` | `vscode`; optional,
    default `auto`
  - `kind` — `auto` | `formula` | `cask` | `tap`; optional, default `auto`
    (brew only)
  - `to` — replacement token or spec; required for `update`
  - `gate` — `auto` | `macos` | `linux` | `none`; optional, default `auto`
  - `tap` — third-party tap; optional
  - `id` — Mac App Store numeric id; required when `manager=mas` and the id
    is not already on the line
- `{mode}` — `pr` | `local`; optional, default `pr`.
  - `pr`: branch from `origin/main`, commit, push, open a PR, squash-merge
    it into `main`, then stop.
  - `local`: commit on a local branch; do not push or open a PR.
- `{dry_run}` — optional boolean, default `false`. Resolve, classify, and
  report the plan. Write no files, create no commit, and open no PR.

Unknown parameters or invalid values abort before side effects.

## Success Criteria

- [ ] Abort before side effects unless this worktree is the dotfiles repo
      (`Brewfile` and `ai-coding/plugins/` exist at the root) and
      `{packages}` parses to at least one valid record.
- [ ] Resolve every record's manager, kind, gate, and target path before the
      first edit. One unresolved or conflicting record aborts the set.
- [ ] Prove each `add` / `update` target exists and is not disabled via the
      manager API in [references/managers.md](references/managers.md). Prove
      each `delete` target is present in its manifest.
- [ ] Edit only the planned manifest lines (and a tap line that the last
      consumer of that tap required). No drive-by reordering or retargeting.
- [ ] Re-run verification after the edit: exact line presence/absence, OS-gate
      eval via [scripts/eval-brewfile-os.py](scripts/eval-brewfile-os.py) for
      Brewfile changes, and the same API checks as the plan.
- [ ] `{dry_run}=true` writes nothing.
- [ ] `{mode}=pr` produces one Conventional Commit, one GitHub PR from a
      branch off `origin/main`, a squash-merge into `main`, and a Done report
      that names the PR URL and the merge commit SHA. A blocked merge is not
      Done: report the PR URL and the merge error, then stop.
- [ ] `{mode}=local` produces the same commit contract without push, PR, or
      merge.

## Guardrails

- MUST compose `conventional-commits` and `minimal-diffs`. If either skill
  is missing, stop before editing.
- MUST NOT invent a new manifest file. If the resolved manager has no file
  in [references/managers.md](references/managers.md), abort and name the
  gap (apt is upgrade-only in `install.sh`; there is no apt package list).
- MUST NOT run `brew bundle`, `brew install`, `snap install`, `uv tool
  install`, or `mas install` unless the user asked to provision this
  machine. Manifest edit plus API / parse evidence is enough (cloud VMs
  often have no Homebrew).
- MUST NOT add a tap when `homebrew/core` or `homebrew/cask` already ships
  the package. MUST NOT use `mas` when a Homebrew cask exists.
- MUST NOT shrink the set of unguarded Linux-capable CLI casks unless the
  user is updating or deleting one of those casks.
- MUST NOT force-push, amend, or merge with `--admin`. On merge failure,
  leave the PR open and stop.
- MUST NOT commit unrelated paths (including untracked docs).
- MUST NOT create a Backlog.md ticket unless the user asked or one already
  exists for this change. When a ticket exists, add `Ticket-Id: TKT-NNN`
  to the commit body.
- Scope: one package-set → one commit → (in `pr`) one merged PR. Out of
  scope: rewriting `install.sh`, adding package managers, or changing
  sync/mirror tooling.

## Workflow

1. **Preflight.** Confirm repo identity. Parse `{packages}`. Resolve
   `{mode}` (`pr`) and `{dry_run}` (`false`). Require
   `conventional-commits` and `minimal-diffs`. For `{mode}=pr`, require
   `gh` and a clean worktree (`git status --porcelain` empty of unrelated
   paths). Fetch `origin/main`.
2. **Classify.** For each record, follow Kind Resolution and OS Gates in
   [references/managers.md](references/managers.md). Probe APIs. Record
   the planned line, file, and gate. Abort the whole set on the first
   failure.
3. **Plan.** Render the Output Format Plan. Stop when `{dry_run}` is true
   or a record is ambiguous after the resolution rules.
4. **Branch.** `{mode}=pr`: create `chore/packages-<slug>` from
   `origin/main`. `{mode}=local`: use the current branch when it is not
   `main`; otherwise create the same slug branch locally.
5. **Edit.** Apply each record with a minimal diff. Keep section
   placement and tap `trusted:` syntax from the reference. On `delete`,
   drop the tap line only when this package was its last consumer.
6. **Verify.** Grep the exact lines. For Brewfile edits, run:

   ```sh
   python3 ai-coding/plugins/dotfiles-dev/skills/manage-packages/scripts/eval-brewfile-os.py \
     --file Brewfile --os linux --kind cask
   python3 ai-coding/plugins/dotfiles-dev/skills/manage-packages/scripts/eval-brewfile-os.py \
     --file Brewfile --os mac --kind cask
   ```

   Re-check APIs. A Linux eval MUST NOT request a new `if OS.mac?` package.
   A macOS eval MUST request it. Cross-platform formulae stay unguarded.
7. **Commit.** One Conventional Commit for the set. Scope `brew`, `mas`,
   `snap`, `uv`, or `vscode` when every record shares that manager;
   otherwise `packages`. Recent brew subjects look like
   `chore(brew): add utm cask`. Body: why, tap/gate choice, and
   Acceptance / Verification bullets when the change is non-trivial.
8. **PR mode.** Push `-u origin HEAD`. Open the PR with `gh pr create`
   using the PR template in the reference. Then:

   ```sh
   gh pr merge --squash --delete-branch
   ```

   Confirm `origin/main` advanced to the squash commit. That is Done.
   If merge is rejected (review required, checks, conflict), report the
   PR URL and the error; do not retry with extra flags.

## Output Format

Named sections, in order:

### Plan

One row per record: `name`, `action`, `manager`, `kind`, `file`, `gate`,
`line` (the exact planned text), and the API proof used.

### Edits

Repo-relative paths and the line-level change, or `none (dry-run)`.

### Verification

Commands run, exit status, and the facts they proved (token, tap,
`disabled`/`deprecated`, bottles or platform, Linux vs macOS eval).

### Git

Branch, commit SHA, subject. For `{mode}=pr`: PR URL, merge result
(`merged` | `blocked`), merge commit SHA when merged.

### Outcome

One sentence. `pr` + successful merge ends with **Done**.
