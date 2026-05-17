---
name: deterministic-design
description: "Enumerate and eliminate every source of non-determinism so that the same input produces bit-identical output on every run, every machine, and every process. Use when the user asks for deterministic design, removing non-determinism, or reproducible behavior across runs, machines, or processes."
license: MIT
---

# Deterministic Design

Same input → same output, every run, every machine, every process.

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly asks for:

- Deterministic design or behavior
- Removing or eliminating non-determinism
- Reproducibility across runs, machines, environments, or processes

Do not apply this skill to unrelated work or as a background concern unless explicitly requested.

## Design Principles

- **Same input → same output, every run.** Any deviation is a bug, not an acceptable variance.
- **Pure functions over stateful operations.** Prefer computations that depend only on their explicit arguments and produce no side effects.
- **Explicit dependency injection over ambient state.** Pass clocks, random sources, environment values, and IDs as arguments; never read them from global or ambient state inside pure logic.
- **Reproducible builds.** Pin all dependency versions, compiler flags, and toolchain versions. Build outputs must be bit-identical given the same source.
- **Testable in isolation.** Each component must be exercisable without touching the network, filesystem, system clock, or any external process.
- **Output bit-identical across machines and runs.** Byte-level equality is the acceptance bar, not statistical similarity.

## Sources of Non-Determinism

### Random Seeds

**Failure mode:** Uncontrolled PRNGs draw different values each run, making outputs unpredictable.

**Mitigation:** Pin seeds explicitly at every layer before any random draw. Examples: `random.seed(42)`, `numpy.random.seed(42)`, `torch.manual_seed(42)`, `PYTHONHASHSEED=0`. Record the seed in logs so any run can be replayed exactly.

---

### Wall-Clock Time

**Failure mode:** `time.time()`, `Date.now()`, `System.currentTimeMillis()`, and equivalents embed run-time noise into outputs (timestamps, filenames, signatures).

**Mitigation:** Inject a clock interface (e.g., a `Clock` object or `now()` callback) as an explicit argument. In tests, freeze the clock to a fixed value. Never read ambient wall time inside pure logic.

---

### Monotonic Clocks

**Failure mode:** `time.monotonic()`, `System.nanoTime()`, and equivalent calls measure elapsed time from an arbitrary epoch that differs across processes and machines, producing different duration and ordering values.

**Mitigation:** Use monotonic clocks only for measuring intervals within a single run; never emit their raw values as data. Inject the clock source in tests to make elapsed-time logic deterministic.

---

### Timezones

**Failure mode:** Date formatting, parsing, and arithmetic silently depend on the process timezone, producing different output on machines with different `TZ` settings.

**Mitigation:** Store and transmit all timestamps in UTC. Set `TZ=UTC` in build, test, and CI environments. Convert to local time only at display boundaries, never inside logic.

---

### Hash and Dict Iteration Order

**Failure mode:** Python dicts (pre-3.7 insertion order was not guaranteed), Java `HashMap`, Go maps, and most hash tables iterate in an implementation-defined order that can change across runs, Python versions, or hash randomization seeds (`PYTHONHASHSEED`).

**Mitigation:** Sort keys before iterating (`sorted(d.keys())`). Use ordered data structures (`collections.OrderedDict`, sorted maps) wherever insertion-order iteration is required. Fix `PYTHONHASHSEED=0` in reproducible contexts.

---

### Set Ordering

**Failure mode:** Sets (`set`, `frozenset`, `HashSet`) have no guaranteed iteration order. Serializing, logging, or accumulating from a set without sorting produces different orderings each run.

**Mitigation:** Convert sets to sorted lists before any order-sensitive operation (`sorted(my_set)`). Use `SortedSet` or equivalent ordered-set structures if ordering must be maintained structurally.

---

### Parallel Race Conditions

**Failure mode:** Multi-threaded or multi-process code writing to shared state without synchronization produces data races; the result depends on OS scheduling, which is non-deterministic.

