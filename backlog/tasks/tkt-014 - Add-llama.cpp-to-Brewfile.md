---
id: TKT-014
title: Add llama.cpp to Brewfile
status: Done
assignee: []
created_date: '2026-08-19 01:09'
updated_date: '2026-08-19 01:09'
labels: []
dependencies: []
references:
  - 'https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md'
  - 'https://formulae.brew.sh/formula/llama.cpp'
priority: medium
type: chore
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add the official Homebrew package for llama.cpp so brew bundle installs it on Mac and Linux.

Upstream install docs: https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md (`brew install llama.cpp`). Formula is homebrew/core; no extra tap.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Brewfile contains brew "llama.cpp"
- [x] #2 No extra Homebrew tap is added for llama.cpp
- [x] #3 The llama.cpp formula line is not OS-gated, matching upstream Mac and Linux Homebrew support
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add brew "llama.cpp" to the Brewfile development tooling section.
2. Do not add a tap; the formula is homebrew/core.
3. Leave the line unguarded so Mac and Linux brew bundle both request it.
4. Verify against formulae.brew.sh and a Brewfile parse.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2026-08-19 on this worktree. Cloud VM has no Homebrew, so evidence is Brewfile parse plus the live formulae.brew.sh API.

- AC1: Brewfile:104 is brew "llama.cpp"
- AC2: grep finds no llama.cpp tap; only the core formula line
- AC3: that line has no if OS.mac? / if OS.linux?
- formulae.brew.sh: name=llama.cpp tap=homebrew/core disabled=false; bottles include sonoma, arm64_sonoma, x86_64_linux, arm64_linux; stable=10470

Log: /opt/cursor/artifacts/llama_cpp_brewfile_verify.log
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added brew "llama.cpp" to the Brewfile development tooling section. The formula is homebrew/core (Mac and Linux), matching https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md. All three acceptance criteria have runtime evidence in llama_cpp_brewfile_verify.log.
<!-- SECTION:FINAL_SUMMARY:END -->
