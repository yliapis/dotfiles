---
name: deterministic-design
description: "Guide deterministic design and removal of non-determinism. Use when the user asks for deterministic behavior, reproducibility, or removing non-determinism across code or systems."
license: MIT
---
# Deterministic Design

Same input -> same output, every run, every machine, every process. Use this skill to make code and systems produce bit-identical output instead of merely similar or statistically stable output.

## When to Invoke

This skill is manually invoked. Use it only when the user explicitly asks for deterministic design, deterministic behavior, reproducibility, or removing non-determinism from a target code path or system.

## Sources of Non-Determinism

| Source | Failure mode | Concrete mitigation |
|---|---|---|
| Random seeds | PRNGs, framework samplers, and randomized algorithms draw different values across runs. | Pin seeds at every layer, such as `random.seed(0)`, `numpy.random.default_rng(0)`, `torch.manual_seed(0)`, and `PYTHONHASHSEED=0`; pass seeded RNG objects explicitly. |
| Wall-clock time | Calls like `time.time()`, `Date.now()`, or `datetime.now()` embed the current run time in outputs. | Inject a `Clock` interface; use a frozen clock in tests and deterministic jobs; pass timestamps as input data. |
| Monotonic clocks | Elapsed-time measurements vary with scheduler pauses, machine load, and process timing. | Inject a monotonic clock abstraction; record deterministic logical ticks or fixture durations instead of reading ambient elapsed time. |
| Timezones | Local timezone settings change parsing, formatting, and day-boundary behavior. | Normalize to UTC for storage and comparison; pass an explicit timezone; set process timezone to `UTC` for reproducible jobs. |
| Hash and dict iteration order | Hash randomization and insertion histories can change map traversal and serialized output. | Sort keys before iterating or serializing; use ordered maps with canonical insertion; set `PYTHONHASHSEED` when hash behavior affects output. |
| Set ordering | Sets expose no stable iteration order, so downstream lists or serialized values can change. | Convert sets to sorted lists before iteration, comparison, or serialization; use deterministic data structures when order matters. |
| Parallel race conditions | Competing workers update shared state in timing-dependent order. | Single-thread deterministic sections; use barrier synchronization, explicit ownership, stable work queues, or deterministic merge phases. |
| Floating-point reduction order | Addition and reduction order change rounding, especially across vectorized or parallel execution. | Use fixed reduction order, pairwise or compensated summation, fixed-precision decimal/integer arithmetic, or deterministic BLAS settings. |
| Network jitter | Latency, packet ordering, retries, and remote state change the observed result. | Mock network calls with recorded fixtures; use content-addressed inputs; pin service responses; disable live network in deterministic runs. |
| Filesystem `readdir` order | Directory listing order depends on filesystem and creation history. | Sort directory entries before processing; canonicalize paths and traversal order. |
| Environment variable leakage | Ambient environment values alter paths, credentials, feature flags, and tool behavior. | Canonicalize the environment by passing an allowlisted env map; clear unrelated variables; pin required variables in config. |
| Locale-dependent string operations | Sorting, casing, parsing, and formatting vary by locale. | Set locale to `C` or `POSIX`; use locale-independent collation and formatting APIs. |
| Undefined behavior in compilers | Undefined or unspecified behavior can differ by compiler, optimization level, CPU, or memory layout. | Remove undefined behavior; enable sanitizers; use deterministic compiler versions and flags; pin the toolchain. |
| GPU non-determinism (atomic adds, cuDNN) | Atomic operations, algorithm selection, and kernels can return different numeric results. | Disable nondeterministic ops; enable deterministic framework modes such as `torch.use_deterministic_algorithms(True)`; pin cuDNN algorithms and GPU driver versions. |
| Thread-pool ordering | Work-stealing and pool scheduling change task completion order and aggregation order. | Use a fixed worker count with stable partitioning; collect results by deterministic key; merge only after all workers complete. |
| Async race conditions | Futures, promises, callbacks, and event-loop scheduling resolve in timing-dependent order. | Await explicit dependencies; collect async results with stable indices; sort by deterministic key before side effects or output. |
| Retry jitter | Random backoff and retry timing change request order, timestamps, and selected winners. | Replace jitter with a deterministic retry schedule; inject retry policy and seeded RNG; record retry decisions in fixtures. |
| ID generation (UUIDs, autoincrement collisions) | UUIDs, database sequences, and concurrent inserts create run-specific identifiers. | Use content-hash IDs, deterministic sequence allocation, or caller-supplied IDs derived from canonical input. |
| Memory layout differences | Address-dependent behavior, pointer ordering, ASLR, and allocator choices vary by process and machine. | Do not serialize addresses or compare pointer values for order; assign stable logical IDs; use deterministic allocators only when required. |
| Garbage collector finalizers | Finalizer timing depends on GC heuristics and memory pressure. | Replace finalizers with explicit lifecycle methods such as `close()` or `dispose()`; scope resources with deterministic ownership. |
| Weak references | Weak reference liveness changes with GC timing and memory pressure. | Avoid weak references in output-producing logic; snapshot strong references at deterministic boundaries; use explicit cache invalidation. |

## Design Principles

- Same input -> same output, every run.
- Prefer pure functions over stateful operations.
- Prefer explicit dependency injection over ambient state for clocks, RNGs, environment, filesystems, network, and services.
- Make builds reproducible by pinning toolchains, dependencies, compiler flags, locales, and execution environments.
- Keep logic testable in isolation with fixtures for time, random seeds, network data, filesystem entries, and environment variables.
- Require output to be bit-identical across machines, runs, processes, CPU counts, locales, and supported execution environments.

## Deliverable When Invoked

When invoked against a target, produce one of two deliverables:

1. A deterministic refactor of the target code that removes every identified source of non-determinism and preserves the intended behavior.
2. A checklist of fixes that names each non-determinism source found in the target and pairs it with a concrete mitigation.

Use this checklist format when returning a plan instead of editing code:

| Source | Location in target code | Mitigation | Status |
|---|---|---|---|
| Wall-clock time | `src/report.py` `build_report()` | Inject a `Clock` and pass a fixed timestamp in deterministic runs. | planned |
| Filesystem `readdir` order | `src/report.py` file discovery | Sort directory entries before reading files. | planned |

## Worked Example: Before and After

Before (non-deterministic):

```python
import json
import os
import random
import time

def build_manifest(directory):
    files = os.listdir(directory)
    random.shuffle(files)
    return json.dumps({
        "generated_at": time.time(),
        "files": files,
    })
```

After (deterministic):

```python
import json
import os

def build_manifest(directory, clock):
    files = sorted(os.listdir(directory))
    return json.dumps(
        {
            "generated_at": clock.now(),
            "files": files,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
```

The rewrite removes ambient wall-clock time by injecting `clock`, removes random seed dependence by dropping the shuffle, sorts filesystem entries, and serializes dict keys in canonical order.

## Verification

- Run the target twice from a clean state and byte-compare outputs, for example `cmp out/run1.bin out/run2.bin`.
- Run the target on two machines or environments and hash-compare outputs, for example `sha256sum out.bin`.
- Vary CPU count, thread-pool size, locale, timezone, and environment variables; confirm output bytes are unchanged.
- Run with randomized scheduling or repeated stress loops when parallel or async paths exist; confirm deterministic merge order and identical output hashes.
- Rebuild from pinned dependencies and toolchains; confirm artifacts match by byte comparison or reproducible-build hash comparison.
