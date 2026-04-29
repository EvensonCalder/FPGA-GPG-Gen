source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fixedbase_sched_synth"]
file mkdir $proj_dir
create_project ed25519_ht_fixedbase_sched_synth $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_scalar_sched_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_scalar_mul_issue2.sv
    rtl/ed25519_ht_fe17_madd_sched.sv
    rtl/ed25519_ht_fixedbase_table.sv
    rtl/ed25519_ht_fixedbase_sched.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set contexts 16
if {[info exists ::env(CONTEXTS)]} {
    set contexts $::env(CONTEXTS)
}

set_property top ed25519_ht_fixedbase_sched [current_fileset]
set_property generic "INIT_FILE=[file normalize build/ht_fixedbase_table.mem] CONTEXTS=$contexts TAG_WIDTH=4" [current_fileset]
synth_design -top ed25519_ht_fixedbase_sched -part xc7k160tffg676-2
create_clock -period 10.000 -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_utilization -hierarchical -file "$proj_dir/utilization_hier.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"

if {[info exists ::env(POST_OPT)] && $::env(POST_OPT)} {
    opt_design
    report_utilization -file "$proj_dir/utilization_opt.rpt"
    report_utilization -hierarchical -file "$proj_dir/utilization_hier_opt.rpt"
    report_timing_summary -file "$proj_dir/timing_summary_opt.rpt"
}
