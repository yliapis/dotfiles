---
name: deterministic-design
description: "Drive a systematic effort to eliminate every source of non-determinism so that the same input produces a bit-identical output on every run, every machine, and every process. Use when the user explicitly asks for deterministic design, deterministic behavior, reproducibility, or removing non-determinism from code or a system. Manually invoked only — do not apply against unrelated edits."
license: MIT
---

# Deterministic Design

Same input → same output, every run, every machine, every process.

A program is deterministic when its observable output is a pure function of its declared inputs. Hidden inputs — wall-clock time, hash seeds, thread schedules, filesystem ordering, GPU reduction order, ambient environment — silently break that contract. This skill drives a systematic effort to find and eliminate every such hidden input from a target piece of code or system, then to prove the result is bit-identical across runs and machines.

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly asks for one of:

- deterministic design, deterministic behavior, or deterministic execution;
- reproducibility across runs, machines, processes, containers, or environments;
- removing non-determinism, flaky tests, or "works on my machine" drift;
- bit-identical output between two runs or two hosts (`sha256sum` parity).

Do not apply this skill against unrelated edits. If the user has not asked for determinism, leave the target code alone.

## Sources of Non-Determinism

Each entry below names a source, its failure mode, and at least one concrete, named mitigation. If a source genuinely does not apply to the target's language or runtime, keep its row in the checklist with `Status: N/A` and a one-line rationale rather than silently dropping it.

### Random Seeds
Failure mode: uncontrolled PRNGs — `random`, `numpy.random`, `torch`, `jax`, `Math.random`, `secrets`, OpenSSL randomness — draw different values each run, so anything derived from them differs.
Mitigation: pin seeds explicitly at every layer at process start: `random.seed(0)`, `numpy.random.seed(0)`, `torch.manual_seed(0)`, `torch.cuda.manual_seed_all(0)`, `jax.random.PRNGKey(0)`. Inject a `Random` instance into the call graph instead of relying on module-level state. Export `PYTHONHASHSEED=0`.

### Wall-Clock Time
Failure mode: `time.time()`, `datetime.now()`, `Date.now()`, `System.currentTimeMillis()` embed run-time noise into outputs, logs, IDs, and hashes.
Mitigation: inject a `Clock` interface and read time only through it. Provide a `FrozenClock(0)` or `FakeClock` in tests. Treat any current-time read inside pure logic as a bug; move it to the edge of the program.

### Monotonic Clocks
Failure mode: `time.monotonic()`, `clock_gettime(CLOCK_MONOTONIC)`, `performance.now()` are unrelated to wall time but still differ run to run; they leak into timing-based branches, retry decisions, and cache eviction order.
Mitigation: inject a monotonic clock alongside the wall clock. In tests, use a step-controlled fake that advances only when the test explicitly ticks it. Never let control flow or output content depend on observed elapsed time.

### Timezones
Failure mode: `datetime.now()` without `tzinfo`, `time.localtime()`, or formatting with `%Z` produces different strings on different hosts; naive datetimes silently absorb the host's `TZ`.
Mitigation: pin `TZ=UTC` in the canonicalized environment. Work in UTC internally; serialize with timezone-aware ISO 8601. Forbid naive datetimes at module boundaries; convert at the edge.

### Hash and Dict Iteration Order
Failure mode: Python `dict` is insertion-ordered, but string and bytes hashes are salted via `PYTHONHASHSEED`, so anything derived from `hash()` differs across runs; Go map iteration is intentionally randomized; Java `HashMap` order is unspecified.
Mitigation: set `PYTHONHASHSEED=0`. Sort keys before iterating when output depends on iteration order: `for k in sorted(d):`. Serialize with `json.dumps(payload, sort_keys=True)`. In Go, copy keys to a slice and `sort.Strings(...)` before ranging.

### Set Ordering
Failure mode: `set` and `frozenset` iteration order in Python depends on hash and insertion history; Java `HashSet`, Rust `HashSet`, and JS `Set` (when keys go through hashing) are unordered.
Mitigation: convert to `sorted(s)` before iterating, hashing, or serializing. Use `OrderedDict`, `BTreeSet`, or `LinkedHashSet` when the order is observable. Never emit a raw set into output.

