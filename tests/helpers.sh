#!/usr/bin/env bash
#
# helpers.sh — Minimal assertion harness for the dotfiles test suite.
#
# Deliberately dependency-free (no bats, no shunit2) so the suite runs on a
# bare macOS or Ubuntu box before any packages have been installed — which is
# exactly the situation install.sh is meant to bootstrap.
#
# Usage:
#   source "$(dirname "$0")/helpers.sh"
#   assert_equals "expected" "actual" "description"
#   finish   # prints the summary and sets the exit code

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_SUITE="$(basename "${0}")"

# Colour codes, but only when attached to a terminal that can show them.
if [[ -t 1 ]]; then
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
    C_RED=''; C_GREEN=''; C_DIM=''; C_OFF=''
fi

# _pass <description>
# Record and report a successful assertion.
_pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf '  %sok%s   %s\n' "${C_GREEN}" "${C_OFF}" "${1}"
}

# _fail <description> <detail...>
# Record and report a failed assertion. Detail lines are indented beneath it.
_fail() {
    local desc="${1}"; shift
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  %sFAIL%s %s\n' "${C_RED}" "${C_OFF}" "${desc}"
    local line
    for line in "$@"; do
        printf '       %s%s%s\n' "${C_DIM}" "${line}" "${C_OFF}"
    done
}

# assert_equals <expected> <actual> <description>
assert_equals() {
    local expected="${1}" actual="${2}" desc="${3}"
    if [[ "${expected}" == "${actual}" ]]; then
        _pass "${desc}"
    else
        _fail "${desc}" "expected: ${expected}" "actual:   ${actual}"
    fi
}

# assert_contains <haystack> <needle> <description>
assert_contains() {
    local haystack="${1}" needle="${2}" desc="${3}"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        _pass "${desc}"
    else
        _fail "${desc}" "expected to contain: ${needle}" "actual: ${haystack}"
    fi
}

# assert_not_contains <haystack> <needle> <description>
assert_not_contains() {
    local haystack="${1}" needle="${2}" desc="${3}"
    if [[ "${haystack}" != *"${needle}"* ]]; then
        _pass "${desc}"
    else
        _fail "${desc}" "expected NOT to contain: ${needle}"
    fi
}

# assert_file_exists <path> <description>
assert_file_exists() {
    if [[ -f "${1}" ]]; then
        _pass "${2}"
    else
        _fail "${2}" "no such file: ${1}"
    fi
}

# assert_dir_exists <path> <description>
assert_dir_exists() {
    if [[ -d "${1}" ]]; then
        _pass "${2}"
    else
        _fail "${2}" "no such directory: ${1}"
    fi
}

# assert_success <description> <command...>
# Runs the command, capturing output, and asserts a zero exit status.
assert_success() {
    local desc="${1}"; shift
    local output status
    output="$("$@" 2>&1)"; status=$?
    if [[ ${status} -eq 0 ]]; then
        _pass "${desc}"
    else
        _fail "${desc}" "exit status: ${status}" "output: ${output}"
    fi
}

# suite <name>
# Print a heading for a group of assertions.
suite() {
    printf '\n%s%s%s\n' "${C_DIM}" "${1}" "${C_OFF}"
}

# finish
# Print the summary line and exit non-zero if anything failed.
finish() {
    printf '\n%s: %d assertions, %d failed\n' \
        "${CURRENT_SUITE}" "${TESTS_RUN}" "${TESTS_FAILED}"
    [[ ${TESTS_FAILED} -eq 0 ]]
}
