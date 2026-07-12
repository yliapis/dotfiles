---
name: deterministic-design
description: "Drive a systematic effort to enumerate and eliminate every source of non-determinism in a target so the same input produces bit-identical output on every run, every machine, and every process. Use when the user explicitly asks for deterministic design, reproducibility, or removing non-determinism from a piece of code or a system. Manually invoked only — do not apply against unrelated edits."
license: MIT
---

# Deterministic Design

Same input → same output, every run, every machine, every process.

A program is deterministic when its observable output is a pure function of its declared inputs. Hidden inputs — wall-clock time, hash seeds, thread schedules, filesystem ordering, GPU reduction order, ambient environment — silently break that contract. This skill drives an audit-and-fix discipline against a specific target: find every such hidden input, pair it with a concrete mitigation, then prove the result is bit-identical across runs and machines.

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly asks for one of:

- Deterministic design, deterministic behavior, or deterministic execution.
- Reproducibility across runs, machines, processes, containers, or environments.
- Removing non-determinism, flaky tests tied to ordering or timing, or "works on my machine" drift.
- Bit-identical output between two runs or two hosts (e.g., `sha256sum` parity).

Do not apply this skill against unrelated edits. If the user has not asked for determinism, leave the target alone. The cost of a deterministic refactor is real (injection points, reduced parallelism, deferred clock and RNG access); it pays back only when the user has asked for it.

## Sources of Non-Determinism

Each entry below names a source, its failure mode, and at least one concrete, named mitigation. When invoked against a target, walk this list end-to-end. If a source genuinely does not apply to the target's language or runtime, keep its row in the checklist with `Status: N/A` and a one-line rationale rather than silently dropping it.

### Random Seeds
- Failure mode: uncontrolled PRNGs — `random`, `numpy.random`, `torch`, `jax`, `Math.random`, `secrets`, OpenSSL randomness — draw different values each run; anything sampled, shuffled, initialized, or signed downstream drifts.
- Mitigation: pin seeds explicitly at every layer before any random draw: `random.seed(0)`, `numpy.random.seed(0)`, `torch.manual_seed(0)`, `torch.cuda.manual_seed_all(0)`, `jax.random.PRNGKey(0)`. Inject a `Random` instance into the call graph instead of relying on module-level state. Export `PYTHONHASHSEED=0`. In JS, pass an explicit seed to a seeded RNG (e.g., `seedrandom`) instead of `Math.random`.

### Wall-Clock Time
- Failure mode: `time.time()`, `datetime.now()`, `Date.now()`, `System.currentTimeMillis()`, `Instant.now()` embed run-time noise into outputs, logs, IDs, filenames, headers, and signed payloads.
- Mitigation: inject a `Clock` interface and read time only through it. Provide a `FrozenClock(0)` or `FakeClock` in tests. Treat any current-time read inside pure logic as a bug; move it to the edge of the program. For build artifacts, set `SOURCE_DATE_EPOCH`.

### Monotonic Clocks
- Failure mode: `time.monotonic()`, `time.perf_counter()`, `System.nanoTime()`, `performance.now()`, `clock_gettime(CLOCK_MONOTONIC)` are unrelated to wall time but still differ run to run; they leak into timing-based branches, retry decisions, cache eviction order, and durations embedded in artifacts.
- Mitigation: inject a `MonotonicClock` alongside the wall clock. In tests, use a step-controlled fake that advances only when the test explicitly ticks it. Never let control flow or output content depend on observed elapsed time. Record real durations in a side channel (logs, telemetry), not in the artifact.

### Timezones
- Failure mode: `datetime.now()` without `tzinfo`, `time.localtime()`, `strftime("%Z")`, and DST rules produce different strings on hosts with different `TZ`; naive datetimes silently absorb the host's timezone.
- Mitigation: pin `TZ=UTC` in the canonical run environment. Work in UTC internally; serialize as timezone-aware ISO 8601. Forbid naive datetimes at module boundaries; use `datetime.now(timezone.utc)` only via the injected clock; convert to local time only at display edges.

