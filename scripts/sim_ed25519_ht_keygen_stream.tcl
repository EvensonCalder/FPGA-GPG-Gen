source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_keygen_stream_sim"]
set ref_dir [file normalize "saif_ed25519_ref"]

file mkdir $proj_dir
create_project ed25519_ht_keygen_stream_sim $proj_dir -part xc7k160tffg676-2 -force

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

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ht_keygen_stream.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ht_keygen_stream.sv"]]
set_property top tb_ed25519_ht_keygen_stream [get_filesets sim_1]
set mul_lanes 1
if {[info exists ::env(MUL_LANES)]} {
    set mul_lanes $::env(MUL_LANES)
}
set lanes 2
if {[info exists ::env(LANES)]} {
    set lanes $::env(LANES)
}
set native_compress 0
if {[info exists ::env(NATIVE_COMPRESS)]} {
    set native_compress $::env(NATIVE_COMPRESS)
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
set burst_count 8
if {[info exists ::env(BURST_COUNT)]} {
    set burst_count $::env(BURST_COUNT)
}
set table_generic "-generic_top INIT_FILE=[file normalize build/ht_fixedbase_table.mem] -generic_top MUL_LANES=$mul_lanes -generic_top LANES=$lanes -generic_top NATIVE_COMPRESS=$native_compress -generic_top BATCH_COMPRESS=$batch_compress -generic_top BATCH_SIZE=$batch_size -generic_top MULTI_CONTEXT_SCALAR=$multi_context_scalar -generic_top SCALAR_CONTEXTS=$scalar_contexts -generic_top BURST_COUNT=$burst_count"
set_property -name xsim.elaborate.xelab.more_options -value $table_generic -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
