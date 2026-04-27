set proj_dir [file normalize "build/vivado_gpg_vanity_uart_soak"]
file mkdir $proj_dir

create_project gpg_vanity_uart_soak $proj_dir -part xc7k160tffg676-2 -force
foreach f {
    rtl/uart_tx.v
    rtl/gpg_vanity_hit_uart_encoder.sv
    rtl/gpg_vanity_hit_uart.sv
    rtl/gpg_vanity_uart_soak_top.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set_property top gpg_vanity_uart_soak_top [current_fileset]

add_files -fileset constrs_1 [file normalize "constraints/gpg_vanity_uart_soak_top.xdc"]

synth_design -top gpg_vanity_uart_soak_top -part xc7k160tffg676-2
opt_design
place_design
route_design

report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
write_bitstream -force "$proj_dir/gpg_vanity_uart_soak_top.bit"
