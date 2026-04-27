source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fe17_mul_pipe_impl"]
set clk_period [expr {[info exists ::env(CLK_PERIOD)] ? $::env(CLK_PERIOD) : 4.500}]

file mkdir $proj_dir
create_project ed25519_ht_fe17_mul_pipe_impl $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_fe17_mul_impl_top.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set_property top ed25519_ht_fe17_mul_impl_top [current_fileset]
synth_design -top ed25519_ht_fe17_mul_impl_top -part xc7k160tffg676-2
create_clock -period $clk_period -name clk [get_ports clk]
opt_design
place_design
phys_opt_design
route_design
phys_opt_design

report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
report_timing -max_paths 10 -file "$proj_dir/timing_paths.rpt"
