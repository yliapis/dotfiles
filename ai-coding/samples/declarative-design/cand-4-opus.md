---
name: declarative-design
description: "Guide the user through designing a YAML DSL schema for their domain by applying declarative-design principles. Use when the user explicitly asks for declarative design, DSL design, YAML schema design, or schema design help."
license: MIT
---

# Declarative Design

Walk the user from "what is the domain?" to "here is a validated YAML schema with a worked example." The deliverable is data — a DSL schema, a conforming instance, and an explicit list of validation rules. Procedural code is downstream of the schema and is not part of what this skill produces.

## Declarative Principles

Frame every recommendation around these. Pick at least five when reviewing a draft schema.

- **What, not how** — describe the desired state of the world; let consumers decide the procedure.
- **Data over behavior** — the schema is the artifact; runtime code is a consumer of that data, not a co-author of it.
- **Schema as source of truth** — every consumer (validator, UI, runner, docs) reads the same schema; never let a second source diverge.
- **Idempotent definitions** — re-evaluating the same instance yields the same result; the order of statements does not change meaning.
- **No hidden state** — every meaningful fact appears in the data; nothing depends on what happened before or in which order keys were read.
- **Configuration as data** — configuration is a value you can diff, version, and validate; not a sequence of mutating calls.
- **Composition over imperative wiring** — assemble behavior by composing values (references, includes, defaults), not by chaining steps.

## Design Walkthrough

Work through these concerns in order. Each step depends only on those above it, and each produces an artifact the next step consumes. Do not silently skip a step; if a concern does not apply, record that as a deliberate choice.

1. **Entities** — Ask: what nouns does the domain have? Produce a flat list of entity names (e.g., `feature`, `team`).
2. **Attributes** — Ask: for each entity, what does the user set or observe? Produce an attribute list per entity.
3. **Types** — Ask: what is the value space of each attribute? Pick scalar types (`string`, `integer`, `number`, `boolean`, `date`), structured types (`list`, `map`, `object`), or enums.
4. **Validation rules** — Ask: what makes an instance well-formed? Capture per-field constraints (range, length, regex) and cross-field constraints (conditional requirements, mutual exclusion).
5. **Naming conventions** — Pick one casing for keys (e.g., `snake_case`) and one for identifier values (e.g., `kebab-case`), and apply them everywhere. Use the singular for a single value and the plural for a collection (`team` vs `teams`).
6. **Hierarchical structure** — Decide what nests inside what. Prefer shallow trees and flat keys; reach for nesting only when it removes ambiguity or expresses true containment.
7. **Defaults** — For each optional field, state the value omission implies. Defaults MUST be values, not behaviors.
8. **Required vs optional** — Mark each field. Optional MUST NOT mean undefined behavior; either default the field or document that absence is a real, named state.
9. **Enums** — Where a field has a small closed set of values, enumerate them by name. Treat enums as extension points: plan how new values will be added without breaking existing instances.
10. **References** — When one entity points to another, name the reference key (e.g., `owner` → `teams[].name`) and decide whether cycles are allowed.
11. **Extensibility** — Name the forward-compatible escape hatch: an `extensions:` map, additive enum values, and an explicit `schema_version`. Document that consumers MUST ignore unknown keys inside the escape hatch.

## Worked Example

A small feature-flag DSL: two entities (`feature` and `team`), four enums, one cross-reference, one conditional validation, and an explicit extensibility hatch.

