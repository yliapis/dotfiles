---
name: work-item-ticket
description: "Parameterized work-item ticket rendered once per ticket by the ticket-breakdown skill. Tokens are substituted from the normalized work item; frontmatter, the template-file comment, and italic guidance notes are stripped from the rendered ticket."
license: MIT
---

<!--
TEMPLATE FILE — not a rendered ticket. The ticket-breakdown skill
(./SKILL.md) reads this file at invocation time and renders it once per
ticket, substituting every {token} from the normalized work item per the
skill's Field Derivation rules. Rendering strips this comment, the YAML
frontmatter, and every *italic guidance note*. A custom {ticket_template}
may use any subset of the token vocabulary in SKILL.md's Template Contract;
this file is the canonical instance and uses all of it.
-->

# {ticket_id}: {title}

- **Type:** {type}
- **Severity:** {severity}
- **Priority:** {priority}
- **Labels:** {labels}
- **Estimate:** {estimate}
- **Source:** {source}
- **Source ref:** {source_ref}

*Metadata is single-line: `{type}` is the Conventional Commits type the fix
would carry; `{priority}` maps from `{severity}` (`critical` → `P0`, `major` →
`P1`, `minor` → `P2`, `nit` → `P3`, `unclassified` → `P2`); `{estimate}` is an
advisory t-shirt size; `{source_ref}` points into the analysis
(`<path>:<line-range>` or a section identifier).*

## Summary

{summary}

*1–3 sentences: what is wrong or missing and why it matters, standing on its
own for a reader who has not opened the analysis.*

## Context & Evidence

{context}

{evidence}

*`{context}` is a short paragraph of background the reader needs before the
evidence; `{evidence}` is a bulleted list quoting or referencing the analysis.
Every bullet traces to the source — nothing here is invented.*

## Scope

{where}

Out of scope: {out_of_scope}

*`{where}` lists the affected paths, symbols, or modules as bullets. The
out-of-scope line names the nearest tempting over-reach (adjacent refactors,
sibling findings ticketed separately) so the ticket stays one independently
shippable concern.*

## Acceptance Criteria

{done_when}

*A `- [ ]` checklist of observable checks: a command that passes, a behavior
that no longer reproduces, a document section that exists. The item's
`Done-when:` text lands here verbatim when the analysis supplied one.*

## Dependencies

{dependencies}

*Ticket ids whose completion this ticket's acceptance requires, as bullets —
typically ordering among fragments split from one composite item. `None.`
otherwise.*
