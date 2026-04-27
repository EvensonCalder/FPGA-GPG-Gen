# High-Throughput GPG Vanity Architecture

## Goal

The hot path must stay on FPGA:

```text
TRNG reseed -> DRBG/counter seed stream -> SHA-512 seed expansion -> Ed25519 fixed-base public key
    -> OpenPGP v4 fingerprint -> 4173-pattern prefix/suffix matcher -> UART hit frame
```

The host CPU must not receive or filter rejected candidates. UART only carries accepted hits.

## Throughput Target

The accepted pattern count is:

```text
4173 suffix cases + 4173 prefix cases = 8346 cases
```

Expected candidates per hit:

```text
2^48 / 8346 = 33,726,405,522 candidates
```

Candidate rates for target hit intervals:

```text
1 hour:  9.37 M candidates/s
2 hours: 4.68 M candidates/s
24 hours: 390 k candidates/s
7 days:   55.8 k candidates/s
```

This means the design target is not UART bandwidth and not SHA-1. It is Ed25519 fixed-base scalar multiplication throughput.

## Host CPU Role

The CPU is allowed only in non-hot-path roles:

- Set run parameters: fixed OpenPGP creation timestamp, pattern mode, DRBG reseed policy.
- Receive accepted UART hit frames.
- Write private files with restrictive permissions.
- Reconstruct/import GPG keys using the same timestamp.
- Independently verify the public key and OpenPGP fingerprint for accepted hits.
- Run statistical validation on TRNG samples outside the key-search hot path.

The CPU must not:

- Compute Ed25519 public keys for every candidate.
- Compute OpenPGP fingerprints for every candidate.
- Receive rejected seeds/public keys.

## FPGA Role

The FPGA must do all candidate-rate work:

- Generate unpredictable 32-byte seeds from a DRBG reseeded by the existing RO TRNG.
- Compute `SHA512(seed)` and clamp the lower 32 bytes to the Ed25519 scalar.
- Compute the Ed25519 base-point public key.
- Compute the OpenPGP v4 Ed25519 primary-key fingerprint.
- Match the first/last 12 hex digits against the 16 classes.
- Emit only hits with `class_id`, original 32-byte seed, public key, and CRC.

## Implemented Backend

The following backend pieces are already implemented and verified:

| Module/tool | Purpose | Status |
| --- | --- | --- |
| `tools/openpgp_ed25519.py` | Host reference for OpenPGP v4 Ed25519 public-key fingerprint | Verified against GnuPG binary export |
| `rtl/openpgp_v4_ed25519_fingerprint.sv` | Fixed OpenPGP v4 Ed25519 SHA-1 fingerprint core | Simulated against reference vector; synthesizes at 50 MHz |
| `rtl/gpg_vanity_pattern_matcher.v` | 16-class 4173-pattern prefix/suffix matcher | Synthesizes |
| `rtl/gpg_vanity_filter.sv` | Candidate backend: fingerprint + matcher + hit payload registers | Synthesizes at 50 MHz |
| `rtl/gpg_vanity_hit_uart_encoder.sv` | Hardware encoder for `GPGV1` hit frames with CRC32 | Simulated against software frame reference; synthesizes at 50 MHz |
| `rtl/gpg_vanity_backend_uart.sv` | Backend wrapper from candidate seed/public key to UART TX | Synthesizes at 50 MHz |
| `tools/receive_gpg_vanity_uart.py` | Secure hit receiver and 16-file splitter | Tested with synthetic frame |
| `tools/verify_gpg_vanity_hits.py` | Verifies received hit files against OpenPGP fingerprint patterns | Ready |

Backend synthesis result at 50 MHz:

```text
gpg_vanity_filter:
  LUT: 3907 / 101400 = 3.85%
  FF:  3897 / 202800 = 1.92%
  DSP: 0
  WNS: 13.425 ns

gpg_vanity_hit_uart:
  LUT: 1311 / 101400 = 1.29%
  FF:   586 / 202800 = 0.29%
  DSP: 0
  WNS: 17.675 ns

gpg_vanity_backend_uart:
  LUT: 5195 / 101400 = 5.12%
  FF:  4259 / 202800 = 2.10%
  DSP: 0
  WNS: 13.425 ns
```

The backend is not the bottleneck.

## Reference Ed25519 Core Status

`saif_ed25519_ref/` is useful as a correctness reference, not as the final high-throughput engine.

Current KeyGen-only adapter:

```text
rtl/ed25519_keygen_core.sv
SHA512_wrapper_mux -> seckey_clamp -> base_TOP -> ge_p3_tobytes
```

Latch-free baseline OOC synthesis result after sequential carry/encoding cleanup:

```text
LUT: 59819 / 101400 = 58.99%
FF:  51076 / 202800 = 25.19%
DSP: 32 / 600 = 5.33%
BRAM: 0
Latches: 0
50 MHz WNS: 6.482 ns
```

Behavioral seed-to-public-key simulation against Python `cryptography` vectors:

```text
sim/tb_ed25519_keygen_core.sv
vector 0: 111706 cycles
vector 1: 111852 cycles
50 MHz estimate: about 447 candidates/s per lane
```

Measured resource-push experiments on the same reference-style lane:

| Variant | Keygen latency | LUT | FF | DSP | Timing result |
| --- | ---: | ---: | ---: | ---: | --- |
| 10-product/cycle `fe_mul` | about 69.1k cycles/key | 63658 | 51089 | 140 | 50 MHz WNS 4.234 ns |
| Parallel `fe_sq`/`fe_sq2` | about 42.5k cycles/key | 67296 | 50789 | 250 | 50 MHz WNS 4.234 ns |
| Single-cycle carry compression | about 16.5k cycles/key | 75455 | 50493 | 250 | 50 MHz WNS 0.843 ns |
| 6-stage carry split | about 20.3k cycles/key | 69824 | 50545 | 250 | 100 MHz WNS -5.518 ns |
| DSP operand pipeline + SHA round pipeline | 37667 / 38405 cycles/key | 70577 | 57221 | 250 | 150 MHz WNS +0.080 ns |
| Shift/add square precompute | 37667 / 38405 cycles/key | 70794 | 57186 | 240 | 160 MHz WNS -0.161 ns |
| Registered precompute select output | 37667 / 38405 cycles/key | 70726 | 57985 | 240 | 160 MHz WNS -0.146 ns |
| Split `select` absolute lookup from sign application | 37731 / 38469 cycles/key | 71922 | 58762 | 240 | 175 MHz WNS +0.049 ns |

The 6-stage carry split removed the previous 72-level carry-chain worst path. Later edits pushed the reference-style lane to 175 MHz OOC synthesis by cutting DSP operand paths, SHA-512 round-add paths, square precompute multipliers, and finally the `base_TOP` signed-window `select` path.

Current best OOC point:

```text
Latency: 37731 / 38469 cycles/key, mean 38100 cycles/key
175 MHz OOC: WNS +0.049 ns, TNS 0, 0 failing endpoints
Resources: 71922 LUT / 58762 FF / 240 DSP / 0 BRAM
Estimated single-lane rate: 175e6 / 38100 = 4.59k candidates/s
Mean hit interval for 8346 cases: about 85 days
```

Rejected experiment:

```text
Splitting final fold carry paths in fe_sq2, fe_mul, and fe_sq preserved correctness,
but increased latency to 38475 / 39213 cycles/key and still missed 180 MHz OOC
timing by 0.073 ns. It was reverted because it reduced expected candidates/s.
```

Historical failed timing example from the earlier 6-stage point:

```text
100 MHz probe: WNS -5.518 ns, TNS -5929.549 ns, 3737 failing endpoints
150 MHz probe: WNS -8.851 ns, TNS -20901.309 ns, 5077 failing endpoints
200 MHz probe: WNS -10.518 ns, TNS -32669.326 ns, 11084 failing endpoints

Worst path at 100 MHz:
  Source:      u_base_top/state_reg[0]/C
  Destination: ge_fsm_top_instant/mul_unit/h_temp_reg[2][63]/D
  Data delay:  15.499 ns = 7.279 ns logic + 8.220 ns route
  Levels:      36, including 17 CARRY4 and 2 DSP48E1
```

The current reference-style lane is now about `4.59k` candidates/s at the best OOC synthesis point. OOC synthesis is not final place-and-route timing; the fully integrated generator should expect some margin loss.

Reasons it is not final:

- Wide field multipliers and squarers have no DSP pipeline registers.
- Sequential arithmetic is not lane-replicable enough for high candidate rates.
- Full reference top includes Sign/Verify logic that is irrelevant for vanity search.
- The current optimized keygen lane already uses about 71% of LUTs and 40% of DSPs before backend integration, so a second lane will not fit on the XC7K160T.
- The 180 MHz probe still fails after low-risk local cuts; remaining paths cross `base_TOP`/`ge_top` control and unified field-operation datapaths.

## Required High-Throughput Rewrite

The final accelerator should keep the same mathematical function but replace the arithmetic datapath:

1. `ed25519_seed_expand_lane`: accepts a 32-byte seed, computes SHA-512, outputs clamped scalar and preserved seed.
2. `ed25519_fixed_base_lane`: pipelined fixed-base scalar multiplication for the Ed25519 base point.
3. `ed25519_encode_lane`: converts extended/projective result to compressed 32-byte public key.
4. `gpg_vanity_filter`: current backend, one per lane or shared depending on candidate rate.
5. `hit_uart_encoder`: frames only accepted results.

Design constraints for the rewrite:

- Use DSP48E1 pipeline registers; no unregistered wide multipliers on timing-critical paths.
- Avoid inferred latches completely.
- Use fixed-base precomputation stored in distributed ROM/BRAM to reduce additions.
- Make lanes independent so the design can scale until DSP/LUT/timing limits are reached.
- Prefer a streaming ready/valid interface between stages.
- Optimize for candidates/s, not single-operation latency.

## Practical Milestones

1. Prototype correctness path: use `ed25519_keygen_core.sv` at low clock after cleanup only to verify seed/public/fingerprint end-to-end.
2. Build high-throughput field arithmetic: pipelined `fe_mul`, `fe_sq`, modular reduction, and inversion/encoding strategy.
3. Replace `base_TOP` with fixed-base-only scalar multiplication.
4. Integrate one full lane with `gpg_vanity_filter` and measure candidates/s on hardware.
5. Replicate lanes until timing or resources cap out.
6. Compare measured candidates/s with the expected hit interval and adjust accepted pattern breadth if needed.

## Reality Check

The requested 1-2 hour hit interval requires `4.68M-9.37M` full GPG-fingerprint candidates/s. That is an aggressive target for an XC7K160T. The FPGA is still the correct place for acceleration, but the achievable rate will depend on how much fixed-base arithmetic can be pipelined and replicated. The current reference core is far below that target; the final result requires a dedicated high-throughput scalar-multiplication implementation, not just wiring the reference core to UART.

Current mean-hit estimates for the 8346 accepted 12-hex prefix/suffix cases:

| Candidate rate | Mean hit interval |
| ---: | ---: |
| 3.94k/s, 150 MHz OOC best before select split | 99 days |
| 4.20k/s, 160 MHz OOC select-split lane | 93 days |
| 4.59k/s, 175 MHz OOC select-split lane | 85 days |
| 5.00M/s reference target | 1.87 hours |

Conclusion: further incremental edits to the Saif-style sequential core are useful for a low-throughput correctness bitstream, but not for the high-throughput vanity target. The next architecture step should be a fixed-base-specific lane with registered DSP sum trees, precomputed basepoint tables, and throughput-oriented pipelining.
