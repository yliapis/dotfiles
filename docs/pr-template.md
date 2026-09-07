# Pull request template

Use this body with `gh pr create`. Commit messages follow the
`conventional-commits` skill.

Package-manifest PRs (`manage-packages`) squash-merge with a subject like
`chore(brew): add <token> <kind>` (`(#80)` on main). Scope `brew`, `mas`,
`snap`, `uv`, or `vscode` when every change shares that manager; otherwise
`packages`.

```
chore(brew): add utm cask

Install the official Homebrew cask for UTM so brew
bundle provisions the free hypervisor GUI on macOS.
```

## Body

````markdown
Adds the official Homebrew <kind> for <name> so `brew bundle` installs it.

```sh
brew install [--cask] <name>
```

<tap / gate / mas-vs-cask rationale>

## Verification

Cloud VMs do not have Homebrew, so this was checked with a Brewfile
OS-gate parse and the live formulae.brew.sh API:

- exact line
- tap / no extra tap
- Linux eval vs macOS eval
- API: token, tap, disabled, deprecated, version, platform
````

For snap / uv / vscode, swap the install command and API. Keep the
Verification heading.
