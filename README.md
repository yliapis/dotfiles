# dotfiles

run installation with the following command:

```sh
source install.sh
```

## Linux baseline packages

On non-macOS hosts the Brewfile is skipped unless `GUI_INSTALL=1`, and fresh
VMs and containers often lack basics like `zsh` or `rsync`. `install.sh` and
`refresh.sh` therefore run `scripts/bootstrap-packages.sh`, which detects the
system package manager — apt (Debian/Ubuntu), dnf/yum (Fedora/RHEL), pacman
(Arch), apk (Alpine), zypper (openSUSE) — and installs declarative lists
(macOS no-ops and keeps using the Brewfile):

- `packages/base.txt` — always: repo machinery + Homebrew-on-Linux prereqs
- `packages/gui.txt` — only when `GUI_INSTALL=1` (e.g. tilix)

Each line is one logical package, with per-manager name overrides where
distros disagree (`#` comments allowed; `-` skips a manager):

```text
procps           dnf=procps-ng pacman=procps-ng apk=procps-ng
build-essential  dnf=gcc,gcc-c++,make pacman=base-devel apk=build-base zypper=gcc,gcc-c++,make
```

On a brand-new VM or container it can run standalone, before anything else
(POSIX sh, so it works where bash/zsh are missing):

```sh
sh scripts/bootstrap-packages.sh                # add --dry-run to preview
sh scripts/bootstrap-packages.sh --dry-run --manager apk   # preview another distro
```

Re-runs are cheap: already-installed packages are skipped without sudo.

## Makefile

Common tasks are wrapped in a `Makefile`. List all targets with:

```sh
make help
```
