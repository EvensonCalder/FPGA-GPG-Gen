open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7k160t_0] 0]
current_hw_device $dev
refresh_hw_device $dev
set_property PROGRAM.FILE [file normalize "build/vivado_gpg_vanity_search/gpg_vanity_search_top.bit"] $dev
program_hw_devices $dev
