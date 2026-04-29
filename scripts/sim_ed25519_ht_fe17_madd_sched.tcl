source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_fe17_madd_sched_sim"]
file mkdir $proj_dir
create_project ed25519_ht_fe17_madd_sched_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_scalar_sched_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_scalar_mul_issue2.sv
    rtl/ed25519_ht_fe17_madd_sched.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

add_files -fileset sim_1 [file normalize "sim/tb_ed25519_ht_fe17_madd_sched.sv"]
set_property file_type SystemVerilog [get_files [file normalize "sim/tb_ed25519_ht_fe17_madd_sched.sv"]]
set_property top tb_ed25519_ht_fe17_madd_sched [get_filesets sim_1]

set contexts 4
if {[info exists ::env(CONTEXTS)]} {
    set contexts $::env(CONTEXTS)
}
set vector_count 21
if {[info exists ::env(VECTOR_COUNT)]} {
    set vector_count $::env(VECTOR_COUNT)
}
set total_count 21
if {[info exists ::env(TOTAL_COUNT)]} {
    set total_count $::env(TOTAL_COUNT)
}
set sim_generics "-generic_top CONTEXTS=$contexts -generic_top VECTOR_COUNT=$vector_count -generic_top TOTAL_COUNT=$total_count"
set_property -name xsim.elaborate.xelab.more_options -value $sim_generics -objects [get_filesets sim_1]
set_property -name xsim.simulate.xsim.more_options -value "-testplusarg VECTOR_FILE=[file normalize sim/ht_fe17_madd_vectors.mem]" -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
