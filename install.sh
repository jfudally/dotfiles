#!/usr/bin/env bash
#
# install.sh — Install these dotfiles onto a macOS or Ubuntu/Debian host.
#
# Usage:
#   ./install.sh
#
# Environment overrides (mainly for tests and CI):
#   DOTFILES_OS_OVERRIDE=macos|ubuntu   force the detected platform
#   DOTFILES_SKIP_PACKAGES=1            install configs only, no packages
#   DOTFILES_SKIP_SUBMODULES=1          do not run git submodule init/update
#   HOME=<dir>                          install into an alternate home
#
# What it does:
#   1. Syncs the git submodules (oh-my-zsh and its two plugins).
#   2. Backs up and installs the shell config files into $HOME.
#   3. Installs oh-my-zsh plus the bundled plugins.
#   4. Stages the platform's package manifest under ~/.local/env and installs
#      it via Homebrew (macOS) or apt (Ubuntu/Debian).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./lib/common.sh
source "${REPO_ROOT}/lib/common.sh"

# Config files copied verbatim into $HOME.
readonly CONFIGS=(.vimrc .aliases .zshrc .tmux.conf)

# oh-my-zsh custom plugins vendored as submodules.
readonly ZSH_PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting)

# sync_submodules
# Pull in oh-my-zsh and the zsh plugins. Skipped when the working tree already
# has them (tests) or when this is not a git checkout (tarball download).
sync_submodules() {
    if [[ -n "${DOTFILES_SKIP_SUBMODULES:-}" ]]; then
        log_info "skipping submodule sync (DOTFILES_SKIP_SUBMODULES set)"
        return 0
    fi
    if ! has_cmd git || [[ ! -d "${REPO_ROOT}/.git" ]]; then
        log_warn "not a git checkout; skipping submodule sync"
        return 0
    fi
    log_info "syncing git submodules"
    git -C "${REPO_ROOT}" submodule init
    git -C "${REPO_ROOT}" submodule update
}

# install_configs
# Copy each config into $HOME, preserving anything already there as <name>.bk.
install_configs() {
    local config dest
    for config in "${CONFIGS[@]}"; do
        dest="${HOME}/${config}"
        backup_path "${dest}"
        cp "${REPO_ROOT}/${config}" "${dest}"
        log_info "installed ${config}"
    done
}

# install_oh_my_zsh
# Replace ~/.oh-my-zsh with the vendored copy, then drop the plugin submodules
# into its custom plugin directory.
#
# Plugins go under custom/plugins (not plugins/) because that is where
# oh-my-zsh expects third-party plugins; the bundled plugins/ directory is
# overwritten on upgrade.
install_oh_my_zsh() {
    local omz="${HOME}/.oh-my-zsh"

    [[ -d "${REPO_ROOT}/.oh-my-zsh" ]] || die \
        "the .oh-my-zsh submodule is empty; run: git submodule update --init"

    log_info "installing oh-my-zsh"
    copy_tree "${REPO_ROOT}/.oh-my-zsh" "${omz}"

    local plugin
    for plugin in "${ZSH_PLUGINS[@]}"; do
        if [[ ! -d "${REPO_ROOT}/${plugin}" ]]; then
            log_warn "the ${plugin} submodule is empty; skipping"
            continue
        fi
        copy_tree "${REPO_ROOT}/${plugin}" "${omz}/custom/plugins/${plugin}"
        # Also populate the legacy location so an existing ~/.zshrc that
        # predates the custom/ layout keeps working.
        copy_tree "${REPO_ROOT}/${plugin}" "${omz}/plugins/${plugin}"
        log_info "installed plugin ${plugin}"
    done
}

# install_packages <os>
# Stage the platform's manifest under ~/.local/env and hand off to the
# matching package script.
install_packages() {
    local os="${1}"
    local env_dir="${HOME}/.local/env"
    mkdir -p "${env_dir}"

    case "${os}" in
        macos)
            cp "${REPO_ROOT}/Brewfile" "${env_dir}/Brewfile"
            log_info "staged ${env_dir}/Brewfile"
            if [[ -n "${DOTFILES_SKIP_PACKAGES:-}" ]]; then
                log_info "skipping package installation (DOTFILES_SKIP_PACKAGES set)"
                return 0
            fi
            bash "${REPO_ROOT}/scripts/packages_macos.sh" "${env_dir}/Brewfile"
            ;;
        ubuntu|debian)
            cp "${REPO_ROOT}/Aptfile" "${env_dir}/Aptfile"
            log_info "staged ${env_dir}/Aptfile"
            if [[ -n "${DOTFILES_SKIP_PACKAGES:-}" ]]; then
                log_info "skipping package installation (DOTFILES_SKIP_PACKAGES set)"
                return 0
            fi
            bash "${REPO_ROOT}/scripts/packages_ubuntu.sh" "${env_dir}/Aptfile"
            ;;
    esac
}

# report_shell <os>
# zsh is installed by the package step but is not necessarily the login shell.
# Tell the user rather than changing their shell behind their back.
report_shell() {
    [[ -n "${DOTFILES_SKIP_PACKAGES:-}" ]] && return 0
    case "${SHELL}" in
        *zsh) return 0 ;;
    esac
    local zsh_path
    zsh_path="$(command -v zsh || true)"
    [[ -z "${zsh_path}" ]] && return 0
    log_warn "your login shell is ${SHELL}, not zsh. To switch:"
    log_warn "  chsh -s ${zsh_path}"
}

main() {
    local os
    os="$(detect_os)"

    case "${os}" in
        macos|ubuntu|debian) ;;
        *) die "unsupported platform: ${os} (supported: macos, ubuntu, debian)" ;;
    esac

    log_info "installing dotfiles for ${os}"

    sync_submodules
    install_configs
    install_oh_my_zsh
    install_packages "${os}"
    report_shell

    log_info "done. Start a new shell, or run: source ~/.zshrc"
}

main "$@"
