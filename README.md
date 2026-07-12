# dotfiles

run installation with the following command:

```sh
source install.sh
```

## Linux (apt) baseline

On non-macOS hosts the Brewfile is skipped unless `GUI_INSTALL=1`, and fresh
VMs often lack basics like `zsh` or `rsync`. `install.sh` and `refresh.sh`
therefore run `scripts/bootstrap-apt.sh`, which installs declarative package
lists on Debian/Ubuntu (and no-ops elsewhere):

- `packages/apt-base.txt` — always: repo machinery + Homebrew prerequisites
- `packages/apt-gui.txt` — only when `GUI_INSTALL=1` (e.g. tilix)

On a brand-new VM it can run standalone, before anything else:

```sh
bash scripts/bootstrap-apt.sh   # add --dry-run to preview
```

To add a package, add a line to the relevant list (`#` comments allowed).
Re-runs are cheap: already-installed packages are skipped without sudo.

## Makefile

Common tasks are wrapped in a `Makefile`. List all targets with:

```sh
make help
```
