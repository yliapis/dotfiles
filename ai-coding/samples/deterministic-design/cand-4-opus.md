---
name: deterministic-design
description: "Force code and systems to produce bit-identical output for the same input on every run, machine, and process by enumerating and eliminating every source of non-determinism. Use when the user asks for deterministic design, reproducibility, or removing non-determinism from a target piece of code or system."
license: MIT
---

# Deterministic Design

Same input → same output, every run, every machine, every process.

This skill is the playbook for hunting down and eliminating non-determinism. When invoked, it drives a systematic audit of a target codebase — clock reads, random draws, iteration orders, race conditions, environment leaks, numerical reductions — and pairs each finding with a concrete mitigation, until two runs produce byte-identical output.

## When to Invoke

This skill is **manually invoked**. Apply it only when the user explicitly asks for one of:

- Deterministic design or deterministic behavior of a target piece of code or system.
- Reproducibility (reproducible builds, reproducible runs, reproducible outputs).
- Removing non-determinism, "flakiness" tied to ordering or timing, or "make it produce the same output every time".

Do not apply this skill against unrelated work. If the user is editing code without asking for determinism, this skill stays inert.

## Sources of Non-Determinism

Every source below is paired with a failure mode and at least one concrete mitigation. When invoked against a target, walk this list and confirm each applicable source is either neutralised or explicitly out of scope.

### Random Seeds

- Failure mode: uncontrolled PRNGs draw fresh values on every run; any output that depends on randomness drifts.
- Mitigation: pin seeds explicitly at every layer (`random.seed(0)`, `numpy.random.seed(0)`, `torch.manual_seed(0)`, `torch.cuda.manual_seed_all(0)`); set `PYTHONHASHSEED=0`. Pass seeds in as parameters; never read them from ambient state.

### Wall-Clock Time

- Failure mode: `time.time()`, `datetime.now()`, `Date.now()` embed run-time noise (timestamps in logs, headers, IDs, filenames) into outputs.
- Mitigation: inject a clock interface into any function that needs the time. In tests and reproducible runs, supply a frozen or monotonically-stepping fake clock. Forbid ambient time reads in pure logic via lint or review.

### Monotonic Clocks

- Failure mode: `time.monotonic()` / `perf_counter` / `CLOCK_MONOTONIC` produce different values every run because they measure elapsed real time.
- Mitigation: confine monotonic clocks to measurement and observability paths only. Never let their values flow into outputs, hashes, IDs, file content, or control flow that influences the result.

### Timezones

- Failure mode: timezone-aware operations and formatters depend on `TZ`, system locale, or DST rules; "today" and "yesterday" disagree across machines.
- Mitigation: pin all timestamps to UTC. Set `TZ=UTC` in the runtime environment. Use timezone-aware libraries (`zoneinfo`, `Temporal`) and pass the zone explicitly; never rely on the system default.

### Hash and Dict Iteration Order

- Failure mode: hash randomization (`PYTHONHASHSEED`) and historical dict ordering changes mean iteration produces different sequences across runs and language versions.
- Mitigation: never serialise or hash a dict by raw iteration; always sort keys (`json.dumps(obj, sort_keys=True)`). Set `PYTHONHASHSEED=0` for runs that must be reproducible. Use ordered data structures (`collections.OrderedDict`, `BTreeMap`) where order is observable.

### Set Ordering

- Failure mode: `set` and `frozenset` iteration depends on hash; output that prints, serialises, or aggregates from a set drifts.
- Mitigation: sort before iterating (`for x in sorted(myset)`). Use ordered alternatives (e.g. `sortedcontainers.SortedSet`, `BTreeSet`) when an order-preserving set is needed.

### Parallel Race Conditions

- Failure mode: multiple workers race to update shared state or write to a shared output; whichever wins changes per scheduler.
- Mitigation: design for commutative or per-key-disjoint reductions. Sort outputs by a stable key before emitting. Use barriers and explicit ordering (gather → sort → reduce). When in doubt, single-thread the reduction step.

### Floating-Point Reduction Order

- Failure mode: `(a + b) + c ≠ a + (b + c)` in IEEE-754; parallel sums and unordered reductions return different bits per scheduler / vector width.
- Mitigation: pin the reduction tree shape — sort-then-sum, or use Kahan / Neumaier compensated summation. For libraries, set deterministic flags (e.g. `torch.use_deterministic_algorithms(True)`). Where bit-equality matters, run the reduction single-threaded with a fixed traversal order.

### Network Jitter

- Failure mode: live network I/O introduces latency, packet ordering, partial reads, retries, and ambient state into outputs.
- Mitigation: mock the network in tests and reproducible runs. Replay recorded fixtures (e.g. VCR-style cassettes). Where a real call is unavoidable, hash the canonical request and treat the response as content-addressed.

### Filesystem `readdir` Order

- Failure mode: `os.listdir`, `glob`, `walkdir`, `readdir(2)` return entries in filesystem-native order, which differs across filesystems, OSes, and even repeated runs on the same FS.
- Mitigation: sort the result of every directory listing before consuming it (`sorted(os.listdir(path))`). Treat any unsorted directory iteration in a reproducible path as a bug.

