source [file normalize "scripts/check_gpg_vanity_ht_search_synth.tcl"]

if {[info exists ::env(SKIP_PLACE_UTIL_CHECK)] && $::env(SKIP_PLACE_UTIL_CHECK)} {
    set_param place.skipUtilizationCheck 1
}

set ro_loop_nets [get_nets -hierarchical -regexp {.*ro_bank_inst.*/chain.*}]
puts "Acknowledging [llength $ro_loop_nets] RO loop nets"
if {[llength $ro_loop_nets] > 0} {
    set_property ALLOW_COMBINATORIAL_LOOPS TRUE $ro_loop_nets
}

opt_design
report_utilization -file "$proj_dir/utilization_opt_impl.rpt"
report_timing_summary -file "$proj_dir/timing_summary_opt_impl.rpt"
place_design
phys_opt_design
route_design
phys_opt_design
report_utilization -file "$proj_dir/utilization_routed.rpt"
report_timing_summary -file "$proj_dir/timing_summary_routed.rpt"
report_route_status -file "$proj_dir/route_status.rpt"
report_drc -file "$proj_dir/drc_routed.rpt"
report_methodology -file "$proj_dir/methodology_routed.rpt"
write_checkpoint -force "$proj_dir/routed.dcp"
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS FALSE [current_design]
write_bitstream -force "$proj_dir/gpg_vanity_ht_search_top.bit"