**Mitigation:** Protect shared mutable state with locks, use message-passing instead of shared memory, or restructure computations to avoid shared writes. For reproducible parallel aggregation, use barrier synchronization and fixed work partitioning.

---

### Floating-Point Reduction Order

**Failure mode:** Floating-point addition is not associative; `(a + b) + c ≠ a + (b + c)` in general. Parallel or vectorized reductions (e.g., `np.sum`, GPU reductions) sum elements in implementation-defined order, giving different results depending on thread count or SIMD width.

**Mitigation:** Use pairwise or Kahan summation with a fixed reduction order. For ML training, use `torch.use_deterministic_algorithms(True)` and `CUBLAS_WORKSPACE_CONFIG=:4096:8`. Accept slightly lower performance as the cost of reproducibility.

---

### Network Jitter

**Failure mode:** Real network calls introduce variable latency and can fail intermittently, making any logic that depends on response timing or ordering non-deterministic.

**Mitigation:** Mock or stub all network calls in deterministic contexts. Record and replay responses using a fixture or VCR-style cassette. Never let network timing influence branching or ordering in pure logic.

---

### Filesystem `readdir` Order

**Failure mode:** Directory listing order (`os.listdir`, `readdir`, `glob`) is filesystem-defined and not lexicographic on most systems (ext4, APFS, etc.). Processing files in listing order produces different outputs depending on the filesystem and OS.

**Mitigation:** Always sort directory entries immediately after listing (`sorted(os.listdir(path))`). Treat unsorted listings as undefined.

---

### Environment Variable Leakage

**Failure mode:** Logic that reads `os.environ`, `System.getenv`, or equivalent inherits the process environment, which differs between developer machines, CI, and production.

**Mitigation:** Canonicalize the environment at process startup: require all configuration to be explicitly passed in or set to known defaults. In tests, reset `os.environ` to a minimal known set before each run. Never branch on ambient environment variables inside pure logic.

---

### Locale-Dependent String Operations

**Failure mode:** String comparison, case conversion (`str.lower()`), number formatting, and sorting depend on the process locale. The same code produces different output on systems where `LC_ALL` or `LANG` is set differently.

**Mitigation:** Set `LC_ALL=C` or `LC_ALL=POSIX` in build, test, and CI scripts. In application code, use locale-independent APIs (e.g., `str.casefold()` is not locale-safe; use `locale`-free byte-level comparison or ICU with a pinned locale).

---

### Undefined Behavior in Compilers

**Failure mode:** C, C++, and Rust unsafe code that triggers undefined behavior (out-of-bounds access, uninitialized reads, integer overflow) may produce different machine code and different outputs across compilers, optimization levels, and architectures.

**Mitigation:** Enable sanitizers (`-fsanitize=address,undefined`) in CI. Use a deterministic compiler with pinned version and flags (e.g., via Nix or a reproducible build system). Avoid relying on compiler-specific behavior; stick to the language standard.

---

### GPU Non-Determinism (Atomic Adds, cuDNN)

**Failure mode:** GPU kernels using atomic operations (`atomicAdd`) accumulate values in a thread-scheduling-dependent order. cuDNN selects algorithms at runtime that may differ across runs and GPU models. Both produce floating-point results that vary by run.

**Mitigation:** Set `torch.use_deterministic_algorithms(True)`, `torch.backends.cudnn.deterministic = True`, `torch.backends.cudnn.benchmark = False`, and `CUBLAS_WORKSPACE_CONFIG=:4096:8`. Accept the associated performance cost. For custom CUDA kernels, replace atomics with a deterministic reduction (e.g., sort-then-scan).

---

### Thread-Pool Ordering

**Failure mode:** Work submitted to a thread pool is executed in an order determined by OS scheduling. If results are collected as they complete (e.g., `concurrent.futures.as_completed`), the output order is non-deterministic.

