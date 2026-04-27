set proj_dir [file normalize "build/vivado_ed25519_ge_p2_dbl_v1_sim"]
set ref_dir [file normalize "saif_ed25519_ref"]
file mkdir $proj_dir
create_project ed25519_ge_p2_dbl_v1_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f [list \
    [file normalize "rtl/ed25519_fe_addsub_pipe.sv"] \
    "$ref_dir/fe_modules/fe_add.sv" \
    "$ref_dir/fe_modules/fe_sub.sv" \
    "$ref_dir/fe_modules/fe_mul.sv" \
    "$ref_dir/fe_modules/fe_sq.sv" \
    "$ref_dir/fe_modules/fe_sq2.sv" \
    "$ref_dir/fe_modules/fe_copy.sv" \
    "$ref_dir/baseP_mult/ge_fsm_top.sv" \
    "$ref_dir/baseP_mult/ge_top.sv" \
    [file normalize "rtl/ed25519_fe_mul_wrap_pipe.sv"] \
    [file normalize "rtl/ed25519_ge_p2_dbl_v1.sv"] \
] {
    add_files $f
    set_property file_type SystemVerilog [get_files $f]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ge_p2_dbl_v1.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ge_p2_dbl_v1.sv"]]
set_property top tb_ed25519_ge_p2_dbl_v1 [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
