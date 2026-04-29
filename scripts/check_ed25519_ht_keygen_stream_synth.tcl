source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_keygen_stream_synth"]
set ref_dir [file normalize "saif_ed25519_ref"]

file mkdir $proj_dir
create_project ed25519_ht_keygen_stream_synth $proj_dir -part xc7k160tffg676-2 -force

foreach f {
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

set_property top ed25519_ht_keygen_stream [current_fileset]
set lanes 2
if {[info exists ::env(LANES)]} {
    set lanes $::env(LANES)
}
set mul_lanes 1
if {[info exists ::env(MUL_LANES)]} {
    set mul_lanes $::env(MUL_LANES)
}
set batch_compress 0
if {[info exists ::env(BATCH_COMPRESS)]} {
    set batch_compress $::env(BATCH_COMPRESS)
}
set batch_size 8
if {[info exists ::env(BATCH_SIZE)]} {
    set batch_size $::env(BATCH_SIZE)
}
set multi_context_scalar 0
if {[info exists ::env(MULTI_CONTEXT_SCALAR)]} {
    set multi_context_scalar $::env(MULTI_CONTEXT_SCALAR)
}
set scalar_contexts 16
if {[info exists ::env(SCALAR_CONTEXTS)]} {
    set scalar_contexts $::env(SCALAR_CONTEXTS)
}
set native_compress 0
if {[info exists ::env(NATIVE_COMPRESS)]} {
    set native_compress $::env(NATIVE_COMPRESS)
}
set_property generic "INIT_FILE=[file normalize build/ht_fixedbase_table.mem] MUL_LANES=$mul_lanes LANES=$lanes NATIVE_COMPRESS=$native_compress BATCH_COMPRESS=$batch_compress BATCH_SIZE=$batch_size MULTI_CONTEXT_SCALAR=$multi_context_scalar SCALAR_CONTEXTS=$scalar_contexts" [current_fileset]
synth_design -top ed25519_ht_keygen_stream -part xc7k160tffg676-2
create_clock -period 10.000 -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_utilization -hierarchical -file "$proj_dir/utilization_hier.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