**Mitigation:** Submit tasks in a fixed order and collect results in submission order (`executor.map` preserves order). Use barriers or explicit synchronization points to ensure phases complete before the next begins.

---

### Async Race Conditions

**Failure mode:** Concurrent coroutines that read/write shared state without explicit awaiting or locking produce interleaving-dependent outputs. In Python `asyncio`, JavaScript `Promise` chains, or Go goroutines, the scheduler's choices determine which coroutine advances first.

**Mitigation:** Use async locks (`asyncio.Lock`, `sync.Mutex`) around shared state. Prefer sequential composition of async steps when order matters. Test with a deterministic event loop or mock scheduler to expose ordering assumptions.

---

### Retry Jitter

**Failure mode:** Exponential backoff with jitter (`sleep(base * random())`) makes retry timing non-deterministic, which can affect which attempt succeeds first or which result is used.

**Mitigation:** In production, jitter is intentional for load spreading. For reproducible contexts (tests, simulations), inject a seeded PRNG or a fixed sleep schedule. Never use real-time jitter in paths whose output must be deterministic.

---

### ID Generation (UUIDs, Autoincrement Collisions)

**Failure mode:** `uuid.uuid4()`, database autoincrement IDs, and `os.urandom`-seeded tokens generate different values each run. Any output embedding these IDs will not be bit-identical across runs.

**Mitigation:** Use content-addressed IDs (hash of the content) where possible. For sequence IDs in tests, inject a counter starting from a fixed value. For UUIDs, use `uuid.UUID(int=counter)` or a seeded UUID-v4 via a pinned PRNG in reproducible contexts.

---

### Memory Layout Differences

**Failure mode:** Address-space layout randomization (ASLR), struct padding, pointer sizes, and alignment differ across compilers, architectures, and OS versions. Code that serializes raw memory (`memcpy` to disk, pickle of Python objects with pointer-dependent hash) produces different bytes on different machines.

**Mitigation:** Use portable, schema-defined serialization formats (Protocol Buffers, Arrow, JSON with sorted keys, MessagePack). Never serialize raw pointers or platform-dependent struct layouts.

---

### Garbage Collector Finalizers

**Failure mode:** GC-managed languages (Python, Java, Go, JVM) run finalizers/destructors in an order determined by the collector's algorithm and scheduling. If a finalizer has side effects (logging, file writes, network calls), those effects occur non-deterministically.

**Mitigation:** Remove side effects from finalizers entirely. Use explicit resource management (`with` / `try-finally` / RAII) rather than relying on GC-driven cleanup. In tests, force GC with `gc.collect()` and a fixed seed, but prefer explicit teardown.

---

### Weak References

**Failure mode:** Weak references (`weakref.ref` in Python, `WeakReference` in Java) are invalidated when the GC collects the referent. Collection timing is non-deterministic, so code branching on `ref() is None` may take different paths each run.

**Mitigation:** Avoid using weak references in paths whose output must be deterministic. Replace with explicit lifetime management (strong references with explicit release, reference counting, or arena allocation). In tests, explicitly `del` objects and call `gc.collect()` before asserting weak-reference liveness.

---

## Deliverable When Invoked

When this skill is applied to a target, produce exactly one of:

### (a) Deterministic Refactor

A direct rewrite of the target code that eliminates every identified source of non-determinism, following the mitigations in the Sources section above. Each change must be self-contained and annotated with which non-determinism source it addresses.

### (b) Checklist of Fixes

A structured checklist identifying every non-determinism source in the target and pairing it with a concrete mitigation. Use this format:

| Source | Location | Mitigation | Status |
|---|---|---|---|
| Random seed | `train.py:42` — `np.random.rand()` with no seed | Pin seed: add `np.random.seed(42)` before first draw; set `PYTHONHASHSEED=0` in env | ☐ open |
| Wall-clock time | `report.py:17` — `datetime.now()` embedded in filename | Inject clock argument; pass fixed datetime in tests | ☐ open |
| Dict iteration order | `pipeline.py:88` — iterating `config` dict | Wrap in `sorted(config.keys())` | ☐ open |

