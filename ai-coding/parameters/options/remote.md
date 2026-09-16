# `remote` — git remote used for end-of-run push and hygiene checks

Configured git remote name (default `origin`) used for end-of-run push or
push-hygiene checks: merge-commit-push pushes the target branch to it;
wrap-up pushes `base_branch` after the archive merge; soft-shutdown checks
it for unpushed commits.

- **Used by:** merge-commit-push, wrap-up, soft-shutdown
- **Full entry:** [concerns/lifecycle.md](../concerns/lifecycle.md#remote)
