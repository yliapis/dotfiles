---
name: declarative-design
description: "Design a YAML DSL schema for a user-supplied domain by walking from entities to a validated instance, applying declarative-design principles that put data and composition ahead of imperative wiring. Use when the user explicitly asks for declarative design, DSL design, or YAML schema design help."
license: MIT
---

# Declarative Design

This skill takes a runtime user from "I have a domain I want to describe" to "I have a YAML DSL schema, a conforming instance, and an explicit list of validation rules." The deliverable is the schema and its rules — not the program that interprets them. Treat every step as discovering data that is already implicit in the domain, not as inventing behavior to bolt onto it.

## Declarative Principles

State each principle as a contrast: do *this*, not *that*. Bias every later decision toward the left-hand side.

- **What, not how.** Describe the outcome the system must guarantee. Do not script the steps an interpreter should run.
- **Data over behavior.** The schema and its instances are the artifacts. Code is a downstream consumer that any conforming implementation could replace.
- **Schema as source of truth.** Every consumer reads the same schema. If two consumers disagree about what a field means, the schema — not either consumer — is the authority.
- **Idempotent definitions.** Re-reading the same document yields the same model. There is no "apply twice and get a different result."
- **No hidden state.** Every fact the runtime depends on appears in the data. Order of definitions, prior runs, and ambient environment do not change meaning.
- **Configuration as data.** Configuration is a value the user can copy, diff, and version. It is not a sequence of imperative mutations.
- **Composition over imperative wiring.** Build larger meanings by composing smaller values (references, lists, maps), not by sequencing function calls.

## Design Walkthrough

Work the steps in order; each one depends only on the ones above it. At every step, state the question the runtime user must answer and capture the artifact that step produces.

