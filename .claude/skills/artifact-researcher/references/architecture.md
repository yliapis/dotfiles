# Type: architecture

Fully specified. Write a prose companion that answers two questions: how the system is put together, and how someone uses it.

## When this type applies

- A single git checkout (repo root or `submodules/oss/<name>`)
- Optional existing diagrams at `docs/analysis/submodules/<name>/architecture.{excalidraw,svg,png}`

Do not draw new diagrams. If the three diagram files are missing, say so in the header and continue.

## Baseline

Analyze the pinned commit. For a submodule, that is `git rev-parse HEAD` inside the checkout after `git submodule update --init --depth 1 <path>` — the SHA already recorded in the parent repo. Do not `git pull` or fast-forward the submodule. Record that SHA in the header.

## Write path

Default: `docs/analysis/submodules/<name>/Architecture.md` when the artifact is a harness-spec OSS submodule. Otherwise `<artifact-dir>/Architecture.md`.

Write only that file. Do not edit the analyzed checkout.

## Required header

```markdown
# <Name> architecture

- **Source:** `<repo-relative-source>` @ `<pinned-sha>`
- **Diagrams:** [architecture.svg](./architecture.svg) · [architecture.png](./architecture.png) · [architecture.excalidraw](./architecture.excalidraw)
- **License / caveat:** ...
```

If a diagram file is absent, keep the link slot and note the gap in the caveat line.

## Body

Headings follow the repo. Do not copy the ANALYSIS.md capsule outline (identity, layout, 3–7 abstractions, loop, distinctive choice). Two Architecture.md files need not share an outline.

Cover both:

- **Architecture** — modules, control flow, where any existing diagram bands live in source. Cite real files (`path:line`), not the SVG.
- **Usage** — how a person or agent runs it (CLI, TUI, library, config, typical invocation). Cite entry points and in-tree docs.

Every structural or usage claim needs a `path:line` citation inside the analyzed tree (or the parent worktree that contains it).

## Isolation

When dispatched through a worktree-runner:

- Confirm `git rev-parse --show-toplevel` is the assigned worktree and HEAD matches the assigned branch.
- Keep every read, write, and command inside that worktree.
- Init only the submodule under analysis.
- Commit on the worktree branch. Do not merge.

## Claude_Code-_Source_Code

This tree is research-only and unlicensed. Open the caveat in the header. See `docs/analysis/ANALYSIS.md` §3.6 when that file is in the worktree, and the submodule README. Default Glob/Grep often cannot see the tree; use unrestricted shell listing if those tools return empty. Read on a specific file path usually works.

## Verifier

A write is complete when all of the following hold:

```sh
f="$OUT"   # resolved Architecture.md path
test -s "$f"
grep -q "$PINNED_SHA" "$f"
grep -q 'architecture.svg' "$f"
grep -q 'architecture.png' "$f"
grep -q 'architecture.excalidraw' "$f"
grep -qiE 'usage|cli|invoke|run' "$f"
```

For `Claude_Code-_Source_Code`, also require `grep -qiE 'research-only|unlicensed|no license' "$f"`.

## Reference corpus

These files in `agent-harness-spec` are the worked examples for this type:

- `docs/analysis/submodules/Claude_Code-_Source_Code/Architecture.md`
- `docs/analysis/submodules/codex/Architecture.md`
- `docs/analysis/submodules/dspy/Architecture.md`
- `docs/analysis/submodules/hermes-agent/Architecture.md`
- `docs/analysis/submodules/open-interpreter/Architecture.md`
- `docs/analysis/submodules/openclaw/Architecture.md`
- `docs/analysis/submodules/opencode/Architecture.md`
- `docs/analysis/submodules/pi/Architecture.md`

Read one before writing a new file when those paths exist in the workspace. Match their citation density and header shape, not their section titles.
