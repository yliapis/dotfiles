# Concise Design

Turn a target that says too much — a doc, prompt, spec, skill card, or comment set — into its minimal faithful form. Every fact keeps exactly one canonical site, every surviving unit carries a job someone can name, and nothing the original committed to is lost. The deliverable is the tightened revision plus the audit that earns it: a cut log and a single-source map. The invariant: same facts, fewer words, still readable in one pass.

## When to Invoke

Name this trait when the user explicitly asks for one of:

- Concise, terse, or to-the-point design; "tighten this", "make it concise".
- Cutting repetition or redundancy; "say it once", "deduplicate this doc", "non-repeated".
- Trimming filler, boilerplate, hedging, or narration from a target.

Do not apply against unrelated edits. If the user has not asked for concision, leave the target alone. A concision pass churns text reviewers have already read; it pays back only when the user has asked for it.

## Design Walkthrough

Work the steps in order; each step depends on the steps above it, and each produces an artifact the next step consumes. If a concern does not apply to the user's domain, record that as a deliberate choice (with a one-line rationale) rather than silently skipping it.

1. **Unit inventory** — Question: what are the target's independently cuttable units of meaning (sections, paragraphs, list items, comments, functions)? Artifact: a numbered unit list with a one-line gloss each. Choose the granularity you could delete at; a piece that cannot be removed on its own belongs to a larger unit.
2. **Job assignment** — Question: what does each unit do for its reader — inform a decision, define a term, warn, instruct? Artifact: the unit list annotated with exactly one job per unit. A unit with two jobs is two units; a unit with none is a cut candidate.
3. **Duplicate map** — Question: which facts are stated more than once? Artifact: a fact list, each entry naming every site that states it. Restatement in different words is still duplication; back-references like "as mentioned above" and "in other words" mark the second site.
4. **Canonical site** — Question: for each duplicated fact, which single site owns it? Artifact: a fact → owning-site map; every other site becomes a cross-reference or a deletion. The owner is where the reader needs the fact first, not where it happened to be written first.
5. **Dead-weight cut** — Question: which units and phrases change nothing when deleted — throat-clearing, hedges, meta-narration, restated headings, the jobless units from step 2? Artifact: a cut list with a one-line reason per entry. Delete the candidate and reread; if no reader decision changes, the cut stands.
6. **Tighten survivors** — Question: can each remaining unit do its job in fewer words with no meaning lost? Artifact: the rewritten target. Prefer deleting a clause to abbreviating a term; keep qualifiers that change meaning ("idempotent", "at most once"), cut qualifiers that soften delivery ("note that", "fairly").
7. **Loss audit** — Question: does the revision still perform every job from step 2? Artifact: a job-by-job checklist mapping each job to the revision unit that now carries it. An orphaned job forces a restore from the cut list.
8. **Readability floor** — Question: does the revision read in one pass? Artifact: a pass/fail note per section, plus any words restored where it failed. A cut that makes the reader reread saved nothing; stop at clear, not at minimal.

## Worked Example

One documentation section, tightened. The first block is the input, the second is the revision, the third is the audit that accounts for every removed word.

```markdown
## Timeouts

The `timeout_ms` option is used to configure the request timeout. This timeout
controls how long the client will wait for a response before it gives up. The
default value for `timeout_ms` is 5000, which means that by default the client
waits five seconds. Note that it is important to be aware that retries (see
below) each get their own timeout. In other words, every retry attempt is
subject to its own `timeout_ms` window rather than sharing one. If you want to
disable the timeout entirely, you can set `timeout_ms` to 0.
```

```markdown
## Timeouts

`timeout_ms` caps how long the client waits for a response; `0` disables the
cap. Default: `5000`. Each retry attempt gets its own `timeout_ms` window.
```

