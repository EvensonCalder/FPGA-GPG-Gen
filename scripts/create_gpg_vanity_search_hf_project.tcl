set proj_dir [file normalize "build/vivado_gpg_vanity_search_hf"]
set ref_dir [file normalize "saif_ed25519_ref"]
file mkdir $proj_dir

create_project gpg_vanity_search_hf $proj_dir -part xc7k160tffg676-2 -force

foreach f [list \
    [file normalize "rtl/uart_tx.v"] \
    [file normalize "rtl/xilinx_ro_entropy.v"] \
    [file normalize "rtl/xilinx_ro_bank.v"] \
    [file normalize "rtl/trng_core.v"] \
    [file normalize "rtl/openpgp_v4_ed25519_fingerprint.sv"] \
    [file normalize "rtl/gpg_vanity_pattern_matcher.v"] \
    [file normalize "rtl/gpg_vanity_filter.sv"] \
    [file normalize "rtl/gpg_vanity_hit_uart_encoder.sv"] \
    [file normalize "rtl/gpg_vanity_hit_uart.sv"] \
    [file normalize "rtl/gpg_vanity_backend_uart.sv"] \
    [file normalize "rtl/ed25519_scalar_recode_4bit.sv"] \
    [file normalize "rtl/ed25519_fixedbase_table_select_pipe.sv"] \
    [file normalize "rtl/ed25519_fe_addsub_pipe.sv"] \
    [file normalize "rtl/ed25519_fe_mul_wrap_pipe.sv"] \
    [file normalize "rtl/ed25519_fixedbase_group_engine_v1.sv"] \
    [file normalize "rtl/ed25519_fixedbase_context_v2_shared.sv"] \
    [file normalize "rtl/ed25519_fixedbase_core.sv"] \
    [file normalize "rtl/ed25519_keygen_core.sv"] \
    [file normalize "rtl/gpg_vanity_search_hf_top.sv"] \
] {
    add_files $f
    set_property file_type SystemVerilog [get_files $f]
}

foreach dir {baseP_mult fe_modules ge_modules others p3_tobytes sha512} {
    foreach f [glob -nocomplain -directory "$ref_dir/$dir" *.sv *.v] {
        add_files $f
        set_property file_type SystemVerilog [get_files $f]
    }
}

set_property top gpg_vanity_search_hf_top [current_fileset]
set debug_accept_all [expr {[info exists ::env(DEBUG_ACCEPT_ALL)] ? $::env(DEBUG_ACCEPT_ALL) : 0}]
set_property generic "DEBUG_ACCEPT_ALL=$debug_accept_all" [current_fileset]
add_files -fileset constrs_1 [file normalize "constraints/gpg_vanity_search_hf_top.xdc"]

synth_design -top gpg_vanity_search_hf_top -part xc7k160tffg676-2

set ro_loop_nets [get_nets -hierarchical -regexp {.*ro_bank_inst.*/chain.*}]
puts "Acknowledging [llength $ro_loop_nets] RO loop nets"
if {[llength $ro_loop_nets] > 0} {
    set_property ALLOW_COMBINATORIAL_LOOPS TRUE $ro_loop_nets
}

opt_design
place_design
route_design

report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
write_bitstream -force "$proj_dir/gpg_vanity_search_hf_top.bit"
