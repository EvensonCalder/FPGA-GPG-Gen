set clk_period [expr {[info exists ::env(CLK_PERIOD)] ? $::env(CLK_PERIOD) : "3.333"}]
set suffix [expr {[info exists ::env(PROJ_SUFFIX)] ? $::env(PROJ_SUFFIX) : "300mhz"}]
set proj_dir [file normalize "build/vivado_ed25519_ge_p2_dbl_v1_synth_${suffix}"]
file mkdir $proj_dir
create_project ed25519_ge_p2_dbl_v1_synth $proj_dir -part xc7k160tffg676-2 -force

foreach f [list \
    [file normalize "rtl/ed25519_fe_addsub_pipe.sv"] \
    [file normalize "rtl/ed25519_fe_mul_wrap_pipe.sv"] \
    [file normalize "rtl/ed25519_ge_p2_dbl_v1.sv"] \
] {
    add_files $f
    set_property file_type SystemVerilog [get_files $f]
}

set_property top ed25519_ge_p2_dbl_v1 [current_fileset]
synth_design -top ed25519_ge_p2_dbl_v1 -part xc7k160tffg676-2
create_clock -name clk -period $clk_period [get_ports clk]
report_timing_summary -file "$proj_dir/timing_summary.rpt"
report_utilization -file "$proj_dir/utilization.rpt"
