set period [expr {[info exists ::env(CLK_PERIOD)] ? $::env(CLK_PERIOD) : "20.000"}]
set suffix [expr {[info exists ::env(PROJ_SUFFIX)] ? $::env(PROJ_SUFFIX) : [string map {. p} $period]}]
set proj_dir [file normalize "build/vivado_ed25519_keygen_core_synth_${suffix}"]
set ref_dir  [file normalize "saif_ed25519_ref"]

file mkdir $proj_dir
create_project ed25519_keygen_core_synth_${suffix} $proj_dir -part xc7k160tffg676-2 -force

foreach dir {baseP_mult fe_modules ge_modules others p3_tobytes sha512} {
    foreach f [glob -nocomplain -directory "$ref_dir/$dir" *.sv *.v] {
        add_files $f
        set_property file_type SystemVerilog [get_files $f]
    }
}

foreach f {
    rtl/ed25519_scalar_recode_4bit.sv
    rtl/ed25519_fixedbase_table_select_pipe.sv
    rtl/ed25519_fe_addsub_pipe.sv
    rtl/ed25519_fe_mul_wrap_pipe.sv
    rtl/ed25519_fixedbase_group_engine_v1.sv
    rtl/ed25519_fixedbase_context_v2_shared.sv
    rtl/ed25519_fixedbase_core.sv
    rtl/ed25519_keygen_core.sv
} {
    add_files [file normalize $f]
    set_property file_type SystemVerilog [get_files [file normalize $f]]
}

set_property top ed25519_keygen_core [current_fileset]
synth_design -top ed25519_keygen_core -part xc7k160tffg676-2 -mode out_of_context
create_clock -period $period -name clk [get_ports clk]
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
