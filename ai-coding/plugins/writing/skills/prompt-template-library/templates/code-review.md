---
name: code-review
description: Review code changes (pull requests, diffs, individual files) for quality, security, and correctness; emit a severity-grouped report.
tags: [code-review, pr-review, review, security, quality, correctness, refactor]
---

# Code Review: <short identifier for the change set>

## Task

Review the supplied code change against the named criteria and emit a single structured report grouping findings by severity, each finding citing a specific location and the criterion it violates.

## Parameters

- `{change_set}` — the artifact under review: PR URL, branch range (`base..head`), a list of file paths, or an inline diff. Required.
- `{criteria}` — categories to evaluate; optional, default: correctness, security, performance, readability, test coverage.
- `{severity_levels}` — severity labels in descending order; optional, default: `critical`, `major`, `minor`, `nit`.

## Success Criteria

- [ ] Every finding cites a specific location (file path plus line range or symbol name) and the criterion it relates to.
- [ ] Every finding carries a severity label drawn from `{severity_levels}` and a one-sentence rationale grounded in the code.
- [ ] Findings are grouped by severity in the rendered report; severity sections with no findings are omitted.
- [ ] The summary records counts per severity and names the single biggest concern in one sentence.
- [ ] No finding is raised without evidence quoted or referenced from the change.

## Guardrails

- MUST NOT modify any file in `{change_set}`; review is read-only.
- MUST NOT raise a finding without evidence cited from the change.
- MUST evaluate against `{criteria}` even when the reviewing model's defaults disagree; do not substitute model preferences for the named criteria.
- MUST distinguish blocking findings (`critical`, `major`) from non-blocking findings (`minor`, `nit`) in the summary.
- Scope: produce findings only. Out of scope: writing patches, opening PRs, running tests, or merging.

## Workflow

1. Resolve `{change_set}` to a concrete diff and the set of files touched.
2. Read every touched file with enough surrounding context to evaluate the change in place.
3. For each active criterion in `{criteria}`, walk the diff and record findings as `{location, criterion, severity, evidence, rationale}`.
4. Group findings by severity; deduplicate identical findings (same location plus criterion).
5. Render the report using the Output Format below.

## Output Format

A single Markdown report:

````markdown
# Code Review: <short identifier for the change set>

**Criteria applied:** <comma-separated list>
**Change set:** <resolved {change_set}>

## Summary
<2-4 sentences: overall assessment, counts by severity, biggest concern.>

## Findings

### Critical
- **<criterion>** @ `<path>:<line-range>`
  - Evidence: <short quote or reference>
  - Rationale: <one sentence>

### Major
- ...

### Minor / Nit
- ...
````
