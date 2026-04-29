# HT Scalar Scheduler Model

Current reliable scalar path:

- Fixed-base window: w=10
- Table entries: 26 windows x 512 entries
- Group operations per scalar: 26 mixed additions
- Current `MUL_LANES=2` single-context stream accept gap: 2165 cycles/key
- Current group-engine MADD latency with two FMUL lanes: 72 cycles
- Fixed-base table select is prefetched during each MADD, removing most per-window
  table/control bubbles from the single-context path.

The current design is latency-bound:

```text
26 MADD * ~72 cycles = 1872 cycles
+ SHA/recode/remaining control overhead ~= 293 cycles
= ~2165 cycles/key
```

Throughput target at 100 MHz:

```text
0.2M keys/s => 500 cycles/key
1.0M keys/s => 100 cycles/key
```

The scalar stage must therefore stop waiting on each MADD. It needs multiple
contexts and shared issue/retire over the FMUL lanes.

Mixed-add multiply structure after `D=2Z` is computed by add:

```text
Phase 0 independent:
  B = (Y + X) * q_yplusx
  A = (Y - X) * q_yminusx
  C = T * q_xy2d

Phase 1 after E/F/G/H:
  X = E * F
  Y = G * H
  Z = F * G
  T = E * H
```

Total FMUL per MADD: 7.

For 26 MADD:

```text
26 * 7 = 182 FMUL/key
2 FMUL lanes ideal lower bound = 91 issue cycles/key
```

This matches the 1M keys/s-level roadmap only if:

- FMUL lanes accept one op per cycle.
- At least 32 contexts are available to hide ~32-cycle FMUL latency.
- A tagged result retire path updates context registers when FMUL results return.
- Contexts only stall on phase dependencies, not on global pipeline latency.

Practical first milestone:

```text
~8 contexts, simple round-robin issue
target scalar throughput: 800-1500 cycles/key
```

Aggressive milestone:

```text
16-32 contexts, two FMUL lanes saturated most cycles
target scalar throughput: 200-500 cycles/key
```

The existing `ed25519_ht_keygen_scalar_mc_stage` is the boundary for this
replacement. It should eventually own:

- SHA512 dispatch/result buffering
- w=10 recode per context
- table select per context
- per-context accumulator registers
- per-context MADD phase state
- two global tagged FMUL issue ports
- tagged retire routing back to contexts

Current shared-FMUL building block:

- `ed25519_ht_scalar_mul_issue2` owns the two physical FMUL pipes and returns
  FIFO-tagged retire results.
- `ed25519_ht_fe17_madd_ext_issue` is a verified external-issue MADD slice using
  those tagged retire results.
- Standalone MADD latency remains 72 cycles, matching the current in-engine
  `MUL_LANES=2` MADD path, so this split does not add single-context latency.
- `ed25519_ht_fe17_madd_sched` shares the two FMUL pipes across multiple MADD
  contexts. Focused simulation results:
  - 4 contexts, 21 MADD: 456 cycles, ~21.7 cycles/MADD
  - 8 contexts, 21 MADD: 253 cycles, ~12.0 cycles/MADD
  - 16 contexts, 21 MADD: 184 cycles, ~8.8 cycles/MADD
  - 16 contexts, 256 MADD: 1631 cycles, ~6.4 cycles/MADD

The scheduler direction is viable. Further standalone tuning has diminishing
returns; next work should connect a 16-context scalar/fixedbase front-end to this
shared MADD scheduler.

Integrated fixedbase/keygen measurements:

- `ed25519_ht_fixedbase_sched`, 16 contexts, 32 scalars: 4191 cycles,
  ~130 cycles/scalar.
- `ed25519_ht_fixedbase_sched`, 16 contexts, 128 scalars: 16489 cycles,
  ~128 cycles/scalar.
- End-to-end stream with `MULTI_CONTEXT_SCALAR=1`, `SCALAR_CONTEXTS=16`,
  `BATCH_COMPRESS=1`, `BATCH_SIZE=16`, `BURST_COUNT=32`:
  `accept_gap=1`, `avg_output_gap=615`, `avg_total_gap=1370`.
- End-to-end stream with the same settings and `BURST_COUNT=128`:
  `accept_gap=1`, `avg_output_gap=1051`, `avg_total_gap=1236`.

The scalar/fixedbase hot path is no longer the main limiter in simulation. The
next bottleneck is the batch16 affine/compression backend, whose amortized cost is
around 1.1k-1.2k cycles/key in the integrated stream.