### Parallel Race Conditions
Failure mode: shared mutable state updated by multiple workers produces results that depend on interleaving — last-writer-wins, lost updates, partial reads.
Mitigation: make the parallel region pure (map-only, no shared writes) and reduce via a deterministic merge ordered by partition index. Use barrier synchronization for inter-stage ordering, or run single-threaded when correctness depends on order. Forbid `dict.setdefault`-style "first writer wins" on shared state.

### Floating-Point Reduction Order
Failure mode: `(a + b) + c ≠ a + (b + c)` in IEEE-754; parallel sums, BLAS, cuBLAS, and `numpy.einsum` reorder reductions across CPU counts, producing different last bits.
Mitigation: fix the reduction order — e.g., `sum(sorted(xs))`, pairwise/Kahan summation with a pinned schedule. Pin a single-threaded BLAS (`OMP_NUM_THREADS=1`, `MKL_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`). Prefer integer or fixed-precision arithmetic for accumulators where feasible.

### Network Jitter
Failure mode: real network calls return at variable times, in variable orders, with variable retries and partial failures; results merged in arrival order differ each run.
Mitigation: mock the network at a stable boundary (HTTP client, gRPC stub, message bus) and replay a recorded fixture. Sort responses by request key before merging. Strip wall-clock timestamps from response bodies before they enter pure logic.

### Filesystem `readdir` Order
Failure mode: `os.listdir`, `glob.glob`, `pathlib.iterdir`, `fs.readdir`, and `Files.list` return entries in OS- and filesystem-dependent order (ext4, APFS, tmpfs, and overlayfs all differ); the same checkout on two CI runners enumerates differently.
Mitigation: sort directory entries before use: `sorted(os.listdir(path))`, `sorted(glob.glob(pattern))`. Never feed unsorted `readdir` output into a hash, tar archive, or downstream pipeline. For archive builds, pass `--sort=name` to `tar` and pin `mtime` via `SOURCE_DATE_EPOCH`.

### Environment Variable Leakage
Failure mode: code reads `os.environ` (`HOME`, `USER`, `PATH`, `LANG`, `TMPDIR`, CI vars, hostnames) and embeds host-specific values into outputs, logs, or build artifacts.
Mitigation: canonicalize the environment at process entry — start from an empty `env` and inject only a pinned allowlist (`PATH`, `TZ=UTC`, `LANG=C.UTF-8`, `LC_ALL=C.UTF-8`, `PYTHONHASHSEED=0`, `SOURCE_DATE_EPOCH=0`). Forbid direct `os.environ` reads in business logic; inject configuration explicitly through a `Config` object.

### Locale-Dependent String Operations
Failure mode: `str.lower()`, `str.upper()`, `sorted()` on strings, `strftime`, `printf("%f")`, and number parsing change behavior with locale (Turkish dotless I, German ß, comma vs dot decimals, localized month names).
Mitigation: set `LC_ALL=C` and `LANG=C.UTF-8`. Use Unicode-aware, locale-independent operations: `str.casefold()`, `unicodedata.normalize("NFC", s)`, ICU collation with an explicit locale tag. Format numbers with `repr(x)` or `format(x, ".17g")`, never with locale-aware formatters.

### Undefined Behavior in Compilers
Failure mode: C/C++/Rust `unsafe` code with signed-integer overflow, uninitialized reads, strict-aliasing violations, or data races compiles to different output under different optimizer flags or compiler versions; output bytes depend on accidents.
Mitigation: pin a deterministic-build toolchain (specific compiler version, `-O2 -fno-strict-aliasing -fwrapv -fno-fast-math`, `-frandom-seed=$file`, `-fdebug-prefix-map`, `SOURCE_DATE_EPOCH`). Run UBSan, ASan, and TSan in CI to surface UB. Forbid uninitialized reads and data races at review time; the goal is "no UB", not "UB that happens to behave today".

