---
name: {trait}-design
description: "{One-sentence definition of what this skill turns into what artifact, e.g. 'Turn a domain into a YAML DSL schema and worked instance.'} Use when the user explicitly asks for {trait} design, {variant phrase 1}, or {variant phrase 2}. Manually invoked only — do not apply against unrelated edits."
license: MIT
---

<!--
TEMPLATE FILE — not a real skill. Replace every {placeholder} when authoring a new
<trait>-design/SKILL.md. The design-skill meta-skill (../design-skill/SKILL.md) consumes
this template at runtime to scaffold new trait-design skills; it depends on the section
names and section order below being stable across versions. Section bodies are the
author-supplied parts. Remove this comment and the *italic guidance notes* throughout
when filling the template.
-->

# {Trait Title} Design

{One-paragraph framing: name the journey ("turn X into Y"), the deliverable shape (data, schema, refactor patch, audit checklist), and the key invariant the skill enforces.}

*The framing paragraph is the elevator pitch for an LLM that may have only this paragraph in context. Make every word earn its place.*

## When to Invoke

This skill is manually invoked. Apply it only when the user explicitly asks for one of:

- {Explicit phrase 1}
- {Explicit phrase 2}
- {Explicit phrase 3}

Do not apply against unrelated edits. If the user has not asked for {trait}, leave the target alone.

*Calibrate the trigger phrase list to the trait's natural English: a deterministic-design trigger says "reproducibility" or "bit-identical output"; a declarative-design trigger says "DSL", "schema", "domain modeling". The "manually invoked" guard is non-negotiable; every trait skill in this family fights against premature auto-attachment.*

## Design Walkthrough

Work the steps in order; each step depends on the steps above it, and each produces an artifact the next step consumes. If a concern does not apply to the user's domain, record that as a deliberate choice (with a one-line rationale) rather than silently skipping it.

1. **{Step 1 name}** — Question: {what does this step ask?}. Artifact: {what does this step produce?}. {Optional one-sentence heuristic that calibrates the answer.}
2. **{Step 2 name}** — Question: {...}. Artifact: {...}. {heuristic}.
3. **{Step 3 name}** — Question: {...}. Artifact: {...}. {heuristic}.

*The `**{Step N name}**` slug is what the controller's walkthrough header-resolution rule (see [../designer-controller/SKILL.md](../designer-controller/SKILL.md)) keys on. Keep step names short, descriptive, and stable across schema versions; existing trait skills run 7–15 steps, but smaller is fine if the trait is narrow.*

## Worked Example

{One concrete instance that exercises the interesting cases of the walkthrough above.}

```yaml
# {fenced example artifact}
```

*Size the example to fit on one screen. Show the inputs and the resulting deliverable. Prefer a cohesive end-to-end example over a fragmentary one; readers learn the skill by reading the worked example.*

## Deliverable

When this skill finishes, the user leaves with:

1. **{Artifact 1}** — {one-sentence description; cite the section it composes from}.
2. **{Artifact 2}** — {one-sentence description}.
3. **{Artifact 3}** — {one-sentence description}.

{One-sentence note on what is NOT in the deliverable, e.g. "Choice of validator library, codegen tool, or runtime is the user's call and outside this skill's scope."}

*The deliverable is the contract between this skill and the user. Authors should be able to point at every artifact and say which section produced it. Adjacent runtime concerns (validators, codegen, deploy tooling) are typically out of scope and should be named as such.*

## Validation & Verification

A conforming deliverable MUST satisfy every rule below. Each rule traces back to a specific decision in the walkthrough above; rules without a traceable origin are a smell.

- **{Rule 1}.** {Constraint phrased as a checkable invariant. Cite the walkthrough step it comes from.}
- **{Rule 2}.** {constraint}.
- **{Rule 3}.** {constraint}.

Verify the deliverable by running these checks (each MUST pass before declaring the skill done):

1. {Check 1: a concrete command, procedure, or comparison.}
2. {Check 2.}
3. {Check 3.}

*Validation states the contract; verification proves the deliverable honors it. When a check genuinely cannot apply to a target (e.g., the trait does not deal with reproducibility, so a `sha256sum` parity check is irrelevant), record that explicitly with a one-line rationale rather than silently skipping it.*

## When Not To Use

- **{Anti-case 1}.** {One sentence on why this skill fights the domain in this case; what the user should do instead.}
- **{Anti-case 2}.** {one sentence}.
- **{Anti-case 3}.** {one sentence}.
- **{Adjacent skill is a better fit}.** {If another trait-design skill or a non-design tool covers the case better, name it.}

*The "When Not To Use" section is what makes the skill safe to auto-attach against bare phrasings. The longer this section, the safer the skill.*

## {Trait} Principles

Frame every design decision around these. Each is a "do this, not that" choice, not an abstract value.

- **{Principle 1}** — {Imperative framing. State the choice the skill makes, not the value it nominally upholds.}
- **{Principle 2}** — {imperative framing}.
- **{Principle 3}** — {imperative framing}.
- **{Principle 4}** — {imperative framing}.

*Principles live last because by this point the reader has seen the walkthrough, the worked example, the deliverable, and the validation contract. The principles' job is to summarize the worldview the rest of the skill has already enacted, not to introduce it.*