### Hash and Dict Iteration Order
- Failure mode: Python `dict` is insertion-ordered but string and bytes hashes are salted via `PYTHONHASHSEED`, so anything derived from `hash()` differs across runs; Go map iteration is intentionally randomized; Java `HashMap` order is unspecified.
- Mitigation: set `PYTHONHASHSEED=0`. Sort keys before iterating when output depends on iteration order: `for k in sorted(d):`. Serialize with `json.dumps(payload, sort_keys=True)`. In Go, copy keys to a slice and `sort.Strings(...)` before ranging. Use ordered data structures (`collections.OrderedDict`, `BTreeMap`, `LinkedHashMap`) when order is observable.

### Set Ordering
- Failure mode: `set` and `frozenset` iteration order in Python depends on hash and insertion history; Java `HashSet`, Rust `HashSet`, and JS `Set` (when keys go through hashing) are unordered or order-unstable.
- Mitigation: convert to `sorted(s)` before iterating, hashing, or serializing. Use `SortedSet`, `BTreeSet`, or `LinkedHashSet` when an ordered set is structurally required. Never emit a raw set into observable output.

### Parallel Race Conditions
- Failure mode: shared mutable state updated by multiple workers produces results that depend on interleaving — last-writer-wins, lost updates, partial reads.
- Mitigation: make the parallel region pure (map-only, no shared writes) and reduce via a deterministic merge ordered by partition index or sorted key. Use barrier synchronization for inter-stage ordering, or run the critical section single-threaded when correctness depends on order. Forbid `dict.setdefault`-style "first writer wins" on shared state.

### Floating-Point Reduction Order
- Failure mode: `(a + b) + c ≠ a + (b + c)` in IEEE-754; parallel sums, BLAS, cuBLAS, `numpy.einsum`, and SIMD reductions reorder across CPU counts and lane widths, producing different last bits.
- Mitigation: fix the reduction order — `sum(sorted(xs))`, pairwise / Kahan / Neumaier compensated summation with a pinned schedule. Pin a single-threaded BLAS (`OMP_NUM_THREADS=1`, `MKL_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`). Prefer integer or fixed-precision arithmetic for accumulators where feasible. Disable compiler reassociation (`-fno-fast-math`, no `-ffast-math`).

### Network Jitter
- Failure mode: real network calls return at variable times, in variable orders, with variable retries, partial reads, and even variable payloads (load-balanced backends, A/B routing).
- Mitigation: mock the network at a stable boundary (HTTP client, gRPC stub, message bus) and replay a recorded fixture (`vcrpy`, `nock`, MSW, VCR-style cassettes). Sort responses by request key before merging. Strip wall-clock timestamps from response bodies before they enter pure logic.

### Filesystem `readdir` Order
- Failure mode: `os.listdir`, `glob.glob`, `pathlib.iterdir`, `fs.readdir`, `Files.list`, and `readdir(3)` return entries in OS- and filesystem-dependent order (ext4, APFS, tmpfs, overlayfs, NFS all differ); the same checkout on two CI runners enumerates differently.
- Mitigation: sort directory entries before use: `sorted(os.listdir(path))`, `sorted(glob.glob(pattern))`. When walking trees with `os.walk`, sort `dirnames` and `filenames` in place at every level so descent order is fixed. Never feed unsorted `readdir` output into a hash, tar archive, or downstream pipeline. For archive builds, pass `--sort=name` to `tar` and pin `mtime` via `SOURCE_DATE_EPOCH`.

### Environment Variable Leakage
- Failure mode: code reads `os.environ` (`HOME`, `USER`, `PATH`, `LANG`, `TMPDIR`, `HOSTNAME`, CI vars) and embeds host-specific values into outputs, logs, or build artifacts.
- Mitigation: canonicalize the environment at process entry — start from an empty `env` (`env -i`) and inject only a pinned allowlist (`PATH`, `TZ=UTC`, `LANG=C.UTF-8`, `LC_ALL=C.UTF-8`, `PYTHONHASHSEED=0`, `SOURCE_DATE_EPOCH=0`). Forbid direct `os.environ` reads in business logic; inject configuration explicitly through a `Config` object.

