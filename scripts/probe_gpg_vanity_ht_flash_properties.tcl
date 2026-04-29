set cfgmem_part "mx25l25673g-spi-x1_x2_x4"

open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices xc7k160t_0] 0]
current_hw_device $dev
refresh_hw_device $dev
create_hw_cfgmem -hw_device $dev [lindex [lsort -unique [get_cfgmem_parts $cfgmem_part]] 0]
set cfgmem [get_property PROGRAM.HW_CFGMEM $dev]

puts "DEVICE_PROPERTIES"
report_property $dev
puts "CFGMEM_PROPERTIES"
report_property $cfgmem

close_hw_manager
