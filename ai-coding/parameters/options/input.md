# `input` — raw user text meta-prompt classifies into a mode

Everything the user typed after `/meta-prompt`; raw text whose first job
is classification into HELP / CREATE / REFINE mode. `key=value` tokens
(`n=`, `k=`, `update-mode=`, `style(s)=`) and flags are parsed out of it
and stripped before mode detection. Empty input selects HELP.

- **Used by:** meta-prompt
- **Full entry:** [concerns/intent.md](../concerns/intent.md#artifact-specific)
