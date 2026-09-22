#!/usr/bin/env bash
#
# packages_ubuntu.sh — Install the Aptfile package set on Ubuntu/Debian.
#
# Called by install.sh; also runnable directly:
#   ./scripts/packages_ubuntu.sh [path/to/Aptfile]
#
# Design notes:
#   * Packages are installed one at a time rather than in a single apt-get
#     invocation. A name that is missing on one Ubuntu release (lsd on 22.04,
#     7zip on <22.10) would otherwise abort the whole batch.
#   * Tools with no apt package (gh, uv, lsd) get explicit installers below.
#   * Everything is idempotent: re-running is cheap and safe.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"

APTFILE="${1:-${REPO_ROOT}/Aptfile}"

# SUDO — empty when already root (containers, CI), otherwise `sudo`.
if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=""
else
    has_cmd sudo || die "sudo is required to install packages (or run as root)"
    SUDO="sudo"
fi

# read_aptfile <path>
# Echo one package name per line, stripping comments and blank lines.
read_aptfile() {
    local line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%%#*}"                      # drop trailing comment
        line="${line#"${line%%[![:space:]]*}"}" # ltrim
        line="${line%"${line##*[![:space:]]}"}" # rtrim
        [[ -n "${line}" ]] && printf '%s\n' "${line}"
    done < "${1}"
}

# apt_install_each <package...>
# Install packages individually, warning about any the release does not carry.
apt_install_each() {
    local pkg missing=()
    for pkg in "$@"; do
        if dpkg -s "${pkg}" >/dev/null 2>&1; then
            continue    # already installed
        fi
        log_info "installing ${pkg}"
        if ! DEBIAN_FRONTEND=noninteractive ${SUDO} apt-get install -y -qq "${pkg}"; then
            missing+=("${pkg}")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "unavailable on this release, skipped: ${missing[*]}"
    fi
}

# install_gh
# GitHub CLI is not in the Ubuntu archive; add the official apt repository.
install_gh() {
    has_cmd gh && return 0
    log_info "adding the GitHub CLI apt repository"
    ${SUDO} mkdir -p -m 755 /etc/apt/keyrings
    if ! curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | ${SUDO} tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null; then
        log_warn "could not fetch the GitHub CLI signing key; skipping gh"
        return 0
    fi
    ${SUDO} chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | ${SUDO} tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    ${SUDO} apt-get update -qq
    apt_install_each gh
}

# install_uv
# uv ships as a static binary via the official installer, which drops it in
# ~/.local/bin -- already on PATH courtesy of .zshrc.
install_uv() {
    has_cmd uv && return 0
    log_info "installing uv"
    if ! curl -fsSL https://astral.sh/uv/install.sh | sh; then
        log_warn "uv installation failed; install it manually from astral.sh/uv"
    fi
}

# install_lsd
# lsd only reached the Ubuntu archive in 23.04. Try apt first, then fall back
# to the upstream .deb so 22.04 hosts still get it.
install_lsd() {
    has_cmd lsd && return 0
    if apt-cache show lsd >/dev/null 2>&1; then
        apt_install_each lsd
        return 0
    fi
    local version="1.1.5" arch deb tmp
    arch="$(dpkg --print-architecture)"
    tmp="$(mktemp -d)"
    deb="lsd_${version}_${arch}.deb"
    log_info "installing lsd ${version} from upstream (.deb)"
    if curl -fsSL -o "${tmp}/${deb}" \
        "https://github.com/lsd-rs/lsd/releases/download/v${version}/${deb}"; then
        ${SUDO} dpkg -i "${tmp}/${deb}" >/dev/null 2>&1 \
            || log_warn "lsd .deb failed to install; skipping"
    else
        log_warn "could not download lsd; the ls alias will fall back to plain ls"
    fi
    rm -rf "${tmp}"
}

# link_debian_renamed_binaries
# Debian renames two binaries to dodge existing packages: bat -> batcat and
# fd -> fdfind. Expose the upstream names in ~/.local/bin so scripts and
# muscle memory work the same on both platforms.
link_debian_renamed_binaries() {
    mkdir -p "${HOME}/.local/bin"
    if has_cmd batcat && ! has_cmd bat; then
        ln -sf "$(command -v batcat)" "${HOME}/.local/bin/bat"
        log_info "linked batcat -> ~/.local/bin/bat"
    fi
    if has_cmd fdfind && ! has_cmd fd; then
        ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"
        log_info "linked fdfind -> ~/.local/bin/fd"
    fi
}

main() {
    [[ -f "${APTFILE}" ]] || die "no Aptfile at ${APTFILE}"

    log_info "updating apt package lists"
    ${SUDO} apt-get update -qq || log_warn "apt-get update failed; continuing"

    local packages=()
    while IFS= read -r pkg; do
        packages+=("${pkg}")
    done < <(read_aptfile "${APTFILE}")

    [[ ${#packages[@]} -gt 0 ]] && apt_install_each "${packages[@]}"

    install_gh
    install_uv
    install_lsd
    link_debian_renamed_binaries

    log_info "ubuntu package installation complete"
}

main "$@"
