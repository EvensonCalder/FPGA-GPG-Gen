set proj_dir [file normalize "build/vivado_gpg_vanity_backend_io_sim"]
file mkdir $proj_dir

create_project gpg_vanity_backend_io_sim $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/gpg_vanity_pattern_matcher.v
    rtl/gpg_vanity_hit_uart_encoder.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

foreach f {
    sim/tb_gpg_vanity_pattern_matcher.sv
    sim/tb_gpg_vanity_hit_uart_encoder.sv
} {
    add_files -fileset sim_1 [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set_property top tb_gpg_vanity_pattern_matcher [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
close_sim

set_property top tb_gpg_vanity_hit_uart_encoder [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
close_sim
