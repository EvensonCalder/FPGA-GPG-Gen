source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fe17_addsub_pipe_sim"]
file mkdir $proj_dir
create_project ed25519_ht_fe17_addsub_pipe_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_addsub_pipe.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ht_fe17_addsub_pipe.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ht_fe17_addsub_pipe.sv"]]
set_property top tb_ed25519_ht_fe17_addsub_pipe [get_filesets sim_1]
set vector_arg "-testplusarg VECTOR_FILE=[file normalize sim/ht_fe17_addsub_vectors.mem]"
set_property -name xsim.simulate.xsim.more_options -value $vector_arg -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
