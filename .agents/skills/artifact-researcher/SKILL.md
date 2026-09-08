---
name: artifact-researcher
description: "Route an analysis type across one or more artifacts — a single repo, a repo collection, or a folder of docs — and write a cited research file. Use when the user asks to research artifacts, write Architecture.md, inventory a collection, compare repos, deep-dive a control path, or analyze a folder of docs."
license: MIT
---

# Artifact Researcher

Route one analysis `type` across one or more `artifacts` and write a cited research file. This skill is the composition surface. It does not inline type procedures; it reads the matching card from [./references/](./references/) at invocation time.

## When to Invoke

Apply when the user asks to:

- research or analyze a repo, a repo collection, or a folder of docs
- write `Architecture.md` (or another typed analysis file) next to existing diagrams
- inventory, compare, or deep-dive artifacts
- invoke `artifact-researcher` or `/research-artifact`

Do not apply on bare "document this project" (that is a different skill) or on Excalidraw-only requests (use `excalidraw-diagrams`).

## Invocation Contract

Knobs appear as inline `key=value` tokens or as natural-language back-references. Inline tokens win when both forms disagree.

- Lists are comma-separated. Quote a path that contains spaces: `artifacts="docs/analysis/submodules"`.
- An unrecognized `key=...` token aborts with `unknown knob: <key>; available knobs: type, artifacts, out, use_worktree, base_branch, worktree_name`.

## Knob Inventory

**Required:**

- `type` — `architecture` | `inventory` | `comparative` | `deep-dive` | `collection`. Must resolve via [## Type Map](#type-map).
- `artifacts` — one or more paths (repo root, collection directory, or docs folder). Relative paths resolve from the current workspace root.

**Output:**

- `out` — write path. Optional. Default for a harness-spec submodule analysis: `docs/analysis/submodules/<name>/<Type>.md` where `<Type>` is `Architecture` for `architecture` and the type name in Title Case otherwise. For any other artifact, default is `<artifact-dir>/<Type>.md`. When `artifacts` names more than one path and `type` is not `comparative` or `collection`, write one file per artifact using that default.

**Isolation:**

- `use_worktree` — boolean. Default `true` when the write target is in a git repo the caller does not already own as a worktree. When `true`, disk writes happen inside a dedicated worktree forked from `base_branch`.
- `base_branch` — branch the worktree is forked from. Default: current branch (`git rev-parse --abbrev-ref HEAD`).
- `worktree_name` — worktree directory and branch slug. Default: `docs/<type>-<artifact-slug>`.

## Type Map

| `type` | Card | Status |
|---|---|---|
| `architecture` | [references/architecture.md](references/architecture.md) | specified |
| `inventory` | [references/types.md](references/types.md#inventory) | stub |
| `comparative` | [references/types.md](references/types.md#comparative) | stub |
| `deep-dive` | [references/types.md](references/types.md#deep-dive) | stub |
| `collection` | [references/types.md](references/types.md#collection) | stub |

A stub type aborts after naming the gap. Do not invent a procedure for it.

## Success Criteria

- [ ] Knobs resolve before any write. Unknown `type`, empty `artifacts`, or a missing path aborts with an explanatory error and no filesystem side effects.
- [ ] The type card is read in full before analysis starts. Stub types stop there.
- [ ] Every structural or usage claim in the written file has a `path:line` citation inside the analyzed tree.
- [ ] The file is written only at the resolved `out` path(s). No edits land in an OSS submodule tree and no recorded submodule SHA changes.
- [ ] When `use_worktree=true`, the calling working tree stays clean; the runner commits on the worktree branch and does not merge.
- [ ] Stop-slop applies: no filler, no uncited claims, no adverbs, no "not X, it's Y" contrasts, no em dashes.

## Guardrails

- MUST read the type card; MUST NOT reimplement or paraphrase it in the skill body.
- MUST NOT write into an upstream OSS checkout. Analysis of `submodules/oss/<name>` writes to the parent analysis tree.
- MUST NOT fast-forward a pinned submodule. Analyze the gitlink SHA already recorded in the parent repo.
- MUST NOT generate Excalidraw diagrams. Pair existing `architecture.{excalidraw,svg,png}` when they exist; otherwise say they are absent.
- MUST NOT implement a stub type.
- Scope: route a type, analyze the named artifacts, write the typed file. Out of scope: merging worktrees, pushing, opening PRs, updating submodule SHAs.

## Workflow

1. Parse knobs. Validate `type` against the Type Map and that every `artifacts` path exists.
2. If `type` is a stub, report the stub paragraph from `references/types.md` and stop.
3. Read the type card. Resolve `out` (and per-artifact defaults when needed).
4. When `use_worktree=true`, create or confirm a worktree per `worktree-task` / `worktree-runner`. Init only the submodule(s) under analysis. Do not `git pull` inside a submodule.
5. Analyze the artifact(s) per the type card. For `Claude_Code-_Source_Code`, if Glob/Grep return empty, list and search with unrestricted shell permissions.
6. Write the file(s). Apply stop-slop. Cite `path:line`.
7. When inside a worktree, commit with Conventional Commits (`docs(analysis): add <Type>.md for <slug>`) and leave a clean tree. Do not merge.

## Output Format

Chat reply:

- `Type`: resolved type
- `Artifacts`: absolute paths analyzed
- `Out`: absolute write path(s)
- `Worktree`: path and branch, or `in-place`
- `Status`: `success` / `failed` / `incomplete`
- `Notes`: pinned SHAs, missing diagrams, visibility caveats
