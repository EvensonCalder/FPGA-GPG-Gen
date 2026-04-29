# FPGA-GPG-Gen

Hardware-accelerated OpenPGP vanity Ed25519 key generator on Xilinx Kintex-7.

An FPGA generates Ed25519 keypairs at high speed, computes OpenPGP fingerprints on-chip, and matches a configurable vanity pattern. Matching candidates are streamed over UART to a host that writes secret keys as `.gpg` files.

## Architecture

```
FPGA                                    Host
────                                    ────
TRNG → SHA-512 → Ed25519 scalar-mul     UART ← receive_gpg_vanity_uart.py
  ring-oscillator entropy       │              │
  Von-Neumann debias            │         parse GPGV1 frames
  online health tests           │         CRC32 verify
                                │              │
        OpenPGP fingerprint      │         class_suffix.txt
        pattern match            │         class_prefix.txt
              │                  │              │
         hit? → GPGV1 frame ─────┘         suffix_xxxx.gpg
                seed + public              prefix_xxxx.gpg
                CRC32
```

- **TRNG**: 32 ring-oscillator entropy sources per core, independent sampling, health-monitored
- **SHA-512**: seed expansion to secret scalar
- **Ed25519 scalar multiplication**: high-throughput radix-17 fixed-base ladder with w=9 precomputed table
- **Fingerprint**: on-chip OpenPGP v4 Ed25519 hashing
- **Matcher**: configurable suffix/prefix pattern match on fingerprint hex
- **UART frame**: binary `GPGV1 || class_id || seed || public || crc32` at 2 Mbps

## Performance

| Metric | Value |
|--------|-------|
| Clock | 64.7 MHz |
| Keygen latency | 7152 cycles |
| Throughput | ~9047 keys/s |
| Slice | 24161 / 25350 (95.3%) |
| DSP | 473 / 600 (78.8%) |
| BRAM | 192 / 325 (59.1%) |

Expected time to hit a "last 8 hex all equal" suffix: ~8.2 hours.

## Directory Layout

```
rtl/            FPGA source (SystemVerilog)
sim/            Testbench source and vector data
scripts/        Vivado Tcl build, simulation, and programming scripts
tools/           Host-side Python tools (receiver, keygen, verification)
docs/           Design documents and operation guides
saif_ed25519_ref/  Reference Ed25519 implementation (third-party, with permission)
```

## Quick Start

Rebuild the bitstream:

```sh
vivado -mode batch -source scripts/impl_gpg_vanity_ht_search.tcl
```

Run the receiver:

```sh
tools/run_gpg_vanity_receiver.sh
```

See `docs/RUN_GPG_VANITY_HT.md` for programming, flash setup, and full operation commands.

## Requirements

- Vivado 2025.2
- Kintex-7 XC7K160T (-2 speed grade)
- Python 3 (host receiver)
- GnuPG (optional, for key import)

## License

MIT — see [LICENSE](LICENSE).
