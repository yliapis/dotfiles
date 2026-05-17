---
name: deterministic-design
description: "Eliminate every source of non-determinism in a target so the same input produces a bit-identical output on every run, every machine, and every process. Use when the user explicitly asks for deterministic design, reproducibility, or removing non-determinism."
license: MIT
---

# Deterministic Design

Same input → same output, every run, every machine, every process.

This skill drives a code- or system-wide effort to identify and eliminate every source of non-determinism in a target. It is an audit-and-fix discipline, not a coding style: invoked on demand against a specific target, never pulled into unrelated edits.

## When to Invoke

Apply this skill only when the user explicitly asks for one of:

- "Make this deterministic" / "remove non-determinism".
- "Reproducible builds" or "reproducible outputs".
- "Same input → same output across runs / machines / processes".
- A concrete bug whose root cause is non-determinism (flaky test, drifting hash, output that changes between runs).

Do NOT apply this skill against unrelated work. The cost of deterministic refactoring is real (added injection points, reduced parallelism, deferred clock and RNG calls); it pays back only when the user has asked for it.

## Sources of Non-Determinism

Every entry below names one source, the failure mode it produces, and at least one concrete mitigation. If a category does not apply to the target language or runtime, mark it N/A with a one-line rationale rather than dropping it.

### Random seeds
- Failure mode: PRNG state drifts between runs, so any sample, shuffle, dropout, or model initialization changes.
- Mitigation: pin seeds at every layer that owns RNG state. Python: `random.seed(0)`, `numpy.random.seed(0)`, `torch.manual_seed(0)`, `torch.cuda.manual_seed_all(0)`. Set `PYTHONHASHSEED=0` in the environment. JS: pass an explicit seed to a seeded RNG (e.g., `seedrandom`) instead of `Math.random`.

### Wall-clock time
- Failure mode: `time.time()`, `Date.now()`, `Instant.now()` embed run-time noise into outputs (timestamps, log lines, cache keys, signed payloads).
- Mitigation: inject a clock interface and depend only on the injected clock in pure logic. In tests use a frozen or scripted clock (`freezegun`, fake `Clock` in Java/Kotlin, fake timers in JS). For build artifacts, set `SOURCE_DATE_EPOCH`.

### Monotonic clocks
- Failure mode: `time.monotonic()`, `perf_counter()`, `System.nanoTime()` produce per-process timing that leaks into outputs (durations, profiling data, jittered scheduling decisions).
- Mitigation: never embed monotonic readings in any artifact the user is meant to compare. Where timing must drive behavior, inject a `MonotonicClock` and stub it deterministically; record real durations in a side channel (logs, telemetry), not in the artifact.

### Timezones
- Failure mode: parsing or rendering datetimes against the host TZ produces different strings on different machines.
- Mitigation: serialize datetimes in UTC ISO-8601, parse with explicit timezone (never naive). Set `TZ=UTC` in the canonical run environment. Avoid `datetime.now()`; use `datetime.now(timezone.utc)` only via the injected clock.

### Hash and dict iteration order
- Failure mode: hash randomization (Python ≥3.3) and insertion-order quirks across runtime versions yield different iteration order, which leaks into serialized output and downstream hash digests.
- Mitigation: set `PYTHONHASHSEED=0`. Sort keys before serializing (`json.dumps(..., sort_keys=True)`). Iterate via `sorted(d.items())` whenever order is observable in output. Use deterministic data structures (sorted maps, ordered dicts) for any structure whose iteration order escapes the boundary.

### Set ordering
- Failure mode: iterating a `set` or `frozenset` yields hash-dependent order that varies between processes.
- Mitigation: never iterate a set into observable output. Convert via `sorted(s)` or use an ordered structure (insertion-ordered list, sorted list, `SortedSet`) before any serialization step.

### Parallel race conditions
- Failure mode: two workers updating shared state in different interleavings produce different results each run.
- Mitigation: remove shared mutable state (immutable inputs and pure reduce). Where parallelism is required, use a deterministic reduction order: collect partial results into a keyed map and reduce in sorted key order. As a fallback, single-thread the critical section or barrier-sync so the merge order is fixed.

