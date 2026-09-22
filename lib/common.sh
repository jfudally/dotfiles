#!/usr/bin/env bash
#
# lib/common.sh — Shared platform detection, logging, and filesystem helpers.
#
# Sourced by install.sh and the per-OS package scripts. Contains no top-level
# side effects so it is safe to source from tests.

# ── Logging ──────────────────────────────────────────────────────────────────
# All log output goes to stderr. Helper functions in this library and its
# callers reserve stdout for return values, so mixing the two would corrupt
# command substitution.

if [[ -t 2 ]]; then
    _LOG_BLUE=$'\033[34m'; _LOG_YELLOW=$'\033[33m'
    _LOG_RED=$'\033[31m';  _LOG_OFF=$'\033[0m'
else
    _LOG_BLUE=''; _LOG_YELLOW=''; _LOG_RED=''; _LOG_OFF=''
fi

# log_info <message...>
log_info() { printf '%s==>%s %s\n' "${_LOG_BLUE}" "${_LOG_OFF}" "$*" >&2; }

# log_warn <message...>
log_warn() { printf '%swarn:%s %s\n' "${_LOG_YELLOW}" "${_LOG_OFF}" "$*" >&2; }

# log_error <message...>
log_error() { printf '%serror:%s %s\n' "${_LOG_RED}" "${_LOG_OFF}" "$*" >&2; }

# die <message...>
# Log an error and abort with a non-zero status. Fail loud, fail early.
die() { log_error "$@"; exit 1; }

# ── Platform detection ───────────────────────────────────────────────────────

# detect_os
# Echo a lowercase platform identifier: macos, ubuntu, debian, linux, or the
# raw uname value for anything unrecognised.
#
# Set DOTFILES_OS_OVERRIDE to force a value; the test suite uses this to
# exercise the Ubuntu code path from a Mac and vice versa.
detect_os() {
    if [[ -n "${DOTFILES_OS_OVERRIDE:-}" ]]; then
        printf '%s\n' "${DOTFILES_OS_OVERRIDE}"
        return 0
    fi

    case "$(uname -s)" in
        Darwin)
            printf 'macos\n'
            ;;
        Linux)
            # /etc/os-release is the standard on every modern distro. ID_LIKE
            # catches Ubuntu derivatives (Pop!_OS, Mint) that apt still serves.
            if [[ -r /etc/os-release ]]; then
                local ID='' ID_LIKE=''
                # shellcheck disable=SC1091
                . /etc/os-release
                case "${ID}" in
                    ubuntu) printf 'ubuntu\n'; return 0 ;;
                    debian) printf 'debian\n'; return 0 ;;
                esac
                case " ${ID_LIKE} " in
                    *" ubuntu "*) printf 'ubuntu\n'; return 0 ;;
                    *" debian "*) printf 'debian\n'; return 0 ;;
                esac
            fi
            printf 'linux\n'
            ;;
        *)
            uname -s | tr '[:upper:]' '[:lower:]'
            ;;
    esac
}

# is_macos / is_linux
# Convenience predicates over detect_os, for readable `if` conditions.
is_macos() { [[ "$(detect_os)" == "macos" ]]; }
is_linux() {
    case "$(detect_os)" in
        ubuntu|debian|linux) return 0 ;;
        *) return 1 ;;
    esac
}

# is_apt_based
# True when apt-get is the right package manager for this host.
is_apt_based() {
    case "$(detect_os)" in
        ubuntu|debian) return 0 ;;
        *) return 1 ;;
    esac
}

# ── Filesystem helpers ───────────────────────────────────────────────────────

# has_cmd <name>
# True when <name> is an executable on PATH.
has_cmd() { command -v "${1}" >/dev/null 2>&1; }

# backup_path <path>
# Move an existing file, directory, or symlink aside to <path>.bk before it is
# replaced. A missing path is a silent no-op.
#
# Note this handles regular files as well as symlinks: an earlier version only
# checked for symlinks and silently destroyed hand-written configs.
backup_path() {
    local target="${1}"
    # -e follows symlinks (false for a broken one), so test -L separately.
    if [[ -e "${target}" || -L "${target}" ]]; then
        rm -rf "${target}.bk"
        mv "${target}" "${target}.bk"
        log_info "backed up ${target} -> ${target}.bk"
    fi
    return 0
}

# copy_tree <source-dir> <dest-dir>
# Recursively copy a directory, replacing any existing destination.
#
# Uses rsync when available for speed, and falls back to cp because a minimal
# Ubuntu container (ubuntu:24.04, debian:slim) ships without rsync.
copy_tree() {
    local src="${1}" dest="${2}"
    rm -rf "${dest}"
    mkdir -p "$(dirname "${dest}")"
    if has_cmd rsync; then
        # Trailing slash on src copies contents into dest, not src itself.
        rsync -a --exclude '.git' "${src}/" "${dest}/"
    else
        cp -R "${src}" "${dest}"
        rm -rf "${dest}/.git"
    fi
}
