# Declarative Design

Turn a domain the user names — feature flags, RBAC policies, CI pipelines, form layouts, alert rules — into a YAML DSL schema that is the source of truth, plus a worked conforming instance and an explicit list of validation rules. The journey is: domain → entities → attributes → types → validation → schema → instance. Treat every step as discovering data already implicit in the domain, not as inventing behavior to bolt onto it; the deliverable is data, not code.

## Declarative Principles

Frame every design decision around these. Each is a "do this, not that" choice, not an abstract value.

- **What, not how** — describe the outcome the system must guarantee, not the steps an interpreter should run.
- **Data over behavior** — the schema and its instances are the artifacts; runtimes are downstream consumers that any conforming implementation could replace.
- **Schema as source of truth** — every consumer (validator, UI, server, runner, docs) reads the same schema; no second definition is allowed to drift.
- **Idempotent definitions** — re-reading the same definition yields the same model; order of evaluation never changes meaning.
- **No hidden state** — every meaningful fact is visible in the data, not implicit in execution order, prior runs, or ambient context.
- **Configuration as data** — configuration is a value the user can copy, diff, and version, not a sequence of imperative mutations.
- **Composition over imperative wiring** — build larger meanings by composing smaller values (references, enums, nested structures), not by sequencing function calls.

## Design Walkthrough

Work the steps in order; each one depends only on the steps above it, and each produces an artifact the next step consumes. If a concern does not apply to the user's domain, record that as a deliberate choice rather than silently skipping it.