### GPU Non-Determinism (Atomic Adds, cuDNN)
Failure mode: CUDA `atomicAdd` on floats reorders contributions across warps; cuDNN convolution and reduction algorithms select non-deterministic kernels by default; `scatter_add`, `index_add`, and many reductions on GPU are non-deterministic.
Mitigation: `torch.use_deterministic_algorithms(True, warn_only=False)`, `torch.backends.cudnn.deterministic = True`, `torch.backends.cudnn.benchmark = False`, set `CUBLAS_WORKSPACE_CONFIG=:4096:8` (or `:16:8`). Replace `scatter_add` with a sorted gather and dense reduction. Accept the throughput cost in exchange for bit-identical kernels.

### Thread-Pool Ordering
Failure mode: `ThreadPoolExecutor`, `multiprocessing.Pool`, OpenMP, and Rayon dispatch tasks in whatever order workers become free; merged results depend on completion order, not submission order.
Mitigation: collect results into a buffer keyed by task index, then iterate the buffer in index order before reducing. Cap the pool size to a fixed value, or set `OMP_NUM_THREADS=1` for the reproducible run. Never rely on `as_completed`-style ordering for output content.

### Async Race Conditions
Failure mode: `asyncio.gather`, `Promise.all`, `tokio::join!` start tasks concurrently; return values are returned in submission order, but side effects (logs, DB writes, shared caches) fire in arrival order, which depends on scheduler and I/O latency.
Mitigation: keep async tasks pure and side-effect-free; collect their return values and apply side effects sequentially in submission order on the awaiter. Forbid shared mutable state across awaits; if unavoidable, guard with an explicit lock and a deterministic acquisition order.

### Retry Jitter
Failure mode: exponential-backoff retries with random jitter produce different timing and different downstream effects each run; retry counts vary with wall-clock budgets.
Mitigation: in tests and reproducible runs, draw jitter from the injected `Random(seed=0)` or disable it entirely. Replace live network retries with a fixture replay so retries are eliminated. Make the retry count a deterministic input (`max_attempts=N`), not a wall-clock-bounded loop.

### ID Generation (UUIDs, Autoincrement Collisions)
Failure mode: `uuid.uuid4()` is fully random; `uuid.uuid1()` embeds wall-clock time and MAC address; database autoincrement IDs depend on insertion order across parallel writers and can collide or reorder under contention.
Mitigation: use **content-hash IDs** — `uuid.uuid5(NAMESPACE, canonical_repr)` or `sha256(canonical_bytes)` — so the same input always yields the same ID. Where surrogate IDs are unavoidable, generate them from an injected seeded `Random` and assign them in a deterministic traversal order (sorted by a stable natural key).

### Memory Layout Differences
Failure mode: ASLR, pointer arithmetic, `id(obj)`, default `repr` of objects without `__repr__`, and CPython object addresses leak into outputs via debug logs, default `object.__repr__`, or `pickle` byte streams across versions.
Mitigation: never embed pointer values, `id()`, or default `object.__repr__` into observable output. Use stable serializers (`json.dumps(..., sort_keys=True)`, `pickle` with a pinned protocol, `msgpack`, Protobuf with deterministic encoding) and pin the language/runtime version. Disable ASLR (`setarch $(uname -m) -R`) for byte-identical core dumps if those are part of the output.

### Garbage Collector Finalizers
Failure mode: `__del__`, `weakref` callbacks, and JVM/Go finalizers run in GC-determined order, sometimes during interpreter shutdown, with observable side effects (closing files, flushing buffers, emitting logs).
Mitigation: use explicit `with`/`try-finally`/RAII/`defer` for any side-effectful resource. Treat `__del__` as best-effort cleanup only, never as a source of observable output. If finalizer ordering is part of the contract, force it with explicit `gc.collect()` at deterministic checkpoints and verify the call order in tests.

### Weak References
Failure mode: `weakref` / `WeakValueDictionary` / Java `WeakHashMap` lookups return `None` based on GC timing, so cache hit/miss behavior — and any output derived from it — differs run to run.
Mitigation: replace weak caches with bounded strong caches (LRU with fixed capacity) on the deterministic path. If weak references are required for memory reasons, ensure cache hit/miss affects only performance, never output content; assert this with a test that forces `gc.collect()` and compares output.