### Locale-Dependent String Operations
- Failure mode: `str.lower()`, `str.upper()`, `sorted()` on strings, `strcoll`, `strftime`, `printf("%f")`, regex character classes, and number parsing change behavior with locale (Turkish dotless I, German ß, comma vs dot decimals, localized month names).
- Mitigation: set `LC_ALL=C` and `LANG=C.UTF-8` for the run. Use Unicode-aware, locale-independent operations: `str.casefold()`, `unicodedata.normalize("NFC", s)`, ICU collation with an explicit, pinned locale tag. Format numbers with `repr(x)` or `format(x, ".17g")`, never with locale-aware formatters. For byte-ordered sorts, key on `s.encode("utf-8")`.

### Undefined Behavior in Compilers
- Failure mode: C / C++ / Rust `unsafe` code with signed-integer overflow, uninitialized reads, strict-aliasing violations, OOB access, or data races compiles to different output under different optimizer flags or compiler versions; output bytes depend on accidents.
- Mitigation: pin compiler version and flags in the build manifest (`-O2 -fno-strict-aliasing -fwrapv -fno-fast-math`, `-frandom-seed=$file`, `-fdebug-prefix-map`, `SOURCE_DATE_EPOCH`). Run UBSan, ASan, and TSan in CI and treat any finding as a determinism bug. Use `-ftrivial-auto-var-init=zero` to zero-init stack vars. In Rust, prefer `wrapping_*` / `checked_*` arithmetic primitives over relying on `--release` overflow behavior.

### GPU Non-Determinism (Atomic Adds, cuDNN)
- Failure mode: CUDA `atomicAdd` on floats reorders contributions across warps; cuDNN convolution and reduction algorithms select non-deterministic kernels by default; `scatter_add`, `index_add`, and many GPU reductions are non-deterministic; TF32 / FP16 paths produce different bits across devices.
- Mitigation: `torch.use_deterministic_algorithms(True, warn_only=False)`, `torch.backends.cudnn.deterministic = True`, `torch.backends.cudnn.benchmark = False`, set `CUBLAS_WORKSPACE_CONFIG=:4096:8` (or `:16:8`). In TensorFlow, `tf.config.experimental.enable_op_determinism()`. Replace `scatter_add` / raw `atomicAdd` with deterministic reductions (sorted gather, segmented scan, sort-then-reduce). Accept the throughput cost.

### Thread-Pool Ordering
- Failure mode: `ThreadPoolExecutor`, `multiprocessing.Pool`, OpenMP, Rayon, and work-stealing pools dispatch tasks in whatever order workers become free; merged results depend on completion order, not submission order.
- Mitigation: collect results into a buffer keyed by task index, then iterate the buffer in index order before reducing (`executor.map` preserves submission order; otherwise store `(index, result)` and sort by `index`). Pin the pool size; set `OMP_NUM_THREADS=1` for the reproducible run. Never rely on `as_completed`-style ordering for output content.

### Async Race Conditions
- Failure mode: `asyncio.gather`, `Promise.all`, `tokio::join!` start tasks concurrently; return values come back in submission order, but side effects (logs, DB writes, shared caches) fire in arrival order, which depends on scheduler and I/O latency. `Promise.race` / `select!` winners depend on timing.
- Mitigation: keep async tasks pure and side-effect-free; collect their return values and apply side effects sequentially in submission order on the awaiter. Forbid shared mutable state across awaits; if unavoidable, guard with an explicit lock and a deterministic acquisition order. Forbid `Promise.race` inside the deterministic boundary unless the winner is provably unique. Use a deterministic / virtual-time event loop in tests.

### Retry Jitter
- Failure mode: exponential-backoff retries with random jitter produce different timing and different downstream effects each run; retry counts vary with wall-clock budgets.
- Mitigation: route jitter through the injected seeded `Random(seed=0)`, or disable jitter entirely inside the deterministic boundary (`jitter=0`). Replace live network retries with a fixture replay so retry timing never reaches output. Make the retry count a deterministic input (`max_attempts=N`), not a wall-clock-bounded loop.

### ID Generation (UUIDs, Autoincrement Collisions)
- Failure mode: `uuid.uuid4()` is fully random; `uuid.uuid1()` embeds wall-clock time and MAC address; database autoincrement IDs depend on insertion order across parallel writers and can collide or reorder under contention.
- Mitigation: use **content-hash IDs** — `uuid.uuid5(NAMESPACE, canonical_repr)` or `sha256(canonical_bytes)` — so the same input always yields the same ID. Where surrogate IDs are unavoidable, generate them from an injected seeded `Random` and assign them in a deterministic traversal order (sorted by a stable natural key). For ULID-style IDs, pin the timestamp via the injected clock.

