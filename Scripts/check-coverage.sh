#!/usr/bin/env bash
set -euo pipefail

minimum_coverage="${1:-90}"
profile_path=".build/debug/codecov/default.profdata"

swift test --enable-code-coverage

if [[ ! -f "${profile_path}" ]]; then
    echo "error: coverage profile not found at ${profile_path}" >&2
    exit 1
fi

test_binary="$(
    find .build/debug -path "*.xctest/Contents/MacOS/*" -type f -perm -111 | head -n 1
)"

if [[ -z "${test_binary}" ]]; then
    echo "error: SwiftPM test binary not found under .build/debug" >&2
    exit 1
fi

coverage_report="$(
    xcrun llvm-cov report "${test_binary}" \
        -instr-profile "${profile_path}" \
        -ignore-filename-regex="(/Tests/|/\\.build/|/Sources/CopyasCLI/|/Sources/Copyas/Model/LiveModelClient\\.swift$)"
)"

printf "%s\n" "${coverage_report}"

line_coverage="$(
    printf "%s\n" "${coverage_report}" |
        awk '/^TOTAL/ { gsub("%", "", $9); print $9 }'
)"

if [[ -z "${line_coverage}" ]]; then
    echo "error: could not parse TOTAL line coverage from llvm-cov report" >&2
    exit 1
fi

awk -v actual="${line_coverage}" -v minimum="${minimum_coverage}" '
    BEGIN {
        if ((actual + 0) >= (minimum + 0)) {
            exit 0
        }
        exit 1
    }
' || {
    echo "error: line coverage ${line_coverage}% is below required ${minimum_coverage}%" >&2
    exit 1
}

echo "line coverage ${line_coverage}% meets required ${minimum_coverage}%"
