---
name: deterministic-design
description: "Enumerate and eliminate every source of non-determinism so that the same input produces bit-identical output on every run, every machine, and every process. Use when the user asks for deterministic design, reproducible behavior, or removing non-determinism from code or systems."
license: MIT
---

# Deterministic Design

Same input → same output, every run, every machine, every process.

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly asks for:

- Deterministic design or deterministic behavior
- Reproducibility across runs, machines, or processes
- Removing or eliminating non-determinism from a codebase or system

Do not apply this skill automatically to unrelated tasks.

## Design Principles

- **Same input → same output, every run.** No ambient state may influence the output path.
- **Pure functions over stateful operations.** Logic that reads only its arguments is testable and reproducible by construction.
- **Explicit dependency injection over ambient state.** Clocks, random sources, environment, and I/O must be passed in, not read from globals.
- **Reproducible builds.** Pin all dependencies (package versions, compiler flags, base images) so that a build from the same source always produces the same artifact.
- **Testable in isolation.** Every component that could be non-deterministic must be replaceable with a deterministic stub in tests.
- **Output bit-identical across machines and runs.** No platform-dependent padding, pointer-derived values, or locale-sensitive formatting may leak into outputs.

## Sources of Non-Determinism

### Random Seeds

**Failure mode:** Uncontrolled PRNGs (e.g., `random`, `numpy.random`, `torch`) draw different values on each run.

**Mitigation:** Pin every PRNG seed explicitly at every layer before any sampling occurs. Set the language-level hash seed environment variable (e.g., `PYTHONHASHSEED=0`). Pass seed values as explicit parameters rather than reading global state.

```python
# Example seed pinning (deterministic)
import random, numpy as np, torch
random.seed(42)
np.random.seed(42)
torch.manual_seed(42)
torch.cuda.manual_seed_all(42)
```

### Wall-Clock Time

**Failure mode:** Calls to `time.time()`, `Date.now()`, `System.currentTimeMillis()`, or similar embed the run-time instant into outputs, making identical inputs produce different results across runs.

**Mitigation:** Inject a clock interface whose implementation can be frozen or advanced deterministically. In production code, pass the clock; in tests, pass a fixed-value stub. Never read ambient time inside pure logic.

### Monotonic Clocks

**Failure mode:** Monotonic timers (`time.monotonic()`, `std::chrono::steady_clock`) record elapsed time since an arbitrary epoch. They differ across processes and machines even with identical inputs.

**Mitigation:** Treat monotonic timestamps the same as wall-clock time: inject a clock abstraction. For benchmarking or profiling, accept non-determinism explicitly and isolate it from result-bearing code paths.

### Timezones

**Failure mode:** Date formatting, parsing, and arithmetic depend on the local timezone (e.g., `datetime.now()` without `tz=`), producing different strings or offsets on machines in different zones.

**Mitigation:** Use UTC throughout. Store and compare instants as UTC-aware objects. Format timestamps with an explicit timezone designator. Set `TZ=UTC` in CI and container environments.

### Hash and Dict Iteration Order

**Failure mode:** In many runtimes (Python ≥ 3.3 with hash randomization, Java `HashMap`, Go maps), iterating over a hash map or set yields a different order on each run because bucket assignment is randomized at startup.

**Mitigation:** Sort keys before iterating (`sorted(d.items())`). Use ordered map types (`collections.OrderedDict`, Java `LinkedHashMap`) when insertion order matters. Set `PYTHONHASHSEED=0` to disable Python hash randomization, or design code that does not rely on iteration order at all.

### Set Ordering

**Failure mode:** Sets are unordered by definition; iterating or serializing them produces arbitrary orderings that differ across runs and implementations.

**Mitigation:** Convert to a sorted list before iterating, serializing, or hashing: `sorted(my_set)`. When order must be stable across types, define a canonical key function. Prefer deterministic data structures (sorted sets, tries) when ordering is load-bearing.

### Parallel Race Conditions

**Failure mode:** When threads or processes race to write shared state, the final value depends on scheduling, and outputs differ across runs.

**Mitigation:** Synchronize with locks, barriers, or message-passing. For aggregations, prefer commutative and associative reduction operators. Use deterministic work-stealing schedulers where available. When parallelism is for throughput only, accumulate results into per-worker buffers and merge in a fixed order after all workers finish.

### Floating-Point Reduction Order

**Failure mode:** IEEE 754 floating-point addition is not associative. Parallel or vectorized reductions (e.g., `sum`, `dot`, `reduce`) produce different results depending on operand ordering, which changes with thread count or SIMD lane width.

**Mitigation:** Use pairwise or Kahan summation for scalar code. For distributed or GPU reductions, fix the reduction tree topology or use fixed-point accumulators where exact results are required. Document any remaining floating-point non-determinism explicitly.

### Network Jitter

