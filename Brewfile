
tap "anomalyco/tap", trusted: { formula: "opencode" }
tap "darrylmorley/whatcable", trusted: { cask: "whatcable" } if OS.mac?
tap "getagentseal/codeburn", trusted: { formula: "codeburn" }
tap "hashicorp/tap", trusted: { formula: "terraform" }
tap "janekbaraniewski/tap", trusted: { formula: "openusage" }
tap "nicosuave/tap", trusted: { formula: "memex" }

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
brew "pv"
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
brew "tailscale" if OS.linux?
brew "telnet" if OS.mac?
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
brew "worktrunk"
brew "tuicr"
brew "backlog-md"
brew "pre-commit"
brew "yamllint"
brew "hyperfine"
brew "llama.cpp"

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

cask_args appdir: "/Applications" if OS.mac?

# web browers
cask "arc" if OS.mac?
cask "brave-browser" if OS.mac?
cask "google-chrome" if OS.mac?

# communication
cask 'discord' if OS.mac?
cask "slack" if OS.mac?
cask "signal" if OS.mac?
cask "telegram" if OS.mac?
cask "zoom" if OS.mac?

# productivity & media
cask "chatgpt" if OS.mac?
cask "claude" if OS.mac?
cask "dropbox" if OS.mac?
cask "linear" if OS.mac?
cask "microsoft-office" if OS.mac?
cask "notion" if OS.mac?
cask "notion-calendar" if OS.mac?
cask "spotify" if OS.mac?
cask "steam" if OS.mac?
cask "tad" if OS.mac?
cask "vlc" if OS.mac?

# development tools
brew "anomalyco/tap/opencode", trusted: true
brew "getagentseal/codeburn/codeburn", trusted: true
brew "herdr"
brew "nicosuave/tap/memex", trusted: true
brew "hermes-agent"
brew "janekbaraniewski/tap/openusage", trusted: true
cask "claude-code"
cask "codex"
cask "cursor"
cask "devin-cli"
cask "docker-desktop" if OS.mac?
cask "utm" if OS.mac?
cask "crystalfetch" if OS.mac?
cask "iterm2" if OS.mac?
cask "warp" if OS.mac?
cask "github" if OS.mac?
cask "postman" if OS.mac?
cask "postico" if OS.mac?
cask "sublime-text" if OS.mac?
cask "sublime-merge" if OS.mac?
cask "visual-studio-code" if OS.mac?
# cloud
brew "awscli"
brew "helm"
brew "k9s"
brew "kubernetes-cli"
cask "gcloud-cli"
# raspberry pi
cask "raspberry-pi-imager" if OS.mac?
# fonts
cask "font-jetbrains-mono-nerd-font"

# utilities
cask "apparency" if OS.mac?
cask "cyberduck" if OS.mac?
cask "daisydisk" if OS.mac?
cask "keepingyouawake" if OS.mac?
cask "ledger-wallet" if OS.mac?
cask "rectangle" if OS.mac?
cask "pearcleaner" if OS.mac?
cask "protonvpn" if OS.mac?
cask "tailscale-app" if OS.mac?
cask "raycast" if OS.mac?
cask "stats" if OS.mac?
cask "the-unarchiver" if OS.mac?
cask "darrylmorley/whatcable/whatcable", trusted: true if OS.mac?

###############################

# vscode settings
vscode "github.copilot-chat"
