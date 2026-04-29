source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fixedbase_sched_impl"]
file mkdir $proj_dir
create_project ed25519_ht_fixedbase_sched_impl $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_scalar_sched_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_scalar_mul_issue2.sv
    rtl/ed25519_ht_fe17_madd_sched.sv
    rtl/ed25519_ht_fixedbase_table.sv
    rtl/ed25519_ht_fixedbase_sched.sv
    rtl/ed25519_ht_fixedbase_sched_impl_top.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set contexts 16
if {[info exists ::env(CONTEXTS)]} {
    set contexts $::env(CONTEXTS)
}

set clock_period 10.000
if {[info exists ::env(CLOCK_PERIOD)]} {
    set clock_period $::env(CLOCK_PERIOD)
}

set_property top ed25519_ht_fixedbase_sched_impl_top [current_fileset]
set_property generic "INIT_FILE=[file normalize build/ht_fixedbase_table.mem] CONTEXTS=$contexts TAG_WIDTH=4" [current_fileset]

if {[info exists ::env(SKIP_PLACE_UTIL_CHECK)] && $::env(SKIP_PLACE_UTIL_CHECK)} {
    set_param place.skipUtilizationCheck 1
}

synth_design -top ed25519_ht_fixedbase_sched_impl_top -part xc7k160tffg676-2
create_clock -period $clock_period -name clk [get_ports clk]
opt_design
report_utilization -file "$proj_dir/utilization_opt.rpt"
report_utilization -hierarchical -file "$proj_dir/utilization_hier_opt.rpt"
report_timing_summary -file "$proj_dir/timing_summary_opt.rpt"

place_design
report_utilization -file "$proj_dir/utilization_place.rpt"
report_utilization -hierarchical -file "$proj_dir/utilization_hier_place.rpt"
report_timing_summary -file "$proj_dir/timing_summary_place.rpt"

phys_opt_design
report_timing_summary -file "$proj_dir/timing_summary_physopt.rpt"

route_design
report_route_status -file "$proj_dir/route_status.rpt"
report_utilization -file "$proj_dir/utilization_route.rpt"
report_utilization -hierarchical -file "$proj_dir/utilization_hier_route.rpt"
report_timing_summary -file "$proj_dir/timing_summary_route.rpt"
