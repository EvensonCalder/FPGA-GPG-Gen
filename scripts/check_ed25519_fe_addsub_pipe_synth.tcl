set period [expr {[info exists ::env(CLK_PERIOD)] ? $::env(CLK_PERIOD) : "5.714"}]
set suffix [expr {[info exists ::env(PROJ_SUFFIX)] ? $::env(PROJ_SUFFIX) : [string map {. p} $period]}]
set proj_dir [file normalize "build/vivado_ed25519_fe_addsub_pipe_synth_${suffix}"]

file mkdir $proj_dir
create_project ed25519_fe_addsub_pipe_synth_${suffix} $proj_dir -part xc7k160tffg676-2 -force

add_files [file normalize "rtl/ed25519_fe_addsub_pipe.sv"]
set_property file_type SystemVerilog [get_files [file normalize "rtl/ed25519_fe_addsub_pipe.sv"]]

set_property top ed25519_fe_addsub_pipe [current_fileset]
synth_design -top ed25519_fe_addsub_pipe -part xc7k160tffg676-2 -mode out_of_context
create_clock -period $period -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
