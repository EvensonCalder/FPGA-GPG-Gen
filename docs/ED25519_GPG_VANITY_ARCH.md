# Ed25519 GPG Vanity Generator Architecture

## Target

Generate Ed25519 OpenPGP key candidates on the FPGA, test each candidate against accepted 12-hex-digit public-key fingerprint shapes, and send only accepted hits over UART.

The current TRNG/UART project is the entropy and I/O preparation stage. It does not yet contain Ed25519 scalar multiplication, SHA-512, OpenPGP fingerprint hashing, or the final pattern matcher.

## Fingerprint Object To Confirm

Before implementing the matching hardware, the exact GPG object must be fixed. The recommended target is the OpenPGP v4 primary-key fingerprint that GnuPG displays for an Ed25519 signing key. That fingerprint is SHA-1 over the OpenPGP public-key packet body, so the following fields affect the matched text:

- OpenPGP version, normally v4 unless v6 keys are requested.
- Creation timestamp.
- Public-key algorithm, EdDSA for Ed25519 in v4 OpenPGP.
- Ed25519 curve OID encoding.
- Encoded Ed25519 public point.

If the timestamp used in hardware differs from the timestamp used when constructing/importing the final GPG key, the GPG fingerprint will change. The hardware generator must therefore either fix the timestamp and output it with the key material, or make the host importer use the same timestamp.

## Feasibility Math

For a 12-hex-digit feature, the search space is `2^48` possible suffixes or prefixes. With the requested `2 * 4178 = 8356` accepted cases, the expected candidate count is:

```text
2^48 / 8356 = 33,686,018,608 candidates
```

To find one hit in 1 to 2 hours, the FPGA would need roughly:

```text
1 hour:  9.36 million Ed25519 public keys / second
2 hours: 4.68 million Ed25519 public keys / second
```

That throughput is far beyond a straightforward single Ed25519 scalar-multiplier implementation on an XC7K160T. A practical FPGA implementation must either:

- Widen the accepted pattern set substantially.
- Use many deeply pipelined scalar-multiplier lanes and accept high resource use.
- Move bulk search to GPU/CPU and use the FPGA as a TRNG/security appliance.
- Search a cheaper target than the GPG fingerprint, such as raw public-key bytes, if that is acceptable.

UART is not the throughput bottleneck because only accepted hits are transmitted. Candidate generation and fingerprint hashing dominate.

## Hardware Pipeline

Recommended fully-on-FPGA pipeline:

```text
TRNG -> DRBG reseed FIFO -> candidate seed generator
    -> SHA-512 secret expansion + Ed25519 clamp
    -> Ed25519 base-point scalar multiplication
    -> OpenPGP public-key packet encoder
    -> SHA-1 or v6 fingerprint hash
    -> 12-hex pattern matcher
    -> UART hit frame encoder
```

### Randomness Matching

Using 32 fresh TRNG bytes per candidate at 5 million candidates/s would require about `160 MiB/s` of entropy, which is unrealistic for the current fabric RO TRNG. The practical architecture is:

- Use the existing validated RO TRNG to seed and periodically reseed a cryptographic DRBG.
- Generate each 32-byte Ed25519 seed from the DRBG plus a counter.
- Keep the DRBG state entirely on FPGA.
- Never output rejected seeds.

This keeps key candidates unpredictable while allowing the key generator to run much faster than the physical entropy source.

### Pattern Classes

Use one 4-bit class identifier for 16 output files:

```text
bit[3]   = 0 for suffix/last-12-hex match, 1 for prefix/first-12-hex match
bit[2:0] = pattern family 0..7
```

The interpreted pattern alphabet is:

```text
1234567890ABCDEF
```

The current reference matcher in `tools/gpg_vanity_patterns.py` defines these families:

