
tap "anomalyco/tap"
tap "darrylmorley/whatcable"
tap "getagentseal/codeburn"
tap "hashicorp/tap"
tap "nicosuave/tap"

###############################
#     cli tools               #
###############################

# standard tools for cli
# note existing tools are included in this list to ensure they are up to date

# shells
brew "bash"
brew "fish"
brew "zsh"

brew "starship"

# general tools
brew "coreutils"
brew "dasel"
brew "direnv"
brew "duckdb"
brew "gcc"
brew "gpg"
brew "gpg2"
brew "grep"
brew "gum"
brew "neovim"
brew "rsync"
brew "shellcheck"
brew "shfmt"
# tldr was disabled in homebrew-core 2025-10-24 as unmaintained upstream.
# Use tlrc or tealdeer for tldr pages instead.
# brew "tldr"
brew "tmux"
brew "watch"
brew "unzip"
brew "vim"
brew "xz"
brew "z"
brew "zip"

# file viewing tools
brew "bat"
brew "eza"
brew "glow"
brew "hexyl"
brew "jq"
brew "yq"
brew "visidata"

# filesystem search tools
brew "broot"
brew "dust"
brew "findutils"
brew "fd"
brew "fzf"
brew "ncdu"
brew "ranger"
brew "ripgrep"
brew "tree"

# network tools
brew "net-tools" if OS.linux?
brew "arp-scan"
brew "cloudflared"
brew "curl"
brew "httpie"
brew "mtr"
brew "nmap"
brew "openssh"
brew "openssl@3"
brew "rclone"
brew "telnet"
brew "wget"

# system monitoring / top alternatives
brew "btop"
brew "bottom"
brew "htop"
brew "glances"
brew "gtop"
brew "nvtop"

# development tooling
brew "make"
brew "git"
brew "git-lfs"
brew "gh"
brew "git-delta"
brew "lazygit"
brew "backlog-md"
brew "pre-commit"
brew "yamllint"
brew "hyperfine"

# languages
brew "go"
brew "lua"
brew "node"
brew "hashicorp/tap/terraform", trusted: true
brew "opentofu"

# set system python3 as 3.12
brew "python@3.12"
# python tooling
brew "pipx"
brew "pyenv"
# uv also drives scripts/install-doc-tools.sh (docling, markitdown, ...)
brew "uv"
brew "ruff"
brew "ty"
brew "mypy"

###############################
#     macOS Apps              #
###############################

# via Cask

cask_args appdir: "/Applications"

# web browers
cask "arc"
cask "brave-browser"
cask "google-chrome"

# communication
cask 'discord'
cask "slack"
cask "signal"
cask "telegram"
cask "zoom"

# productivity & media
cask "chatgpt"
cask "claude"
cask "dropbox"
cask "linear"
cask "microsoft-office"
cask "notion"
cask "notion-calendar"
cask "spotify"
cask "steam"
cask "tad"
cask "vlc"

# development tools
brew "anomalyco/tap/opencode", trusted: true
brew "getagentseal/codeburn/codeburn", trusted: true
# agent multiplexer for running multiple coding agents in one terminal
brew "herdr"
brew "nicosuave/tap/memex", trusted: true
brew "hermes-agent"
cask "claude-code"
cask "codex"
cask "cursor"
cask "devin-cli"
cask "docker-desktop"
cask "iterm2"
cask "warp"
cask "github"
cask "postman"
cask "postico"
cask "sublime-text"
cask "sublime-merge"
cask "visual-studio-code"
# cloud
brew "awscli"
brew "helm"
brew "k9s"
brew "kubernetes-cli"
cask "gcloud-cli"
# raspberry pi
cask "raspberry-pi-imager"
# fonts
cask "font-jetbrains-mono-nerd-font"

# utilities
cask "apparency"
cask "cyberduck"
cask "daisydisk"
cask "keepingyouawake"
cask "ledger-wallet"
cask "rectangle"
cask "pearcleaner"
cask "protonvpn"
cask "raycast"
cask "stats"
cask "the-unarchiver"
cask "darrylmorley/whatcable/whatcable", trusted: true

###############################

# vscode settings
vscode "github.copilot-chat"
