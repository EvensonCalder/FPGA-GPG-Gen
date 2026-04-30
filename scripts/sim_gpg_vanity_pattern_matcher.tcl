set proj_dir [file normalize "build/vivado_gpg_vanity_pattern_matcher_sim"]
file mkdir $proj_dir

create_project gpg_vanity_pattern_matcher_sim $proj_dir -part xc7k160tffg676-2 -force
add_files [file normalize "rtl/gpg_vanity_pattern_matcher.v"]
add_files -fileset sim_1 [file normalize "sim/tb_gpg_vanity_pattern_matcher.sv"]

set_property file_type SystemVerilog [get_files [file normalize "sim/tb_gpg_vanity_pattern_matcher.sv"]]
set_property top tb_gpg_vanity_pattern_matcher [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
