## Kintex-7 XC7K160T FFG676 board constraints for TRNG UART output.

set_property PACKAGE_PIN G22 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name clk_50m [get_ports clk_50m]

set_property PACKAGE_PIN AF4 [get_ports key2_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports key2_reset_n]

set_property PACKAGE_PIN E12 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property SLEW SLOW [get_ports uart_tx]
set_property DRIVE 8 [get_ports uart_tx]

## Ring oscillators intentionally contain combinational loops.
set ro_loop_nets [get_nets -hierarchical -regexp {.*ro_bank_inst.*/chain.*}]
if {[llength $ro_loop_nets] > 0} {
    set_property ALLOW_COMBINATORIAL_LOOPS TRUE $ro_loop_nets
}
