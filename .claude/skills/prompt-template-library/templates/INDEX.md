# Prompt Template Library

Catalog of seed skeletons used by the `prompt-template-library` skill when an agent is drafting a new prompt (typically via `/meta-prompt` or any equivalent flow). The skill picks one template per invocation and hands its body to the caller as the starting skeleton; the caller fills in the body and renders the final prompt.

For the selection behavior (auto-selection algorithm, interactive mode, fallback rules, composition with `/meta-prompt`), see `ai-coding/plugins/writing/skills/prompt-template-library/SKILL.md`. This file documents the library's data contract only.

## File-Level Convention

Every template lives at `templates/` as a Markdown file whose filename stem matches its `name` frontmatter field in kebab-case. Files outside this directory are not part of the catalog.

Each template MUST carry YAML frontmatter with at least these three fields:

- `name` (string, required) — the template's canonical identifier in kebab-case, matching the filename stem.
- `description` (string, required) — one sentence describing what kind of prompt this template seeds and when it fits.
- `tags` (list of strings, required) — a small set (typically 3-7) of lowercase trigger terms the auto-selector matches against the drafting intent. Tags should be specific (e.g., `security`, `pr-review`, `refactor`), not generic (e.g., `prompt`, `task`).

The template body below the frontmatter is the seed skeleton: any Markdown content the caller can use as a starting point.

## Reserved Files

- `INDEX.md` (this file) is not a template; it is the catalog index.
- `default.md` (when present) is the reserved fallback used by the skill when no other template scores above zero in auto-selection. It is excluded from auto-selection scoring but appears in the interactive picker.

## Auto-Selection in One Paragraph

In auto mode the skill builds an `intent_terms` set from the caller's drafting context (task description, requested output format, any inline user-supplied keywords), tokenizes each candidate's `tags`, `name`, and `description`, scores `+3` for a tag-token match, `+2` for a name-token match, and `+1` for a description-token match (highest weight per term, no double-counting), and picks the highest-scoring template. Ties break on lexicographically lowest `name`, then lowest filename. When every candidate scores zero, the skill falls back to `default.md`, or to an inline minimal skeleton when `default.md` is absent. The full procedure (tokenization rules, stopwords, scoring example) lives in the skill's SKILL.md.

## Adding a New Template

1. Pick a short kebab-case name that captures the prompt's intent (e.g., `code-review`, `bugfix-investigation`, `schema-design`). Avoid generic names (`helper`, `utility`).
2. Create `templates/` with a new Markdown file whose stem is the chosen name, carrying the required frontmatter:
   ```yaml
   ---
   name: <name>
   description: One-sentence summary of when this template fits.
   tags: [tag1, tag2, tag3]
   ---
   ```
3. Write the body as a Markdown skeleton. Mirror the section shape callers expect (typically `## Task`, `## Success Criteria`, `## Guardrails`, `## Workflow`, `## Output Format`, matching `/meta-prompt`'s Output Format). Leave per-prompt details as bracketed placeholders inside fenced blocks; the caller fills them in.
4. Append a one-line entry to the Catalog section below so the template is discoverable by humans browsing the index.
5. The template is now eligible for auto-selection on the next invocation; the skill makes no other registration step.

The skill does not enforce additional constraints beyond the three required frontmatter fields. Optional fields (e.g., `author`, `version`, `examples`) are permitted but not consulted by the auto-selector.

## Catalog

Update this list when adding or removing a template. The skill does not read this section; it is for human navigation only.

- `default.md` — generic fallback skeleton mirroring `/meta-prompt`'s Output Format. Reserved as the auto-selection fallback when no other template scores above zero.
- `code-review.md` — seed for prompts that review code changes (PRs, diffs, individual files) for quality, security, or correctness.

## What This Index Does Not Do

- It does not define selection logic. That logic lives in `prompt-template-library/SKILL.md`.
- It does not register templates. Adding a file to `templates/` is sufficient; updating the Catalog section above is for human readability only.
- It does not author or edit templates; that work is left to whoever is contributing the template.
