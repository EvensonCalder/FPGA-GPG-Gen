source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_gpg_vanity_ht_search_synth"]
set ref_dir [file normalize "saif_ed25519_ref"]
file mkdir $proj_dir
create_project gpg_vanity_ht_search_synth $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/xilinx_ro_entropy.v
    rtl/xilinx_ro_bank.v
    rtl/trng_core.v
    rtl/uart_tx.v
    rtl/openpgp_v4_ed25519_fingerprint.sv
    rtl/gpg_vanity_pattern_matcher.v
    rtl/gpg_vanity_filter.sv
    rtl/gpg_vanity_hit_uart_encoder.sv
    rtl/gpg_vanity_hit_uart.sv
    rtl/gpg_vanity_backend_uart.sv
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_fe17_square_pipe.sv
    rtl/ed25519_ht_fe17_invert_pow.sv
    rtl/ed25519_ht_fe17_encode_public.sv
    rtl/ed25519_ht_fe17_batch_affine8.sv
    rtl/ed25519_ht_fe17_batch_affine16.sv
    rtl/ed25519_ht_fe17_batch_affine32.sv
    rtl/ed25519_ht_fe17_batch_affine_n.sv
    rtl/ed25519_ht_scalar_sched_pkg.sv
    rtl/ed25519_ht_fe17_madd.sv
    rtl/ed25519_ht_fe17_dbl.sv
    rtl/ed25519_ht_fe17_group_engine.sv
    rtl/ed25519_ht_fixedbase_table.sv
    rtl/ed25519_ht_scalar_mul_issue2.sv
    rtl/ed25519_ht_fe17_madd_sched.sv
    rtl/ed25519_ht_fixedbase_sched.sv
    rtl/ed25519_ht_fixedbase_context.sv
    rtl/ed25519_ht_fe17_to_fe10.sv
    rtl/ed25519_ht_fixedbase_core.sv
    rtl/ed25519_ht_fixedbase_fe17_core.sv
    rtl/ed25519_ht_keygen_core.sv
    rtl/ed25519_ht_keygen_scalar_stage.sv
    rtl/ed25519_ht_keygen_scalar_mc_stage.sv
    rtl/ed25519_ht_keygen_compress_lane.sv
    rtl/ed25519_ht_keygen_native_compress_lane.sv
    rtl/ed25519_ht_keygen_batch8_compress_stage.sv
    rtl/ed25519_ht_keygen_batch8_pingpong_stage.sv
    rtl/ed25519_ht_keygen_batch16_pingpong_stage.sv
    rtl/ed25519_ht_keygen_batch32_pingpong_stage.sv
    rtl/ed25519_ht_keygen_batchn_pingpong_stage.sv
    rtl/ed25519_scalar_recode_4bit.sv
    rtl/ed25519_ht_keygen_stream.sv
    rtl/gpg_vanity_ht_search_top.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

foreach dir {fe_modules others p3_tobytes sha512} {
    foreach f [glob -nocomplain -directory "$ref_dir/$dir" *.sv *.v] {
        add_files $f
        set_property file_type SystemVerilog [get_files $f]
    }
}

set lanes [expr {[info exists ::env(LANES)] ? $::env(LANES) : "2"}]
set mul_lanes [expr {[info exists ::env(MUL_LANES)] ? $::env(MUL_LANES) : "1"}]
set native_compress [expr {[info exists ::env(NATIVE_COMPRESS)] ? $::env(NATIVE_COMPRESS) : "0"}]
set batch_compress [expr {[info exists ::env(BATCH_COMPRESS)] ? $::env(BATCH_COMPRESS) : "0"}]
set batch_size [expr {[info exists ::env(BATCH_SIZE)] ? $::env(BATCH_SIZE) : "8"}]
set multi_context_scalar [expr {[info exists ::env(MULTI_CONTEXT_SCALAR)] ? $::env(MULTI_CONTEXT_SCALAR) : "0"}]
set scalar_contexts [expr {[info exists ::env(SCALAR_CONTEXTS)] ? $::env(SCALAR_CONTEXTS) : "8"}]
set trng_cores [expr {[info exists ::env(TRNG_CORES)] ? $::env(TRNG_CORES) : "2"}]
set use_pll [expr {[info exists ::env(USE_PLL)] ? $::env(USE_PLL) : "1"}]
set debug_accept_all [expr {[info exists ::env(DEBUG_ACCEPT_ALL)] ? $::env(DEBUG_ACCEPT_ALL) : "0"}]
set clk_hz [expr {[info exists ::env(CLK_HZ)] ? $::env(CLK_HZ) : ($use_pll ? "64705882" : "50000000")}]
set baud [expr {[info exists ::env(BAUD)] ? $::env(BAUD) : "2000000"}]

set_property top gpg_vanity_ht_search_top [current_fileset]
set_property generic "INIT_FILE=[file normalize build/ht_fixedbase_table.mem] CLK_HZ=$clk_hz BAUD=$baud LANES=$lanes MUL_LANES=$mul_lanes NATIVE_COMPRESS=$native_compress BATCH_COMPRESS=$batch_compress BATCH_SIZE=$batch_size MULTI_CONTEXT_SCALAR=$multi_context_scalar SCALAR_CONTEXTS=$scalar_contexts TRNG_CORES=$trng_cores USE_PLL=$use_pll DEBUG_ACCEPT_ALL=$debug_accept_all" [current_fileset]

synth_design -top gpg_vanity_ht_search_top -part xc7k160tffg676-2
read_xdc [file normalize "constraints/gpg_vanity_ht_search_top.xdc"]
set clock_period_ns [expr {($use_pll || ![info exists ::env(CLOCK_PERIOD_NS)]) ? "20.000" : $::env(CLOCK_PERIOD_NS)}]
create_clock -period $clock_period_ns -name clk_50m [get_ports clk_50m]
report_utilization -file "$proj_dir/utilization.rpt"
report_utilization -hierarchical -file "$proj_dir/utilization_hier.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"

if {[info exists ::env(POST_OPT)] && $::env(POST_OPT)} {
    opt_design
    report_utilization -file "$proj_dir/utilization_opt.rpt"
    report_utilization -hierarchical -file "$proj_dir/utilization_hier_opt.rpt"
    report_timing_summary -file "$proj_dir/timing_summary_opt.rpt"
}
