#!/usr/bin/env bash
#
# test_shell_config.sh — Tests for the shell configuration itself (.zshrc,
# .aliases) and the package manifests.
#
# These guard the portability properties that are easy to regress: no
# hardcoded macOS-only paths, clean parsing under zsh, and manifests that only
# claim packages the target platform can actually install.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

# shellcheck source=./helpers.sh
source "${TEST_DIR}/helpers.sh"

suite "shell scripts parse cleanly"

for script in install.sh lib/common.sh scripts/packages_macos.sh scripts/packages_ubuntu.sh; do
    assert_success "bash -n ${script}" bash -n "${REPO_ROOT}/${script}"
done

if command -v zsh >/dev/null 2>&1; then
    for config in .zshrc .aliases; do
        assert_success "zsh -n ${config}" zsh -n "${REPO_ROOT}/${config}"
    done
else
    printf '  skip .zshrc parse check (zsh not installed)\n'
fi

suite ".zshrc contains no unguarded macOS-only paths"

zshrc="$(cat "${REPO_ROOT}/.zshrc")"

# The Apple Silicon asdf path was hardcoded, so the source line blew up on
# Intel Macs and on every Linux host.
assert_not_contains "${zshrc}" '. /opt/homebrew/opt/asdf/libexec/asdf.sh' \
    "asdf is not sourced from a hardcoded Homebrew path"

# `/user/local` was a typo for `/usr/local` in CPPFLAGS.
assert_not_contains "${zshrc}" '/user/local' \
    "the /user/local typo is gone"

# Anything referencing a macOS-only location must sit inside a platform guard
# rather than being exported unconditionally.
while IFS= read -r line; do
    case "${line}" in
        export\ ANDROID_HOME=*Library/Android*)
            _fail "ANDROID_HOME is not unconditionally macOS" "${line}" ;;
        export\ PATH=*Applications/Visual*)
            _fail "VS Code path is not unconditionally macOS" "${line}" ;;
    esac
done <<< "${zshrc}"
_pass "no unconditional macOS-only exports"

suite ".zshrc sets the locale before loading the theme"

# zsh fixes its character-set handling early in startup, so a LANG assigned
# after oh-my-zsh loads arrives too late and the agnoster prompt still errors.
# Ordering is the whole fix, hence an explicit ordering test.
locale_line="$(grep -n 'export LANG=' "${REPO_ROOT}/.zshrc" | head -1 | cut -d: -f1)"
omz_line="$(grep -n 'oh-my-zsh.sh' "${REPO_ROOT}/.zshrc" | head -1 | cut -d: -f1)"

if [[ -n "${locale_line}" && -n "${omz_line}" ]]; then
    if [[ "${locale_line}" -lt "${omz_line}" ]]; then
        _pass "LANG is set (line ${locale_line}) before oh-my-zsh loads (line ${omz_line})"
    else
        _fail "LANG is set before oh-my-zsh loads" \
            "LANG at line ${locale_line}, oh-my-zsh at line ${omz_line}"
    fi
else
    _fail "LANG is set before oh-my-zsh loads" \
        "could not locate both lines (LANG=${locale_line:-none} omz=${omz_line:-none})"
fi

suite ".zshrc sources cleanly under zsh on this host"

# A real end-to-end check: start zsh with the repo's rc file against a
# throwaway HOME containing the installed tree, and require a silent,
# successful startup. This is what actually breaks on a fresh Ubuntu box.
if command -v zsh >/dev/null 2>&1; then
    sandbox="$(mktemp -d)"
    trap 'rm -rf "${sandbox}"' EXIT
    env HOME="${sandbox}" DOTFILES_SKIP_PACKAGES=1 DOTFILES_SKIP_SUBMODULES=1 \
        bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1

    startup_output="$(env HOME="${sandbox}" ZDOTDIR="${sandbox}" \
        zsh -i -c 'exit' 2>&1)"
    startup_status=$?

    assert_equals "0" "${startup_status}" "interactive zsh startup exits 0"
    assert_not_contains "${startup_output}" "no such file or directory" \
        "startup reports no missing files"
    assert_not_contains "${startup_output}" "command not found" \
        "startup reports no missing commands"
    # The agnoster prompt's powerline glyphs fail under a non-UTF-8 locale,
    # which is the default on a minimal Ubuntu host. Observed on ubuntu:24.04.
    assert_not_contains "${startup_output}" "character not in range" \
        "startup renders prompt glyphs without a locale error"