### Memory Layout Differences
- Failure mode: ASLR, allocator quirks, pointer arithmetic, `id(obj)`, default `repr` of objects without `__repr__`, struct padding, and pointer sizes (32- vs 64-bit) leak into outputs via debug logs, default `object.__repr__`, raw `memcpy` to disk, or `pickle` byte streams across versions.
- Mitigation: never embed pointer values, `id()`, `Object.hashCode` defaults, or default `object.__repr__` into observable output. Strip `0x...` patterns from reproducible artifacts. Use schema-defined serializers (`json.dumps(..., sort_keys=True)`, `pickle` with a pinned protocol, msgpack, Protobuf / FlatBuffers / CBOR with deterministic encoding) and pin the language / runtime version. Disable ASLR (`setarch $(uname -m) -R`) when byte-identical core dumps or debug output are part of the contract.

### Garbage Collector Finalizers
- Failure mode: `__del__`, `weakref` callbacks, and JVM / Go / .NET finalizers run in GC-determined order, sometimes during interpreter shutdown, with observable side effects (closing files, flushing buffers, emitting logs).
- Mitigation: use explicit `with` / `try-finally` / RAII / `defer` for any side-effectful resource. Treat `__del__` and `finalize()` as best-effort cleanup only, never as a source of observable output. If finalizer ordering is part of the contract, force it with explicit `gc.collect()` at deterministic checkpoints and verify the call order in tests. Disable cyclic GC at the boundary (`gc.disable()` in tests) when its tracing alters timing-observable behavior.

### Weak References
- Failure mode: `weakref` / `WeakValueDictionary` / Java `WeakHashMap` / C++ `weak_ptr` lookups return `None` based on GC timing, so cache hit / miss behavior — and any output derived from it — differs run to run.
- Mitigation: replace weak caches with bounded strong caches (LRU with fixed capacity) on the deterministic path so eviction is a function of inputs, not of GC timing. If weak references are required for memory reasons, ensure cache hit / miss affects only performance, never output content; assert this with a test that forces `gc.collect()` and compares output.

## Design Principles

- **Same input → same output, every run.** This is the single invariant the skill enforces. Any deviation is a bug, not an acceptable variance. If you cannot state the full input set of a function in one sentence, the design is not finished.
- **Pure functions over stateful operations.** Push state to the edges; keep the core a function of its arguments. A function whose output depends only on its arguments cannot be flaky.
- **Explicit dependency injection over ambient state.** Pass `clock`, `random`, `env`, `fs`, `net` as parameters or interfaces; never read them from module-level globals or process-wide singletons.
- **Reproducible builds.** Pin compiler and runtime versions, lock dependencies by hash (not floating tags), pin container images by digest, set `SOURCE_DATE_EPOCH`, strip build paths and timestamps from artifacts, sort archive entries. The same source tree must produce byte-identical artifacts.
- **Testable in isolation.** Each unit must run under fakes for every injected dependency: no real network, no filesystem outside a tmpdir, no real clock, no real GPU.
- **Output bit-identical across machines and runs.** The acceptance test is `sha256sum` parity, not "looks the same" — every diagnostic is a hash comparison.

## Deliverable When Invoked

When this skill is invoked against a target, produce **one** of the following — pick one explicitly, do not mix. Choose (a) when the target is small and the user has authorized the refactor; choose (b) when the target is large, exploratory, or the user wants to scope the work first.

### (a) Deterministic Refactor

A patch (or set of patches) against the target code that eliminates every identified source of non-determinism. Each change cites the source it addresses (e.g., "pin seed: addresses Random Seeds entry"). The refactor MUST NOT introduce new non-determinism; the patch is acceptable only when every row of the checklist below would be marked `applied`, `verified`, or `N/A`, and the verification checks below pass.

### (b) Checklist of Fixes

A table that names every non-determinism source identified in the target and pairs each with a concrete mitigation. Use exactly these four columns, in this order:

