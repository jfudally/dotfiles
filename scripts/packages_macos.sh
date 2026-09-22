#!/usr/bin/env bash
#
# packages_macos.sh — Install the Brewfile package set on macOS.
#
# Called by install.sh; also runnable directly:
#   ./scripts/packages_macos.sh [path/to/Brewfile]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"

BREWFILE="${1:-${REPO_ROOT}/Brewfile}"

# ensure_brew_on_path
# Homebrew lives at a different prefix on Apple Silicon and Intel, and a fresh
# install is not yet on PATH in this shell. Locate it and load its shellenv.
ensure_brew_on_path() {
    has_cmd brew && return 0
    local prefix
    for prefix in /opt/homebrew /usr/local; do
        if [[ -x "${prefix}/bin/brew" ]]; then
            eval "$("${prefix}/bin/brew" shellenv)"
            return 0
        fi
    done
    return 1
}

main() {
    [[ -f "${BREWFILE}" ]] || die "no Brewfile at ${BREWFILE}"

    if ! ensure_brew_on_path; then
        die "Homebrew is not installed. Install it first:
  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi

    log_info "running brew bundle against ${BREWFILE}"
    brew bundle --file "${BREWFILE}" || die "brew bundle failed"

    log_info "macos package installation complete"
}

main "$@"