| Family | Class suffix | Class prefix | Count | Shape |
| --- | --- | --- | ---: | --- |
| 0 | `0` | `8` | 11 | `1122 3344 5566` ... `AABB CCDD EEFF` |
| 1 | `1` | `9` | 11 | `6655 4433 2211` ... `FFEE DDCC BBAA` |
| 2 | `2` | `a` | 5 | `1234 5678 90AB` ... `5678 90AB CDEF` |
| 3 | `3` | `b` | 11 | `1234 5665 4321` ... `ABCD EFFE DCBA` |
| 4 | `4` | `c` | 11 | `6543 2112 3456` ... `FEDC BAAB CDEF` |
| 5 | `5` | `d` | 14 | `1122 3333 2211` ... `DDEE FFFF EEDD` |
| 6 | `6` | `e` | 14 | `3322 1111 2233` ... `FFEE DDDD EEFF` |
| 7 | `7` | `f` | 4096 | `XXXX YYYY ZZZZ` |

This sums to `4173` patterns per side and `8346` prefix-or-suffix cases. The user confirmed `4173` is the correct per-side count.

Reference check:

```bash
python3 tools/gpg_vanity_patterns.py --summary
```

## secworks/ed25519 Reference

`https://github.com/secworks/ed25519` was checked as a possible reference. It has a permissive BSD-style license, but its README says the implementation was only just started, and the two RTL files are placeholders:

```text
ed25519.v       Top level wrapper for the ed25519 core. Nothing here yet though.
ed25519_core.v  The actual ed25519 core top entity.
```

It is therefore not a usable Ed25519 key-generation core. Other pieces from the secworks ecosystem may still be useful, especially mature hash cores, but the scalar-multiplication datapath will need a different source or a new implementation.

## SaifMo01 Ed25519 FPGA Reference

`https://github.com/SaifMo01/Ed25519-Cryptographic-Digital-Signature-on-FPGA` is a more substantial reference than `secworks/ed25519`. The repository was cloned locally to `saif_ed25519_ref/`. The user contacted the author and confirmed it can be used for this learning/exploration project.

It contains SystemVerilog modules for:

- `Top_fsm/Ed25519_TOP.sv`: 64-bit bus wrapper with `opmode == 00` KeyGen, `01` Sign, `10` Verify.
- `Top_fsm/ed25519_fsm_top.sv`: top FSM for KeyGen/Sign/Verify.
- `sha512/*`: SHA-512 wrapper and compression core.
- `baseP_mult/*`: base-point scalar multiplication and double-scalar multiplication datapath.
- `fe_modules/*`, `ge_modules/*`, `sc_ops/*`: finite-field, group, and scalar operations.

Important integration findings:

- KeyGen uses `others/RNG.v`, a fixed-seed 256-bit LFSR, as the private seed source. That must be replaced by our TRNG/DRBG candidate stream.
- The top KeyGen returns a `512-bit` clamped/expanded secret and `256-bit` public key. Our UART hit protocol should output the original 32-byte seed, not only the expanded scalar, so the wrapper must preserve the seed before SHA-512 expansion.
- The SHA-512 wrapper supports fixed 32/96/128-byte message shapes for Ed25519 internals. GPG/OpenPGP fingerprint matching still needs an additional OpenPGP public-key packet encoder and SHA-1 fingerprint hash for v4 keys, or the corresponding v6 fingerprint hash if v6 keys are selected.
- The design is sequential and resource-efficient, not a many-million-candidates-per-second pipeline. `fe_mul` and `fe_sq` serialize arithmetic over many cycles, and SHA-512 compression is one round per cycle. It may be useful as a correctness baseline or first integrated prototype, but it is unlikely to reach the requested 1-2 hour hit interval without many lanes or a different high-throughput architecture.
- The test flow is ModelSim-style (`run.do`) and relies on `dpi_crypto_sign.dll`. Before integration, run independent simulation vectors and a Vivado synthesis pass on the target Kintex-7.

Local synthesis checks:

