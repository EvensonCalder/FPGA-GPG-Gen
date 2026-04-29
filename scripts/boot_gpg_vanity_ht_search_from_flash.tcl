open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices xc7k160t_0] 0]
current_hw_device $dev
refresh_hw_device $dev

puts "BOOTING_FROM_FLASH $dev"
boot_hw_device $dev
after 10000
refresh_hw_device $dev

puts "BOOT_STATUS [get_property REGISTER.BOOT_STATUS $dev]"
puts "CONFIG_STATUS [get_property REGISTER.CONFIG_STATUS $dev]"
puts "DONE_PIN [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
puts "EOS [get_property REGISTER.CONFIG_STATUS.BIT04_END_OF_STARTUP_(EOS)_STATUS $dev]"

close_hw_manager
