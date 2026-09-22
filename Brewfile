# Brewfile — macOS package manifest. See Aptfile for the Ubuntu counterpart.
#
# Installed by scripts/packages_macos.sh via `brew bundle`.

# macOS-only: `mas` drives the Mac App Store, and cask-upgrade extends
# `brew cu` to casks. Neither has a Linux equivalent.
tap "buo/cask-upgrade"
brew "mas"

# Shell and terminal
brew "zsh"
brew "tmux"

# Core CLI tooling
brew "bat"
brew "fzf"
brew "gh"
brew "gnupg"
brew "lsd"
brew "pkgconf"
brew "ripgrep"
brew "sevenzip"
brew "telnet"
brew "uv"

# Python
brew "python@3.13"

# Databases and services
brew "mysql", restart_service: :changed
brew "opensearch"
brew "postgresql@14"
brew "valkey", restart_service: :changed
