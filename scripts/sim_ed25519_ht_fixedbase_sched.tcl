source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fixedbase_sched_sim"]
file mkdir $proj_dir
create_project ed25519_ht_fixedbase_sched_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_scalar_sched_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_scalar_mul_issue2.sv
    rtl/ed25519_ht_fe17_madd_sched.sv
    rtl/ed25519_ht_fixedbase_table.sv
    rtl/ed25519_ht_fe17_square_pipe.sv
    rtl/ed25519_ht_fe17_group_engine.sv
    rtl/ed25519_ht_fixedbase_context.sv
    rtl/ed25519_ht_fixedbase_sched.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ht_fixedbase_sched.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ht_fixedbase_sched.sv"]]
set_property top tb_ed25519_ht_fixedbase_sched [get_filesets sim_1]

set contexts 16
if {[info exists ::env(CONTEXTS)]} {
    set contexts $::env(CONTEXTS)
}
set total_count 32
if {[info exists ::env(TOTAL_COUNT)]} {
    set total_count $::env(TOTAL_COUNT)
}
set sim_generics "-generic_top INIT_FILE=[file normalize build/ht_fixedbase_table.mem] -generic_top CONTEXTS=$contexts -generic_top TOTAL_COUNT=$total_count"
set_property -name xsim.elaborate.xelab.more_options -value $sim_generics -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
