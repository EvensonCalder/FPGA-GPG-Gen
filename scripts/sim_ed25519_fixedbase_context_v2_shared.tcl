set proj_dir [file normalize "build/vivado_ed25519_fixedbase_context_v2_shared_sim"]
set ref_dir [file normalize "saif_ed25519_ref"]
file mkdir $proj_dir
create_project ed25519_fixedbase_context_v2_shared_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f [list \
    [file normalize "rtl/ed25519_scalar_recode_4bit.sv"] \
    [file normalize "rtl/ed25519_fixedbase_table_select_pipe.sv"] \
    [file normalize "rtl/ed25519_fe_addsub_pipe.sv"] \
    [file normalize "rtl/ed25519_fe_mul_wrap_pipe.sv"] \
    [file normalize "rtl/ed25519_fixedbase_group_engine_v1.sv"] \
    [file normalize "rtl/ed25519_fixedbase_context_v2_shared.sv"] \
    "$ref_dir/others/SHL8.sv" \
    "$ref_dir/others/negative.v" \
    "$ref_dir/others/equal.v" \
    "$ref_dir/others/cmov.sv" \
    "$ref_dir/others/decompose.sv" \
    "$ref_dir/others/carry_prop_seq.sv" \
    "$ref_dir/others/slide_rtl.sv" \
    "$ref_dir/others/select.sv" \
    "$ref_dir/baseP_mult/base_rom1.sv" \
    "$ref_dir/baseP_mult/bi-constants-rom.sv" \
    "$ref_dir/fe_modules/fe_add.sv" \
    "$ref_dir/fe_modules/fe_cmov.sv" \
    "$ref_dir/fe_modules/fe_sub.sv" \
    "$ref_dir/fe_modules/fe_neg.sv" \
    "$ref_dir/fe_modules/fe_mul.sv" \
    "$ref_dir/fe_modules/fe_sq.sv" \
    "$ref_dir/fe_modules/fe_sq2.sv" \
    "$ref_dir/fe_modules/fe_copy.sv" \
    "$ref_dir/ge_modules/ge_p3_to_p2.sv" \
    "$ref_dir/ge_modules/ge_p2_dbl.sv" \
    "$ref_dir/ge_modules/ge_p3_dbl.sv" \
    "$ref_dir/baseP_mult/ge_fsm_top.sv" \
    "$ref_dir/baseP_mult/ge_top.sv" \
    "$ref_dir/ge_modules/ge_top_wrapper_mux.sv" \
    "$ref_dir/baseP_mult/base_TOP.sv" \
] {
    add_files $f
    set_property file_type SystemVerilog [get_files $f]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_fixedbase_context_v2_shared.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_fixedbase_context_v2_shared.sv"]]
set_property top tb_ed25519_fixedbase_context_v2_shared [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
