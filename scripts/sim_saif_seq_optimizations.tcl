set proj_dir [file normalize "build/vivado_saif_seq_optimizations_sim"]
file mkdir $proj_dir

create_project saif_seq_optimizations_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    saif_ed25519_ref/others/SHL8.sv
    saif_ed25519_ref/others/carry_prop.sv
    saif_ed25519_ref/others/carry_prop_seq.sv
    saif_ed25519_ref/fe_modules/fe_tobytes.sv
    saif_ed25519_ref/fe_modules/fe_tobytes_seq.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

add_files -fileset sim_1 [file normalize "sim/tb_saif_seq_optimizations.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_saif_seq_optimizations.sv"]]
set_property top tb_saif_seq_optimizations [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
