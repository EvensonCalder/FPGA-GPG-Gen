set bit_file [file normalize "build/vivado_trng_uart/trng_uart_top.bit"]

if {![file exists $bit_file]} {
    error "bitstream not found: $bit_file"
}

open_hw_manager
connect_hw_server
open_hw_target

set devices [get_hw_devices *xc7k160t*]
if {[llength $devices] == 0} {
    set devices [get_hw_devices]
}
if {[llength $devices] == 0} {
    error "no JTAG hardware device found"
}

set dev [lindex $devices 0]
current_hw_device $dev
refresh_hw_device $dev
set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "Programmed $dev with $bit_file"
