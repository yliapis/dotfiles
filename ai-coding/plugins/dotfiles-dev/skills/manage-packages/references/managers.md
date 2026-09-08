# Package manifests

Read this from `SKILL.md` before the first edit. Paths are repo-relative.

## Catalog

| Manager | Manifest | When to use |
|---|---|---|
| `brew` | `Brewfile` | Homebrew formulae, casks, taps, and `vscode` extensions that live in the Brewfile |
| `mas` | `Brewfile.mas` | Homebrew + Mac App Store (`brew bundle` runs `mas` lines); installed when `BREW_BUNDLE_MAS=1` |
| `snap` | `scripts/snap-installs.sh` | Ubuntu snap lines (`sudo snap install …`) |
| `uv` | `scripts/install-doc-tools.sh` | `uv tool install` specs |
| `vscode` | `Brewfile` (`vscode "…"` lines) | VS Code / Cursor extension ids |

There is no apt package list. `install.sh` only runs `apt update` /
`apt upgrade`. If the user asks to add an apt package, abort.

Do not create a new manifest. If a later `Brewfile.*` or
`scripts/*-installs.sh` appears, read it and treat it as that manager;
do not invent a third file for the same manager.

## Kind resolution (`manager=auto` or `kind=auto`)

Probe in this order. Stop at the first rule that binds:

1. **Already present.** A matching token in a catalog file wins. `delete`
   and `update` use that file.
2. **homebrew/core formula.** `GET https://formulae.brew.sh/api/formula/<name>.json`
   returns 200 and `disabled` is false → `brew` formula. Prefer this for
   CLI tools even when a cask of the same token exists.
3. **homebrew/cask.** `GET https://formulae.brew.sh/api/cask/<token>.json`
   returns 200 and `disabled` is false → `brew` cask. Prefer this over
   `mas` when both exist (CrystalFetch: cask shipped, MAS unused).
4. **Existing Brewfile tap.** Only when the user names that tap or
   upstream install docs require it. Add both the `tap` line (with
   `trusted:`) and the fully-qualified `brew` / `cask` line.
5. **mas.** Use only when there is no Homebrew cask and the user wants
   the App Store build, or `brew search` returns unrelated tokens (LightBlue
   → lighthouse / lightburn). Prove the id with the iTunes lookup API and
   require `MacDesktop` in `supportedDevices`.
6. **snap / uv / vscode.** Only when the user names that manager, or the
   token already lives in that manifest.

Abort when two different products share the token and the rules above do
not separate them. Do not guess a third-party tap.

Treat HTTP 404 on both formula and cask APIs as "not on core/cask", then
continue to steps 4–6. Treat `disabled=true` as unusable for `add`.

## OS gates (`gate=auto`)

Brewfile uses postfix `if OS.mac?` / `if OS.linux?` (see TKT-013).

| Package | Gate |
|---|---|
| macOS GUI app (cask or tap that needs `/Applications`) | `if OS.mac?` |
| Formula that requires macOS (or arm64-only macOS, e.g. `macmon`) | `if OS.mac?` |
| Linux-only formula (`net-tools`) | `if OS.linux?` |
| Cross-platform formula with mac + linux bottles (`pv`) | none |
| Formula that Linux installs another way (`llama.cpp`) | `if OS.mac?` |
| Linux-capable CLI cask | none |

CLI casks that stay unguarded so Linux `BREW_BUNDLE=1` still gets them:
`claude-code@latest` (was `claude-code`), `codex`, `cursor`, `devin-cli`,
`gcloud-cli`, `font-jetbrains-mono-nerd-font`. Do not add `if OS.mac?` to
that set. Derive the live set from the Brewfile (`cask` lines with no
OS postfix) rather than treating this list as the only truth.

`cask_args appdir: "/Applications"` stays `if OS.mac?`.

`Brewfile.mas` runs only on macOS; do not add OS postfix there.

## APIs

```sh
# Homebrew (cloud VMs often have no brew binary)
curl -fsS "https://formulae.brew.sh/api/formula/${NAME}.json"
curl -fsS "https://formulae.brew.sh/api/cask/${TOKEN}.json"

# Mac App Store
curl -fsS "https://itunes.apple.com/lookup?id=${ID}"

# Snap
curl -fsS -H "Snap-Device-Series: 16" \
  "https://api.snapcraft.io/v2/snaps/info/${NAME}"

# uv / PyPI
curl -fsS "https://pypi.org/pypi/${DIST}/json"
```

