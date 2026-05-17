---
name: declarative-design
description: "Design a YAML DSL schema for a domain the user names — modeling entities, attributes, types, defaults, references, validation rules, and extensibility — then deliver the schema, a worked conforming instance, and an explicit validation-rules list. Use when the user explicitly asks for declarative design, DSL design, YAML schema design, or schema design help; do not self-attach to general edits or refactors."
license: MIT
---

# Declarative Design

Turn a domain the user names — feature flags, RBAC policies, CI pipelines, form layouts, alert rules — into a YAML DSL schema that is the source of truth, plus a worked instance and an explicit list of validation rules. The journey is: domain → entities → attributes → types → validation → schema → conforming instance. The deliverable is data, not code.

## Declarative Principles

Frame every design decision around these. Each is a "do this, not that" choice, not an abstract value.

- **What, not how** — describe the outcomes the system should produce, not the steps to produce them.
- **Data over behavior** — the schema and its instances are the artifact; runtimes are consumers of that data.
- **Schema as source of truth** — every consumer (UI, server, validator, docs) reads the same schema; no second definition is allowed to drift.
- **Idempotent definitions** — re-reading the same definition yields the same result; order of evaluation never changes meaning.
- **No hidden state** — every meaningful fact is visible in the data, not implicit in execution order or runtime side effects.
- **Configuration as data** — configuration is a value, not a sequence of mutations or method calls.
- **Composition over imperative wiring** — assemble behavior by composing values (references, enums, nested structures), not by sequencing imperative calls.

## Design Walkthrough

Work the domain in this order; each step depends only on the previous ones, and each step produces an artifact you carry into the next.

1. **Entities** — Question: what nouns live in the domain? Artifact: the entity list. Keep it small; if more than ~7 top-level entities appear, look for a hierarchy hiding inside.
2. **Attributes** — Question: for each entity, what does the user observe or set? Artifact: an attribute list per entity. An entity with no attributes is usually a tag or enum value in disguise.
3. **Types** — Question: what is the value space of each attribute? Artifact: a type assignment (`string`, `integer`, `boolean`, `enum<…>`, `list<…>`, structured object, or a reference). Prefer the narrowest type that still admits every legitimate value.
4. **Validation rules** — Question: what makes an instance well-formed? Artifact: a list of per-field and cross-field constraints, derived directly from the types and attribute semantics chosen above.
5. **Naming conventions** — Question: one casing, singular or plural per construct? Artifact: a written rule (e.g., `snake_case` keys, singular entity names, plural list keys, no abbreviations). Apply it uniformly.
6. **Hierarchical structure** — Question: what nests inside what? Artifact: a parent–child map. Prefer shallow nesting and flat keys when possible; nest only when the child cannot stand alone.
7. **Defaults** — Question: for each optional field, what value does omission imply? Artifact: a default for every optional field. Omission MUST be a well-defined value, never undefined behavior.
8. **Required vs optional** — Question: which fields must appear on every instance? Artifact: a per-attribute `required: true|false` marking. Optional fields rely on the defaults from the previous step.
9. **Enums** — Question: which fields have a small closed set of allowed values? Artifact: enum definitions, each with a complete value list. Closed enums first; open string fields only when the set is genuinely open.
10. **References** — Question: when one entity points at another, how is the pointer encoded? Artifact: a reference convention — which key is the target, how the reference is written, and how cycles are handled (usually: forbidden unless explicitly named).
11. **Extensibility** — Question: how does the schema change without breaking existing instances? Artifact: a forward-compatibility plan — a `schema_version` field, an `extensions:` block on each entity, additive-only enum changes, and a written deprecation policy.

## Worked Example

Domain: a small feature-flags DSL. The first YAML block is the schema; the second is one concrete configuration that conforms to it. The example illustrates entities (`flag`, `segment`), enum-typed strategies, defaults for optional fields, references from flags to segments, and an extensibility hatch.

