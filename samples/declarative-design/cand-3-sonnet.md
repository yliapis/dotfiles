---
name: declarative-design
description: "Guide a runtime user from a domain description to a validated YAML DSL schema. Use when the user explicitly asks for declarative design, DSL design, YAML schema design, or schema design help."
license: MIT
---

# Declarative Design

This skill walks you through designing a YAML DSL schema for any domain you bring to it. Starting from "what are the things in your domain?" and ending with "here is a validated schema, a conforming worked instance, and a written list of validation rules," the journey follows declarative principles: every decision produces a data artifact, not a sequence of instructions. By the end, your schema is the single source of truth and any downstream tool is merely a consumer of it.

## Declarative Principles

Apply these principles at every step of the design:

- **What, not how** — describe what the system should be or have, not the procedure for achieving it. Schemas enumerate facts; runtime is the consequence.
- **Data over behavior** — the schema is the deliverable. Behavior is a consumer of the data, not an ingredient of the design.
- **Schema as source of truth** — every consumer (validator, code generator, documentation tool) reads the same schema. No second source is maintained alongside it.
- **Idempotent definitions** — re-evaluating or re-applying a definition produces the same result. A field declared `required: true` means the same thing every time it is read.
- **No hidden state** — every meaningful fact is visible in the data. Nothing significant depends on evaluation order, accumulated side effects, or out-of-band context.
- **Configuration as data** — configuration values are data, not sequences of mutations. A `defaults:` block is a value; a series of `set` calls is not.
- **Composition over imperative wiring** — assemble complex structures by composing smaller schema fragments rather than by sequencing calls that build state.

## Design Walkthrough

Work through these concerns in order; each step produces a concrete artifact that feeds the next.

1. **Entities** — List the nouns in the domain. Ask: "What are the things this system tracks or configures?" Each noun that has its own identity and attributes becomes a top-level or named entity in the schema.

2. **Attributes** — For each entity, list what a user observes or sets on it. Ask: "What facts about this entity matter to consumers?" Each fact becomes a key in the entity's attribute map.

3. **Types** — Decide the value space of every attribute. Pick from: string, integer, float, boolean, null, a structured mapping, a sequence, or an enum (defined in step 9). Annotate each attribute with its type.

4. **Validation rules** — Capture the constraints that make an instance well-formed. Include per-field constraints (min/max length, regex pattern, numeric range) and cross-field constraints (if field A is present, field B is required).

5. **Naming conventions** — Choose one casing style (e.g., `snake_case`) and one plurality rule (e.g., singular for entity names, plural for list keys). Apply them everywhere. Document the convention in a top-level comment or `$schema-meta` block.

6. **Hierarchical structure** — Decide what nests inside what. Prefer shallow nesting (two levels or fewer) and flat keys when possible. Deep nesting is a signal that an entity should be promoted to a named top-level definition.

7. **Defaults** — For every optional attribute, state the value omission implies. List defaults explicitly in the schema or in a companion `defaults:` block so they are data, not hidden logic.

8. **Required vs optional** — Mark which attributes must appear on every instance. Optional MUST NOT mean undefined behavior; every optional attribute has a documented default or a documented "absent means not applicable" semantic.

9. **Enums** — When an attribute's value space is a small, closed set, enumerate the allowed values. Name the enum so it can be reused across entities.

10. **References** — When one entity refers to another (e.g., a `role` references a `permission` by name), declare the reference key explicitly, state whether cycles are allowed, and state how a dangling reference is treated (error vs. ignored).

11. **Extensibility** — Name the forward-compatible escape hatch. Common patterns: an `extensions:` mapping whose keys are namespaced strings, additive-only enum values, or a `version:` field whose increment signals a breaking change.

## Worked Example

The following example models a feature-flag system. Flags have a name, an enabled state, a rollout percentage, an audience enum, and optional overrides that reference flags by name. The schema demonstrates all eleven walkthrough concerns in a domain small enough to read on one screen.

**Schema:**

