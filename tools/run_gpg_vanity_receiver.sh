#!/usr/bin/env bash
set -euo pipefail

cd /home/evenson/GPGgen

UART_PORT="${GPG_VANITY_UART_PORT:-/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0}"
OUT_DIR="${GPG_VANITY_OUT_DIR:-/home/evenson/GPGgen/build/gpg_vanity_real_hits}"
GPG_DIR="${GPG_VANITY_GPG_DIR:-/home/evenson/GPGgen/build/gpg_vanity_real_hits_gpg}"
BAUD="${GPG_VANITY_BAUD:-2000000}"
LOG_FILE="${GPG_VANITY_LOG_FILE:-/home/evenson/GPGgen/build/gpg_vanity_receiver.log}"

mkdir -p "$(dirname "$LOG_FILE")"
chmod 700 "$(dirname "$LOG_FILE")" 2>/dev/null || true

{
  printf '\n[%s] starting receiver port=%s baud=%s out_dir=%s gpg_dir=%s\n' \
    "$(date -Is)" "$UART_PORT" "$BAUD" "$OUT_DIR" "$GPG_DIR"
  exec python3 tools/receive_gpg_vanity_uart.py \
    --port "$UART_PORT" \
    --baud "$BAUD" \
    --out-dir "$OUT_DIR" \
    --gpg-dir "$GPG_DIR" \
    --file-prefix class \
    --timestamp 1700000000 \
    --mlock
} 2>&1 | tee -a "$LOG_FILE"
