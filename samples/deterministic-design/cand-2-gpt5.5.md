---
name: deterministic-design
description: "Use when the user asks for deterministic design, reproducibility, or removing non-determinism; manually invoked to make the same input produce bit-identical output across runs, machines, and processes."
license: MIT
---
# Deterministic Design

Same input → same output, every run, every machine, every process. Treat every hidden dependency as a source of entropy until it is made explicit, pinned, sorted, or removed.

## When to Invoke

This skill is manually invoked. Apply it only when the user asks for deterministic design, reproducibility, or removal of non-determinism from a specific code path, pipeline, model, build, test, or system.

## Sources of Non-Determinism

| Source | Failure mode | Concrete mitigation |
|---|---|---|
| Random seeds | PRNGs choose different streams across runs or libraries. | Pin seeds at every layer, such as `random.seed(0)`, `numpy.random.seed(0)`, `torch.manual_seed(0)`, and `PYTHONHASHSEED=0`; pass seeded generators explicitly. |
| Wall-clock time | Calls such as `time.time()` or `Date.now()` embed run time into output. | Inject a clock interface; use frozen clocks in tests; pass timestamps as input instead of reading ambient time in logic. |
| Monotonic clocks | Elapsed-time measurements vary by scheduler, CPU, and process timing. | Inject a monotonic clock; record deterministic tick values in tests; remove elapsed time from persisted output. |
| Timezones | Local timezone settings change parsed dates, formatted strings, and day boundaries. | Normalize to UTC; set `TZ=UTC`; use timezone-aware datetime types and explicit formatters. |
| Hash and dict iteration order | Hash randomization or insertion history changes map traversal order. | Sort keys before iterating; use deterministic ordered maps; set language hash seeds where supported. |
| Set ordering | Sets expose arbitrary iteration order that can vary by process or memory layout. | Convert sets to sorted lists before output or reduction; use deterministic ordered-set data structures. |
| Parallel race conditions | Concurrent writes, reductions, or scheduling choices change results. | Single-thread deterministic sections; use barrier synchronization; partition work deterministically and merge in a fixed order. |
| Floating-point reduction order | Addition and aggregation are not associative, so different orders produce different bits. | Use fixed reduction trees; use fixed-precision arithmetic; sort inputs before reduction; disable compiler reassociation. |
| Network jitter | Latency, packet ordering, retries, and live service state change responses. | Mock network calls; record/replay fixtures; pin service snapshots; sort response collections before use. |
| Filesystem `readdir` order | Directory listing order is filesystem-dependent and unstable. | Sort directory entries from `readdir`, `os.listdir`, `glob`, and similar APIs before processing. |
| Environment variable leakage | Ambient environment changes paths, feature flags, credentials, and runtime behavior. | Canonicalize environment variables; pass an allowlisted environment; clear or pin values such as `PATH`, `HOME`, and feature flags. |
| Locale-dependent string operations | Collation, casing, parsing, and formatting differ by locale. | Set `LC_ALL=C` or `LC_ALL=POSIX`; use locale-independent comparisons and explicit encodings. |
| Undefined behavior in compilers | Undefined behavior lets compiler version, flags, or architecture change output. | Remove undefined behavior; enable sanitizers; use deterministic compiler versions and flags; avoid relying on unspecified evaluation order. |
| GPU non-determinism (atomic adds, cuDNN) | Atomic operations, kernel selection, and library autotuning can reorder work. | Disable nondeterministic ops; set deterministic GPU modes such as `torch.use_deterministic_algorithms(True)`; disable cuDNN benchmarking; avoid atomic-add reductions. |
| Thread-pool ordering | Work stealing and pool sizing change task completion order. | Fix pool size; assign stable task indexes; collect results by index; merge outputs only after all tasks complete. |
| Async race conditions | Futures, promises, callbacks, and event loops resolve in timing-dependent order. | Await explicit dependencies; use deterministic queues; sort completed tasks by stable key before output. |
| Retry jitter | Randomized backoff changes request timing and observable side effects. | Disable jitter for deterministic runs; use seeded backoff generators; cap retries with scripted retry schedules. |
| ID generation (UUIDs, autoincrement collisions) | UUIDs, database sequences, and concurrent inserts create run-specific identifiers. | Use content-hash IDs; derive IDs from stable input keys; allocate IDs in a deterministic prepass. |
| Memory layout differences | Address randomization, allocation order, and pointer values leak into ordering or output. | Do not serialize addresses; sort by semantic keys; avoid pointer-address comparators; disable address-derived hashes. |
| Garbage collector finalizers | Finalizer timing depends on collection heuristics and memory pressure. | Do not rely on finalizers for observable behavior; close resources explicitly; use deterministic disposal scopes. |
| Weak references | Weak-reference lifetime depends on garbage collection timing and reachability. | Avoid weak references in deterministic logic; promote required data to strong ownership; snapshot weak maps into sorted strong values before use. |
| Ambient mutable state | Global caches, singletons, and process-level state leak previous runs into current output. | Prefer pure functions; reset state at boundaries; inject dependencies; make caches content-addressed and versioned. |
| Build inputs and dependency versions | Toolchain, dependency, or generated-file drift changes binaries and outputs. | Use lockfiles; pin compiler and dependency versions; set reproducible build flags; strip timestamps from artifacts. |

## Design Principles

- Same input → same output, every run.
- Prefer pure functions over stateful operations.
- Prefer explicit dependency injection over ambient state.
- Make builds reproducible by pinning toolchains, dependencies, generated files, and build flags.
- Keep deterministic logic testable in isolation with clocks, random generators, network clients, and filesystems supplied as inputs.
- Require output to be bit-identical across machines, runs, and processes.

## Deliverable When Invoked

When this skill is invoked against a target, produce one of two acceptable deliverables:

1. A deterministic refactor of the target code that removes or controls every identified source of non-determinism while preserving the intended behavior.
2. A checklist of fixes that names each identified source of non-determinism in the target and pairs it with a concrete mitigation.

Checklist format:

| Source | Location in target code | Mitigation | Status |
|---|---|---|---|
| Filesystem `readdir` order | `src/load_inputs.py` | Sort `os.listdir(input_dir)` before processing files. | pending |
| Wall-clock time | `src/render_report.py` | Inject `clock.now()` and pass a fixed clock in reproducible runs. | pending |

## Worked Example: Before / After

Before (non-deterministic):

```python
import os
from datetime import datetime

def build_manifest(input_dir):
    return {
        "generated_at": datetime.now().isoformat(),
        "files": [name for name in os.listdir(input_dir)],
    }
```

After (deterministic):

```python
import os

def build_manifest(input_dir, clock):
    return {
        "generated_at": clock.now().isoformat(),
        "files": sorted(os.listdir(input_dir)),
    }
```

The rewrite controls wall-clock time by injecting `clock` and controls filesystem `readdir` order by sorting directory entries before serializing output.

## Verification

- Run the target twice with the same input and byte-compare outputs, for example `cmp -s out/run1.bin out/run2.bin`.
- Run on two machines or isolated environments and hash-compare outputs, for example `sha256sum out.bin` on each environment.
- Vary CPU count, thread-pool size, locale, timezone, and allowlisted environment variables; confirm outputs are unchanged.
- Run with randomized scheduling stress tools, where available, and confirm the deterministic merge order still produces identical bytes.
- Inspect generated artifacts for embedded timestamps, absolute paths, random IDs, memory addresses, and locale-specific formatting.