```yaml
# feature-flags schema v1.0
version: "1.0"

$defs:
  audience_enum:
    description: "Closed set of audiences a flag may target."
    values:
      - all
      - internal
      - beta
      - canary

  override:
    description: "A named exception that supersedes the flag's default rollout."
    attributes:
      audience:
        type: audience_enum
        required: true
      enabled:
        type: boolean
        required: true

  flag:
    description: "A single feature flag and its rollout policy."
    attributes:
      name:
        type: string
        required: true
        pattern: "^[a-z][a-z0-9_-]*$"
        description: "Unique snake_case identifier for the flag."
      enabled:
        type: boolean
        required: true
        default: false
        description: "Master switch; false disables the flag for all audiences."
      rollout_pct:
        type: integer
        required: false
        default: 100
        minimum: 0
        maximum: 100
        description: "Percentage of eligible users who see the flag when enabled."
      audience:
        type: audience_enum
        required: false
        default: all
        description: "Which audience the default rollout targets."
      overrides:
        type: sequence
        items: override
        required: false
        default: []
        description: "Per-audience exceptions; evaluated before the default rollout."
      extends:
        type: string
        required: false
        description: "Name of a flag whose settings this flag inherits. No cycles allowed."
      extensions:
        type: mapping
        required: false
        description: "Namespace-prefixed extra keys for forward compatibility (e.g., acme.io/owner)."

flags:
  type: sequence
  items: flag
  required: true
  description: "Ordered list of all feature flags in this configuration."
```

**Conforming instance:**

```yaml
version: "1.0"

flags:
  - name: dark_mode
    enabled: true
    rollout_pct: 100
    audience: all

  - name: new_checkout
    enabled: true
    rollout_pct: 20
    audience: beta
    overrides:
      - audience: internal
        enabled: true
      - audience: canary
        enabled: true
    extensions:
      acme.io/owner: "payments-team"

  - name: experimental_search
    enabled: false
    extends: new_checkout
```

## Validation Rules

A conforming YAML document MUST satisfy every rule below. Evaluate rules in order; a document failing an earlier rule need not be evaluated further.

- **Required fields present** — every attribute marked `required: true` in the schema appears on every instance of that entity.
- **Enum values within the declared set** — every attribute typed as an enum holds one of the values listed in the corresponding `$defs` entry.
- **References resolve** — every `extends` value names a flag that exists in the same `flags` sequence; dangling references are invalid.
- **No reference cycles** — the `extends` graph is a directed acyclic graph; a flag may not extend itself, directly or transitively.
- **No duplicate keys at the same scope** — no two flags share the same `name`; no two overrides within a single flag share the same `audience`.
- **Per-field constraints hold** — `name` matches the pattern `^[a-z][a-z0-9_-]*$`; `rollout_pct` is an integer in [0, 100]; string fields do not exceed any declared maximum length.
- **No unknown top-level keys** — only `version` and `flags` appear at the document root; unknown keys at the root are invalid.
- **Extension keys are namespaced** — keys in an `extensions:` mapping use a reverse-DNS prefix (e.g., `acme.io/key`); bare keys are invalid.

## Deliverable

When this skill finishes, you leave with three artifacts:

1. **A YAML DSL schema** for your domain, covering entities, attributes, types, validation rules, naming conventions, hierarchy, defaults, required/optional distinctions, enums, references, and extensibility.
2. **At least one conforming worked instance** that passes every validation rule listed in the schema.
3. **A written validation-rules list** mapping each constraint to the schema decision that motivates it.

The schema is the source of truth. Every downstream tool — validator, code generator, documentation renderer — is a consumer of the schema, not a co-author of it.

## When Not To Use

- **The task is inherently imperative or stateful.** If the design question is "what should the system *do* step by step?" and the answer resists being expressed as stable data, a schema is the wrong tool.
- **The domain has no stable entities yet.** Designing a schema before the entities and their relationships are understood produces a schema that will be thrown away. Stabilize the domain model first.
- **A general-purpose programming language carries the design more honestly.** If the constraints require conditionals, loops, or mutable state that a data language cannot express without contortion, use code and revisit schema design after the logic stabilizes.
- **The schema would duplicate an existing standard.** If a widely-adopted schema (JSON Schema, OpenAPI, AsyncAPI, Kubernetes CRD) already covers the domain, adopt it rather than authoring a bespoke DSL.
