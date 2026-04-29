open_hw_manager
connect_hw_server
open_hw_target

puts "HW_TARGETS: [get_hw_targets]"
puts "HW_DEVICES: [get_hw_devices]"

foreach dev [get_hw_devices] {
    current_hw_device $dev
    refresh_hw_device $dev
    puts "DEVICE: $dev PART=[get_property PART $dev]"
    set cfgmem_obj [get_property PROGRAM.HW_CFGMEM $dev]
    puts "PROGRAM.HW_CFGMEM: $cfgmem_obj"
}

close_hw_manager
