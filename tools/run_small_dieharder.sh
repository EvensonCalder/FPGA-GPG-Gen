#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 <random.bin>" >&2
    exit 2
fi

file=$1

run_test() {
    local id=$1
    local p=$2
    shift 2
    dieharder -g 201 -f "$file" -d "$id" -p "$p" "$@"
}

run_test 0 20
run_test 2 20
run_test 3 20
run_test 8 20
run_test 9 20
run_test 15 20
run_test 100 20
run_test 101 20
run_test 102 20 -n 4
run_test 200 20 -n 8
run_test 204 20

# DCT consumes more data and rewinds small files heavily. Keep p lower for
# 16 MiB screening; use larger samples before raising this.
run_test 206 10
