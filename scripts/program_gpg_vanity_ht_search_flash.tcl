set proj_dir [file normalize "build/vivado_gpg_vanity_ht_search_synth"]
set mcs_file "$proj_dir/gpg_vanity_ht_search_top_flash.mcs"
set cfgmem_part "mx25l25673g-spi-x1_x2_x4"

open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices xc7k160t_0] 0]
current_hw_device $dev
refresh_hw_device $dev

create_hw_cfgmem -hw_device $dev [lindex [lsort -unique [get_cfgmem_parts $cfgmem_part]] 0]
set cfgmem [get_property PROGRAM.HW_CFGMEM $dev]

set_property PROGRAM.FILES [list $mcs_file] $cfgmem
set_property PROGRAM.BLANK_CHECK 0 $cfgmem
set_property PROGRAM.ERASE 1 $cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $cfgmem
set_property PROGRAM.VERIFY 1 $cfgmem

set bridge_bit [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
puts "PROGRAMMING_CFGMEM_BRIDGE $bridge_bit"
create_hw_bitstream -hw_device $dev $bridge_bit
program_hw_devices $dev
refresh_hw_device $dev

puts "PROGRAMMING_FLASH $cfgmem_part $mcs_file"
program_hw_cfgmem -hw_cfgmem $cfgmem
puts "PROGRAMMED_FLASH $cfgmem with $mcs_file"
