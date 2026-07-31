# Repo Critique — dotfiles

- **Description:** repo-critique
- **Model:** openai/gpt-5.6-terra-pro
- **Captured at (UTC):** 2026-07-31T23:24:17Z

---

# Critique: dotfiles repository (targeted operational review)

**Context:** `/Users/yliapis/src/dotfiles`. This review examined the installation, home-directory sync, project-mirror, indexing, cloud-bootstrap, and configuration paths. Existing untracked architecture-diagram files were not changed.

**Criteria applied:** correctness, side-effect safety, idempotency, deterministic behavior, and operability.

## Summary

The repo-root mirror workflow is solid: it has deterministic source enumeration, collision detection, pruning, and no-write drift checks. `make mirrors-check`, `make skills-index-check`, and `make commands-index-check` all passed with zero drift; the applicable shell syntax and shellcheck checks also passed.

The principal risks remain in `scripts/sync-coding-tools.sh`, whose home-directory copy workflow neither behaves as a no-write dry run nor converges destination state to the source tree. Its inverse operation is incomplete, and unlike the project-mirror workflow it silently permits flattened artifact-name collisions. The installer also does not execute the existing Snap installer because its naming does not match the install-script discovery convention.

## Findings

### High

- **Correctness / side-effect safety** @ `scripts/sync-coding-tools.sh:207,239,243,248,262` and `Makefile:95-96`
  - **Evidence:** `--dry-run` is documented as making no filesystem writes, but copy mode unconditionally executes `mkdir -p` for command, skill, agent, and plugin destinations. The EXIT trap at line 207 appends to `~/.cache/dotfiles/sync.log` for dry runs as well.
  - **Reproduction:** with a disposable `HOME`, `scripts/sync-coding-tools.sh --dry-run --targets cursor` created `.cursor/{commands,skills,agents,plugins/...}` plus `.cache/dotfiles/sync.log`.
  - **Impact:** a preview command alters the machine it is supposed to inspect, breaking automation and user expectations.
  - **Recommendation:** guard all directory creation and audit-log writes behind `! DRY_RUN`; if audit logging during previews is intended, document it as the explicit exception rather than promising no writes.

- **Idempotency / correctness** @ `scripts/sync-coding-tools.sh:216,240,244,249`
  - **Evidence:** `RSYNC_BASE=(rsync -aL --itemize-changes)` has no pruning behavior, although copy mode is described as deterministic and as using the repo as source of truth.
  - **Reproduction:** after copy-syncing to a disposable `HOME`, deleting `ai-coding/plugins/writing/commands/critique.md`, and re-syncing, the old `~/.cursor/commands/critique.md` still existed.
  - **Impact:** retired commands, skills, and agents remain discoverable; destination state depends on historical syncs rather than the checked-out tree.
  - **Recommendation:** introduce a manifest-owned destination namespace and prune only owned entries, or use `rsync --delete` only where the destination is exclusively managed by this repo. Do not broadly delete shared user directories.

- **Correctness / reversibility** @ `scripts/sync-coding-tools.sh:409-419,438-440,457-463`
  - **Evidence:** the copy-mode unlink branch only considers regular files (`-f`), while skills are copied as directories. Marketplace/plugin cleanup only handles a symlinked plugin directory.
  - **Reproduction:** after copy-syncing and running `--unlink` in a disposable `HOME`, `~/.cursor/skills/stop-slop` and `~/.cursor/plugins/local/ai-coding` both remained.
  - **Impact:** the advertised reverse operation leaves meaningful copy-mode state behind and cannot restore a clean prior state.
  - **Recommendation:** record ownership for copied skill/plugin directories and remove only verified owned artifacts recursively; cover copy and symlink modes independently with integration tests.

### Medium

- **Correctness** @ `scripts/sync-coding-tools.sh:50-52,240,244,249` vs. `scripts/sync-project-mirrors.sh:149-168`
  - **Evidence:** home-directory sync flattens commands, skills, and agents from every plugin without a duplicate-name preflight. The sibling project-mirror script explicitly aborts on those collisions.
  - **Reproduction:** adding a second synthetic `designer.md` under another plugin let `sync-coding-tools.sh --targets cursor` complete successfully; it did not reject the collision.
  - **Impact:** two plugins can provide the same flattened artifact name and silently shadow one another in every home-directory installation.
  - **Recommendation:** perform the same collision validation before both sync workflows, ideally from a shared Bash-compatible checker or common manifest generator.

- **Completeness** @ `install.sh:64-68`, `scripts/snap-installs.sh`, and `install.sh:264`
  - **Evidence:** `run_install_scripts` selects only `scripts/install-*.sh`, but the existing Snap installer is named `snap-installs.sh`; no other code invokes it. The refresh path also retains a TODO for Snap refresh.
  - **Impact:** the committed Snap installation script is not part of either bootstrap or refresh, making its declared tooling unmanaged in practice.
  - **Recommendation:** rename it to the discovery convention, invoke it explicitly on supported Linux systems, or remove it and document Snap installation as manual. Add a corresponding refresh policy if Snap is intentionally supported.

- **Robustness** @ `install.sh:228-244,247-267`
  - **Evidence:** unlike the operational scripts, `install.sh` has no strict error policy and always reaches its completion message after the bootstrap sequence unless an individual function explicitly exits.
  - **Impact:** failures from package installers, Brewfile provisioning, copying home configuration, or modular scripts can leave a partial system while the script reports completion.
  - **Recommendation:** make executable installation fail fast (`set -euo pipefail`) and identify deliberately nonfatal operations explicitly. If sourced execution remains supported, use return-aware error handling so failures do not terminate the caller’s shell.

## What is working well

- `scripts/sync-project-mirrors.sh` is a good model for the rest of the tooling: source-directory guards, deterministic ordering, collision checks, pruning, real-copy enforcement, and `--check` semantics are all present.
- `scripts/gen-artifact-index.sh` produces deterministic indexes and exposes drift checks through the Makefile.
- Validation completed successfully:
  - `zsh -n install.sh scripts/sync-coding-tools.sh`
  - `shellcheck scripts/sync-project-mirrors.sh scripts/gen-artifact-index.sh ai-coding/hooks/*.sh`
  - `make mirrors-check skills-index-check commands-index-check`

## Suggested remediation order

1. Make `--dry-run` genuinely side-effect free.
2. Define owned-artifact/pruning semantics for copy mode and implement complete copy-mode unlink.
3. Add flattened-name collision validation to home-directory sync.
4. Bring the Snap installer into a deliberate bootstrap/refresh contract.
5. Establish an explicit failure model for `install.sh`.
