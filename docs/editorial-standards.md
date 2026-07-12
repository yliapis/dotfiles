# Editorial Standards for LLM-Assisted Writing

A style guide and rulebook for long-form content drafted or co-authored by large language models.

---

## 1. Voice and Tone

### 1.1 Objective Authority
Write as an informed analyst presenting evidence, not as a pundit delivering verdicts. The reader should trust the work because the reasoning is visible, not because the prose sounds confident.

### 1.2 Attribution of Value Judgments
Never assert subjective rankings as objective fact. When a claim reflects someone's priorities or values, attribute it.

| Biased | Corrected |
|--------|-----------|
| They failed at the thing that matters more. | They failed at what policymakers said mattered more. |
| The real risk is choosing nothing. | Inaction carries more risk than a wrong choice, according to the firms we surveyed. |

If you cannot identify who holds the opinion, reconsider whether the sentence belongs in the piece.

---

## 2. Prose Cadence

The single most recognizable tell of LLM-generated prose is **staccato rhythm**: short, punchy, declarative sentences arranged in contrasting pairs or rapid-fire lists. This section defines the patterns to avoid and the techniques to use instead.

### 2.1 False-Contrast Pairs

The pattern: two short sentences where the first negates and the second asserts.

| Avoid | Use Instead |
|-------|-------------|
| This is not a theoretical argument. It is standard financial engineering. | This is standard financial engineering, not a theoretical exercise. |
| Washington is no longer trying to stop the flow of chips. It is taxing it. | Washington has shifted from trying to stop the flow of chips to simply taxing it. |
| It's not about speed. It's about survival. | The issue is survival, not speed. *(or merge into the surrounding paragraph)* |

**Fix**: Merge into a single sentence using "rather than," "instead of," a comma, or a subordinate clause. The contrast should land inside the sentence, not across a full stop.

### 2.2 Sentence-Fragment Lists

The pattern: three or more ultra-short declarative sentences in rapid succession for rhythmic punch.

| Avoid | Use Instead |
|-------|-------------|
| Routers fail. Disks fail. TCP packets corrupt. | Routers fail, disks fail, and TCP packets corrupt. |
| The gap widens. The cost compounds. The window closes. | The gap widens as costs compound and the window closes. |

**Fix**: Join with commas, conjunctions, or subordination. If the items are genuinely a list, use a comma-separated series. If they form a causal chain, connect them with "as," "while," or "and."

### 2.3 Dramatic One-Liner Closers

The pattern: a single punchy sentence at the end of a paragraph or section, designed as a mic-drop.

| Avoid | Use Instead |
|-------|-------------|
| Permanent resistance is a terminal diagnosis. | ...no compensation package reverses the damage once permanent resistance has set in. |
| The moat is zero. | ...but no individual customer holds any moat. |

**Fix**: Absorb the closer into the preceding sentence. If the thought is important enough to keep, it is important enough to earn a full clause with context.

### 2.4 Parallel Structure Overuse

The pattern: back-to-back sentences with identical grammatical construction.

| Avoid | Use Instead |
|-------|-------------|
| Every dollar of cloud spend reduces EBITDA. Every dollar of GPU CapEx is invisible to EBITDA. | Every dollar of cloud spend reduces EBITDA, whereas GPU CapEx is invisible to EBITDA entirely. |
| They do not wait for the company to fail. They leave when they realize... | Rather than waiting for the company to fail, they leave as soon as they realize... |

**Fix**: Vary the sentence structure. Use subordinate clauses ("whereas," "while," "rather than") to connect the two halves. One subject, one verb chain.

### 2.5 The Dramatic Pivot

The pattern: a sentence that exists solely to signal a reversal or hidden insight, often starting with "But here's the thing," "The real question is," or using headlines like "The X Nobody Talks About."

**Fix**: Cut the throat-clearing and state the point directly. If the section heading needs a label, make it descriptive rather than theatrical.

### 2.6 Compressed Negation Tags

The pattern: appending "not X" to the end of a clause as a punchy kicker.

| Avoid | Use Instead |
|-------|-------------|
| Export controls bought time, not advantage. | Export controls bought time without lasting advantage. |
| The talent exodus is the leading indicator, not the lagging one. | Talent flight precedes competitive decline, not the other way around. |

**Fix**: Expand "not X" into a prepositional phrase ("without," "rather than") or a full clause.

---

## 3. General Prose Rules

### 3.1 Connected Phrases Over Sequential Declarations
A paragraph should flow through an argument, not stack assertions. If you can hear a drumbeat when you read it aloud, rewrite it.

### 3.2 Vary Sentence Length
Mix longer analytical sentences (25-40 words) with shorter ones (8-15 words). The problem is never a short sentence on its own; it is five short sentences in a row.

### 3.3 Earn Your Emphasis
Bold, italics, and short sentences all serve the same function: emphasis. Use one at a time, sparingly.

### 3.4 Lead with Evidence, Not Verdict
Present the data or observation first, then the interpretation. The reader should be able to form their own conclusion before you state yours.

### 3.5 Eliminate Weasel Words
This includes both vague qualifiers ("some," "many," "significant," "arguably," "it is widely believed," "experts say") and throat-clearing preambles ("It is worth noting that," "It is important to understand that," "The key takeaway here is"). Either name the source, provide the number, or cut the qualifier entirely. If a claim cannot be backed with a citation or data point, the sentence is not ready to publish. If a preamble adds no information, start with the substance.

### 3.6 Avoid the Paradox Formula
"X did the opposite of what it intended" is a valid observation stated once. Repeating the ironic-reversal framing across multiple sections makes the piece feel like it has one rhetorical move.

---

## 4. Content Structure

### 4.1 Articles
Each article follows this structure:
1. **Hero section**: title, author, date
2. **Lead paragraph**: one-paragraph summary of the thesis
3. **Analysis sections**: evidence-first prose with section headers
4. **Data elements**: structured data supporting the analysis
5. **Assessment**: explicit evaluation
6. **Conclusions**: numbered takeaways, each with a bold lead sentence followed by supporting evidence

### 4.2 Table of Contents
Each entry shows the title, a brief description, and a link to the full article.

---

## 5. Pre-Publish Checklist

- [ ] **5.1** Read the piece aloud. Flag any passage where you hear a rhythmic drumbeat of short, parallel sentences.
- [ ] **5.2** Search for "not" followed by a period within two sentences: likely a false-contrast pair.
- [ ] **5.3** Search for three or more consecutive sentences under 10 words each: likely a fragment list.
- [ ] **5.4** Count em dashes. More than two per page indicates connector monotony.
- [ ] **5.5** Verify all value judgments are attributed to a source, stakeholder, or defined perspective.
- [ ] **5.6** Confirm no sentence exists solely as a mic-drop closer.
- [ ] **5.7** Check that weasel words are backed by a named source or a number.