else
    printf '  skip zsh startup check (zsh not installed)\n'
fi

suite ".zshrc is idempotent when re-sourced"

# `source ~/.zshrc` (the ohmyrefresh alias) is run constantly. PATH and the
# compiler flag variables must not grow a duplicate entry each time.
if command -v zsh >/dev/null 2>&1; then
    sandbox2="$(mktemp -d)"
    env HOME="${sandbox2}" DOTFILES_SKIP_PACKAGES=1 DOTFILES_SKIP_SUBMODULES=1 \
        bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1

    # Source the config three extra times, then count duplicate entries.
    dupes="$(env HOME="${sandbox2}" ZDOTDIR="${sandbox2}" zsh -i -c '
        source "$HOME/.zshrc"; source "$HOME/.zshrc"; source "$HOME/.zshrc"
        # `print -rl --` is required: the flag values start with -L/-I, which
        # print would otherwise swallow as its own options.
        print -r -- "PATH_DUPES=$(print -rl -- ${(s.:.)PATH} | sort | uniq -d | wc -l)"
        print -r -- "LDFLAGS_DUPES=$(print -rl -- ${(s. .)LDFLAGS} | sort | uniq -d | wc -l)"
        print -r -- "CPPFLAGS_DUPES=$(print -rl -- ${(s. .)CPPFLAGS} | sort | uniq -d | wc -l)"
    ' 2>/dev/null)"

    for var in PATH LDFLAGS CPPFLAGS; do
        count="$(printf '%s\n' "${dupes}" | sed -n "s/^${var}_DUPES=[[:space:]]*//p" \
            | tr -d '[:space:]')"
        assert_equals "0" "${count:-unknown}" \
            "${var} gains no duplicate entries after re-sourcing"
    done

    rm -rf "${sandbox2}"
else
    printf '  skip idempotency check (zsh not installed)\n'
fi

suite "package manifests"

assert_file_exists "${REPO_ROOT}/Brewfile" "Brewfile exists"
assert_file_exists "${REPO_ROOT}/Aptfile" "Aptfile exists"

# Collect the actual package entries, stripping comments and blank lines. The
# assertions below run against these names rather than the raw file text, so
# an explanatory comment mentioning a macOS tool is not a false positive.
apt_packages=()
malformed=""
while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "${line}" | tr -d '[:space:]')"
    [[ -z "${line}" ]] && continue
    apt_packages+=("${line}")
    if [[ ! "${line}" =~ ^[a-zA-Z0-9][a-zA-Z0-9+._-]*$ ]]; then
        malformed="${line}"
    fi
done < "${REPO_ROOT}/Aptfile"

# Every uncommented Aptfile line must be a bare package name -- the file is fed
# straight to apt-get, so Brewfile-style syntax would be a silent failure.
if [[ -z "${malformed}" ]]; then
    _pass "Aptfile lines are bare package names"
else
    _fail "Aptfile lines are bare package names" "offending line: ${malformed}"
fi

if [[ ${#apt_packages[@]} -gt 0 ]]; then
    _pass "Aptfile declares at least one package"
else
    _fail "Aptfile declares at least one package" "no package entries parsed"
fi

# `mas` is the Mac App Store CLI and cask taps are a macOS-only concept;
# neither can be a package entry in an apt manifest.
for forbidden in mas brew cask; do
    found=""
    for pkg in "${apt_packages[@]}"; do
        [[ "${pkg}" == "${forbidden}" ]] && found="${pkg}"
    done
    if [[ -z "${found}" ]]; then
        _pass "Aptfile does not list the macOS-only '${forbidden}'"
    else
        _fail "Aptfile does not list the macOS-only '${forbidden}'" "found: ${found}"
    fi
done

# The manifest has to carry the essentials the shell config assumes exist.
for required in zsh tmux vim ripgrep; do
    found=""
    for pkg in "${apt_packages[@]}"; do
        [[ "${pkg}" == "${required}" ]] && found="${pkg}"
    done
    if [[ -n "${found}" ]]; then
        _pass "Aptfile includes ${required}"
    else
        _fail "Aptfile includes ${required}" "not found in the manifest"
    fi
done

finish