```yaml
# Feature Flag DSL — schema v1
# Top-level instance shape: { schema_version, features, teams }

schema:
  version: 1

  root:
    type: object
    required: [schema_version, features, teams]
    fields:
      schema_version: { type: integer, const: 1 }
      features:       { type: list, items: { ref: Feature } }
      teams:          { type: list, items: { ref: Team } }

  types:
    Feature:
      required: [name, description, type, default, enabled, owner]
      fields:
        name:        { type: string, pattern: "^[a-z][a-z0-9-]*$", unique: true }
        description: { type: string, min_length: 1, max_length: 200 }
        type:        { type: enum, values: [boolean, string, number, json] }
        default:     { type: any, must_match_type: "this.type" }
        enabled:     { type: boolean }
        owner:       { type: ref, target: "teams[].name" }
        rollout:     { type: object, ref: Rollout, optional: true, default: { strategy: all-or-nothing } }
        tags:        { type: list, items: { type: string }, optional: true, default: [] }
        expires_at:  { type: date, optional: true }
        extensions:  { type: map, optional: true, note: "Forward-compatible bag; unknown keys are allowed only here." }

    Rollout:
      required: [strategy]
      fields:
        strategy:     { type: enum, values: [all-or-nothing, percentage, targeted, environment] }
        percentage:   { type: integer, range: [0, 100], required_when: "strategy == 'percentage'" }
        targets:      { type: list, items: { type: string }, required_when: "strategy == 'targeted'" }
        environments: { type: list, items: { type: enum, values: [dev, staging, prod] }, required_when: "strategy == 'environment'" }

    Team:
      required: [name, contact]
      fields:
        name:    { type: string, pattern: "^[a-z][a-z0-9-]*$", unique: true }
        contact: { type: string, min_length: 1 }
```

A conforming instance:

```yaml
schema_version: 1

features:
  - name: dark-mode
    description: Toggle the dark UI theme on the web app.
    type: boolean
    default: false
    enabled: true
    owner: frontend
    rollout:
      strategy: percentage
      percentage: 25
    tags: [ui, experiment]
    expires_at: 2026-09-01

  - name: checkout-redesign
    description: New one-page checkout flow.
    type: boolean
    default: false
    enabled: true
    owner: commerce
    rollout:
      strategy: environment
      environments: [dev, staging]

teams:
  - name: frontend
    contact: frontend@example.com
  - name: commerce
    contact: "#commerce-team"
```

## Validation Rules

A conforming document MUST satisfy every rule below. Each rule maps back to a decision made in the walkthrough.

- **Required fields present.** Every field declared `required` is present on every instance of its entity.
- **Types match.** Every value matches the declared type of its field; `default` matches the value space named by its sibling `type`.
- **Enums within the declared set.** Every enum-typed field takes a value listed in the schema for that enum.
- **References resolve.** Every reference names a declared entity (e.g., `owner` resolves to some `teams[].name`).
- **No duplicate keys at the same scope.** Map keys are unique within a scope, and list-entry fields marked `unique: true` do not repeat their value across the list.
- **Per-field constraints hold.** `pattern`, `min_length`, `max_length`, `range`, and similar constraints pass for every instance value.
- **Conditional requirements hold.** Fields marked `required_when: <expr>` are present whenever the expression evaluates true (e.g., `percentage` is required when `strategy == 'percentage'`).
- **Unknown keys are confined.** Unknown top-level or per-type keys are rejected; forward-compatible additions live under the declared `extensions:` map and consumers MUST ignore unknown keys inside it.

## Deliverable

When the skill finishes, the user leaves with three artifacts:

1. **A YAML DSL schema** for their domain — a single YAML document declaring entities, attributes, types, defaults, enums, references, and an extensibility hatch.
2. **At least one worked instance** — a YAML document that parses and that satisfies every validation rule above.
3. **An explicit list of validation rules** — the constraints a conforming instance MUST satisfy, each rule traceable to a schema decision made in the walkthrough.

The schema is the source of truth. Any downstream tool (validator, UI, runner, doc generator) is a consumer of the schema; choice of YAML parser, validator library, or codegen tool is the user's call and outside this skill's scope.

## When Not To Use

Stop and pick a different approach when the problem is fundamentally imperative, procedural, or stateful:

- **Step-by-step procedures.** "Run this, then if X, run that, otherwise retry" — when the order is the meaning, a data document loses information.
- **Stateful workflows.** Long-lived processes whose transitions cannot be reduced to data without losing meaning (e.g., orchestration with side effects, transactional retries, in-flight context).
- **Unstable domain.** The entities, attributes, or vocabulary are still in flux; pinning them down as a schema is premature and will churn.
- **Better expressed as code.** A general-purpose language carries the design more honestly when control flow, recursion, or runtime computation is the essence of the problem rather than incidental to it.
