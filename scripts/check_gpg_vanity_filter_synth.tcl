set proj_dir [file normalize "build/vivado_gpg_vanity_filter_synth"]
file mkdir $proj_dir

create_project gpg_vanity_filter_synth $proj_dir -part xc7k160tffg676-2 -force
foreach f {
    rtl/openpgp_v4_ed25519_fingerprint.sv
    rtl/gpg_vanity_pattern_matcher.v
    rtl/gpg_vanity_filter.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set_property top gpg_vanity_filter [current_fileset]
synth_design -top gpg_vanity_filter -part xc7k160tffg676-2 -mode out_of_context
create_clock -period 20.000 -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