| Source | Location in target code | Mitigation | Status |
|---|---|---|---|
| Random seed not pinned | `train.py:42` | Set `random.seed(0)`, `numpy.random.seed(0)`, `torch.manual_seed(0)`; export `PYTHONHASHSEED=0` | applied |
| Wall-clock time embedded in output | `report.py:88` | Inject `Clock`; replace `time.time()` with `clock.now()`; use `FrozenClock(0)` in tests | applied |
| Dict iteration order in serializer | `serializer.py:17` | `json.dumps(payload, sort_keys=True)` | applied |
| Filesystem `readdir` order | `loader.py:9` | `sorted(os.listdir(path))` before iteration | proposed |
| cuDNN nondeterministic conv | `model.py:120` | `torch.use_deterministic_algorithms(True)`; `CUBLAS_WORKSPACE_CONFIG=:4096:8`; replace `scatter_add` with sorted gather | applied |
| `uuid4()` written into manifest | `manifest.py:33` | Replace with `sha256(canonical_bytes)` content-hash ID | proposed |
| Locale-dependent sort | `index.py:91` | Run under `LC_ALL=C`; key on UTF-8 bytes | applied |
| `__del__` flushes log file | `cache.py:55` | Move flush into `__exit__`; remove finalizer side effect | proposed |
| Weak references | (none found) | N/A — no `weakref` usage in target | N/A |

`Status` values: `proposed` (identified, not yet applied), `applied` (fix landed), `verified` (fix landed and determinism check passes), `N/A` (does not apply to this target, with a one-line rationale recorded in the row). No other values. The checklist must include one row per source enumerated above that applies to the target; `proposed` rows are expected here (scoping is the point of this deliverable) but block acceptance of deliverable (a), and any source that genuinely does not apply must be recorded as `N/A` with a rationale, not silently dropped.

## Example: Before / After

The "before" snippet below is non-deterministic on purpose; it appears here only as the labelled "before" half of a before / after pair.

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

This snippet leaks: random PRNGs (`uuid4`, `random.random`, `torch.randn`), wall-clock time (`time.time`), filesystem `readdir` order (`os.listdir`), hash and dict iteration order (iterating `weights` without sorting), floating-point reduction order (the unordered `sum`; BLAS may multi-thread it), GPU non-determinism (`conv2d` under cuDNN), and environment variable leakage (`HOSTNAME`). The same `items` produces a different record on every call.

### After (deterministic)

