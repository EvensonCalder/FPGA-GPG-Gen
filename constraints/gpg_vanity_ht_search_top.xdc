set_property PACKAGE_PIN G22 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]

set_property PACKAGE_PIN AF4 [get_ports key2_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports key2_reset_n]

set_property PACKAGE_PIN E12 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property DRIVE 8 [get_ports uart_tx]
set_property SLEW SLOW [get_ports uart_tx]
