set proj_dir [file normalize "build/vivado_gpg_vanity_hit_uart_synth"]
file mkdir $proj_dir

create_project gpg_vanity_hit_uart_synth $proj_dir -part xc7k160tffg676-2 -force
foreach f {
    rtl/uart_tx.v
    rtl/gpg_vanity_hit_uart_encoder.sv
    rtl/gpg_vanity_hit_uart.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set_property top gpg_vanity_hit_uart [current_fileset]
synth_design -top gpg_vanity_hit_uart -part xc7k160tffg676-2 -mode out_of_context
create_clock -period 20.000 -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
