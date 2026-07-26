# Change Contract

Loaded by the `operating-git` change and commit motions, and by
`operating-tickets` while executing a ticket.

Default to the smallest change that satisfies the request. A noisy diff makes review harder than the change itself, and most reviewer fatigue comes from edits that weren't asked for.

## What "minimal" means in practice

- **Change only what the task requires.** If asked to fix a bug, fix the bug — don't also rename variables, reformat the function, or tidy nearby code.
- **Preserve unrelated formatting.** Don't reflow whitespace, reorder imports, or normalize quotes/braces outside the lines you're already changing.
- **Match the existing code style.** If the file uses tabs, single quotes, or one specific pattern, follow it — even if your default would differ.
- **Prefer editing existing files over creating new ones.** Don't extract helpers, modules, or constants unless the task clearly requires it.
- **Don't add what wasn't asked for.** No new defensive checks, error wrapping, logging, type annotations, or "while I'm here" improvements unless they're part of the task.
- **No drive-by comments.** Don't add comments that narrate the code. Add comments only where intent is non-obvious and the code itself can't convey it.
- **Don't bundle unrelated cleanups.** If you spot something worth fixing outside the task's scope, surface it in your reply, not in the diff.

## When in doubt

If a broader refactor or cleanup would genuinely improve the change, call it out and ask before doing it — don't bundle it into the same diff.

If a small fix has both a clearly correct fix and a "better" fix, do the clearly correct one and surface the alternative in your message rather than in the diff.

## Examples

**Asked: "rename `getUser` to `fetchUser`"**

- Do: rename the symbol and update call sites. Nothing else.
- Don't: rename + reformat the file + add JSDoc + extract a helper.

**Asked: "fix the null pointer in `parseConfig`"**

- Do: add the null check that prevents the crash. Nothing else.
- Don't: add the null check + rewrite with early returns + extract the parsing logic.

**Asked: "add a `--verbose` flag"**

- Do: thread the flag through in the existing style. New code only, no surrounding cleanup.
- Don't: add the flag + refactor the CLI parser + reorganize the options module.
