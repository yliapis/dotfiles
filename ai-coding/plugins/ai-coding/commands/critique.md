# Critique

## Task
Critically analyze a prompt, code, or software artifact against a set of criteria and produce a structured report of findings.

## Parameters
- `{context}` — the artifact to analyze: file path, directory path, URL, or inline content. Required.
- `{criteria}` — judgment criteria as a file path, directory path, or inline text. Optional, default: quality (clarity, correctness, completeness, robustness) and determinism (reproducibility, idempotency, stable outputs across runs).
- `{model}` — model to use for each analysis run. Optional, default: parent agent's model.
- `{parallel}` — maximum concurrent analysis threads. Optional, default: `1`.
- `{num_experiments}` — number of independent analysis runs to perform. Optional, default: `1`.

## Success Criteria
- [ ] The report header restates the resolved `{context}`, the active criteria, `{model}`, `{num_experiments}`, and `{parallel}`.
- [ ] Every finding cites a specific location in `{context}` (file path, line range, section identifier, or quoted span).
- [ ] Every finding names the specific criterion from `{criteria}` it relates to.
- [ ] Every finding carries a severity label (`critical`, `major`, `minor`, or `nit`) and a one-sentence rationale grounded in evidence.
- [ ] When `{num_experiments} > 1`, the report distinguishes convergent findings (raised by multiple runs) from divergent findings (raised by some) and records the agreement count per finding.
- [ ] When `{context}` is ambiguous, partially inaccessible, or out of scope for `{criteria}`, the report names the gap explicitly in an Open Questions section instead of guessing.

## Guardrails
- MUST NOT modify `{context}` or any other file; analysis is read-only.
- MUST NOT raise a finding without evidence quoted or referenced from `{context}`.
- MUST evaluate against `{criteria}` even when it conflicts with the analyzing model's defaults; do not substitute the model's own preferences.
- MUST honor the requested replication: prefer parallel execution up to `{parallel}` workers; fall back to sequential only when a tool, rate limit, or shared state forbids parallel execution, and note the fallback in the report.
- Scope: produce findings only. Do not propose code edits, write patches, or open PRs unless `{criteria}` explicitly requests recommendations.

## Workflow
1. Resolve `{context}`: read the referenced file/directory contents or accept inline data; record what was loaded and what was skipped or unreachable.
2. Resolve `{criteria}`: read the referenced criteria or apply the default quality + determinism set; restate the active criteria in the report header.
3. Plan replication: schedule `{num_experiments}` independent analysis runs, dispatching up to `{parallel}` at a time using `{model}`.
4. For each run, evaluate `{context}` against every active criterion and emit findings of the form `{location, criterion, severity, evidence, rationale}`.
5. Aggregate across runs: merge identical findings (same location + same criterion), record the agreement count per finding, and list divergent findings separately.
6. Render the final report using the Output Format.

## Output Format
A single markdown report with these sections:

```markdown
# Critique: <short identifier for {context}>

**Criteria applied:** <list>
**Runs:** <num_experiments> (parallel up to <parallel>, model: <model>)

## Summary
<2–4 sentences: overall assessment, count by severity, biggest concern.>

## Findings

### Critical
- **<criterion>** @ `<location>` (<N>/<num_experiments> runs)
  - Evidence: <short quote or reference>
  - Rationale: <one sentence>

### Major
- ...

### Minor / Nit
- ...

## Divergent Findings
<Only when num_experiments > 1; findings raised by some but not all runs, with run counts.>

## Open Questions
<Ambiguities in {context} or {criteria} that blocked a confident judgment.>
```
