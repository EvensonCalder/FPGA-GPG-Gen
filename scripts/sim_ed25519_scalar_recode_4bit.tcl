set proj_dir [file normalize "build/vivado_ed25519_scalar_recode_4bit_sim"]
file mkdir $proj_dir
create_project ed25519_scalar_recode_4bit_sim $proj_dir -part xc7k160tffg676-2 -force

add_files [file normalize "rtl/ed25519_scalar_recode_4bit.sv"]
set_property file_type SystemVerilog [get_files [file normalize "rtl/ed25519_scalar_recode_4bit.sv"]]

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_scalar_recode_4bit.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_scalar_recode_4bit.sv"]]

set_property top tb_ed25519_scalar_recode_4bit [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
