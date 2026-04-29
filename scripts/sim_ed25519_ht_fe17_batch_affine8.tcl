source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fe17_batch_affine8_sim"]
file mkdir $proj_dir
create_project ed25519_ht_fe17_batch_affine8_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_fe17_square_pipe.sv
    rtl/ed25519_ht_fe17_invert_pow.sv
    rtl/ed25519_ht_fe17_encode_public.sv
    rtl/ed25519_ht_fe17_batch_affine8.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ht_fe17_batch_affine8.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ht_fe17_batch_affine8.sv"]]
set_property top tb_ed25519_ht_fe17_batch_affine8 [get_filesets sim_1]
set_property -name xsim.simulate.xsim.more_options -value "-testplusarg VECTOR_FILE=[file normalize sim/ht_batch_affine8_vectors.mem]" -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
