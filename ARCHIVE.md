# Archive — Development History

This document marks files that are definitively superseded or were one-off synthesis wrappers.
If there is any doubt about whether a file might be useful, it stays out of this list.

Nothing has been moved or renamed; all paths remain unchanged.

## Production Build

The current stable bitstream is built with:

```text
LANES=2  MUL_LANES=1  TRNG_CORES=2  USE_PLL=1
NATIVE_COMPRESS=0  BATCH_COMPRESS=0  MULTI_CONTEXT_SCALAR=0
```

All files under `rtl/`, `sim/`, `scripts/`, and `tools/` that are not listed below are either
in the production path or represent verified development work that may still be referenced.

---

## Archived — Superseded Implementations

These modules were written, tested, and found to be resource-infeasible or slower than
the production path.  They compile but are not instantiated in the current top-level.

### Native compression (superseded — legacy compression is faster in sim)

```
rtl/ed25519_ht_fe17_invert_pow.sv
rtl/ed25519_ht_keygen_native_compress_lane.sv
sim/tb_ed25519_ht_fe17_invert_pow.sv
scripts/sim_ed25519_ht_fe17_invert_pow.tcl
```

### Synthesis harness wrappers (not design modules)

```
rtl/ed25519_ht_fixedbase_sched_impl_top.sv
rtl/ed25519_ht_keygen_stream_impl_top.sv
```

---

## Archived — Earlier Hardware Projects

These are pre-HT standalone projects (countdown timer, TRNG-only, early vanity top-levels).
They are not part of the current GPG vanity search pipeline.

```
scripts/create_gpg_vanity_search_project.tcl
scripts/create_gpg_vanity_search_x2_project.tcl
scripts/create_gpg_vanity_search_hf_project.tcl
scripts/create_gpg_vanity_uart_soak_project.tcl
scripts/program_gpg_vanity_search.tcl
scripts/program_gpg_vanity_search_hf.tcl
scripts/program_gpg_vanity_uart_soak.tcl
scripts/program_trng_uart.tcl
```

---

## Anything Else

If a file is not listed above, it is either:

- In the active production build path, or
- A verified development artifact that could be useful for future work (multi-context,
  batch compression, tagged multiply experiments, etc.)

The archived files above represent dead-ends with a definitive reason for abandonment.