1. **Entities.** What nouns does the domain have? *Artifact:* an enumerated list of entity names with one-line definitions.
2. **Attributes.** For each entity, what does the user observe or set? *Artifact:* an attribute list per entity. Resist conflating "things the user writes" with "things the runtime computes."
3. **Types.** What is the value space of each attribute? Choose scalar types (string, number, boolean), structured types (list, map, object), enums, or references. *Artifact:* a typed attribute table.
4. **Validation rules.** What makes an instance well-formed? Capture per-field constraints (pattern, range, length) and cross-field constraints (mutually exclusive fields, totals that must agree, dependent presence). *Artifact:* a constraint list keyed to fields.
5. **Naming conventions.** Pick one casing (for example `snake_case`) and one number convention (singular for an entity, plural for a collection of that entity). Apply both uniformly. *Artifact:* a one-paragraph naming rule.
6. **Hierarchical structure.** What nests inside what? Prefer the shallowest nesting that still groups related fields together. Lift fields out of nesting when they appear at the top level of two or more entities. *Artifact:* an indented outline of the document shape.
7. **Defaults.** For every optional field, what value does omission imply? *Artifact:* a defaults table. If a field has no sensible default, mark it required instead of letting it be "optional with undefined behavior."
8. **Required vs optional.** Mark every field as one or the other. *Optional* MUST mean "absent equals the stated default," never "absent means anything."
9. **Enums.** When a field has a small closed set of values, enumerate them. *Artifact:* the enumerated values and the policy for extending them (additive only, ideally).
10. **References.** When one entity refers to another, decide the reference key (typically the referenced entity's key field), the resolution scope (same document, same project, global), and how cycles are handled (allowed, forbidden, or topologically ordered). *Artifact:* a reference table per pair of entities.
11. **Extensibility.** Name the forward-compatible escape hatch — a versioned schema header, an `extensions:` map for unknown keys, and an additive-only enum policy. *Artifact:* a versioning rule and a documented extension surface.

## Worked Example

A *feature-flag* DSL illustrates the principles concretely: flags are pure data, audiences are referenced by key, and a runtime evaluator is a pure function from `(flag-doc, request)` to a value. The schema below is the contract; the instance below is one document that conforms to it.

```yaml
# Feature-flag DSL schema (the contract).
version: 1
entities:
  audience:
    fields:
      key:
        type: string
        required: true
        pattern: "^[a-z][a-z0-9_-]*$"
      description:
        type: string
        required: false
      match:
        type: map
        key_type: string
        value_type: string
        required: true
  flag:
    fields:
      key:
        type: string
        required: true
        pattern: "^[a-z][a-z0-9_.-]*$"
      type:
        type: enum
        values: [boolean, string, number, percentage]
        required: true
      description:
        type: string
        required: false
      default:
        type: any
        required: true
      rules:
        type: list
        required: false
        default: []
        item:
          type: object
          fields:
            when:
              type: reference
              entity: audience
              required: true
            value:
              type: any
              required: true
      environments:
        type: list
        required: false
        default: [dev, staging, prod]
        item:
          type: enum
          values: [dev, staging, prod]
      extensions:
        type: map
        key_type: string
        value_type: any
        required: false
        default: {}
```

```yaml
# A conforming instance of the schema above.
version: 1
audiences:
  - key: beta_users
    description: Opt-in beta cohort
    match:
      plan: beta
  - key: internal
    description: Employees and contractors
    match:
      email_domain: example.com
flags:
  - key: checkout.new_summary
    type: boolean
    description: Render the redesigned cart summary
    default: false
    rules:
      - when: beta_users
        value: true
      - when: internal
        value: true
    environments: [dev, staging]
  - key: search.results_per_page
    type: number
    description: Page size for search results
    default: 20
    rules:
      - when: internal
        value: 50
```

## Validation Rules

A document conforms to the schema only when every rule below holds. Each rule traces back to a decision in the walkthrough.

- **Required fields present.** Every field marked `required: true` appears on every instance of its containing entity (walkthrough §8).
- **Enum values in range.** Every enum-typed field holds a value from its declared `values:` list (§9). Unknown values are rejected, never silently accepted.
- **Per-field constraints hold.** Patterns, ranges, lengths, and other per-field rules pass for every value (§4).
- **References resolve.** Every reference (for example `flag.rules[].when`) names a declared entity by its key field, in the resolution scope chosen in §10.
- **No duplicate keys at the same scope.** Audience keys are unique among audiences; flag keys are unique among flags; map keys are unique within a single map (§3, §10).
- **Types match at the leaf.** A flag's `default` and each `rules[].value` are of the flag's declared `type` (§3 + §4).
- **Defaults applied uniformly.** When an optional field is absent, every consumer reads the declared default; absence never means undefined behavior (§7).
- **Extension keys do not collide with declared keys.** Anything under `extensions:` is namespaced and cannot mask a declared field (§11).
- **Schema version recognized.** Consumers reject documents whose `version:` they do not understand, rather than guessing (§11).

## Deliverable

When this skill finishes, the runtime user leaves with three artifacts and nothing else:

1. **A YAML DSL schema** for their domain, structured as a single document. The schema enumerates entities, fields, types, defaults, enums, references, and the extensibility surface.
2. **At least one conforming worked instance** that exercises required fields, defaults, enum values, and at least one cross-entity reference.
3. **An explicit validation-rules list** in prose, with each rule traceable to the schema decision that produced it.

The schema is the source of truth. Any code that reads or writes it is a downstream consumer of these artifacts and can be replaced without changing the design.

## When Not To Use

Skip this skill when the problem resists being expressed as data.

- **Imperative or procedural tasks.** "What steps should the build run, in order, with branching and retries?" is honestly a program, not a schema. A scripting language carries the design better.
- **Stateful workflows.** If meaning depends on prior runs, accumulated state, or side-effecting calls, the design has hidden state that no schema can fully capture.
- **Unstable or unknown entities.** If the domain's nouns are still in flux, designing a schema is premature — sketch on paper first and return to this skill once entities stabilize.
- **One-off configuration.** If exactly one consumer reads exactly one document for exactly one run, schema discipline is overhead. Reach for this skill when multiple consumers, multiple instances, or future versions are foreseeable.
