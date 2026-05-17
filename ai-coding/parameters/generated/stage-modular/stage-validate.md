# Stage: `validate`

## Purpose
Type-check and domain-check every parameter destined for downstream stages — int ranges, file types, list/scalar shape compatibility, enum membership — and fail fast with an explanatory error before any worktree, branch, agent, or persistent side effect is created.

## Position
Runs after `input-resolve` (so shapes are concrete) and before any stage with side effects (`isolate`, `replicate`, `fan-out`, `execute`, `persist`). Pure: no filesystem writes, no network.

## Input Contract

### Required
- `validated_params` (map<string, value>) — the parameter dictionary to check, typically the merged inputs of the pipeline so far.
- `schema` (map<string, type_spec>) — per-parameter declaration. Each `type_spec` is one of the type primitives below.

### Optional
- `strict` (bool, default: `true`) — when `true`, unknown keys in `validated_params` are errors; when `false`, they are recorded as warnings.
- `cross_checks` (list<rule>, default: `[]`) — rules that span more than one parameter (e.g., "`len(agent_model) == parallelism` when `agent_model` is a list").

## Type Primitives (the type vocabulary referenced by every other stage)

- `string` — free text.
- `bool` — `true` | `false`.
- `int` — integer.
- `int_range:<spec>` (alias: `integer_interval`) — integer constrained by `>= N`, `<= N`, `[a,b]`, `(a,b)`, or `(0,∞)`.
- `duration` — strings like `30s`, `5m`, `2h`.
- `enum:<v1|v2|…>` — one of the listed values.
- `path` (subtypes: `file`, `directory`) — filesystem path. Combine with `file_type:.ext1,.ext2` (alias: `extension`) for extension restriction.
- `glob` — glob pattern.
- `url` — http(s) URL.
- `inline:<format>` — literal content with declared format.
- `model_id` — string matching a model registry entry.
- `command` — shell command string.
- `list<T>` — list of `T`.
- `list<T> | T` — either a single `T` or a list of `T` (a.k.a. "scalar broadcasts").
- `map<K,V>` — keyed mapping.
- `ref` — reference to another stage's output (`<stage-name>[<depth>].<param>`).

## Output Contract

- `validation_report` (list<{ param, status, expected, actual, message }>) — one entry per checked param.
- `errors` (list<string>) — fatal mismatches; non-empty `errors` MUST abort the pipeline.
- `warnings` (list<string>) — non-fatal (e.g., unknown keys in non-strict mode, redundant explicit defaults).
- `validated_params` (map<string, value>) — the same dictionary, with normalized values (e.g., scalar-to-list broadcast resolved, defaults filled).

## Depth-Aware Aliasing

- Each composition level runs its own `validate` instance against its own `schema`; instances are addressed as `validate[<depth>]`.
- Inner `validate` MAY narrow but MUST NOT widen the outer schema for inherited keys (e.g., outer `parallel: int_range: >=1` cannot be relaxed to `>=0` inside an inner stage).
- Cross-level rules live at the outermost `validate` that sees both sides (e.g., a rule that ties `fan-out[0].k` to `fan-out[1].k` lives at `validate[0]`).

## Composition Rules

- Strict precedence: `input-resolve` → `validate` → everything else.
- A `validate` stage MAY appear multiple times in a pipeline; subsequent runs check newly introduced params (e.g., after `select` produces a `selected_branch`, a second `validate` can check it is mergeable).
- Errors from `validate` short-circuit the pipeline; no cleanup is required because no side effects have happened yet.

## Examples

### Example 1: worktree-task-agent — validate fan-out shape before any worktree exists

```yaml
stage: validate
validated_params:
  parallelism: 8
  num_partitions: 4
  agent_model: ["opus", "sonnet", "haiku", "gpt-5"]
  base_branch: "main"
  test_command: "pnpm test"
schema:
  parallelism: int_range:>=1
  num_partitions: int_range:>=1
  agent_model: list<model_id> | model_id
  base_branch: string
  test_command: command
cross_checks:
  - "len(agent_model) in {1, parallelism, num_partitions}"
  - "parallelism % num_partitions == 0  # partition sizes must be uniform"
outputs:
  errors: []
  warnings: []
  validated_params:
    agent_model: ["opus", "sonnet", "haiku", "gpt-5"]   # 4 partitions × 2 agents each
```

### Example 2: critique — reject non-positive replication count

```yaml
stage: validate
validated_params:
  num_experiments: 0
  parallel: 1
schema:
  num_experiments: int_range:>=1
  parallel: int_range:>=1
outputs:
  errors: ["num_experiments=0 violates int_range:>=1"]
  validation_report:
    - { param: num_experiments, status: error, expected: ">=1", actual: 0, message: "must be a positive integer" }
```
