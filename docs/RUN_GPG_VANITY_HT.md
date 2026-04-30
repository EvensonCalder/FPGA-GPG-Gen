# GPG Vanity HT Runner

## Current Status

- FPGA image has been programmed to board Quad SPI Flash.
- Flash boot was verified with Vivado: `DONE_PIN 1`, `EOS 1`.
- Host auto-start is not configured. Start the receiver manually when needed.
- Final stable performance is about `9047 keys/s`.
- Heartbeat UART frames are CRC-checked short status frames and were verified on real hardware with no bad frames in the latest capture.

## Normal Use

1. Power on the FPGA board.
2. Start the receiver on the host:

```sh
tools/run_gpg_vanity_receiver.sh
```

Default receiver port:

```text
/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
```

UART settings:

```text
baud = 2000000
flow control = off
```

Output directories:

```text
build/gpg_vanity_real_hits/
build/gpg_vanity_real_hits_gpg/
```

Text hit logs are written under `build/gpg_vanity_real_hits/`.
Per-hit `.gpg` secret-key packets are written under `build/gpg_vanity_real_hits_gpg/`.

## Use A Generated `.gpg` Key File

Each `.gpg` file under this directory is an OpenPGP secret-key packet generated from one FPGA hit:

```text
build/gpg_vanity_real_hits_gpg/
```

List generated key files:

```sh
ls -l build/gpg_vanity_real_hits_gpg/*.gpg
```

Inspect a key packet without importing it:

```sh
gpg --list-packets build/gpg_vanity_real_hits_gpg/<file>.gpg
```

Import one generated secret key into your local GnuPG keyring:

```sh
gpg --import build/gpg_vanity_real_hits_gpg/<file>.gpg
```

List imported secret keys:

```sh
gpg --list-secret-keys --keyid-format long
```

GnuPG may print a warning like this:

```text
gpg: no user ID
```

That is expected for the current output. The FPGA/receiver writes a bare OpenPGP secret-key packet, not a full certificate with user IDs, self-signatures, preferences, or expiration metadata.

To use it as a normal GPG identity, add a user ID after import:

```sh
gpg --quick-add-uid <FINGERPRINT_OR_KEYID> "Your Name <you@example.com>"
```

Then optionally add/update preferences, expiration, or trust using normal GnuPG commands.

Export the public key after adding a user ID:

```sh
gpg --armor --export <FINGERPRINT_OR_KEYID> > vanity_public.asc
```

Export the secret key for backup:

```sh
gpg --armor --export-secret-keys <FINGERPRINT_OR_KEYID> > vanity_secret.asc
chmod 600 vanity_secret.asc
```

Important handling notes:

- Treat every `.gpg` file as private key material.
- Keep `build/gpg_vanity_real_hits_gpg/` private; receiver-created directories use restrictive permissions.
- Do not upload `.gpg`, seed logs, or exported secret keys.
- If you only want to validate hits without importing, use `gpg --list-packets` or the verification tools instead.

Runtime log:

```text
build/gpg_vanity_receiver.log
```

The receiver prints heartbeat/rate status when heartbeat frames arrive. It also prints an idle status line every 60 seconds if no heartbeat or hit has been seen.

Heartbeat frames carry counters, not private key material. The current hardware heartbeat format is:

```text
GPGV1 || 0xFE || produced_count[8] || accepted_count[8] || crc32[4]
```

The CRC covers the heartbeat body beginning with `0xFE`. The receiver also accepts the older 74-byte padded heartbeat format for compatibility.

Example idle line:

```text
rate hits/s=0.000 keys/s=N/A accepted=0 bad_crc=0
```

That means the receiver is alive and listening. Hits are rare, so hit counts remaining at zero for long periods is normal.

Watch the log live:

```sh
tail -f build/gpg_vanity_receiver.log
```

Check whether the receiver process is running:

```sh
pgrep -af receive_gpg_vanity_uart.py
```

Use a different log file:

```sh
GPG_VANITY_LOG_FILE=/path/to/receiver.log tools/run_gpg_vanity_receiver.sh
```

## Select The UART Port

List stable serial device names:

```sh
ls -l /dev/serial/by-id/
```

Current known devices on this host included:

```text
usb-1a86_USB_Serial-if00-port0 -> ../../ttyUSB1
usb-Digilent_Digilent_USB_Device_210251A08870-if00-port0 -> ../../ttyUSB0
usb-Milsky_LL_Dongle_A694CFC453E2-if00 -> ../../ttyACM0
```

The FPGA UART receiver is expected to be the CH340/1a86 device:

```text
/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
```

If the listen device changes, override it when starting the receiver:

```sh
GPG_VANITY_UART_PORT=/dev/serial/by-id/<your-device> tools/run_gpg_vanity_receiver.sh
```

You can also use a direct tty path if needed:

```sh
GPG_VANITY_UART_PORT=/dev/ttyUSB1 tools/run_gpg_vanity_receiver.sh
```

Override output directories if needed:

```sh
GPG_VANITY_OUT_DIR=/path/to/hit_logs \
GPG_VANITY_GPG_DIR=/path/to/gpg_files \
tools/run_gpg_vanity_receiver.sh
```

Override baud rate if the FPGA UART setting changes:

```sh
GPG_VANITY_BAUD=2000000 tools/run_gpg_vanity_receiver.sh
```

## Final FPGA Artifacts

```text
build/vivado_gpg_vanity_ht_search_synth/gpg_vanity_ht_search_top.bit
build/vivado_gpg_vanity_ht_search_synth/gpg_vanity_ht_search_top_flash.mcs
build/vivado_gpg_vanity_ht_search_synth/gpg_vanity_ht_search_top_flash.bin
build/vivado_gpg_vanity_ht_search_synth/timing_summary_routed.rpt
build/vivado_gpg_vanity_ht_search_synth/utilization_routed.rpt
```

## Rebuild Bitstream

```sh
vivado -mode batch -source scripts/impl_gpg_vanity_ht_search.tcl
```

Final default build configuration:

```text
LANES=2
MUL_LANES=1
TRNG_CORES=2
USE_PLL=1
system clock = 64.705882 MHz
```

## Generate Flash Image

```sh
vivado -mode batch -source scripts/write_gpg_vanity_ht_search_cfgmem.tcl
```

Flash configuration:

```text
cfgmem part = mx25l25673g-spi-x1_x2_x4
interface = SPIx4
size = 32M
load address = 0x00000000
compression = disabled
```

## Program FPGA Over JTAG

This loads the bitstream into FPGA SRAM only. It does not persist after power-off.

```sh
vivado -mode batch -source scripts/program_gpg_vanity_ht_search.tcl
```

## Program Board Flash

This erases, programs, and verifies the board Quad SPI Flash.

```sh
vivado -mode batch -source scripts/program_gpg_vanity_ht_search_flash.tcl
```

The script first loads Vivado's cfgmem bridge bitstream, then programs:

```text
build/vivado_gpg_vanity_ht_search_synth/gpg_vanity_ht_search_top_flash.mcs
```

Expected success messages include:

```text
Erase Operation successful.
Program/Verify Operation successful.
Flash programming completed successfully
```

## Verify Flash Boot

```sh
vivado -mode batch -source scripts/boot_gpg_vanity_ht_search_from_flash.tcl
```

Expected output includes:

```text
DONE_PIN 1
EOS 1
```

## Check Flash Part Against Vivado

```sh
vivado -mode batch -source scripts/check_gpg_vanity_ht_flash_part.tcl
```

Expected output includes:

```text
CFG_PART_OK mx25l25673g-spi-x1_x2_x4
FPGA_PART_OK xc7k160t_0 PART=xc7k160t
HW_CFGMEM_OK cfgmem_0
```

## Functional Checks

Keygen stream simulation:

```sh
env LANES=2 MUL_LANES=1 NATIVE_COMPRESS=0 BATCH_COMPRESS=0 MULTI_CONTEXT_SCALAR=0 BURST_COUNT=16 vivado -mode batch -source scripts/sim_ed25519_ht_keygen_stream.tcl
```

Top-level UART smoke simulation:

```sh
vivado -mode batch -source scripts/sim_gpg_vanity_ht_search_top.tcl
```

Receiver self-test:

```sh
python3 tools/selftest_gpg_vanity_uart.py
```

## Final Signoff Numbers

```text
WNS = +0.184 ns
WHS = +0.044 ns
TNS = 0.000
THS = 0.000
failed setup endpoints = 0
failed hold endpoints = 0
```

Resource use:

```text
LUT = 74021 / 101400 = 73.00%
FF = 65490 / 202800 = 32.29%
BRAM tile = 192 / 325 = 59.08%
DSP = 473 / 600 = 78.83%
Slice = 23499 / 25350 = 92.70%
```

Throughput:

```text
cycles/key = 7152
keys/s = 9047
expected suffix hit time = 8.24 h
```

## Notes

- The FPGA hot path performs seed generation, Ed25519 public key generation, OpenPGP fingerprinting, and prefix/suffix matching.
- The host only receives hits and writes records/files.
- Current final bitstream checks `XXXX/YYYY` prefix and suffix pattern classes.
- Report: `docs/GPG_VANITY_HT_OPERATION_REPORT.md`
- Hardware facts: `PROJECT_SPEC.md`
