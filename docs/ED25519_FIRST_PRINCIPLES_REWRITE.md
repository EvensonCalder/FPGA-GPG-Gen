# Ed25519 First-Principles Rewrite

## Problem

The current keygen lane is a heavily optimized reference-style core. It is correct and reaches 175 MHz OOC, but it is still built around a shared, sequential group-operation engine. That makes it resource-heavy and low-throughput:

- Current best OOC: about 175 MHz, about 38.1k cycles/key, about 4.6k keys/s.
- Main bottleneck: fixed-base scalar multiplication plus field inversion/encoding.
- Main structural issue: high-fanout control and wide muxing into shared field units.

Small local edits are now mostly timing tradeoffs. A real throughput gain needs a new fixed-base-specific datapath.

## What To Keep

- SHA-512 wrapper initially, because it is not the dominant cycle cost and already simulates correctly.
- OpenPGP fingerprint, matcher, and UART backend, because they are not bottlenecks.
- Existing keygen test vectors as the top-level correctness gate.
- Existing Saif-style core as a known-good reference, not as the long-term architecture.

## What To Replace

- `base_TOP` fixed-base scalar multiplication.
- Generic `ge_top_mux_wrapper` / `ge_fsm_top` shared group-operation scheduler.
- Sequential shared `fe_mul` / `fe_sq` / `fe_sq2` scheduling, once a clean fixed-base datapath exists.
- Final `ge_p3_tobytes` inversion path, after scalar multiplication is under control.

## First-Principles Architecture

### Scalar Recoding

Use Ed25519 fixed-base signed 4-bit windows:

- Clamp scalar from SHA-512 lower 256 bits.
- Split into 64 nibbles.
- Carry-propagate to signed digits in `[-8, 8]`.
- Process odd digits, four doublings, then even digits, matching the reference algorithm for easy verification.

This keeps the mathematical schedule known-good while replacing the implementation of each operation.

### Fixed-Base Table

Use fixed-base precomputed points only:

- 32 positions.
- 8 positive multiples per position.
- Store `Y+X`, `Y-X`, and `2dXY`.
- Sign handling is done after table read by swapping `Y+X` / `Y-X` and negating `2dXY`.

The first implementation can keep LUT ROM. BRAM packing is a later resource tradeoff, because distributed ROM may route better for one lane.

### Field Representation

Keep the 10-limb radix layout initially:

- Limb widths alternate 26/25 effective bits.
- Stored in signed 32-bit containers for compatibility.
- This allows bit-exact comparison against current field modules.

The later high-throughput variant may switch to 5x51 or 4x64 only if DSP packing proves better on Kintex-7.

### Field Engine V1

Build a new registered field engine with explicit operation issue slots:

- Separate command/data registers from arithmetic datapath.
- No direct state-to-wide-input mux path.
- Use synchronous reset in new modules to improve DSP packing.
- Use fixed latency for `mul`, `sq`, and `add/sub`.
- Register product operands, product outputs, partial sums, and carry stages.

Target for V1 is not maximum throughput; it is clean timing and a reusable base for V2.

### Group Operation V1

Implement only the operations needed for fixed-base keygen:

- mixed addition `ge_madd` with precomputed table point.
- point doubling.
- p1p1-to-p2 and p1p1-to-p3 conversions only as internal pipeline stages, not generic opcodes.

Avoid a generic opcode wrapper. Each stage owns its registers and feeds the next stage directly.

## Expected Milestones

### Milestone 1: Clean Replacement Shell

- New module: `ed25519_fixedbase_core`.
- Same interface shape as the scalar-multiply part of `base_TOP`.
- Initially may instantiate reference field modules internally.
- Must pass current keygen vectors.

Success criteria:

- Correct public key vectors.
- No regression to existing best core.
- OOC report available at 160/175 MHz.

### Milestone 2: Registered Field Engine

- Replace shared field modules with new synchronous-reset field engine.
- Remove state/control to arithmetic-register critical paths.
- Keep the same mathematical schedule.

Success criteria:

- 175 MHz with more timing margin than current best.
- Lower routing pressure in worst paths.
- Similar or lower LUT than current single lane.

### Milestone 3: Throughput Scheduler

- Start overlapping table selection, add/double conversion, and field operation issue.
- Eliminate unnecessary p1p1 conversion wait states where data dependencies allow.

Success criteria:

- Meaningful cycle reduction versus about 38.1k cycles/key.
- Still fits one lane with backend/TRNG.

### Milestone 4: More Parallel Field Arithmetic

- Spend more DSPs to reduce per-field-op latency.
- Use registered product trees and carry pipeline.

Success criteria:

- Better keys/s despite higher DSP usage.
- Remains routable on XC7K160T.

## Non-Goals For The First Rewrite

- Do not implement full Ed25519 sign/verify.
- Do not keep variable-base or double-scalar paths.
- Do not preserve constant-time table selection for physical side-channel resistance; this is local vanity-search hardware.
- Do not target 5M keys/s in one rewrite step. That likely needs a much wider/multi-stage pipeline than the current FPGA can host as a single-lane drop-in.

## Current Experiment Results

