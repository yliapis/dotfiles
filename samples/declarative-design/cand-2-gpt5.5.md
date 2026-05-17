---
name: declarative-design
description: "Guide agents through designing self-contained YAML DSL schemas from a user's domain, from concepts to validation and worked examples. Use when the user explicitly asks for declarative design, DSL design, YAML schema design, or schema design help."
license: MIT
---

# Declarative Design

Use this skill to guide a user from a domain idea to a YAML DSL schema that describes what the system should accept and produce. Keep the schema as the artifact: identify the domain concepts, express them as data, validate the shape explicitly, and finish with a worked instance that conforms to the schema.

## Declarative Principles

- **What-not-how** - describe the desired state and constraints, not execution steps.
- **Data over behavior** - make the DSL a data contract; runtimes consume it rather than hiding logic inside it.
- **Schema as source of truth** - every instance, consumer, and validation rule traces back to the schema.
- **Idempotent definitions** - reading the same document twice should describe the same domain state.
- **No hidden state** - every meaningful fact appears in YAML, not in evaluation order or ambient context.
- **Configuration as data** - configuration is a value with fields, defaults, and rules, not a sequence of mutations.
- **Composition over imperative wiring** - combine small declarative objects instead of prescribing call order.

## Design Walkthrough

1. **Entities** - ask what nouns the domain needs to describe. Produce a short list of top-level entities and define the responsibility of each one.
2. **Attributes** - ask what facts each entity exposes or accepts. Produce a field list for every entity, keeping behavior out of field names.
3. **Types** - ask what value space each attribute allows. Produce scalar, list, map, object, enum, or reference types with clear constraints.
4. **Validation rules** - ask what makes a document invalid. Produce field-level and cross-entity rules before writing examples.
5. **Naming conventions** - ask what names should look like. Produce casing, pluralization, identifier, and reserved-word conventions.
6. **Hierarchical structure** - ask which entities own other entities. Produce a nesting model that keeps repeated objects shallow and predictable.
7. **Defaults** - ask what omission means for each optional field. Produce explicit default values or state that no default exists.
8. **Required vs optional** - ask which fields must be present for meaning to be unambiguous. Produce a required-field list and optional-field defaults.
9. **Enums** - ask which fields have a closed set of allowed values. Produce named enum sets and define how future values can be introduced.
10. **References** - ask how entities point to each other. Produce reference keys, uniqueness rules, and resolution rules for missing or cyclic references.
11. **Extensibility** - ask where future data can be added without breaking existing documents. Produce versioning rules and a bounded extension shape.

## Worked Example

This example designs a small YAML DSL for feature flag definitions. The schema treats flags, variants, and rollout rules as data; a runtime can evaluate the data, but the DSL itself only declares state and constraints.

```yaml
schema:
  name: feature_flag_catalog
  version: 1
  entities:
    flag:
      required:
        - key
        - owner
        - status
        - variants
      optional:
        description: ""
        default_variant: "off"
        rules: []
        extensions: {}
      attributes:
        key:
          type: string
          pattern: "^[a-z][a-z0-9_]*$"
        owner:
          type: string
          min_length: 1
        status:
          type: enum
          values:
            - draft
            - active
            - retired
        variants:
          type: list
          min_items: 1
          item:
            type: object
            required:
              - name
              - weight
            attributes:
              name:
                type: string
                pattern: "^[a-z][a-z0-9_]*$"
              weight:
                type: integer
                minimum: 0
                maximum: 100
        default_variant:
          type: reference
          target: flag.variants.name
        rules:
          type: list
          item:
            type: object
            required:
              - segment
              - variant
            attributes:
              segment:
                type: string
              variant:
                type: reference
                target: flag.variants.name
```

```yaml
flags:
  - key: checkout_redesign
    owner: growth
    status: active
    description: Enables the redesigned checkout flow.
    default_variant: off
    variants:
      - name: off
        weight: 70
      - name: on
        weight: 30
    rules:
      - segment: beta_users
        variant: on
    extensions:
      ticket: GROW-142
```

## Validation Rules

- A conforming document MUST contain a `flags` list, and each flag MUST include `key`, `owner`, `status`, and `variants`.
- Flag `key` values and variant `name` values MUST match the declared identifier pattern and be unique within their scope.
- Enum fields MUST use declared values only; `status` is limited to `draft`, `active`, or `retired`.
- `variants` MUST contain at least one item, and every variant `weight` MUST be an integer from 0 through 100.
- Reference fields MUST resolve inside the same flag: `default_variant` and each rule `variant` MUST name an existing variant.
- Defaults MUST be applied only when optional fields are omitted; omission MUST NOT create undefined behavior.
- No duplicate keys may appear at the same YAML mapping scope.
- Extension data MUST stay under `extensions` and MUST NOT override declared fields.

## Deliverable

When the skill finishes, the runtime user leaves with a YAML DSL schema for their task, at least one worked YAML instance that conforms to it, and an explicit list of validation rules. The schema is the source of truth; implementation code, documentation, and tests should consume the schema rather than redefine it.

## When Not To Use

- The task is mainly imperative, procedural, or stateful, and the core question is the order of operations rather than the shape of data.
- The domain has no stable entities, attributes, or constraints yet; gather examples before freezing a schema.
- A constrained YAML DSL would hide essential behavior that belongs in a general-purpose programming language.
