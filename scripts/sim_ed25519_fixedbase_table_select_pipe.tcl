set proj_dir [file normalize "build/vivado_ed25519_fixedbase_table_select_pipe_sim"]
set ref_dir [file normalize "saif_ed25519_ref"]

file mkdir $proj_dir
create_project ed25519_fixedbase_table_select_pipe_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f [list \
    "$ref_dir/baseP_mult/base_rom1.sv" \
    "$ref_dir/others/SHL8.sv" \
    "$ref_dir/others/negative.v" \
    "$ref_dir/others/equal.v" \
    "$ref_dir/fe_modules/fe_cmov.sv" \
    "$ref_dir/others/cmov.sv" \
    "$ref_dir/others/select.sv" \
    [file normalize "rtl/ed25519_fixedbase_table_select_pipe.sv"] \
] {
    add_files $f
    set_property file_type SystemVerilog [get_files $f]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_fixedbase_table_select_pipe.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_fixedbase_table_select_pipe.sv"]]

set_property top tb_ed25519_fixedbase_table_select_pipe [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