### Environment Variable Leakage

- Failure mode: code reads `os.environ` (paths, locale, proxies, `USER`, `HOME`, secrets) and the result varies across machines and CI runners.
- Mitigation: canonicalise the environment at process entry — start from an empty `env` and re-add only the variables the program declares it needs. In tests and reproducible runs, execute under a pinned env block.

### Locale-Dependent String Operations

- Failure mode: `strcoll`, `strftime`, `lower`/`upper`, regex character classes, sort orders, and number formatting depend on `LC_ALL` / `LANG`.
- Mitigation: set locale to `C` or `POSIX` (`LC_ALL=C`) for any process whose output must be reproducible. Avoid locale-aware comparisons in pure logic; use codepoint-ordered comparisons.

### Undefined Behavior in Compilers

- Failure mode: signed overflow, uninitialised reads, strict-aliasing violations, and pointer-provenance bugs let optimisers produce different code on different toolchain versions or flags.
- Mitigation: enable `-fsanitize=undefined,address` in CI; treat any UB report as a determinism bug. Pin compiler version and flags. Use wrapping types or `-ftrapv` where overflow is intended. In Rust, prefer the well-defined `wrapping_*` / `checked_*` arithmetic primitives.

### GPU Non-Determinism (atomic adds, cuDNN)

- Failure mode: parallel atomic adds on the GPU reduce in a scheduler-dependent order; cuDNN selects different convolution algorithms per launch; warp-level operations interleave non-deterministically.
- Mitigation: set deterministic flags (`torch.use_deterministic_algorithms(True)`, `torch.backends.cudnn.deterministic = True`, `torch.backends.cudnn.benchmark = False`); set `CUBLAS_WORKSPACE_CONFIG=:4096:8`. Replace `scatter_add` with sorted gather-add. Accept the throughput cost.

### Thread-Pool Ordering

- Failure mode: `ThreadPoolExecutor`, `rayon`, OpenMP, and similar pools complete tasks in arrival-dependent order; downstream consumers see different sequences.
- Mitigation: collect futures and sort by submission index before consuming. Pin pool size (`OMP_NUM_THREADS=1` in reproducible runs). Prefer `map`-style APIs that preserve input order over `as_completed`/`wait_any` for any path whose output is observed.

### Async Race Conditions

- Failure mode: `async/await` schedulers, event loops, and coroutine queues interleave callbacks in OS-dependent order; logs, output buffers, and shared state vary.
- Mitigation: serialise observable side effects through a single ordered queue. Use deterministic schedulers in tests (virtual time, manual loop drive). Avoid `Promise.race` / `select` over equally-ready tasks where the winner shapes output.

### Retry Jitter

- Failure mode: exponential-backoff libraries add random jitter to retry delays and retry counts; that randomness leaks timing into outputs and logs.
- Mitigation: drive jitter from the same seeded PRNG used elsewhere, or disable jitter entirely in reproducible mode (`jitter=0`). Inject a clock and sleep abstraction so retries can be replayed deterministically.

### ID Generation (UUIDs, autoincrement collisions)

- Failure mode: `uuid4()` is random; `uuid1()` embeds time and MAC; database autoincrement IDs depend on insert order; reusing them across runs causes collisions or drift.
- Mitigation: derive IDs from content hashes (`sha256` of the canonical representation) where ID stability is required. Where IDs must be opaque, draw from a seeded UUID generator. Treat any non-content-addressed ID in a reproducible artefact as a bug.

### Memory Layout Differences

