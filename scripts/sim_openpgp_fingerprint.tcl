set proj_dir [file normalize "build/vivado_openpgp_fingerprint_sim"]
file mkdir $proj_dir

create_project openpgp_fingerprint_sim $proj_dir -part xc7k160tffg676-2 -force
add_files [file normalize "rtl/openpgp_v4_ed25519_fingerprint.sv"]
add_files -fileset sim_1 [file normalize "sim/tb_openpgp_v4_ed25519_fingerprint.sv"]

set_property file_type SystemVerilog [get_files [file normalize "rtl/openpgp_v4_ed25519_fingerprint.sv"]]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_openpgp_v4_ed25519_fingerprint.sv"]]
set_property top tb_openpgp_v4_ed25519_fingerprint [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