```yaml
single_source_map:
  - fact: each retry attempt gets its own timeout window
    sites: [sentence 4, sentence 5]
    canonical: revision sentence 3

cut_log:
  - text: "The `timeout_ms` option is used to configure the request timeout."
    class: restated-heading
  - text: "which means that by default the client waits five seconds"
    class: derivable          # unit conversion the reader can do
  - text: "Note that it is important to be aware that"
    class: throat-clearing
  - text: "In other words, every retry attempt is subject to its own ..."
    class: duplicate          # second site; canonical kept in revision
  - text: "If you want to ... you can"
    class: hedge              # permission the reader already has

loss_audit:
  jobs: [define timeout_ms, state default, explain disabling, warn about retries]
  orphaned: []

size_delta:
  before_words: 91
  after_words: 24
```

## Deliverable

When this trait finishes, the user leaves with:

1. **A tightened revision** of the target — same jobs, same facts, materially fewer words; composed from the survivors of steps 5–6 and gated by steps 7–8.
2. **A cut log** — every deletion with a class (duplicate, derivable, restated-heading, throat-clearing, hedge, meta-narration, jobless unit) and a one-line reason; composed from steps 3 and 5.
3. **A single-source map** — every fact that appeared more than once, paired with the one site that now owns it; composed from step 4.

House style (tone, voice, formatting rules) and new content are not in the deliverable: this trait removes and consolidates; it never introduces facts the original did not carry.

## Validation & Verification

A conforming deliverable MUST satisfy every rule below. Each rule traces back to a specific decision in the walkthrough above; rules without a traceable origin are a smell.

- **Nothing lost.** Every job in the step-2 map is carried by a named unit of the revision (step 7). An orphaned job is a defect, not a style choice.
- **Nothing said twice.** Every fact in the duplicate map has exactly one defining site in the revision; other mentions are cross-references, never restatements (steps 3–4).
- **Every survivor works.** Each unit of the revision carries a job from the step-2 map; no unit survives on momentum (steps 2 and 5).
- **Every cut is accounted for.** The full diff between original and revision is covered by the cut log and the single-source map (steps 3 and 5).
- **Shorter and still readable.** The revision is materially smaller by word or line count and reads in one pass (steps 6 and 8).

Verify the deliverable by running these checks (each MUST pass before declaring the trait's work done):

1. Walk the loss-audit checklist: for each step-2 job, name the revision unit that performs it; restore from the cut log on any orphan.
2. For each fact in the single-source map, search the revision for the fact's key terms (`grep -n` per term); exactly one defining site may match.
3. Diff original against revision (`git diff --word-diff` or `diff -u`) and confirm every removed hunk appears in the cut log or the single-source map.
4. Reread the revision end-to-end fresh (or hand it to a second reader); restore words wherever a sentence needs a second pass or outside context. For code targets, the tests that passed before the pass MUST pass after.
5. Record the size delta (words or lines, before → after) in the report. The number is evidence, not a target.

## When Not To Use

- **Load-bearing redundancy.** Contracts, safety warnings, and normative spec text (RFC-style MUST restatements) repeat by design; deduplicating them changes what they enforce. Flag, don't cut.
- **Teaching material.** Tutorials restate one idea in a second form because the repetition is the pedagogy. Tighten wording inside each explanation; do not collapse the explanations into one.
- **Drafts still moving.** A concision pass on text that is being rewritten is wasted churn; let the content stabilize, then cut once.
- **Targets already at the floor.** When a pass yields only fragment-making cuts — dropped articles, telegraphic clauses — the target is done; further cutting trades comprehension for count.
- **An adjacent trait is a better fit.** When the duplication is structural — one fact defined in two schemas or two config formats — that is the declarative trait's schema-as-source-of-truth problem. Concise design fixes expression; declarative design fixes where data lives.

## Concise Principles

Frame every design decision around these. Each is a "do this, not that" choice, not an abstract value.

- **Every element earns its place** — a unit stays because a named job needs it, not because it was already written.
- **Say it once** — give each fact one canonical site; everywhere else, cross-reference it or trust the reader.
- **Cut before compressing** — delete units that do no work before rewording units that do; density comes from omission, not abbreviation.
- **Say it, don't announce it** — never narrate what the text is about to say or has just said.
- **Precision is not padding** — keep the qualifier that changes meaning; cut the one that softens delivery.
- **Stop at readable** — the floor is one-pass comprehension, not minimum word count; a cut that forces a reread saved nothing.