- Direct table addressing was correct in simulation but worse after synthesis: more LUT and slightly worse 175 MHz slack.
- Fixed-base-only parameter propagation saved some LUT but hurt timing because control still fed shared arithmetic muxes.
- `ed25519_fixedbase_core` now provides the replacement boundary and delegates to `ed25519_fixedbase_context_v2_shared`; keygen vectors pass with the optimized fixed-base path.
- `ed25519_scalar_recode_4bit` implements the fixed-base signed 4-bit recoding and passes standalone simulation.
- `ed25519_fe_addsub_pipe` provides a synchronous-reset two-stage field add/sub primitive. OOC at 200 MHz meets timing with WNS +3.471 ns and uses 321 LUT / 965 FF / 0 DSP.
- `ed25519_fixedbase_table_select_pipe` matches the old table `select` for all 32 positions and digits -8..8. OOC at 250 MHz meets timing with WNS +0.835 ns and uses 7636 LUT / 880 FF / 0 DSP.
- Table selection is fast enough after pipelining, but the one-instance variable-position ROM still costs significant LUT due to wide muxing. BRAM or position-specialized table access remains a later resource tradeoff.
- `ed25519_ge_madd_v1` implements standalone fixed-base mixed addition without the generic opcode wrapper and matches legacy `ge_top` opcode `3'd1` in simulation.
- Replacing legacy `fe_mul` with `ed25519_fe_mul_wrap_pipe` moved the standalone `ge_madd` OOC limit from about 170 MHz to 300 MHz.
- `ed25519_fe_mul_wrap_pipe` now uses synchronous reset, DSP-packed operand/product registers, split product/carry stages, precomputed `g*19`, and sign-extended low-limb carry remainders instead of long `h - (carry << bits)` subtract paths.
- `ed25519_ge_madd_v1` now fires the three independent mixed-add field multiplications in parallel. This raises standalone `ge_madd` DSP usage from 40 to 120 and keeps all three multipliers active during the multiply phase.
- Current best standalone parallel `ge_madd` OOC: 300 MHz meets timing with WNS +0.127 ns and uses 16740 LUT / 19076 FF / 120 DSP.
- 325 MHz parallel `ge_madd` OOC currently fails with WNS -0.129 ns on the per-multiplier operand-selection route into DSP B. The 300 MHz path is still clean, and the next efficiency work should focus on using this higher parallelism in point double / scalar-multiply scheduling rather than adding latency-only pipeline stages.
- `ed25519_ge_p2_dbl_v1` implements standalone point doubling with four parallel field multipliers for `X*X`, `Y*Y`, `Z*(2Z)`, and `(X+Y)^2`. It matches legacy `ge_top` opcode `3'd5` in simulation.
- Current best standalone parallel `p2_dbl` OOC: 300 MHz meets timing with WNS +0.121 ns and uses 22281 LUT / 18183 FF / 160 DSP.
- 325 MHz parallel `p2_dbl` OOC fails with WNS -0.135 ns, TNS -107.909 ns, and 810 failing setup endpoints. The worst path is the same field-multiplier operand-selection route from `g_elem_q_reg` through LUT muxing into DSP B, so the practical OOC target for these V1 parallel group ops is 300 MHz.
- `ed25519_ge_p1p1_to_p2p3_v1` implements the fixed-base conversion stage for both p1p1-to-p2 and p1p1-to-p3. It fires the independent conversion multiplications in parallel and matches constant-opcode legacy `ge_top` references for opcodes `3'd3` and `3'd4` in simulation.
- Current best standalone parallel `p1p1_to_p2p3` OOC: 300 MHz meets timing with WNS +0.127 ns and uses 20339 LUT / 15596 FF / 160 DSP.
- `ed25519_fixedbase_context_v1` integrates table select, parallel `ge_madd`, parallel `p2_dbl`, and parallel p1p1 conversion into a fixed-base scalar-multiply context. It matches legacy `base_TOP` `op_operand=1` outputs for the current scalar test vectors.
- `ed25519_fixedbase_context_v1` simulation reduces fixed-base scalar cycles from legacy about 23.2k-23.9k cycles to 13653 cycles for the tested scalars.
- Current integrated context OOC: 300 MHz meets timing with WNS +0.065 ns and uses 69547 LUT / 58235 FF / 440 DSP. This is good resource occupancy for a context, but not yet good time-averaged hardware utilization because one scalar context still serially waits between `madd`, conversion, and doubling dependencies.
- `ed25519_fixedbase_group_engine_v1` shares one 4-multiplier group engine across mixed-add, point-doubling, and p1p1 conversion. It removes the long-idle dedicated `madd`/`dbl`/`convert` multiplier banks from `context_v1`.
- `ed25519_fixedbase_context_v2_shared` matches legacy `base_TOP` `op_operand=1` outputs for the current scalar test vectors. It takes 14005 cycles for the tested scalars, only 352 cycles slower than `context_v1`.
- Current shared-engine context OOC: 300 MHz meets timing with WNS +0.050 ns and uses 38330 LUT / 29871 FF / 160 DSP. Versus `context_v1`, this cuts DSP from 440 to 160 and LUT from 69547 to 38330 while keeping nearly the same cycles/scalar.
- Next architecture step: replicate shared-engine contexts or build a multi-context scheduler around several shared engines. Three `context_v2_shared` engines would target roughly 480 DSP and much better real throughput per FPGA than one 440-DSP `context_v1`.
- Conclusion: the issue is the architecture boundary, not just table selection or dead branch removal.
