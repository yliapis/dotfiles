# trajectory-leftovers

Seven variants (44 lines each) of an abandoned `trajectory.md` working-notes file that explored how to evolve `meta-prompt.md` and `worktree-task-agent.md` toward first-class fan-out, parallel best-of-N prompt and code refinement. All seven derive from the same base commit `22de432` and differ almost exclusively in the paragraph defining `{num_partitions}` semantics on line 11.

`main` has no `.cursor/commands/trajectory.md` — these were design exploration, not finished commands. The ideas that survived moved into the canonical `.cursor/skills/agent-swarm/SKILL.md` and the partition semantics in `.cursor/commands/worktree-task-agent.md`. The source branches `trajectory-sample-{1..7}` are scheduled for revert and deletion after this archive lands.

## Variants

| File | Original worktree slug | Distinguishing aspect |
|---|---|---|
| `num-partitions-semantics-3c37cd65.md` | num-partitions-semantics-3c37cd65 | Hard even-divisibility requirement; uses `sonnet`/`opus` examples at `{parallelism}=4` and spells out positional mapping ("agents 1-2 sonnet and 3-4 opus"). |
| `partition-semantics-cb538d55.md` | partition-semantics-cb538d55 | Documents the default `{num_partitions}=1` (one shared partition for all agents) and notes that scalar `{agent_model}` broadcasts "regardless of partitioning"; uses abstract `'a'/'b'/'c'/'d'` model placeholders. |
| `partition-semantics-clarify-08eea21c.md` | partition-semantics-clarify-08eea21c | Shortest of the variants; explicitly flags the divisibility rule as still open (twice), leaving non-divisible `{parallelism}/{num_partitions}` "under design". |
| `trajectory-num-partitions-63cc819f.md` | trajectory-num-partitions-63cc819f | Hard even-divisibility requirement; uses the largest-scale illustration (`{parallelism}=8, {num_partitions}=4`) with length-only abstract examples rather than literal model lists. |
| `trajectory-partitions-agent1-328ce420.md` | trajectory-partitions-agent1-328ce420 | Generalizes a partition as "the unit that shares whatever varies at the partition level" (forward-looking beyond just `{agent_model}`); leaves divisibility "still under design". |
| `trajectory-partitions-agent2-1f830908.md` | trajectory-partitions-agent2-1f830908 | Calls out the boundary cases (`{num_partitions}=1` vs `{num_partitions}={parallelism}`) and shows the most concrete fully-expanded 8-entry list-by-agent example with `gpt-5`/`claude`. |
| `trajectory-partitions-agent7-32bfe24a.md` | trajectory-partitions-agent7-32bfe24a | Explicitly pairs partition members with their worktrees ("sibling agents and their worktrees") and alternates models in the list-by-agent example (`["sonnet-4", "opus-4", "sonnet-4", "opus-4"]`) instead of blocking them. |