### Floating-point reduction order
- Failure mode: `(a + b) + c ≠ a + (b + c)` for floats, so parallel sums, GPU reductions, and `numpy` ufuncs across thread counts yield different bits.
- Mitigation: pin reduction order — sum in a fixed sorted order, or use Kahan / pairwise summation. Where accuracy permits, prefer fixed-precision integer or rational arithmetic. On GPU, enable deterministic algorithms (`torch.use_deterministic_algorithms(True)`) and serialize the reduction.

### Network jitter
- Failure mode: real network calls return different timings, retries, partial responses, and even payloads (load-balanced backends, A/B routing).
- Mitigation: mock the network in pure logic. Use a recorded fixture (`vcrpy`, `nock`, MSW) for replay. The deterministic boundary owns no socket; all I/O is injected.

### Filesystem `readdir` order
- Failure mode: directory entry order from `os.listdir`, `readdir(3)`, `glob.glob`, `fs.readdir`, `Files.list` is filesystem-dependent (ext4 ≠ APFS ≠ tmpfs).
- Mitigation: always `sorted(os.listdir(path))` (or `sorted(glob.glob(...))`). When walking trees, use `os.walk` and sort `dirnames` and `filenames` in place at every level so descent order is fixed.

### Environment variable leakage
- Failure mode: ambient env (`LANG`, `TZ`, `HOME`, `PATH`, `USER`, `HOSTNAME`) seeps into rendering, paths, and tool invocations.
- Mitigation: canonicalize the environment at the deterministic boundary — wipe to a known minimal set (`env -i` plus an explicit allowlist), set `TZ=UTC`, `LANG=C.UTF-8`, `LC_ALL=C.UTF-8`. Inject any env-derived value as an explicit parameter; never read globals inside pure logic.

### Locale-dependent string operations
- Failure mode: case folding, sorting (`strcoll`), number/date formatting, and Unicode normalization vary by locale.
- Mitigation: set `LC_ALL=C` (or `C.UTF-8`) for the run. Use locale-independent APIs explicitly: `str.casefold()` for Unicode case, `sorted(..., key=lambda s: s.encode('utf-8'))` for byte-ordered sort, ICU with a pinned collation for human-facing sort.

### Undefined behavior in compilers
- Failure mode: signed integer overflow, uninitialized reads, strict-aliasing violations, OOB access, and data races yield outputs that change with compiler, flags, or version.
- Mitigation: compile with sanitizers (`-fsanitize=undefined,address,thread`) and treat any UBSan/TSan finding as a determinism bug. Pin compiler version and flags in the build manifest. Use `-fwrapv` / `-fno-strict-aliasing` if the code legitimately depends on wrap or aliasing semantics. Use a deterministic compiler toolchain (e.g., `-frandom-seed=...`, reproducible-builds patches).

### GPU non-determinism (atomic adds, cuDNN)
- Failure mode: `atomicAdd` in CUDA, cuDNN's auto-tuned algorithms, and TF32/FP16 paths produce different bits across runs and devices.
- Mitigation: enable deterministic mode (`torch.use_deterministic_algorithms(True)`, `tf.config.experimental.enable_op_determinism()`), set `CUBLAS_WORKSPACE_CONFIG=:4096:8`, disable cuDNN benchmark (`torch.backends.cudnn.benchmark = False`, `torch.backends.cudnn.deterministic = True`). Replace raw `atomicAdd` with deterministic reductions (segmented scan, sort-then-reduce). Disable nondeterministic ops outright when a deterministic substitute exists.

### Thread-pool ordering
- Failure mode: tasks submitted to a pool complete in a different order each run; results merged in completion order are non-deterministic.
- Mitigation: keep submission order as a key on each task and reduce by that key (`executor.map` returns in submission order, or store `(index, result)` and sort by `index` before reducing). Pin pool size when it affects partitioning of the work.

### Async race conditions
- Failure mode: `asyncio.gather` cancellation paths, `Promise.race`, and event-loop interleavings make completion order vary; cooperative scheduling can also alter the order in which awaited side effects appear.
- Mitigation: avoid result-order-dependent logic. Use `asyncio.gather(..., return_exceptions=True)` and reduce results in submission-index order. Forbid `Promise.race` inside the deterministic boundary unless the winner is provably unique.