**Failure mode:** Latency, packet loss, and retry timing vary across runs, causing timeouts to fire at different points or responses to arrive in different orders.

**Mitigation:** Mock all network I/O in deterministic tests. Use deterministic replay (recorded request/response pairs). In integration tests, use controlled in-process stubs. For outputs that depend on response ordering, sort responses by a stable key (e.g., request ID) before processing.

### Filesystem `readdir` Order

**Failure mode:** Directory listing functions (`os.listdir`, `readdir`, `glob`) return entries in filesystem-defined order, which differs between ext4, APFS, HFS+, and NFS mounts, and may vary between runs on the same filesystem.

**Mitigation:** Always sort directory listings before processing: `sorted(os.listdir(path))`. Use deterministic glob libraries that document their ordering guarantees, or sort the results. In build systems, sort input file lists before passing them to compilers or bundlers.

### Environment Variable Leakage

**Failure mode:** Logic that reads `os.environ`, `process.env`, or shell variables inherits the caller's environment, which differs between developer machines, CI systems, and container runtimes.

**Mitigation:** Canonicalize the environment at process startup: explicitly allow-list the variables the program needs and fail fast on unexpected ones. In tests, set the full environment explicitly rather than inheriting the shell's. Use `env -i` or container isolation to strip ambient variables in CI.

### Locale-Dependent String Operations

**Failure mode:** String collation (`sort`, `strcmp`), case folding (`lower()`, `upper()`), and number formatting (`printf "%f"`) produce different results depending on `LC_ALL`, `LC_COLLATE`, and `LANG` settings.

**Mitigation:** Set `LC_ALL=C` (or `POSIX`) for programs that process bytes or ASCII. Use explicit locale-aware APIs when Unicode behavior is intentional and pin the locale in tests. Avoid relying on the default locale for any result that is persisted or compared across environments.

### Undefined Behavior in Compilers

**Failure mode:** C, C++, and Rust (unsafe) programs with undefined behavior (uninitialized reads, signed overflow, data races) produce outputs that differ between compilers, optimization levels, and target architectures.

**Mitigation:** Enable sanitizers (`-fsanitize=address,undefined,thread`) in CI. Use `-ftrivial-auto-var-init=zero` to zero-initialize stack variables. Prefer safe languages or safe subsets. Treat UB as a build-breaking error, not a warning.

### GPU Non-Determinism (Atomic Adds, cuDNN)

**Failure mode:** GPU atomic operations accumulate floating-point values in non-deterministic order. cuDNN selects convolution algorithms based on heuristics that vary between runs and driver versions, producing different floating-point results.

**Mitigation:** Set `torch.use_deterministic_algorithms(True)` and `CUBLAS_WORKSPACE_CONFIG=:4096:8`. Disable cuDNN benchmarking (`torch.backends.cudnn.benchmark = False`) and enable deterministic mode (`torch.backends.cudnn.deterministic = True`). Accept the performance cost or document the non-determinism if disabling it is infeasible.

### Thread-Pool Ordering

**Failure mode:** Tasks submitted to a thread pool complete in an order determined by OS scheduling. If results are consumed as they arrive, their ordering is non-deterministic.

**Mitigation:** Collect all results into an indexed structure keyed by task ID, then process results in index order after all tasks complete. Use `concurrent.futures.as_completed` only when ordering does not matter; use `futures[i].result()` in order when it does.

### Async Race Conditions

**Failure mode:** In async runtimes (asyncio, Node.js, Tokio), the order in which coroutines resume after `await` depends on the event loop's ready queue, which is affected by I/O timing and task creation order.

**Mitigation:** Avoid `gather` when result order is load-bearing; use `asyncio.gather(*tasks, return_exceptions=True)` and index into the returned list. Sequence dependent operations explicitly with `await`. Mock I/O so that tests run in a controlled, synchronous manner.

### Retry Jitter

**Failure mode:** Exponential backoff with random jitter inserts variable delays, causing requests to arrive in different orders across retries and producing different server-side processing sequences.

**Mitigation:** Remove jitter for deterministic tests by mocking the sleep/delay function and controlling the retry schedule. In production, accept ordering non-determinism for retries explicitly and design downstream logic to be order-independent (e.g., idempotent writes, commutative updates).

### ID Generation (UUIDs, Autoincrement Collisions)

**Failure mode:** `uuid4()` produces a random UUID each run. Database autoincrement IDs depend on insertion order, which can vary. Content-unrelated IDs leak non-determinism into serialized outputs and logs.

**Mitigation:** Use content-hash IDs (e.g., SHA-256 of the canonical serialization of the record) where the ID must be stable. In tests, inject a deterministic ID generator (counter, hash). For distributed systems, use UUIDv5 (name-based) or ULID with a pinned timestamp.

### Memory Layout Differences

