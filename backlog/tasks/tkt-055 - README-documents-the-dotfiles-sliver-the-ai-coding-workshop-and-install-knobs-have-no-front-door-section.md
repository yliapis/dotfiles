---
id: TKT-055
title: >-
  README documents the dotfiles sliver; the ai-coding workshop and install knobs
  have no front-door section
status: To Do
assignee: []
created_date: '2026-09-08 21:40'
labels:
  - readme
  - docs
  - 'estimate:S'
  - critique-fable-2026-07-12
  - critique-visual-2026-07-24
dependencies: []
references:
  - >-
    docs/reports/repo-critique-claude-fable-5-thinking-max-2026-07-12T21-25-54Z-019f57dc.md:160-166
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:308-337'
  - 'docs/reports/repo-critique-visualizations-2026-07-24.html:564'
  - 'README.md:1-71'
  - 'install.sh:28-49'
priority: medium
type: docs
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The visual critique measured `ai-coding/` at 96.9% of tracked lines and noted the README never mentioned it. Since then the README gained "Project mirrors" and "Cloud Agents" sections, so the mirror mechanics are documented, but the front door still describes the repo as shell config: nothing explains what the ten plugins under `ai-coding/plugins/` provide (17 skills, 11 commands, agents), how to consume them (`make sync`, the `.cursor-plugin` / `.claude-plugin` marketplace manifests, the repo-root mirrors), or which environment knobs drive `install.sh`.

### Evidence (main @ 225cbf2, 2026-09-08)

- `README.md` sections: intro (`source install.sh`, refresh), Makefile, Project mirrors, Cloud Agents. No section names the plugins, skills, or commands as the product.
- `install.sh:28-49` is the only place `BREW_BUNDLE`, `BREW_BUNDLE_MAS`, `HERDR_PLUGIN_INSTALL`, `APT_UPGRADE`, `CLEAR_CACHE`, `RERUN_INSTALL`, `REFRESH_BREWFILE`, and `REFRESH_SCRIPTS` are documented; `README.md` mentions none of them.
- `ai-coding/plugins/` holds 10 plugins; `.cursor-plugin/marketplace.json` and `.claude-plugin/marketplace.json` already describe each in one line usable as README copy.

### Provenance

Visual critique 2026-07-24 (finding 01 "identity", recommendation 4 "Rewrite the README for what the repo is"), Fable 2026-07-12 (minor: every behavioral knob is discoverable only by reading source).

### Scope

- `README.md`. Keep the entry-point wording consistent with TKT-025; this ticket adds the missing sections rather than deciding the invocation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 README has an ai-coding section that names the plugins with one line each, states where skills, commands, and agents live, and explains the three consumption paths (home-dir sync, project mirrors, marketplace install)
- [ ] #2 README lists or links every install.sh environment knob documented in the script header
- [ ] #3 Every link in README resolves (checked with a link checker or by opening each target)
<!-- AC:END -->
