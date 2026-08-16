# Analysis type stubs

These types are named so the router can reject them cleanly. Do not invent a procedure. When the user asks for one, report the paragraph below and stop.

## inventory

Census of a repo or a collection: language, layout, license, entry points, and a one-line role per member. Intended output: `docs/analysis/submodules/INVENTORY.md` for a harness-spec collection, or `<artifact-dir>/Inventory.md` for a single tree. Not specified in this pass.

## comparative

Cross-artifact pattern comparison (loops, tools, memory, streaming, permissions) with `path:line` citations on each side. Intended output: `docs/analysis/COMPARATIVE.md` or `docs/analysis/submodules/<left>-vs-<right>.md`. Not specified in this pass.

## deep-dive

Line-precise walk of one control path (stream loop, tool dispatch, compaction). Intended output: `docs/analysis/submodules/<name>/Deep-Dive.md`. Not specified in this pass.

## collection

Synthesis across a folder of docs or a repo collection after per-member files exist. Intended output: `docs/analysis/COLLECTION.md`. Not specified in this pass.
