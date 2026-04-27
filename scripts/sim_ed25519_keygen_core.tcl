set proj_dir [file normalize "build/vivado_ed25519_keygen_core_sim"]
set ref_dir  [file normalize "saif_ed25519_ref"]

file mkdir $proj_dir
create_project ed25519_keygen_core_sim $proj_dir -part xc7k160tffg676-2 -force

foreach dir {baseP_mult fe_modules ge_modules others p3_tobytes sha512} {
    foreach f [glob -nocomplain -directory "$ref_dir/$dir" *.sv *.v] {
        add_files $f
        set_property file_type SystemVerilog [get_files $f]
    }
}

foreach f {
    rtl/ed25519_scalar_recode_4bit.sv
    rtl/ed25519_fixedbase_table_select_pipe.sv
    rtl/ed25519_fe_addsub_pipe.sv
    rtl/ed25519_fe_mul_wrap_pipe.sv
    rtl/ed25519_fixedbase_group_engine_v1.sv
    rtl/ed25519_fixedbase_context_v2_shared.sv
    rtl/ed25519_fixedbase_core.sv
    rtl/ed25519_keygen_core.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_keygen_core.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_keygen_core.sv"]]
set_property top tb_ed25519_keygen_core [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
