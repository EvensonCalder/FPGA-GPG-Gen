set proj_dir [file normalize "build/vivado_ed25519_ht_fe17_mul_pipe_synth"]
file mkdir $proj_dir
create_project ed25519_ht_fe17_mul_pipe_synth $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set_property top ed25519_ht_fe17_mul_pipe [current_fileset]
synth_design -top ed25519_ht_fe17_mul_pipe -part xc7k160tffg676-2
create_clock -period 4.000 -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
