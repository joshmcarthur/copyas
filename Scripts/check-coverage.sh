#!/usr/bin/env bash
set -euo pipefail

minimum_coverage="90"
skip_test=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-test)
            skip_test=true
            shift
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                minimum_coverage="$1"
            else
                echo "error: unknown argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ "${skip_test}" == "false" ]]; then
    swift test --enable-code-coverage
fi

profile_path="$(
    find .build -path "*/codecov/default.profdata" -type f 2>/dev/null | head -n 1
)"

if [[ -z "${profile_path}" || ! -f "${profile_path}" ]]; then
    echo "error: coverage profile not found under .build" >&2
    exit 1
fi

test_binary="$(
    find .build -path "*.xctest/Contents/MacOS/*" -type f -perm -111 ! -name "*.dSYM" 2>/dev/null | head -n 1
)"

if [[ -z "${test_binary}" ]]; then
    echo "error: SwiftPM test binary not found under .build" >&2
    exit 1
fi

coverage_report="$(
    xcrun llvm-cov report "${test_binary}" \
        -instr-profile "${profile_path}" \
        -ignore-filename-regex="(/Tests/|/\\.build/|/Sources/CopyasCLI/|/Sources/Copyas/Model/LiveModelClient\\.swift$|/Sources/Copyas/Model/FoundationModelsTokenCounter\\.swift$)"
)"

printf "%s\n" "${coverage_report}"

line_coverage="$(
    printf "%s\n" "${coverage_report}" |
        awk '/^TOTAL/ { gsub("%", "", $10); print $10 }'
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
