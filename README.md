# GPGgen

FPGA-assisted OpenPGP Ed25519 vanity key search for Kintex-7 `XC7K160T`.

The FPGA hot path generates random Ed25519 seeds, derives public keys, computes OpenPGP v4 fingerprints, checks vanity patterns, and streams status/hits over UART. The host receiver only parses UART frames, verifies CRCs, writes hit logs, and emits bare `.gpg` secret-key packets for validated hits.

## Current Target

- Board/device: Kintex-7 `xc7k160tffg676-2`
- Toolchain: Vivado 2025.2
- UART: `2000000` baud, no flow control
- Stable serial path: `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`
- FPGA config: `LANES=2`, `MUL_LANES=1`, `TRNG_CORES=2`, `USE_PLL=1`
- System clock: `64.705882 MHz`
- Pattern mode: prefix and suffix `XXXX/YYYY` checks, 512 total patterns

## Quick Run

Power on the FPGA board, then start the host receiver:

```sh
tools/run_gpg_vanity_receiver.sh
```

Watch runtime output:

```sh
tail -f build/gpg_vanity_receiver.log
```

Outputs:

```text
build/gpg_vanity_real_hits/
build/gpg_vanity_real_hits_gpg/
```

Treat files under `build/gpg_vanity_real_hits_gpg/` as private key material.

## Documentation

- Full runbook: `docs/RUN_GPG_VANITY_HT.md`
- Latest operation report: `docs/GPG_VANITY_HT_OPERATION_REPORT.md`
- Architecture notes: `docs/ED25519_GPG_VANITY_ARCH.md`
- TRNG notes: `docs/TRNG_VALIDATION.md`

## Build And Program

Build the bitstream:

```sh
vivado -mode batch -source scripts/impl_gpg_vanity_ht_search.tcl
```

Generate Flash images:

```sh
vivado -mode batch -source scripts/write_gpg_vanity_ht_search_cfgmem.tcl
```

Program board Quad SPI Flash:

```sh
vivado -mode batch -source scripts/program_gpg_vanity_ht_search_flash.tcl
```

Verify boot from Flash:

```sh
vivado -mode batch -source scripts/boot_gpg_vanity_ht_search_from_flash.tcl
```

Expected boot result includes `DONE_PIN 1` and `EOS 1`.

## Verification

Software receiver self-test:

```sh
python3 tools/selftest_gpg_vanity_uart.py
```

Top-level UART simulation:

```sh
vivado -mode batch -source scripts/sim_gpg_vanity_ht_search_top.tcl
```

The current routed build meets timing and routes fully. Real UART heartbeat CRC was verified from the flashed image with no bad frames in the latest capture.