### Retry jitter
- Failure mode: backoff jitter (random sleep on retry) embeds randomness into timing-dependent outputs and produces test flakes.
- Mitigation: route jitter through the injected RNG (so it is seeded), or disable jitter inside the deterministic boundary. Keep retries on real I/O outside the boundary so retry timing never reaches output.

### ID generation (UUIDs, autoincrement collisions)
- Failure mode: `uuid4()` is random, `uuid1()` embeds host MAC and time, autoincrement IDs depend on insertion order across parallel writers.
- Mitigation: use content-hash IDs (`sha256(canonical_bytes)`) or seeded UUIDv5 with a fixed namespace (`uuid.uuid5(NS, canonical_key)`). For autoincrement, sort inputs into a canonical order before assigning IDs, or replace with content hashes.

### Memory layout differences
- Failure mode: ASLR, allocator quirks, and pointer values that leak into output (debug strings, hash of object identity, `repr` with addresses) differ per process.
- Mitigation: never serialize pointer-derived values (`id(obj)`, `<object at 0x...>`, `Object.hashCode` defaults). When comparing layouts is unavoidable, disable ASLR at the boundary (`setarch -R`); otherwise treat layout as an internal detail and hash content, not addresses.

### Garbage collector finalizers
- Failure mode: `__del__`, `finalize`, and finalizer queues run at GC-dependent times; their side effects (file flushes, log lines, freed handles) reach output in non-deterministic order.
- Mitigation: do not rely on finalizers for correctness. Use explicit `with` / RAII / `try-finally` to release resources at deterministic points. Disable cyclic GC at the boundary (`gc.disable()` in tests) when its tracing alters timing-observable behavior.

### Weak references
- Failure mode: `weakref` callbacks fire when the referent is collected, which is GC-timing-dependent; observers can see different states each run.
- Mitigation: avoid weak references inside the deterministic boundary. Where caching is required, use a strong reference with an explicit eviction policy (LRU with bounded size) so eviction is a function of inputs, not of GC timing.

## Design Principles

- **Same input → same output, every run.** This is the single invariant the skill enforces; every other rule is in service of it.
- **Pure functions over stateful operations.** A function whose output depends only on its arguments is trivially deterministic; mutation, ambient state, and effects are where non-determinism enters.
- **Explicit dependency injection over ambient state.** Clocks, RNGs, env, filesystem, and network are passed in as parameters or interfaces, never read from globals.
- **Reproducible builds.** Compilers, flags, package versions, and the build environment are pinned (lockfiles, container digests, `SOURCE_DATE_EPOCH`); the same source tree produces byte-identical artifacts.
- **Testable in isolation.** Each unit can be exercised without the network, the wall clock, or the host filesystem layout.
- **Output bit-identical across machines and runs.** The contract is `sha256(out_a) == sha256(out_b)` for any two runs on any two machines, not "close enough".

## Deliverable When Invoked

When this skill is applied against a target, produce one of the following — pick (a) when the target is small and the user has authorized the refactor; pick (b) when the target is large, exploratory, or the user wants to scope the work first.

### (a) Deterministic refactor

A patch (or set of patches) that eliminates every identified source of non-determinism in the target. Each change cites the source it addresses (e.g., "pin seed: addresses random-seeds entry"). The refactor MUST NOT introduce new non-determinism; verify with the checks in the Verification section below.

### (b) Checklist of fixes

A table that names every non-determinism source identified in the target, the location in the target code, the proposed mitigation, and the current status. The columns are pinned exactly as below — Source, Location, Mitigation, Status:

| Source | Location | Mitigation | Status |
|---|---|---|---|
| Random seed not pinned | `train.py:42` | Pin via `torch.manual_seed(0)`; set `PYTHONHASHSEED=0` in run script | applied |
| `time.time()` in cache key | `cache.py:18` | Inject `Clock` interface; pass scripted clock in tests | proposed |
| `os.listdir` order leaks into manifest | `manifest.py:73` | Wrap with `sorted(os.listdir(path))` | applied |
| `set` iteration in serializer | `serialize.py:104` | Replace with `sorted(s)` before iterating | proposed |
| ... | ... | ... | ... |

Status values: `proposed` (identified, not yet applied), `applied` (fix landed), `verified` (fix landed and determinism check passes), `n/a` (does not apply to this target, with a one-line rationale recorded in the row).

## Example: Before / After

