# Running The GPG Vanity Receiver

## Current Deliverable

The verified, long-running part delivered now is the FPGA backend/IO path:

```text
candidate seed/public key -> OpenPGP v4 Ed25519 fingerprint -> 4173-pattern matcher -> UART hit frame
```

This is ready to connect to a real Ed25519 keygen lane. The high-throughput Ed25519 scalar-multiplication lane is still the remaining blocker before this becomes a complete fast vanity-key bitstream.

## One-Time Checks

Run the software UART protocol self-test:

```sh
python3 tools/selftest_gpg_vanity_uart.py
```

Run backend IO simulations:

```sh
vivado -mode batch -source scripts/sim_gpg_vanity_backend_io.tcl
```

Run backend OOC synthesis checks:

```sh
vivado -mode batch -source scripts/check_gpg_vanity_filter_synth.tcl
vivado -mode batch -source scripts/check_gpg_vanity_hit_uart_synth.tcl
vivado -mode batch -source scripts/check_gpg_vanity_backend_uart_synth.tcl
```

## Long-Running Receiver

Start the receiver before starting the FPGA generator:

```sh
scripts/run_gpg_vanity_receiver.sh /dev/ttyUSB1 build/gpg_vanity_hits
```

The receiver writes private files:

```text
build/gpg_vanity_hits/class_0.txt
...
build/gpg_vanity_hits/class_f.txt
```

Each line is:

```text
class_id seed_hex public_key_hex
```

The output directory is forced to `0700`; files are forced to `0600`. By default each accepted hit is flushed with `fsync`.

## Board-Level UART Soak Test

This test bitstream emits one synthetic, CRC-valid hit frame per second. It is only for UART/receiver/file-splitting soak verification; it does not generate real vanity keys.

Build it:

```sh
vivado -mode batch -source scripts/create_gpg_vanity_uart_soak_project.tcl
```

Program it over JTAG:

```sh
vivado -mode batch -source scripts/program_gpg_vanity_uart_soak.tcl
```

Receive a short sample:

```sh
python3 tools/receive_gpg_vanity_uart.py --port /dev/ttyUSB1 --out-dir build/gpg_vanity_soak_hits --max-records 16
```

Expected bitstream:

```text
build/vivado_gpg_vanity_uart_soak/gpg_vanity_uart_soak_top.bit
```

Implemented result at 50 MHz:

```text
LUT: 953 / 101400 = 0.94%
FF:  382 / 202800 = 0.19%
WNS: 13.646 ns
```

## Verifying Hits

Use the exact OpenPGP creation timestamp configured in the FPGA run:

```sh
python3 tools/verify_gpg_vanity_hits.py build/gpg_vanity_hits --timestamp 1700000000
```

If Python `cryptography` is available, also verify that each seed derives the recorded public key:

```sh
python3 tools/verify_gpg_vanity_hits.py build/gpg_vanity_hits --timestamp 1700000000 --verify-seed
```

## Important Limitation

Do not treat the current RTL or the soak-test bitstream as a complete high-throughput vanity generator yet. It does not include the final pipelined Ed25519 fixed-base scalar-multiplication lane. The current Saif reference adapter synthesizes but misses 50 MHz timing badly and is not suitable as the final engine.
