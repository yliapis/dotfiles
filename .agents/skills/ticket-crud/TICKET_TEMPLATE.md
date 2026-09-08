---
name: ticket-crud-ticket-template
description: "Canonical versioned Markdown ticket template rendered by the ticket-crud skill."
license: MIT
---

<!--
TEMPLATE FILE — not a rendered ticket. ticket-crud reads this file at
invocation time, removes this metadata and comment, and renders the remaining
document once per normalized work item.
-->

{ticket_frontmatter}

# {ticket_id}: {title}

## Summary

{summary}

## Context and Evidence

{context}

{evidence}

## Scope

### In Scope

{scope}

### Out of Scope

{out_of_scope}

## Acceptance Criteria

{acceptance_criteria}

## Dependencies

{dependencies}

## Open Questions

{open_questions}
