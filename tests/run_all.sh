#!/usr/bin/env bash
#
# run_all.sh — Run every test_*.sh in this directory and aggregate the result.
# Exits non-zero if any suite fails, so it can back a `make test` in CI.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

failed_suites=0
total_suites=0

for suite_file in "${TEST_DIR}"/test_*.sh; do
    [[ -f "${suite_file}" ]] || continue
    total_suites=$((total_suites + 1))
    printf '\n==> %s\n' "$(basename "${suite_file}")"
    if ! bash "${suite_file}"; then
        failed_suites=$((failed_suites + 1))
    fi
done

printf '\n────────────────────────────────────────\n'
if [[ ${failed_suites} -eq 0 ]]; then
    printf 'All %d suites passed.\n' "${total_suites}"
else
    printf '%d of %d suites FAILED.\n' "${failed_suites}" "${total_suites}"
fi

[[ ${failed_suites} -eq 0 ]]
