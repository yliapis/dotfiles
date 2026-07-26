---
name: ticket-create-ticket-template
description: "Canonical ticket-operations/ticket-v1 Markdown template read and rendered by the ticket-create skill."
license: MIT
---

<!-- TICKET-CREATE TEMPLATE
This is a template, not a ticket. ticket-create removes this comment and the
template metadata above, validates the remaining token vocabulary, and renders
the document below once per normalized work item. The second YAML block becomes
the rendered ticket's frontmatter.
-->

---
schema: ticket-operations/ticket-v1
id: {ticket_id}
title: {title_yaml}
status: {status}
status_reason: {status_reason_yaml}
revision: {revision}
type: {type}
severity: {severity}
priority: {priority}
estimate: {estimate}
labels:
{labels_yaml}
batch_id: {batch_id}
spec_digest: {spec_digest}
source:
  kind: {source_kind}
  identifier: {source_identifier_yaml}
  digest: {source_digest}
  refs:
{source_refs_yaml}
dependencies:
{dependency_ids_yaml}
extensions: {{}}
---

# {ticket_id}: {title}

## Summary

{summary}

## Context and Evidence

{context}

{evidence}

## Scope

### In scope

{where}

### Out of scope

{out_of_scope}

## Acceptance Criteria

{done_when}

## Dependencies

{dependencies}
