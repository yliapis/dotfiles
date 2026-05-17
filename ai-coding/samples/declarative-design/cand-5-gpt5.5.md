---
name: declarative-design
description: "Guide users from domain analysis to a validated YAML DSL schema with a conforming worked example. Use when the user explicitly asks for declarative design, DSL design, YAML schema design, or schema design help."
license: MIT
---

# Declarative Design

Use this skill to turn a task domain into a YAML DSL whose schema is the source of truth. Move from domain nouns to a validated schema, then prove the design with a small conforming instance and an explicit list of validation rules.

## Declarative Principles

- **What-not-how**: describe the desired facts and outcomes, not the procedure for producing them.
- **Data over behavior**: make the YAML document the durable artifact; behavior belongs to consumers of that data.
- **Schema as source of truth**: every valid instance is judged against one schema, not scattered assumptions.
- **Idempotent definitions**: the same definition means the same thing each time it is read.
- **No hidden state**: put every meaningful choice in fields, defaults, or references.
- **Configuration as data**: represent configuration as values, not as mutation steps.
- **Composition over imperative wiring**: combine reusable declarations instead of sequencing commands.

## Design Walkthrough

1. **Entities**: what stable nouns exist in the domain? Produce a list of entity kinds and their purpose.
2. **Attributes**: what facts can users observe or set for each entity? Produce an attribute list per entity.
3. **Types**: what value space does each attribute allow? Produce scalar, list, map, object, reference, or enum types.
4. **Validation rules**: what makes an instance well formed? Produce required-field, per-field, and cross-field constraints.
5. **Naming conventions**: what casing, plurality, and identifier style will the DSL use? Produce a naming guide.
6. **Hierarchical structure**: what owns or contains what? Produce a nesting plan that keeps lookup paths predictable.
7. **Defaults**: what value does omission imply? Produce explicit defaults for optional fields.
8. **Required vs optional**: which fields must appear and which can rely on defaults? Produce a required-field list by entity.
9. **Enums**: which fields have closed sets of values? Produce the allowed values and their meanings.
10. **References**: how does one entity point to another? Produce reference keys and rules for resolving them.
11. **Extensibility**: how can future versions add meaning without breaking existing instances? Produce a versioning or `extensions` plan.

## Worked Example

This example designs a small feature-flag DSL. The schema declares flag entities, attribute types, defaults, enums, references to reusable audiences, and an extension point.

```yaml
schema:
  name: feature-flags
  version: 1
  entities:
    audience:
      key: name
      required:
        - name
        - rules
      attributes:
        name:
          type: string
          pattern: "^[a-z][a-z0-9-]*$"
        rules:
          type: list
          items:
            type: object
            required:
              - field
              - operator
              - value
            attributes:
              field:
                type: enum
                values:
                  - country
                  - plan
              operator:
                type: enum
                values:
                  - equals
                  - in
              value:
                type: string
    flag:
      key: key
      required:
        - key
        - enabled
        - rollout
      attributes:
        key:
          type: string
          pattern: "^[a-z][a-z0-9-]*$"
        enabled:
          type: boolean
        rollout:
          type: integer
          minimum: 0
          maximum: 100
        audience:
          type: reference
          entity: audience
          required: false
        owner:
          type: string
          required: false
          default: platform
        lifecycle:
          type: enum
          values:
            - experimental
            - stable
            - retired
          default: experimental
        extensions:
          type: map
          required: false
          default: {}
```

```yaml
feature_flags:
  audiences:
    - name: paid-users
      rules:
        - field: plan
          operator: in
          value: pro,enterprise
  flags:
    - key: new-dashboard
      enabled: true
      rollout: 25
      audience: paid-users
      owner: analytics
      lifecycle: experimental
      extensions:
        ticket: EXP-42
```

## Validation Rules

- Required fields are present for every declared entity instance.
- Field values match their declared types: string, boolean, integer, list, object, map, reference, or enum.
- Enum values appear only in the set declared by the schema.
- Reference fields resolve to an entity instance with the referenced key.
- No duplicate keys appear at the same scope, including entity keys such as `flag.key` and `audience.name`.
- Per-field constraints hold, including regex patterns, integer ranges, and required nested attributes.
- Optional fields either appear with valid values or take their declared default.
- Extension fields stay inside the declared extension point and do not redefine first-class schema fields.

## Deliverable

When the skill finishes, the runtime user leaves with a YAML DSL schema for their task, at least one worked YAML instance that conforms to it, and an explicit validation-rules list. The schema remains the source of truth; downstream tooling is only a consumer of the declared data.

## When NOT to use

- The problem is primarily imperative, procedural, or stateful, and a step-by-step program is the honest model.
- The domain has not stabilized enough to name entities, attributes, and validation rules.
- The desired behavior depends on hidden execution order, mutable process state, or external side effects that should not be encoded as static data.
