# High-Throughput Ed25519 Keygen Rewrite

The verified single-lane GPG vanity generator is frozen as the correctness baseline. Its current production HF build runs at 75 MHz and the golden keygen simulation measures 29146 cycles/key, about 2.6k keys/s. That implementation remains useful as an oracle, but it is not the throughput architecture.

## Target

- First usable milestone: at least 50k seed-to-public keys/s.
- Stretch target: same order as a DSP/BRAM-heavy comb design, hundreds of thousands of keys/s if place-and-route permits.
- Scope for this rewrite phase: seed -> Ed25519 public key generation only. Fingerprint matching and output formatting stay out of the critical path until the generator is proven.

## Architecture Direction

- Keep the old `ed25519_keygen_core` as a golden reference.
- Build a new streaming generation boundary: seed stream in, seed/public stream out, counters for accepted/produced/stalls.
- Replace the temporary golden backend with a DSP-heavy, BRAM-table fixed-base generator.
- Use batch inversion for public-key compression instead of per-key inversion.
- Use a TRNG-conditioned DRBG for high-rate seed supply in the final top.

## Current Rewrite State

- `rtl/ed25519_ht_keygen_stream.sv` defines the new stream interface and counters.
- The first backend intentionally wraps the golden single-lane keygen to stabilize verification and handshaking before arithmetic replacement.
- `sim/tb_ed25519_ht_keygen_stream.sv` checks the streaming boundary against known seed/public vectors.

## Next Backend Milestones

1. Add a BRAM-backed fixed-base table path, initially small-window for correctness.
2. Add a multi-context scheduler for independent scalar contexts.
3. Replace serialized field multiplication with a DSP-saturated pipelined field unit.
4. Add batch inversion and point compression.
5. Synthesize and floorplan the generator independently before reconnecting fingerprint logic.
