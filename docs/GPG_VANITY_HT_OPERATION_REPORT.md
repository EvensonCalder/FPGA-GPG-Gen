# GPG Vanity HT Operation Report

## Final Status

- Final stable bitstream is built, timed, JTAG-programmed, written to board Quad SPI Flash, and boot-verified from Flash.
- Host auto-start was not configured. Real use is: power the board, then manually start the receiver script.

## FPGA Image

- Bitstream: `build/vivado_gpg_vanity_ht_search_synth/gpg_vanity_ht_search_top.bit`
- Flash MCS: `build/vivado_gpg_vanity_ht_search_synth/gpg_vanity_ht_search_top_flash.mcs`
- Flash BIN: `build/vivado_gpg_vanity_ht_search_synth/gpg_vanity_ht_search_top_flash.bin`
- Flash part checked in Vivado: `mx25l25673g-spi-x1_x2_x4`
- Flash interface: `SPIx4`, size `32M`, load address `0x00000000`

## Programming Results

- Vivado cfgmem cross-check passed: `CFG_PART_OK mx25l25673g-spi-x1_x2_x4`, `FPGA_PART_OK xc7k160t_0 PART=xc7k160t`, `HW_CFGMEM_OK cfgmem_0`.
- JTAG program passed: `PROGRAMMED xc7k160t_0 with gpg_vanity_ht_search_top.bit`.
- Flash program passed: erase successful, program/verify successful.
- Flash boot verification passed: `DONE_PIN 1`, `EOS 1`; after boot, Vivado reports no SPI debug core, meaning it left the temporary cfgmem bridge image and loaded the final design.

## Performance

- Config: `LANES=2`, `MUL_LANES=1`, `TRNG_CORES=2`, `USE_PLL=1`.
- Clock: `64.705882 MHz`.
- Keygen rate: `7152 cycles/key`, about `9047 keys/s`.
- Expected suffix hit time: about `8.24 h`.

## Timing

- WNS: `+0.562 ns`.
- WHS: `+0.028 ns`.
- TNS/THS: `0.000`.
- Failed setup/hold endpoints: `0`.

## Manual Run

1. Power on the FPGA board. It should load the final design from Flash.
2. Start the receiver manually:

```sh
tools/run_gpg_vanity_receiver.sh
```

3. Outputs are written under:

```text
build/gpg_vanity_real_hits/
build/gpg_vanity_real_hits_gpg/
```

## UART

- Stable serial path: `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`.
- Baud: `2000000`.
- Receiver smoke test opened the port and reported `accepted=0 bad_crc=0`, as expected without an immediate rare hit.