**Columns are required:**
- **Source** — which non-determinism category (from Sources section)
- **Location** — file and line number in the target code
- **Mitigation** — the concrete, named fix to apply
- **Status** — `☐ open`, `☑ applied`, or `⚠ deferred (reason)`

## Example: Before / After

### Non-Deterministic Training Run Setup

**Before (non-deterministic):**

```python
import random
import numpy as np
import torch
import os

def build_dataset(data_dir):
    files = os.listdir(data_dir)          # readdir order: non-deterministic
    return [load(f) for f in files]

def train():
    ds = build_dataset("data/")
    model = MyModel()
    optimizer = torch.optim.Adam(model.parameters())
    for batch in ds:
        loss = model(batch)
        loss.backward()
        optimizer.step()
    return model
```

**After (deterministic):**

```python
import random
import numpy as np
import torch
import os

SEED = 42

def seed_everything(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.use_deterministic_algorithms(True)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
    os.environ["PYTHONHASHSEED"] = str(seed)
    os.environ["CUBLAS_WORKSPACE_CONFIG"] = ":4096:8"

def build_dataset(data_dir: str) -> list:
    files = sorted(os.listdir(data_dir))  # fixed lexicographic order
    return [load(f) for f in files]

def train(seed: int = SEED) -> "MyModel":
    seed_everything(seed)                  # all sources pinned before first use
    ds = build_dataset("data/")
    model = MyModel()
    optimizer = torch.optim.Adam(model.parameters())
    for batch in ds:
        loss = model(batch)
        loss.backward()
        optimizer.step()
    return model
```

**Non-determinism sources eliminated:**
- `os.listdir` → `sorted(os.listdir(...))` (filesystem readdir order)
- Unseeded PRNG → `seed_everything(42)` (random seeds)
- cuDNN algorithm selection → `cudnn.deterministic=True`, `benchmark=False` (GPU non-determinism)
- CUDA atomic operations → `use_deterministic_algorithms(True)` + workspace config (GPU non-determinism)
- Hash randomization → `PYTHONHASHSEED=0` (hash/dict iteration order)

## Verification

Run these checks after applying the deterministic refactor or checklist:

1. **Run twice, byte-compare outputs:**
   ```bash
   ./run.sh > out1.bin
   ./run.sh > out2.bin
   diff out1.bin out2.bin && echo "PASS: outputs identical"
   ```

2. **Hash-compare outputs across two machines or environments:**
   ```bash
   # On machine A
   sha256sum out.bin > out.sha256
   # On machine B — must match
   sha256sum out.bin | diff - out.sha256 && echo "PASS: cross-machine identical"
   ```

3. **Vary CPU count; outputs must be unchanged:**
   ```bash
   OMP_NUM_THREADS=1 ./run.sh | sha256sum
   OMP_NUM_THREADS=8 ./run.sh | sha256sum
   # Both hashes must match
   ```

4. **Vary locale; outputs must be unchanged:**
   ```bash
   LC_ALL=C      ./run.sh | sha256sum
   LC_ALL=en_US.UTF-8 ./run.sh | sha256sum
   # Both hashes must match
   ```

5. **Vary environment variables; outputs must be unchanged:**
   ```bash
   env -i PATH="$PATH" ./run.sh | sha256sum
   ./run.sh | sha256sum
   # Both hashes must match
   ```

6. **Replay from seed; outputs must be identical to original:**
   ```bash
   SEED=42 ./run.sh | sha256sum
   # Must equal the reference hash recorded at first run
   ```

If any check fails, return to the Sources section to identify the remaining non-determinism source and apply its mitigation before re-running verification.