- Failure mode: pointer values, struct padding, ASLR, allocator order, and platform alignment leak addresses into outputs (debug logs, repr-derived strings, hash codes).
- Mitigation: never serialise an address. Strip `0x...` patterns from any reproducible artefact. Use stable, value-based hashing (hash of canonical bytes, not Python's `id()`). Disable ASLR (`setarch -R`) when bit-equality of debug output matters.

### Garbage Collector Finalizers

- Failure mode: `__del__`, finalizer queues, and similar hooks run at GC-determined times; any side effect they emit (close, flush, log) appears in non-deterministic order.
- Mitigation: never put observable side effects in finalizers. Use explicit context managers (`with`, `defer`, `try/finally`, RAII). If a finalizer must run, drain it deterministically at a fixed barrier (`gc.collect()` at a known point).

### Weak References

- Failure mode: a `weakref` may or may not still resolve depending on GC timing; behaviour branches on liveness in a scheduler-dependent way.
- Mitigation: never branch reproducible logic on weak-reference liveness. Hold strong references along any reproducible path. Reserve weak references for caches and observers whose presence does not affect output.

## Design Principles

- **Same input → same output, every run.** This is the invariant; anything that violates it is a bug.
- **Pure functions over stateful operations.** Push state to the edges; keep the core a function of its inputs.
- **Explicit dependency injection over ambient state.** Pass clocks, RNGs, env, filesystems, and network as parameters; never read them from globals.
- **Reproducible builds.** Pinned toolchains, pinned dependencies, sorted inputs, normalised metadata, `SOURCE_DATE_EPOCH` for embedded timestamps; build outputs are content-addressed.
- **Testable in isolation.** Any unit can be exercised with no network, no real clock, no real filesystem, and produce a single canonical output.
- **Output bit-identical across machines and runs.** The acceptance test is a byte-level diff, not a "looks the same" inspection.

## Deliverable When Invoked

When this skill is invoked against a target, produce **one** of the following:

### (a) Deterministic Refactor

A code change that eliminates every identified source of non-determinism in the target. The refactor:

- Replaces ambient reads (clock, RNG, env, FS, network) with injected dependencies.
- Sorts every iteration over an unordered container.
- Pins every reduction order.
- Sets the deterministic flags for any framework involved.
- Comes with a verification run (see Verification below) that demonstrates two consecutive runs produce byte-identical output.

### (b) Checklist of Fixes

A table that names every non-determinism source identified in the target and pairs it with a concrete mitigation. The checklist has exactly these four columns:

| Source | Location | Mitigation | Status |
|---|---|---|---|
| Random seed not pinned | `train.py:42` | `torch.manual_seed(0); torch.cuda.manual_seed_all(0); PYTHONHASHSEED=0` | applied |
| Wall-clock time embedded in output | `report.py:118` | Inject `clock` parameter; default to `FrozenClock(0)` in reproducible mode | applied |
| `os.listdir` consumed unsorted | `loader.py:67` | Wrap with `sorted(...)` | applied |
| cuDNN nondeterministic conv | `model.py:204` | `torch.backends.cudnn.deterministic = True; benchmark = False` | applied |
| `uuid4()` written into manifest | `manifest.py:33` | Replace with `sha256(canonical_bytes)` content-hash ID | proposed |
| Locale-dependent sort | `index.py:91` | Run under `LC_ALL=C`; switch to codepoint sort | applied |
| `__del__` flushes log file | `cache.py:55` | Move flush into `__exit__`; remove finalizer side effect | proposed |

`Status` values are one of `proposed`, `applied`, `verified`, `out-of-scope` (with a one-line rationale when `out-of-scope`).

The checklist must reference, at minimum, every source from the enumeration above that applies to the target. A source that genuinely does not apply is recorded as `out-of-scope` with a rationale, not silently dropped.

## Worked Example: Before / After

**Before** (non-deterministic — every run differs):

```python
import os
import time
import uuid
import random

def build_manifest(directory):
    entries = []
    for name in os.listdir(directory):
        entries.append({
            "id": str(uuid.uuid4()),
            "name": name,
            "stamped_at": time.time(),
            "weight": random.random(),
        })
    return entries
```

This snippet is non-deterministic on five axes: `os.listdir` order (filesystem `readdir`), `uuid.uuid4()` randomness (ID generation), `time.time()` wall-clock noise, `random.random()` PRNG state (random seeds), and dict iteration order if `entries` is later serialised (hash and dict iteration order).

**After** (deterministic — bit-identical for the same `directory` contents):

```python
import hashlib
import json
import os

def build_manifest(directory, clock, rng):
    entries = []
    for name in sorted(os.listdir(directory)):
        canonical = json.dumps(
            {"dir": directory, "name": name},
            sort_keys=True,
        ).encode()
        entries.append({
            "id": hashlib.sha256(canonical).hexdigest(),
            "name": name,
            "stamped_at": clock.now(),
            "weight": rng.random(),
        })
    return entries
```

Changes: `os.listdir` is sorted; `uuid.uuid4()` is replaced with a content-hash ID; `time.time()` becomes an injected `clock`; `random.random()` becomes an injected, seeded `rng`; embedded JSON serialisation uses `sort_keys=True`. With `clock = FrozenClock(0)` and `rng = SeededRng(0)`, two consecutive runs over the same directory produce byte-identical output.

## Verification

Every refactor produced under this skill must come with at least the following checks. The target passes only when checks 1–3 succeed unmodified.

1. **Run twice; byte-compare outputs.**

   ```bash
   ./run.sh > out.a
   ./run.sh > out.b
   diff out.a out.b   # must be empty
   ```

2. **Hash-compare across two machines (or two pinned environments).**

   ```bash
   sha256sum out.bin                              # machine A
   ssh other 'cd ~/proj && sha256sum out.bin'     # machine B
   # the two hashes must match
   ```

3. **Vary CPU count, locale, and environment; output must be unchanged.**

   ```bash
   LC_ALL=C TZ=UTC PYTHONHASHSEED=0 OMP_NUM_THREADS=1 ./run.sh > out.1cpu
   LC_ALL=C TZ=UTC PYTHONHASHSEED=0 OMP_NUM_THREADS=8 ./run.sh > out.8cpu
   diff out.1cpu out.8cpu   # must be empty
   ```

4. **Run under sanitisers** (`-fsanitize=undefined,address`, `valgrind`, ASan/UBSan, Rust `cargo +nightly miri test`) to catch UB- and memory-driven non-determinism that hides until optimiser flags change.

5. **Document any field that genuinely cannot be made deterministic** (e.g. an unavoidable real clock for an external API call) and exclude it via an explicit, named normaliser before the byte-diff — never silently. The normaliser itself is part of the deliverable.
