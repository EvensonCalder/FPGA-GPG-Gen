set proj_dir [file normalize "build/vivado_trng_uart"]
file mkdir $proj_dir

create_project trng_uart $proj_dir -part xc7k160tffg676-2 -force

add_files [file normalize "rtl/xilinx_ro_entropy.v"]
add_files [file normalize "rtl/xilinx_ro_bank.v"]
add_files [file normalize "rtl/trng_core.v"]
add_files [file normalize "rtl/uart_tx.v"]
add_files [file normalize "rtl/trng_uart_top.v"]
add_files -fileset constrs_1 [file normalize "constraints/trng_uart_top.xdc"]

set_property top trng_uart_top [current_fileset]

synth_design -top trng_uart_top -part xc7k160tffg676-2
opt_design
place_design
route_design

report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"

# RO entropy sources intentionally use combinational loops. The XDC marks the
# loop nets, and this keeps bitgen from rejecting the acknowledged LUTLP-1 DRC.
set_property SEVERITY Warning [get_drc_checks LUTLP-1]
write_bitstream -force "$proj_dir/trng_uart_top.bit"