## Design Principles

- **Same input → same output, every run.** This is the invariant the skill enforces. If you cannot state the full input set of the function in one sentence, the design is not finished.
- **Pure functions over stateful operations.** A function whose output depends only on its arguments cannot be flaky.
- **Explicit dependency injection over ambient state.** Pass `clock`, `random`, `env`, `fs`, `net` as parameters; do not read them from module-level globals or process-wide singletons.
- **Reproducible builds.** Pin compiler and runtime versions, lock dependencies (hashes, not floating tags), set `SOURCE_DATE_EPOCH`, strip build paths and timestamps from artifacts, sort archive entries.
- **Testable in isolation.** Each unit must run under fakes for every injected dependency: no real network, no filesystem outside a tmpdir, no clock, no GPU.
- **Output bit-identical across machines and runs.** The acceptance test is `sha256sum` parity, not "looks the same" — every diagnostic is a hash comparison.

## Deliverable When Invoked

When this skill is invoked against a target, produce **one** of the following — pick one explicitly, do not mix.

**(a) Deterministic refactor.** A patch against the target code that eliminates every identified source of non-determinism. The patch is acceptable only if every row of the checklist below would be marked `applied` or `N/A`.

**(b) Checklist of fixes.** A table naming every non-determinism source identified in the target and pairing each with a concrete mitigation. Use exactly these columns, in this order:

| Source | Location in target code | Mitigation | Status |
|---|---|---|---|
| Random seed | `train.py:42` | Set `random.seed(0)`, `numpy.random.seed(0)`, `torch.manual_seed(0)`; export `PYTHONHASHSEED=0` | applied |
| Wall-clock time | `report.py:88` | Inject `Clock`; replace `time.time()` with `clock.now()`; use `FrozenClock(0)` in tests | applied |
| Dict iteration order | `serializer.py:17` | `json.dumps(payload, sort_keys=True)` | applied |
| Filesystem `readdir` order | `loader.py:9` | `sorted(os.listdir(path))` before iteration | pending |
| GPU non-determinism | `model.py:120` | `torch.use_deterministic_algorithms(True)`; `CUBLAS_WORKSPACE_CONFIG=:4096:8`; replace `scatter_add` with sorted gather | applied |
| Weak references | (none found) | N/A — no `weakref` usage in target | N/A |

`Status` values: `applied`, `pending`, `N/A`. No other values. The checklist must include one row per source identified in the target; a row marked `pending` blocks acceptance.

## Example: Before and After

The "before" snippet below is non-deterministic on purpose; it appears here only as the labelled "before" half of a before/after pair.

### Before (non-deterministic)

```python
import os
import time
import uuid
import random
import numpy as np
import torch

def make_run_record(items):
    run_id = uuid.uuid4().hex
    started_at = time.time()
    weights = {item: random.random() for item in items}
    keys = list(weights.keys())
    files = os.listdir("./inputs")
    total = sum(weights[k] for k in weights)
    x = torch.randn(1, 3, 32, 32)
    w = torch.randn(8, 3, 3, 3)
    model_out = torch.nn.functional.conv2d(x, w).sum().item()
    return {
        "run_id": run_id,
        "started_at": started_at,
        "files": files,
        "keys": keys,
        "total": total,
        "model_out": model_out,
        "host": os.environ["HOSTNAME"],
    }
```

This snippet leaks: random PRNGs (`uuid4`, `random.random`, `torch.randn`), wall-clock time (`time.time`), filesystem `readdir` order (`os.listdir`), hash and dict iteration order (iterating `weights` without sorting), set ordering (implicit when items are deduped through a set elsewhere), floating-point reduction order (the unordered `sum`; BLAS may multi-thread it), GPU non-determinism (`conv2d` under cuDNN), and environment variable leakage (`HOSTNAME`). The same `items` produces a different record on every call.

### After (deterministic)

