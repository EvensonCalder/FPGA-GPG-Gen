set expected_part "mx25l25673g-spi-x1_x2_x4"
set expected_device "xc7k160t"

set parts [lsort -unique [get_cfgmem_parts $expected_part]]
if {[llength $parts] != 1} {
    error "Expected exactly one unique cfgmem part '$expected_part', got: $parts"
}
puts "CFG_PART_OK [lindex $parts 0]"

open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices ${expected_device}_0] 0]
if {$dev eq ""} {
    error "Expected hardware device ${expected_device}_0, got: [get_hw_devices]"
}
current_hw_device $dev
refresh_hw_device $dev

set actual_part [get_property PART $dev]
if {$actual_part ne $expected_device} {
    error "Expected FPGA PART=$expected_device, got PART=$actual_part"
}
puts "FPGA_PART_OK $dev PART=$actual_part"

create_hw_cfgmem -hw_device $dev [lindex $parts 0]
set cfgmem [get_property PROGRAM.HW_CFGMEM $dev]
if {$cfgmem eq ""} {
    error "PROGRAM.HW_CFGMEM is empty after create_hw_cfgmem"
}
puts "HW_CFGMEM_OK $cfgmem"

close_hw_manager
