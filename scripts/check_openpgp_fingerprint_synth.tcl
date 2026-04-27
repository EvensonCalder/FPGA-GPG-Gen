set proj_dir [file normalize "build/vivado_openpgp_fingerprint_synth"]
file mkdir $proj_dir

create_project openpgp_fingerprint_synth $proj_dir -part xc7k160tffg676-2 -force
add_files [file normalize "rtl/openpgp_v4_ed25519_fingerprint.sv"]
set_property file_type SystemVerilog [get_files [file normalize "rtl/openpgp_v4_ed25519_fingerprint.sv"]]

set_property top openpgp_v4_ed25519_fingerprint [current_fileset]
synth_design -top openpgp_v4_ed25519_fingerprint -part xc7k160tffg676-2 -mode out_of_context
create_clock -period 20.000 -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