1. **Entities** — Question: what nouns live in the domain? Artifact: an enumerated list of entity names with one-line definitions. Keep it small; if more than ~7 top-level entities appear, look for a hierarchy hiding inside.
2. **Attributes** — Question: for each entity, what does the user observe or set? Artifact: an attribute list per entity. An entity with no attributes is usually a tag or enum value in disguise.
3. **Types** — Question: what is the value space of each attribute? Artifact: a type assignment per attribute — scalar (`string`, `integer`, `number`, `boolean`, `date`), structured (`list`, `map`, `object`), enum, or reference. Prefer the narrowest type that still admits every legitimate value.
4. **Validation rules** — Question: what makes an instance well-formed? Artifact: a list of per-field constraints (range, length, regex) and cross-field constraints (conditional presence, mutual exclusion, totals that must agree). Derive each rule directly from the types and attribute semantics chosen above.
5. **Naming conventions** — Question: one casing, singular or plural per construct? Artifact: a written rule (e.g., `snake_case` keys, singular entity names, plural list keys, no abbreviations). Apply it uniformly.
6. **Hierarchical structure** — Question: what nests inside what? Artifact: a parent–child map. Prefer the shallowest nesting that still groups related fields; lift fields out of nesting when they appear at the top level of two or more entities.
7. **Defaults** — Question: for each optional field, what value does omission imply? Artifact: an explicit default for every optional field. Omission MUST resolve to a well-defined value, never to undefined behavior.
8. **Required vs optional** — Question: which fields must appear on every instance? Artifact: a per-attribute `required: true|false` marking. *Optional* MUST mean "absent equals the stated default," never "absent means anything."
9. **Enums** — Question: which fields have a small closed set of values? Artifact: enum definitions, each with a complete value list and a policy for extending it (additive only, ideally).
10. **References** — Question: when one entity points at another, how is the pointer encoded? Artifact: the reference key (usually the target's identifier field), the resolution scope (same document, same project, global), and how cycles are handled (allowed, forbidden, or topologically ordered).
11. **Extensibility** — Question: how does the schema change without breaking existing instances? Artifact: a forward-compatibility plan — a `schema_version` field, an `extensions:` block for unknown keys, additive-only enum changes, and a written deprecation policy.

## Worked Example

A small feature-flag DSL: two entities (`flag` and `audience`), enum-typed strategies, defaults for optional fields, a flag-to-audience reference, a cross-field conditional rule, and an extensibility hatch. The first YAML block is the schema (the contract); the second is one concrete document that conforms to it.

```yaml
# Feature-flag DSL schema (the contract).
schema_version: "1.0"

entities:
  audience:
    attributes:
      key:
        type: string
        required: true
        unique: true
        pattern: "^[a-z][a-z0-9_]*$"
      description:
        type: string
        required: false
        default: ""
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

  flag:
    attributes:
      key:
        type: string
        required: true
        unique: true
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
        values: [all, percentage, audience]
        required: false
        default: all
      percentage:
        type: integer
        minimum: 0
        maximum: 100
        required_when: "strategy == 'percentage'"
      audiences:
        type: list
        required_when: "strategy == 'audience'"
        items:
          type: reference
          target: audience.key
      extensions:
        type: map
        required: false
        default: {}
```

```yaml
# A conforming instance of the schema above.
schema_version: "1.0"

audiences:
  - key: beta_users
    match: any
    rules:
      - attribute: plan
        operator: in
        value: [pro, enterprise]
      - attribute: email
        operator: eq
        value: "founder@example.com"

flags:
  - key: new_checkout
    description: "Roll out the new checkout flow to a slice of users."
    enabled: true
    strategy: percentage
    percentage: 25

  - key: beta_dashboard
    enabled: true
    strategy: audience
    audiences: [beta_users]
    extensions:
      ticket: GROW-142

  - key: legacy_login
    enabled: false
```

## Validation Rules

A conforming document MUST satisfy every rule below. Each rule traces back to a specific decision made in the walkthrough.

- **Required fields present.** Every attribute marked `required: true` (e.g., `flag.key`, `flag.enabled`, `audience.key`, `audience.match`, `audience.rules`) appears on every instance of its entity.
- **Types match at the leaf.** Each value lies in the declared type's value space — strings are strings, integers are integers, lists are lists, objects are objects.
- **Enum values are in range.** `flag.strategy ∈ {all, percentage, audience}`, `audience.match ∈ {any, all}`, and each `rules[].operator ∈ {eq, neq, in, not_in, gt, lt}`. No other values are admitted.
- **Per-field constraints hold.** `flag.key` and `audience.key` match `^[a-z][a-z0-9_]*$`; `flag.percentage` is an integer in `0..100`; any declared `min_length`, `max_length`, or `pattern` holds for every value.
- **Conditional requirements hold.** When `flag.strategy == 'percentage'`, `flag.percentage` is present; when `flag.strategy == 'audience'`, `flag.audiences` is present and non-empty.
- **References resolve.** Every entry in `flag.audiences` matches some declared `audience.key`. Dangling references are an error, not a warning; cycles in any reference graph are forbidden unless the schema explicitly allows them.
- **No duplicate keys at a given scope.** `flag.key` values are unique within `flags`; `audience.key` values are unique within `audiences`; map keys are unique within any single mapping.
- **Defaults are applied, not assumed.** Omitted optional fields take the schema-declared default (`flag.description = ""`, `flag.strategy = all`, `flag.extensions = {}`); consumers see the default, never "missing."
- **No unknown fields outside the extensibility hatch.** Top-level keys outside `schema_version`, `audiences`, and `flags` are rejected; unknown per-flag keys live under `extensions:` only and cannot mask declared fields.
- **Schema version is recognized.** Consumers reject documents whose `schema_version` they do not understand rather than guessing; new schema versions are introduced by additive change wherever possible.

## Deliverable

When this trait finishes, the user leaves with three artifacts, all expressed as data:

1. **A YAML DSL schema** for their domain, capturing entities, attributes, types, defaults, required vs optional, enums, references, and the extensibility hatch.
2. **At least one worked instance** that conforms to the schema, sized to fit on one screen, exercising the interesting cases (defaults applied, enum values selected, references resolved).
3. **An explicit validation-rules list** — every constraint a conforming instance MUST satisfy, each rule traceable back to a specific schema decision.

The schema is the source of truth. Any downstream code (validators, UIs, runtimes, doc generators) is a consumer of the schema, never a parallel definition of it. Choice of YAML parser, validator library, or codegen tool is the user's call and outside this trait's scope.

## When Not To Use

- **Imperative or stateful problems.** If the natural answer is "do A, then B, then C, depending on what happened during B," declarative DSL design fights the domain. Write the program; don't twist it into data.
- **Procedural orchestration.** Step-by-step workflows with rich branching control flow are usually better expressed as code or as an explicit step graph, not as a flat YAML document.
- **Unstable domains.** If the entities, attributes, or relationships are still being discovered, designing a schema is premature; sketch concrete instances first and let the schema fall out later.
- **Single-consumer one-off configuration.** If exactly one program reads the data, owns its shape, and changes the shape alongside its own code, a typed data structure in that program's source is usually clearer than a separate DSL.
- **A general-purpose language carries the design more honestly.** When expressive constraints (conditionals, computed defaults, derived values) start to dominate the schema, the cost of inventing a DSL exceeds its benefit. Use a programming language and a typed config object instead.
- **A widely-adopted schema already covers the domain.** If JSON Schema, OpenAPI, AsyncAPI, a Kubernetes CRD, or another established standard already models the domain, adopt it rather than authoring a bespoke DSL.
