# TRNG Validation Notes

This design is a board-level TRNG prototype, not a certification result.

## Build

Run from the repository root:

```sh
vivado -mode batch -source scripts/create_trng_uart_project.tcl
```

Program `build/vivado_trng_uart/trng_uart_top.bit` through JTAG.

```sh
vivado -mode batch -source scripts/program_trng_uart.tcl
```

## Capture

The UART format is 8N1 at 2 Mbps with no flow control.

```sh
python3 tools/capture_trng.py --port /dev/ttyUSB0 --baud 2000000 --bytes 104857600 --out trng_100MiB.bin
```

If Linux rejects the serial device with `Permission denied`, either run a one-time temporary permission change:

```sh
sudo chmod a+rw /dev/ttyUSB1
```

Or add your user to the serial group and log out/in:

```sh
sudo usermod -aG dialout "$USER"
```

For a first smoke test, capture 1 MiB. For meaningful randomness testing, capture at least 100 MiB. For SP 800-90B entropy estimation, follow the tool requirements and collect multiple independent power-cycle captures.

## Small-Sample Screening

Full dieharder/TestU01-style batteries require large files and can produce false failures when a small file is rewound many times. For day-to-day board checks, capture 1 MiB to 16 MiB and run the lightweight screening script:

```sh
python3 tools/capture_trng.py --port /dev/ttyUSB1 --baud 2000000 --bytes 16777216 --out trng_16MiB.bin
python3 tools/quick_validate_trng.py trng_16MiB.bin
```

This checks monobit balance, runs, byte chi-square, nibble poker, byte serial correlation, longest bit run, and most-common-value min-entropy. Passing this screening means only that no obvious statistical defect was seen in a small sample; it is not a cryptographic certification.

For a reduced dieharder screening pass that avoids `-a`, use:

```sh
bash tools/run_small_dieharder.sh trng_16MiB.bin
```

The selected tests are birthdays, binary rank, count-1s, runs, STS monobit/runs/serial, RGB bit distribution, RGB KS, and DAB DCT with reduced `psamples`. This is intentionally lower confidence than a full battery, but it is practical for UART-speed board iteration.

## Version Comparison

Reduced dieharder screening on 16 MiB samples showed that the original and intermediate designs were not necessarily broken; many earlier `dieharder -a` failures were caused or amplified by tests rewinding too-small files. Under the reduced screening flow:

| Sample / design | Reduced dieharder result | Notes |
| --- | --- | --- |
| Original 32-RO sample first 16 MiB | `41 PASS / 1 WEAK / 0 FAIL` | One `diehard_runs` weak result |
| Decimated sample first 16 MiB | `40 PASS / 2 WEAK / 0 FAIL` | Two `sts_serial` weak results |
| ARX conditioner 16 MiB | `41 PASS / 1 WEAK / 0 FAIL` | One `dab_dct` weak result |
| DSP-free XOR/rotate conditioner 16 MiB | `34 PASS / 6 WEAK / 2 FAIL` | Rejected despite using no DSP |
| Retained avalanche conditioner 16 MiB | `42 PASS / 0 WEAK / 0 FAIL` | Best screening result; uses about 6 DSP blocks |

The retained version is therefore the 32-RO, decimated, Von-Neumann-corrected, 32-bit avalanche-conditioned design.

## External Tests

Recommended checks:

```sh
dieharder -g 201 -f trng_100MiB.bin -a
```

Run NIST STS and NIST SP 800-90B entropy assessment separately. Passing dieharder or NIST STS does not prove cryptographic security; it only finds obvious statistical failures.

## Expected RTL Behavior

The FPGA discards the initial startup samples, decimates the raw RO samples, applies RCT/APT health tests, applies Von Neumann correction, mixes each 32 accepted bits through a 32-bit avalanche conditioner, and streams conditioned bytes over UART. If the online health test fails, the UART random stream stops. The default top-level instantiates 32 RO cells, processes every 8th raw sample, emits 32 output bits per 32 accepted Von Neumann bits, and uses a 512-sample APT window with bounds 160..352 to avoid false trips during long captures while still detecting gross bias.

The retained implementation intentionally allows Vivado to map the avalanche multiplications into DSP blocks. A DSP-free XOR/rotate conditioner was tested and used no DSP, but produced multiple `WEAK` results in the reduced dieharder screening. The retained DSP avalanche version used more arithmetic resources but produced the cleanest small-sample result.

## Cryptographic Use

Do not use the UART bytes directly as long-term production keys until the exact bitstream, voltage, temperature range, and board population have passed entropy-source validation. For real cryptographic use, feed validated entropy into a CSPRNG or add a vetted conditioner such as SHA-256/AES-CTR-DRBG.
