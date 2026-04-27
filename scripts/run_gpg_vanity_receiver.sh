#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-/dev/ttyUSB1}"
OUT_DIR="${2:-build/gpg_vanity_hits}"
BAUD="${GPG_VANITY_BAUD:-2000000}"
REPORT_INTERVAL="${GPG_VANITY_REPORT_INTERVAL:-60}"

exec python3 tools/receive_gpg_vanity_uart.py \
    --port "$PORT" \
    --baud "$BAUD" \
    --out-dir "$OUT_DIR" \
    --report-interval "$REPORT_INTERVAL" \
    --mlock