```python
import hashlib
import json
from dataclasses import dataclass
from typing import Protocol

class Clock(Protocol):
    def now(self) -> float: ...

class Filesystem(Protocol):
    def listdir(self, path: str) -> list[str]: ...

@dataclass(frozen=True)
class Deps:
    clock: Clock
    rng: "random.Random"
    fs: Filesystem
    env: dict

def make_run_record(items, deps: Deps):
    ordered_items = sorted(items)

    canonical = json.dumps(ordered_items, sort_keys=True).encode("utf-8")
    run_id = hashlib.sha256(canonical).hexdigest()

    started_at = deps.clock.now()

    weights = {item: deps.rng.random() for item in ordered_items}

    files = sorted(deps.fs.listdir("./inputs"))

    total = sum(weights[k] for k in sorted(weights))

    model_out = _deterministic_conv2d(deps.rng)

    return {
        "run_id": run_id,
        "started_at": started_at,
        "files": files,
        "keys": ordered_items,
        "total": total,
        "model_out": model_out,
        "host": deps.env.get("HOSTNAME", "fixed-host"),
    }

def _deterministic_conv2d(rng):
    import torch
    torch.use_deterministic_algorithms(True, warn_only=False)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
    seed = rng.randrange(2**31)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    x = torch.randn(1, 3, 32, 32)
    w = torch.randn(8, 3, 3, 3)
    return torch.nn.functional.conv2d(x, w).sum().item()
```

The rewrite addresses every source the "before" snippet leaked. IDs become content hashes (ID generation). Time and randomness flow through injected dependencies (wall-clock time, monotonic clocks by extension, random seeds). Filesystem and dict iteration are sorted (filesystem `readdir` order, hash and dict iteration order, set ordering). The reduction iterates in sorted key order with a single-threaded summation (floating-point reduction order, thread-pool ordering, parallel race conditions, async race conditions are sidestepped). GPU kernels are forced deterministic and re-seeded (GPU non-determinism). Environment access is mediated and defaulted (environment variable leakage). Strings are canonicalized through JSON with `sort_keys=True`, which is locale-independent (locale-dependent string operations). No network calls, so network jitter and retry jitter are eliminated by construction. The pinned interpreter and pinned PyTorch version bound undefined behavior in compilers. Outputs never embed `id()` or default `__repr__`, so memory layout differences cannot leak. No `__del__` side effects fire during the call (garbage collector finalizers), and no `weakref` cache is consulted (weak references). Timezones never enter the record because times are mediated through the injected clock and never formatted with a TZ-sensitive routine. Run the function twice with the same `Deps` and the output is bit-identical.

## Verification

Apply every check below against the refactored target. The refactor is "done" only when all three pass.

1. **Run twice, byte-compare.** Run the target end-to-end twice in the same process, then in two fresh processes; outputs must be byte-identical.

   ```bash
   ./run.sh > out.a
   ./run.sh > out.b
   diff out.a out.b
   sha256sum out.a out.b
   ```

2. **Hash-compare across two machines or environments.** Run on at least two hosts (or two containers built from different base images) and compare hashes.

   ```bash
   ssh hostA "cd repo && ./run.sh" | sha256sum
   ssh hostB "cd repo && ./run.sh" | sha256sum
   ```

3. **Vary CPU count, locale, and environment; output must not change.** Sweep across configurations that historically perturb output and confirm the hash is invariant.

   ```bash
   for nthreads in 1 4 16; do
     for locale in C C.UTF-8 en_US.UTF-8 tr_TR.UTF-8; do
       OMP_NUM_THREADS=$nthreads \
       MKL_NUM_THREADS=$nthreads \
       OPENBLAS_NUM_THREADS=$nthreads \
       LC_ALL=$locale \
       LANG=$locale \
       TZ=UTC \
       PYTHONHASHSEED=0 \
       SOURCE_DATE_EPOCH=0 \
       ./run.sh | sha256sum
     done
   done
   ```

If any check fails, return to the enumeration, find the source that was missed, pair it with a concrete mitigation from the list above, and re-run all three checks. Do not declare the target deterministic until every digest matches.