| Design | Result | Resource estimate | Timing note |
| --- | --- | --- | --- |
| Full `Ed25519_TOP` | Synthesis reached netlist generation before timeout during reporting | About `208 DSP`; very large LUT/FF footprint | Includes Sign/Verify and unused logic for our search task |
| `rtl/ed25519_keygen_core.sv` KeyGen-only adapter with optimized fixed-base wrapper | Synthesizes with `0` errors / `0` critical warnings | `61053 LUT`, `48906 registers`, `264 DSP`, `0 BRAM` | 50 MHz OOC timing passes with `WNS +2.037 ns` |

The KeyGen-only adapter uses only these reference blocks:

```text
SHA512_wrapper_mux -> seckey_clamp -> ed25519_fixedbase_core -> ge_p3_tobytes
```

It removes the fixed LFSR from the KeyGen path and accepts an external 32-byte seed. It also preserves the original seed for later UART hit output.

Reusable now:

- `SHA512_wrapper_mux`, `SHA512`, `SHA512_Compress`, `SHA512_PADDING`, `SHA512_K_ROM` as a correctness baseline for 32-byte seed expansion.
- `seckey_clamp` directly.
- `base_TOP` and dependencies as a scalar-multiplication correctness baseline; production keygen now uses `ed25519_fixedbase_context_v2_shared` behind `ed25519_fixedbase_core`.
- `ge_p3_tobytes` and dependencies as a compressed public-key encoder baseline.

Must be rewritten or heavily cleaned before high-throughput use:

- `others/RNG.v`: replaced by TRNG/DRBG.
- `Ed25519_TOP` and `ed25519_fsm_top`: too broad; Sign/Verify are not needed for vanity search.
- `base_TOP`: contains self-holding combinational mux code that infers thousands of latches.
- `fe_mul`, `fe_sq`, `fe_sq2`: need pipelined DSP-friendly implementations for 50 MHz+ and multiple lanes.
- OpenPGP/GPG fingerprint hashing: not present and must be implemented separately.

Recommended usage: treat this repo as a correctness/reference core and first prototype. For the final “run the chip hard” version, keep the functional decomposition but replace the arithmetic datapath with a pipelined, lane-replicable design.

## UART Hit Protocol

Accepted hits are rare, so the UART protocol is optimized for safety and resynchronization, not bandwidth.

Binary frame:

```text
magic      5 bytes  ASCII "GPGV1"
class_id   1 byte   lower nibble is the 0..15 class identifier; upper nibble must be 0
seed      32 bytes  Ed25519 private seed, not expanded scalar
public    32 bytes  Ed25519 public key bytes
crc32      4 bytes  little-endian CRC-32 over class_id || seed || public
```

The host receiver writes one line per accepted hit:

```text
<class_hex> <ed25519_seed_hex> <ed25519_public_hex>
```

Files are named `class_0.txt` through `class_f.txt`, with mode `0600`, inside a directory with mode `0700`.

## Receiver

Use:

```bash
python3 tools/receive_gpg_vanity_uart.py --port /dev/ttyUSB1 --baud 2000000 --out-dir build/gpg_vanity_hits --mlock
```

Security behavior:

- Does not print seeds or public keys to stdout/stderr.
- Refuses symlinked output directories or output files.
- Creates the output directory as `0700` and files as `0600`.
- Disables core dumps.
- Optionally tries `mlockall` with `--mlock`.
- Calls `fsync` after each accepted key by default.

## Implementation Stages

1. Confirm the exact GPG fingerprint target and timestamp handling.
2. Freeze the 8 pattern families and exact accepted-count math.
3. Add a host-side reference generator that creates GnuPG-compatible Ed25519 packets from `seed/timestamp`, computes the exact fingerprint, and verifies matcher results.
4. Implement SHA-512 candidate expansion and DRBG.
5. Implement Ed25519 base-point scalar multiplication.
6. Implement OpenPGP public-key packet encoding and fingerprint hash.
7. Implement the 16-class matcher and UART frame encoder.
8. Build, route, measure throughput, and tune the number of parallel lanes against timing and resource reports.
