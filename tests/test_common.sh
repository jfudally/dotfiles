#!/usr/bin/env bash
#
# test_common.sh — Unit tests for lib/common.sh, the shared platform-detection
# and logging library used by install.sh and the per-OS package scripts.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

# shellcheck source=./helpers.sh
source "${TEST_DIR}/helpers.sh"
# shellcheck source=../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"

suite "detect_os"

# detect_os() must report a stable, lowercase identifier derived from uname so
# that every downstream branch keys off one vocabulary.
os="$(detect_os)"
case "${os}" in
    macos|ubuntu|debian|linux)
        _pass "detect_os returns a known platform (${os})" ;;
    *)
        _fail "detect_os returns a known platform" "got: ${os}" ;;
esac

# The helper must agree with the platform we are actually running on, so the
# suite is meaningful on both a Mac laptop and an Ubuntu CI runner.
case "$(uname -s)" in
    Darwin)
        assert_equals "macos" "${os}" "detect_os identifies Darwin as macos"
        assert_success "is_macos succeeds on Darwin" is_macos
        if is_linux; then
            _fail "is_linux fails on Darwin" "is_linux returned true"
        else
            _pass "is_linux fails on Darwin"
        fi
        ;;
    Linux)
        assert_success "is_linux succeeds on Linux" is_linux
        if is_macos; then
            _fail "is_macos fails on Linux" "is_macos returned true"
        else
            _pass "is_macos fails on Linux"
        fi
        ;;
esac

suite "detect_os honours DOTFILES_OS_OVERRIDE"

# Tests and CI need to exercise the "other" platform's code paths without
# actually being on that platform.
assert_equals "ubuntu" "$(DOTFILES_OS_OVERRIDE=ubuntu detect_os)" \
    "override forces ubuntu"
assert_equals "macos" "$(DOTFILES_OS_OVERRIDE=macos detect_os)" \
    "override forces macos"

suite "has_cmd"

assert_success "has_cmd finds a guaranteed binary (sh)" has_cmd sh
if has_cmd definitely-not-a-real-binary-xyzzy; then
    _fail "has_cmd rejects a missing binary" "returned true"
else
    _pass "has_cmd rejects a missing binary"
fi

suite "logging helpers"

# Log output goes to stderr so it never pollutes a function's stdout value.
stdout_capture="$(log_info 'hello' 2>/dev/null)"
assert_equals "" "${stdout_capture}" "log_info writes nothing to stdout"

stderr_capture="$(log_info 'hello' 2>&1 >/dev/null)"
assert_contains "${stderr_capture}" "hello" "log_info writes the message to stderr"

stderr_capture="$(log_warn 'careful' 2>&1 >/dev/null)"
assert_contains "${stderr_capture}" "careful" "log_warn writes the message to stderr"

stderr_capture="$(log_error 'broken' 2>&1 >/dev/null)"
assert_contains "${stderr_capture}" "broken" "log_error writes the message to stderr"

suite "backup_path"

# Existing files must be preserved before install.sh overwrites them. The
# original implementation only backed up symlinks, silently destroying real
# files -- this is the regression test for that bug.
tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

printf 'original contents\n' > "${tmp_home}/.somerc"
backup_path "${tmp_home}/.somerc"
assert_file_exists "${tmp_home}/.somerc.bk" "backup_path backs up a regular file"
assert_equals "original contents" "$(cat "${tmp_home}/.somerc.bk")" \
    "backup preserves the original contents"

ln -s /dev/null "${tmp_home}/.linkrc"
backup_path "${tmp_home}/.linkrc"
if [[ -L "${tmp_home}/.linkrc.bk" ]]; then
    _pass "backup_path backs up a symlink"
else
    _fail "backup_path backs up a symlink" "no symlink at ${tmp_home}/.linkrc.bk"
fi

# A missing path is a no-op, not an error, so install.sh can call it blindly.
assert_success "backup_path tolerates a missing path" \
    backup_path "${tmp_home}/.does-not-exist"
if [[ -e "${tmp_home}/.does-not-exist.bk" ]]; then
    _fail "backup_path creates nothing for a missing path" "stray backup created"
else
    _pass "backup_path creates nothing for a missing path"
fi

finish
