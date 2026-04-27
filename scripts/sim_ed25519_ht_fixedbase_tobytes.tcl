source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fixedbase_tobytes_sim"]
set ref_dir [file normalize "saif_ed25519_ref"]
file mkdir $proj_dir
create_project ed25519_ht_fixedbase_tobytes_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_fe17_square_pipe.sv
    rtl/ed25519_ht_fe17_madd.sv
    rtl/ed25519_ht_fe17_dbl.sv
    rtl/ed25519_ht_fixedbase_table.sv
    rtl/ed25519_ht_fixedbase_context.sv
    rtl/ed25519_ht_fe17_to_fe10.sv
    rtl/ed25519_ht_fixedbase_core.sv
    rtl/ed25519_scalar_recode_4bit.sv
    rtl/ed25519_fe_addsub_pipe.sv
    rtl/ed25519_fe_mul_wrap_pipe.sv
    rtl/ed25519_fixedbase_table_select_pipe.sv
    rtl/ed25519_fixedbase_group_engine_v1.sv
    rtl/ed25519_fixedbase_context_v2_shared.sv
    saif_ed25519_ref/baseP_mult/base_rom1.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

foreach dir {p3_tobytes fe_modules others} {
    foreach f [glob -nocomplain -directory "$ref_dir/$dir" *.sv *.v] {
        add_files $f
        set_property file_type SystemVerilog [get_files $f]
    }
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ht_fixedbase_tobytes.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ht_fixedbase_tobytes.sv"]]
set_property top tb_ed25519_ht_fixedbase_tobytes [get_filesets sim_1]
set table_generic "-generic_top INIT_FILE=[file normalize build/ht_fixedbase_table.mem]"
set_property -name xsim.elaborate.xelab.more_options -value $table_generic -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