```yaml
schema_version: "1.0"
entities:
  flag:
    attributes:
      key:
        type: string
        required: true
        pattern: "^[a-z][a-z0-9_]*$"
      description:
        type: string
        required: false
        default: ""
      enabled:
        type: boolean
        required: true
      strategy:
        type: enum
        values: [all, percentage, segment]
        required: false
        default: all
      percentage:
        type: integer
        required: false
        min: 0
        max: 100
      segments:
        type: list
        required: false
        default: []
        items:
          type: reference
          target: segment
          by: key
      extensions:
        type: object
        required: false
        default: {}
  segment:
    attributes:
      key:
        type: string
        required: true
        pattern: "^[a-z][a-z0-9_]*$"
      match:
        type: enum
        values: [any, all]
        required: true
      rules:
        type: list
        required: true
        items:
          type: object
          fields:
            attribute:
              type: string
              required: true
            operator:
              type: enum
              values: [eq, neq, in, not_in, gt, lt]
              required: true
            value:
              type: any
              required: true
```

```yaml
schema_version: "1.0"
flags:
  - key: new_checkout
    description: "Roll out the new checkout flow to a slice of users."
    enabled: true
    strategy: percentage
    percentage: 25
  - key: beta_dashboard
    enabled: true
    strategy: segment
    segments: [beta_users]
  - key: legacy_login
    enabled: false
segments:
  - key: beta_users
    match: any
    rules:
      - attribute: plan
        operator: in
        value: [pro, enterprise]
      - attribute: email
        operator: eq
        value: "founder@example.com"
```

## Validation Rules

A conforming document MUST satisfy every rule below; each rule traces back to a specific decision made in the walkthrough.

- **Required fields present.** Every attribute marked `required: true` (e.g., `flag.key`, `flag.enabled`, `segment.key`, `segment.match`, `segment.rules`) appears on every instance of its entity.
- **Types match.** Each attribute value lies in the declared type's value space (strings are strings, integers are integers, lists are lists, objects are objects).
- **Enum values are in range.** `flag.strategy ∈ {all, percentage, segment}`, `segment.match ∈ {any, all}`, and `rules[].operator ∈ {eq, neq, in, not_in, gt, lt}`. No other values are admitted.
- **Per-field constraints hold.** `flag.key` and `segment.key` match `^[a-z][a-z0-9_]*$`. `flag.percentage` is an integer in `0..100`.
- **Conditional requirements hold.** When `flag.strategy == percentage`, `flag.percentage` is present. When `flag.strategy == segment`, `flag.segments` is non-empty.
- **References resolve.** Every entry in `flag.segments` matches some declared `segment.key`. Unresolved references are an error, not a warning.
- **No duplicate keys at a scope.** `flag.key` values are unique within `flags`; `segment.key` values are unique within `segments`.
- **Defaults are applied, not assumed.** Omitted optional fields take the schema-declared default (`flag.description = ""`, `flag.strategy = all`, `flag.segments = []`, `flag.extensions = {}`); consumers see the default, never "missing".
- **No unknown fields outside the extensibility hatch.** Top-level keys outside `schema_version`, `flags`, and `segments` are rejected; per-flag unknown fields live under `extensions` only.

## Deliverable

When the skill finishes, the user leaves with three artifacts, all expressed as data:

1. **A YAML DSL schema** for their domain, capturing entities, attributes, types, defaults, required vs optional, enums, references, and the extensibility hatch.
2. **At least one worked instance** that conforms to the schema, sized to fit on one screen, exercising the interesting cases (defaults applied, enum values, references resolved).
3. **An explicit validation-rules list** — every constraint a conforming instance MUST satisfy, traceable back to a specific schema decision.

The schema is the source of truth. Any downstream code (validators, UIs, runtimes, docs) is a consumer of the schema, never a parallel definition of it.

## When Not To Use

- **Imperative or stateful problems.** If the natural answer is "do A, then B, then C, depending on what happened during B," declarative DSL design fights the domain. Write the program; don't twist it into data.
- **Procedural orchestration.** Step-by-step workflows with rich branching control flow are usually better expressed as code or as an explicit step graph, not as a flat YAML document.
- **Unstable domains.** If the entities, attributes, or relationships are still being discovered, designing a schema is premature; sketch concrete instances first and let the schema fall out later.
- **Single-consumer one-off configuration.** If exactly one program reads the data, owns its shape, and changes the shape alongside its own code, a typed data structure in that program's source is usually clearer than a separate DSL.
- **Domains a general-purpose language carries more honestly.** When expressive constraints (conditionals, computed defaults, derived values) start to dominate the schema, the cost of inventing a DSL exceeds its benefit. Use a programming language and a typed config object instead.
