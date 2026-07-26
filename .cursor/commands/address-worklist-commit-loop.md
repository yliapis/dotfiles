# Address Worklist Commit Loop (Compatibility)

## Status

Deprecated compatibility command. `ticket-execute` supersedes this command for
native `ticket-operations` sets. Keep this slash command only so existing
invocations fail clearly or route into the canonical skill; do not maintain a
second execution workflow here.

## Parameters

- `{worklist}` — required path to a native managed `WORKLIST.md`; maps to
  `ticket-execute` `{target}`.
- `{mode}` — optional `interactive` | `non-interactive` |
  `force-approve-all`; maps unchanged. Default `interactive`.
- `{max_items}` — optional positive integer. `1` maps to `{select}=next`;
  values greater than `1` map to an explicit ordered ID selection after the
  native plan is rendered. Omitted maps to `{select}=all`.
- `{verify_command}` — optional; maps unchanged.
- `{commit_scope}` — optional; maps unchanged.
- `{on_failure}` — optional `abort` | `continue`; maps unchanged.
- `{dry_run}` — optional boolean; maps unchanged.

Legacy parameters `{parallelism}`, `{num_partitions}`, `{agent_model}`,
`{base_branch}`, `{worktree_name}`, `{partition_strategy}`,
`{max_consecutive_failures}`, and `{worklist_writeback}` are unsupported.
Reject them with:

```text
address-worklist-commit-loop is superseded by ticket-execute; remove legacy
fan-out/writeback parameters and invoke ticket-execute on a native ticket set
```

## Workflow

1. Resolve `{worklist}` without mutation.
2. Require `schema: ticket-operations/worklist` and `schema_version: 1`.
   Old checkbox-only worklists and old `ticket-breakdown` ticket files are not
   native sets and MUST be rejected; never guess lifecycle state from them.
3. Validate and translate only the supported parameters above.
4. Invoke the live `ticket-execute` skill and follow its validation, approval,
   lifecycle, evidence, commit, failure, recovery, and reporting contracts
   exactly.
5. Prepend one notice to the canonical report:

```text
Compatibility route: /address-worklist-commit-loop -> ticket-execute
```

## Guardrails

- MUST NOT parse, execute, mutate, stage, or commit tickets independently of
  `ticket-execute`.
- MUST NOT emulate the removed worktree fan-out, sidecar state, MCP writeback,
  or checkbox-only completion behavior.
- MUST NOT modify an old worklist to make it appear native.
- MUST NOT hide rejected or dropped parameters.