```python
import hashlib
import json
import random
from dataclasses import dataclass
from typing import Protocol

class Clock(Protocol):
    def now(self) -> float: ...

class Filesystem(Protocol):
    def listdir(self, path: str) -> list[str]: ...

@dataclass(frozen=True)
class Deps:
    clock: Clock
    rng: random.Random
    fs: Filesystem
    env: dict

def make_run_record(items, deps: Deps):
    ordered_items = sorted(set(items))

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

def _deterministic_conv2d(rng: random.Random) -> float:
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

The rewrite addresses every source the "before" snippet leaked, source by source:

1. **Random Seeds**: PRNG state flows through the injected `deps.rng`; the GPU helper re-seeds `torch.manual_seed` and `torch.cuda.manual_seed_all` from the same RNG before any draw.
2. **Wall-Clock Time** (and **Monotonic Clocks** by extension): `time.time()` is replaced by `deps.clock.now()`; tests pass a `FrozenClock(0)`. **Timezones** never enter the record because times flow through the injected clock and are never formatted with a TZ-sensitive routine.
3. **Hash and Dict Iteration Order**: iteration over `weights` is wrapped in `sorted(weights)`; downstream JSON serialization uses `sort_keys=True`.
4. **Set Ordering**: `sorted(set(items))` produces a stable ordered list before any further use; no raw set escapes into output.
5. **Parallel Race Conditions / Thread-Pool Ordering / Async Race Conditions**: the function is single-threaded and pure relative to `deps`, so no shared mutable state and no scheduler-dependent ordering can leak.
6. **Floating-Point Reduction Order**: the `total` sum iterates in sorted key order; a single-threaded BLAS (set externally via `OMP_NUM_THREADS=1`) pins reduction shape.
7. **Network Jitter** / **Retry Jitter**: there are no network calls; both are eliminated by construction at the deterministic boundary.
8. **Filesystem `readdir` Order**: `sorted(deps.fs.listdir("./inputs"))` fixes directory iteration; the filesystem itself is injected.
9. **Environment Variable Leakage**: `os.environ["HOSTNAME"]` becomes `deps.env.get("HOSTNAME", "fixed-host")`; the canonicalized env is passed in, not read ambiently.
10. **Locale-Dependent String Operations**: strings are canonicalized through `json.dumps(..., sort_keys=True)`, which is locale-independent; the run script sets `LC_ALL=C.UTF-8`.
11. **Undefined Behavior in Compilers**: the pinned Python interpreter and pinned PyTorch version (locked in the build manifest) bound the toolchain.
12. **GPU Non-Determinism**: `torch.use_deterministic_algorithms(True)`, `cudnn.deterministic = True`, `cudnn.benchmark = False`, and `CUBLAS_WORKSPACE_CONFIG=:4096:8` (set in the run environment) force deterministic kernels.
13. **ID Generation**: the random `uuid4()` is replaced by `sha256(canonical_bytes)` — a pure content hash of the sorted input.
14. **Memory Layout Differences**: outputs never embed `id()` or default `__repr__`; serialization goes through JSON with canonical key order.
15. **Garbage Collector Finalizers** and **Weak References**: the function holds no `__del__` side effects and consults no `weakref` cache; both are sidestepped.

Run `make_run_record(items, deps)` twice with the same `items` and `deps` (same `FrozenClock`, same seeded `Random`, same fake filesystem, same env dict) and the output is bit-identical.

## Verification

Apply every check below against the refactored target. The refactor is "done" only when checks 1–3 pass unmodified; checks 4–6 are required when the target's language or runtime makes them applicable.

### 1. Run twice on the same machine; byte-compare outputs

```bash
./run.sh > out.a
./run.sh > out.b
diff out.a out.b              # MUST be empty
sha256sum out.a out.b         # the two digests MUST match
```

Run once in the same process and once in a fresh process; both pairs must match.

### 2. Hash-compare across two machines or environments

```bash
# machine A
ssh hostA "cd repo && ./run.sh | sha256sum"
# machine B
ssh hostB "cd repo && ./run.sh | sha256sum"
# the two hashes MUST be identical
```

If a container is the canonical environment, run the same image (pinned by digest) on both hosts.

### 3. Vary CPU count, locale, timezone, and environment; output MUST be unchanged

Sweep across configurations that historically perturb output and confirm the hash is invariant:

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
# every printed digest MUST be identical
```

Also wipe the environment to a minimal canonical set and confirm the hash is unchanged:

```bash
env -i PATH=/usr/bin:/bin TZ=UTC LC_ALL=C.UTF-8 PYTHONHASHSEED=0 ./run.sh | sha256sum
```

### 4. Replay from a recorded seed (where the target draws random values)

```bash
SEED=42 ./run.sh | sha256sum
# MUST equal the reference hash recorded on the first run with the same seed
```

### 5. Run under sanitizers (where the target is C / C++ / Rust unsafe)

```bash
# C / C++ build with UB and address sanitizers
CFLAGS="-fsanitize=undefined,address,thread" ./build.sh && ./run.sh
# Rust
cargo +nightly miri test
```

Treat any UBSan / ASan / TSan / miri finding as a determinism bug; fix before declaring the target deterministic.

### 6. GPU determinism (where the target uses CUDA / cuDNN)

```bash
PYTHONHASHSEED=0 \
CUBLAS_WORKSPACE_CONFIG=:4096:8 \
./run.sh > out.gpu1

PYTHONHASHSEED=0 \
CUBLAS_WORKSPACE_CONFIG=:4096:8 \
./run.sh > out.gpu2

diff out.gpu1 out.gpu2        # MUST be empty
```

### When a field genuinely cannot be made deterministic

Some outputs (e.g., a timestamp returned by an external API the target must call) cannot be eliminated. Document any such field, exclude it via an explicit, named normalizer applied before the byte-diff, and never silently strip it. The normalizer itself is part of the deliverable.

If any check fails, return to the enumeration: an unmitigated source remains. Identify it, pair it with a concrete mitigation from the list above, and re-run every check. Do not declare the target deterministic until every digest matches.
