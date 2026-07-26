# Merge Commit Push (Compatibility)

## Status

Compatibility command for the `operating-git` integrate motion. Keep this slash
command as an explicit entry point, but maintain no second merge/push procedure
here.

## Parameters

`{source_branch}`, `{target_branch}`, `{merge_strategy}`, `{remote}`,
`{commit_message}`, and `{include_push}` map unchanged to
[../skills/operating-git/MERGE_PUSH.md](../skills/operating-git/MERGE_PUSH.md).

## Workflow

1. Resolve the supplied parameters without changing Git state.
2. Invoke `operating-git` with `{operation}=integrate`.
3. Load and follow `MERGE_PUSH.md` in full. For `--squash`, also load and
   follow `COMMITS.md`.
4. Prefix the canonical report with:

```text
Compatibility route: /merge-commit-push -> operating-git/integrate
```

## Guardrails

- MUST NOT merge, commit, or push independently of `operating-git`.
- MUST NOT weaken clean-tree, conflict, remote, force-push, or reporting rules.
- MUST NOT hide rejected or unsupported parameters.
