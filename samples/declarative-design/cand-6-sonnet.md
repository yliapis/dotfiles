---
name: declarative-design
description: "Guide a runtime user from a domain description to a validated YAML DSL schema with a worked example. Use when the user explicitly asks for declarative design, DSL design, or YAML schema design help."
license: MIT
---

# Declarative Design

This skill walks you from a blank domain to a fully specified YAML DSL schema. You will identify the entities in your domain, assign attributes and types, enumerate validation rules, and produce a concrete schema document plus at least one conforming instance. The schema — not runtime logic — becomes the source of truth; every downstream consumer reads from it, and no behavior is hidden in execution order or implicit state.

## Declarative Principles

- **What, not how** — describe what the system should look like, not the steps to get there; let consumers figure out execution.
- **Data over behavior** — the schema is the deliverable; runtime is a reader of data, not the designer's concern.
- **Schema as source of truth** — every consumer reads the same schema document; there is no second authoritative source.
- **Idempotent definitions** — defining an entity twice with the same data must produce the same result; definitions are values, not mutations.
- **No hidden state** — every meaningful fact appears explicitly in the YAML; nothing is implied by the order in which keys are processed.
- **Configuration as data** — configuration is a structured value that can be read, versioned, and diffed; it is not a sequence of calls.
- **Composition over imperative wiring** — assemble complex constructs by combining simpler named values, not by describing the sequence of steps that produces them.

## Design Walkthrough

Work through each concern in order. Each step takes the output of the previous one as its input.

1. **Entities** — What are the top-level nouns in your domain? List them before writing any YAML. Each entity becomes either a top-level key or a named entry in a map.

2. **Attributes** — For each entity, what properties does a user observe or configure? Produce a flat attribute list per entity before assigning types.

3. **Types** — What is the value space of each attribute? Choose from: scalar (`string`, `integer`, `boolean`, `number`), structured (mapping or sequence), or enum (closed set of string values). Assign types before writing validation rules.

4. **Validation rules** — What makes an instance well-formed? Capture per-field constraints (required, length, range, regex pattern) and cross-field constraints (if field A is present, field B is required) separately.

5. **Naming conventions** — Pick one casing (`snake_case`, `camelCase`, `kebab-case`) and apply it uniformly. Decide singular vs plural per construct (e.g., `pipeline` for a single entity, `steps` for a list).

6. **Hierarchical structure** — What nests inside what? Prefer shallow nesting and flat keys. Introduce nesting only when an attribute belongs exclusively to one parent and cannot stand alone.

7. **Defaults** — For each optional field, state the value that omission implies. Document defaults in the schema, not in consumer code.

8. **Required vs optional** — Mark every field as required or optional. Optional must mean "omission implies the declared default", never "undefined behavior".

9. **Enums** — When a field has a small, closed set of valid values, list them explicitly. Prefer enums over free-form strings wherever the domain is closed.

10. **References** — When one entity refers to another by identity, declare the reference key explicitly (e.g., `pipeline_id: string # must match a declared pipeline name`). Document how cycles are forbidden or resolved.

11. **Extensibility** — Name the forward-compatible escape hatch. Common patterns: an `extensions` mapping for unvalidated vendor keys, additive-only enum values, or a `schema_version` field for breaking changes.

## Worked Example

The domain below is a **feature-flag registry**: a system where teams declare feature flags, assign them to user segments, and configure rollout percentages. The schema encodes what flags exist and how they behave; it does not describe how the flag system evaluates them at runtime.

```yaml
# Feature-flag registry schema
# schema_version: "1.0"

schema_version:
  type: string
  required: true
  description: Semantic version of this schema format.

flags:
  type: map
  required: true
  description: Map of flag name to flag definition.
  value_schema:
    description:
      type: string
      required: true
    enabled:
      type: boolean
      required: true
      default: false
    rollout_pct:
      type: integer
      required: false
      default: 0
      minimum: 0
      maximum: 100
    targeting:
      type: sequence
      required: false
      default: []
      item_schema:
        segment:
          type: string
          required: true
          description: Name of a declared segment.
        rollout_pct:
          type: integer
          required: true
          minimum: 0
          maximum: 100

segments:
  type: map
  required: false
  default: {}
  description: Named user segments referenced by flag targeting rules.
  value_schema:
    criteria:
      type: string
      required: true
      description: Human-readable description of who belongs to this segment.
    extensions:
      type: map
      required: false
      default: {}
      description: Unvalidated vendor-specific keys for forward compatibility.
```

```yaml
# Conforming instance — feature-flag registry
schema_version: "1.0"

flags:
  new_checkout:
    description: "Redesigned checkout flow with address autocomplete."
    enabled: true
    rollout_pct: 20
    targeting:
      - segment: beta_users
        rollout_pct: 100

  dark_mode:
    description: "Dark colour theme across the entire UI."
    enabled: false

segments:
  beta_users:
    criteria: "Users who opted into the early-access programme."
  internal:
    criteria: "Employees with an @example.com email address."
    extensions:
      ldap_group: "eng-internal"
```

## Validation Rules

A conforming document MUST satisfy all of the following rules:

- **Required fields are present.** Every field marked `required: true` in the schema must appear in the instance at the appropriate scope; omitting one is an error.
- **Enum values are within the declared set.** Any field typed as an enum must carry one of the explicitly listed values; no other string is valid.
- **Reference fields resolve.** Any field that names another declared entity (e.g., a `segment` name inside `targeting`) must match a key that exists in the corresponding top-level map.
- **No duplicate keys at the same scope.** A YAML mapping must not repeat a key at the same nesting level.
- **Integer ranges hold.** Fields with `minimum` or `maximum` constraints must satisfy those bounds on every instance value.
- **String pattern constraints hold.** Fields with a `pattern` or `format` constraint must match on every value.
- **Optional fields default cleanly.** When an optional field is absent, the declared default is the effective value; consumers must not treat absence as an error or as a distinct signal.
- **Sequence items conform to item_schema.** Every element of a typed sequence must satisfy all constraints declared for the item type.
- **`schema_version` is present and parseable.** The top-level `schema_version` key must be present and must be a valid semantic-version string; consumers may reject instances whose major version they do not understand.

## Deliverable

When this skill finishes, you leave with:

- **A YAML DSL schema** for your domain, covering every entity, attribute, type, constraint, default, and extensibility escape hatch identified in the walkthrough.
- **At least one conforming instance** that exercises the required fields, at least one optional field, at least one enum value, and at least one reference, to confirm the schema is usable.
- **A written validation-rules list** that maps each constraint back to a schema decision, making it possible to validate instances mechanically without re-reading the walkthrough.

The schema is the source of truth. Downstream consumers — validators, code generators, documentation tools — are readers of the schema, not co-authors of it.

## When Not To Use

- **The task is inherently procedural.** If the design question is "what should the system do step by step?" and the steps cannot be collapsed into a static data structure, a YAML schema will misrepresent the design.
- **The domain has no stable entities yet.** If you cannot name at least three entities confidently, the domain is too fluid; designing a schema now produces a schema you will discard.
- **Stateful orchestration is the core concern.** If the primary artifact is a state machine, a workflow engine configuration, or anything whose correctness depends on execution order, imperative or graph-based design tools are a better fit than a declarative YAML DSL.
- **A general-purpose programming language fits better.** If the constraints are complex enough that encoding them in YAML requires reinventing a type system or an expression language, the schema has outgrown the data language; use code instead.
