source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fe17_group_engine_madd_sim"]
file mkdir $proj_dir
create_project ed25519_ht_fe17_group_engine_madd_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_fe17_square_pipe.sv
    rtl/ed25519_ht_fe17_group_engine.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ht_fe17_group_engine_madd.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ht_fe17_group_engine_madd.sv"]]
set_property top tb_ed25519_ht_fe17_group_engine_madd [get_filesets sim_1]

set mul_lanes 2
if {[info exists ::env(MUL_LANES)]} {
    set mul_lanes $::env(MUL_LANES)
}
set sim_opts "-generic_top MUL_LANES=$mul_lanes"
set_property -name xsim.elaborate.xelab.more_options -value $sim_opts -objects [get_filesets sim_1]
set_property -name xsim.simulate.xsim.more_options -value "-testplusarg VECTOR_FILE=[file normalize sim/ht_fe17_madd_vectors.mem]" -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