Record from Homebrew JSON: `name` or `token`, `tap`, `disabled`,
`deprecated`, `version` / `stable`, bottles or `os_requirements`.
A Linux bottle (`x86_64_linux` or `arm64_linux`) means the formula
stays unguarded unless the formula itself requires macOS or Linux
installs it another way (`llama.cpp` → `scripts/install-llama.cpp.sh`).

When `brew` is on PATH, `brew info` / `brew search` / `brew bundle list
--file=…` may supplement the API. They do not replace it.

## Brewfile placement and syntax

Taps live at the top, C-locale sorted, Homebrew 6 trust syntax:

```ruby
tap "janekbaraniewski/tap", trusted: { formula: "openusage" }
tap "darrylmorley/whatcable", trusted: { cask: "whatcable" } if OS.mac?

brew "janekbaraniewski/tap/openusage", trusted: true
cask "darrylmorley/whatcable/whatcable", trusted: true if OS.mac?
```

Put the package line in the matching section (shells, general tools,
file viewing, filesystem search, network, system monitoring, development
tooling, languages, python tooling, macOS Apps categories, cloud, fonts,
utilities, vscode). Sit next to related packages. When that subsection
is already alphabetical, keep it so.

`add` inserts one line. `delete` removes the line (and the tap if unused).
`update` rewrites the token / spec in place (`linear-linear` → `linear`,
`claude-code` → `claude-code@latest`). To retire an unmaintained core
formula without deleting history, comment it out with a reason, as `tldr`
was:

```ruby
# tldr was disabled in homebrew-core 2025-10-24 as unmaintained upstream.
# Use tlrc or tealdeer for tldr pages instead.
# brew "tldr"
```

Map that to `action=update` with `to=disable` plus a reason in the body.

Double quotes are the Brewfile default. Do not restyle neighbors.

## Snap, uv, and Linux official installers

`scripts/snap-installs.sh` is a linear list of `sudo snap install` lines
(`--classic` when the snap requires it). Insert next to related snaps.
Do not add a snap when the user asked for Homebrew.

Linux Tailscale is `scripts/install-tailscale.sh`, which runs
https://tailscale.com/install.sh (apt on Ubuntu). Do not add
`brew "tailscale"`. macOS uses `cask "tailscale-app" if OS.mac?`.

Linux llama.cpp is `scripts/install-llama.cpp.sh`, which runs
https://llama.app/install.sh (probes CUDA, then ROCm, Vulkan, CPU).
Keep `brew "llama.cpp" if OS.mac?`. Do not leave that formula unguarded.

`scripts/install-doc-tools.sh` installs via `install_uv_tool <spec>`.
Add or remove one call. Leave commented opt-in tools commented unless
the user asks to enable them.

## Historical loop (what this skill encodes)

| Change | Pattern |
|---|---|
| Add core formula (`pv`, `ty`) | Unguarded `brew "name"` in the matching CLI section; API bottles include mac + linux |
| Add macOS-only formula (`macmon`) | `brew "name" if OS.mac?` |
| Linux official install.sh (`tailscale`, `llama.cpp`) | `scripts/install-<name>.sh`; brew/cask only on macOS |
| Add GUI cask (`utm`, `crystalfetch`) | `cask "name" if OS.mac?`; no tap when homebrew/cask ships it |
| Add CLI cask (`devin-cli`, `codex`) | Unguarded `cask "name"` next to other agent CLIs |
| Add third-party formula (`openusage`) | Trusted tap + fully-qualified `brew "tap/name", trusted: true` |
| Add third-party cask (`whatcable`) | Trusted tap gated `if OS.mac?` + trusted cask line |
| Add MAS app (`LightBlue`) | `Brewfile.mas` only; prove no Homebrew cask |
| Rename (`linear-linear` → `linear`) | In-place token swap |
| Retarget (`claude-code` → `@latest`) | Swap token; note `conflicts_with` when the API declares it |
| Disable unmaintained (`tldr`) | Comment out with reason |
| Delete discontinued (`messenger`) | Remove the line |