**Failure mode:** Pointer values, struct padding, and alignment differ between 32-bit and 64-bit targets, compilers, and optimization levels. Serializing raw memory (`memcpy` to file, pickle of Python objects with `__reduce__`) produces different bytes across platforms.

**Mitigation:** Serialize with an explicit schema (Protocol Buffers, FlatBuffers, JSON with sorted keys, CBOR) rather than raw memory dumps. Define struct layouts with explicit packing directives. Avoid `id(obj)` or pointer-derived values in any persistent or compared output.

### Garbage Collector Finalizers

**Failure mode:** GC-managed languages (Java, Go, Python, .NET) may run finalizers (`__del__`, `finalize()`) in an order and at a time determined by the GC, causing side effects (file flushes, log writes, socket closes) to appear non-deterministically.

**Mitigation:** Do not rely on finalizers for observable side effects. Use explicit `close()` / context manager (`with` / `try-finally`) patterns to deterministically release resources. In tests, disable or stub the GC's finalization behavior if it affects test outcomes.

### Weak References

**Failure mode:** Weak references (`weakref`, `WeakReference`, `weak_ptr`) may become invalid at any point during a GC cycle. Code that observes whether a weak reference is live introduces a GC-timing dependency into its output.

**Mitigation:** Avoid branching on weak reference liveness in result-producing code. Use strong references when the object's lifetime must be bounded, and explicit lifetime management (RAII, reference counting with explicit release) when weak references would otherwise be needed.

## Deliverable When Invoked

When this skill is applied to a target codebase or system description, produce exactly one of:

**(a) A deterministic refactor** of the target code that eliminates every identified source of non-determinism, with a brief note for each source explaining the change made.

**(b) A checklist of fixes** when a full refactor is out of scope or the target is a design document rather than code:

| Source | Location in Target | Mitigation | Status |
|---|---|---|---|
| Random seed | `train.py:42` — `np.random.seed()` missing | Pin with `np.random.seed(0)` and `PYTHONHASHSEED=0` | pending |
| Wall-clock time | `pipeline.py:17` — `datetime.now()` | Inject frozen clock via `Clock` interface | pending |
| Dict iteration order | `report.py:55` — `for k in config:` | Replace with `for k in sorted(config):` | pending |
| ... | ... | ... | ... |

The checklist columns are fixed: **Source**, **Location in Target**, **Mitigation**, **Status**. Every row must name a concrete mitigation; vague advice ("be careful") is not acceptable.

## Example: Before / After

The following before/after pair demonstrates eliminating wall-clock time and dict iteration order non-determinism from a report-generation function.

**Before (non-deterministic):**

```python
import time

def generate_report(metrics: dict) -> str:
    lines = [f"Report generated at {time.time()}"]
    for key, value in metrics.items():   # dict iteration order not guaranteed
        lines.append(f"{key}: {value}")
    return "\n".join(lines)
```

**After (deterministic):**

```python
def generate_report(metrics: dict, clock) -> str:
    lines = [f"Report generated at {clock.now()}"]
    for key in sorted(metrics):          # stable, deterministic order
        lines.append(f"{key}: {metrics[key]}")
    return "\n".join(lines)
```

Changes made:
- `time.time()` replaced by an injected `clock.now()` call; tests pass a `FrozenClock(ts=0)`.
- `metrics.items()` replaced by `sorted(metrics)` to guarantee stable key order regardless of insertion history or `PYTHONHASHSEED`.

## Verification

After applying a deterministic refactor or implementing the checklist, verify determinism with the following concrete checks:

1. **Run twice; byte-compare outputs.**

   ```bash
   ./run.sh > out1.bin
   ./run.sh > out2.bin
   diff out1.bin out2.bin && echo "PASS: outputs identical"
   ```

2. **Hash-compare outputs across two machines or environments.**

   ```bash
   sha256sum out.bin  # run on machine A; compare to machine B result manually or via CI artifact comparison
   ```

3. **Vary CPU count; confirm outputs are unchanged.**

   ```bash
   OMP_NUM_THREADS=1 ./run.sh > out_1cpu.bin
   OMP_NUM_THREADS=8 ./run.sh > out_8cpu.bin
   diff out_1cpu.bin out_8cpu.bin && echo "PASS: CPU count does not affect output"
   ```

4. **Vary locale; confirm outputs are unchanged.**

   ```bash
   LC_ALL=C       ./run.sh > out_c.bin
   LC_ALL=en_US.UTF-8 ./run.sh > out_utf8.bin
   diff out_c.bin out_utf8.bin && echo "PASS: locale does not affect output"
   ```

5. **Strip environment; confirm outputs are unchanged.**

   ```bash
   env -i PATH="$PATH" ./run.sh > out_clean_env.bin
   diff out_clean_env.bin out.bin && echo "PASS: ambient environment does not affect output"
   ```

A refactor is only complete when all five checks pass.