A small Python module that builds a manifest of files in a directory.

### Before (non-deterministic)

```python
import os
import time
import random
import json

def build_manifest(path):
    entries = []
    for name in os.listdir(path):                    # filesystem readdir order
        with open(os.path.join(path, name), "rb") as f:
            entries.append({
                "name": name,
                "size": os.path.getsize(os.path.join(path, name)),
                "tag": random.randint(0, 1 << 32),   # unseeded RNG
            })
    return json.dumps({
        "built_at": time.time(),                     # wall-clock time
        "entries": entries,                          # readdir order preserved
        "env_user": os.environ.get("USER", ""),      # env leakage
    })                                               # default sort_keys=False -> dict iteration order
```

Run twice and you get two different manifests: `built_at` differs, `tag` differs, entry order differs across machines, `env_user` differs across hosts, and JSON key order is hash-randomized.

### After (deterministic)

```python
import os
import json
import hashlib
from typing import Protocol

class Clock(Protocol):
    def now(self) -> int: ...

def build_manifest(path: str, clock: Clock, user: str) -> str:
    names = sorted(os.listdir(path))                 # sorted readdir
    entries = []
    for name in names:
        full = os.path.join(path, name)
        with open(full, "rb") as f:
            content = f.read()
        entries.append({
            "name": name,
            "size": len(content),
            "tag": hashlib.sha256(content).hexdigest(),  # content-hash ID
        })
    return json.dumps(
        {
            "built_at": clock.now(),                 # injected clock
            "entries": entries,                      # already sorted
            "user": user,                            # injected, not read from env
        },
        sort_keys=True,                              # canonical key order
        separators=(",", ":"),                       # canonical separators
    )
```

Five changes, each addressing a specific source:

1. `sorted(os.listdir(path))` — fixes filesystem `readdir` order.
2. `clock.now()` via an injected `Clock` — fixes wall-clock time.
3. `hashlib.sha256(content).hexdigest()` — fixes ID generation (content-hash replaces unseeded RNG).
4. `user: str` parameter — fixes environment variable leakage.
5. `sort_keys=True` — fixes hash and dict iteration order in the JSON output.

With identical `path` contents, `clock`, and `user`, two runs produce byte-identical output.

## Verification

After producing either deliverable, run every check below and record the result. A target is not "deterministic" until all of these pass.

### 1. Run twice on the same machine; byte-compare outputs

```bash
./run.sh > out.a
./run.sh > out.b
diff out.a out.b              # MUST be empty
sha256sum out.a out.b         # MUST match
```

### 2. Run on two different machines or environments; hash-compare outputs

```bash
# machine 1
./run.sh > out.m1 && sha256sum out.m1
# machine 2
./run.sh > out.m2 && sha256sum out.m2
# the two hashes MUST be identical
```

If a container is the canonical environment, run the same image (pinned by digest) on both hosts.

### 3. Vary CPU count, locale, timezone, and environment; outputs MUST be unchanged

```bash
# vary CPU count
taskset -c 0   ./run.sh > out.cpu1
taskset -c 0-7 ./run.sh > out.cpu8
diff out.cpu1 out.cpu8        # MUST be empty

# vary locale
LC_ALL=C           ./run.sh > out.locC
LC_ALL=en_US.UTF-8 ./run.sh > out.locUS
diff out.locC out.locUS       # MUST be empty

# vary timezone
TZ=UTC                 ./run.sh > out.utc
TZ=America/Los_Angeles ./run.sh > out.la
diff out.utc out.la           # MUST be empty

# wipe environment to a minimal canonical set
env -i PATH=/usr/bin:/bin TZ=UTC LC_ALL=C.UTF-8 ./run.sh > out.minenv
diff out.utc out.minenv       # MUST be empty
```

### 4. (When applicable) GPU determinism

```bash
PYTHONHASHSEED=0 \
CUBLAS_WORKSPACE_CONFIG=:4096:8 \
./run.sh > out.gpu1

PYTHONHASHSEED=0 \
CUBLAS_WORKSPACE_CONFIG=:4096:8 \
./run.sh > out.gpu2

diff out.gpu1 out.gpu2        # MUST be empty
```

If any check fails, return to the enumeration: an unmitigated source remains. Identify it, pair it with a mitigation from the table above, and re-run every check.
