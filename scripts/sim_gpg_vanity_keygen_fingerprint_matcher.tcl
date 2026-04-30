source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_gpg_vanity_keygen_fingerprint_matcher_sim"]
set ref_dir [file normalize "saif_ed25519_ref"]

file mkdir $proj_dir
create_project gpg_vanity_keygen_fingerprint_matcher_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/openpgp_v4_ed25519_fingerprint.sv
    rtl/gpg_vanity_pattern_matcher.v
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

add_files -fileset sim_1 [file normalize "sim/tb_gpg_vanity_keygen_fingerprint_matcher.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_gpg_vanity_keygen_fingerprint_matcher.sv"]]
set_property top tb_gpg_vanity_keygen_fingerprint_matcher [get_filesets sim_1]
set_property -name xsim.elaborate.xelab.more_options -value "-generic_top INIT_FILE=[file normalize build/ht_fixedbase_table.mem]" -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
