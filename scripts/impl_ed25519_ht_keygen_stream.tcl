source [file normalize "scripts/vivado_threads.tcl"]

set proj_dir [file normalize "build/vivado_ed25519_ht_keygen_stream_impl"]
set ref_dir [file normalize "saif_ed25519_ref"]
set clk_period [expr {[info exists ::env(CLK_PERIOD)] ? $::env(CLK_PERIOD) : "10.000"}]
file mkdir $proj_dir
create_project ed25519_ht_keygen_stream_impl $proj_dir -part xc7k160tffg676-2 -force

foreach f {
    rtl/ed25519_ht_fe17_pkg.sv
    rtl/ed25519_ht_fe17_mul_pipe.sv
    rtl/ed25519_ht_fe17_square_pipe.sv
    rtl/ed25519_ht_fe17_madd.sv
    rtl/ed25519_ht_fe17_dbl.sv
    rtl/ed25519_ht_fe17_group_engine.sv
    rtl/ed25519_ht_fixedbase_table.sv
    rtl/ed25519_ht_fixedbase_context.sv
    rtl/ed25519_ht_fe17_to_fe10.sv
    rtl/ed25519_ht_fixedbase_core.sv
    rtl/ed25519_ht_keygen_core.sv
    rtl/ed25519_ht_keygen_stream.sv
    rtl/ed25519_ht_keygen_stream_impl_top.sv
    rtl/ed25519_scalar_recode_4bit.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

foreach dir {fe_modules others p3_tobytes sha512} {
    foreach f [glob -nocomplain -directory "$ref_dir/$dir" *.sv *.v] {
        add_files $f
        set_property file_type SystemVerilog [get_files $f]
    }
}

set_property top ed25519_ht_keygen_stream_impl_top [current_fileset]
set_property generic "INIT_FILE=[file normalize build/ht_fixedbase_table.mem]" [current_fileset]
synth_design -top ed25519_ht_keygen_stream_impl_top -part xc7k160tffg676-2
create_clock -period $clk_period -name clk [get_ports clk]
opt_design
place_design
phys_opt_design
route_design
phys_opt_design
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
write_checkpoint -force "$proj_dir/routed.dcp"
