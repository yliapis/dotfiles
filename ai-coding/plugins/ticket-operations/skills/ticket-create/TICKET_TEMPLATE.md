---
name: ticket-create-ticket-template
description: "Canonical rich Markdown ticket body rendered by the ticket-create skill."
license: MIT
---

<!--
TICKET-CREATE TEMPLATE
The ticket-create skill reads this file at invocation time, removes this
template metadata and comment, and substitutes the declared tokens. This file
is not a ticket and carries no lifecycle state.
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
