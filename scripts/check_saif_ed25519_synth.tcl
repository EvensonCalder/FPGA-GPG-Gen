set proj_dir [file normalize "build/vivado_saif_ed25519_synth"]
set ref_dir  [file normalize "saif_ed25519_ref"]

file mkdir $proj_dir
create_project saif_ed25519_synth $proj_dir -part xc7k160tffg676-2 -force

foreach dir {baseP_mult fe_modules frombytes ge_modules others p3_tobytes sc_ops sha512 Top_fsm} {
    foreach f [glob -nocomplain -directory "$ref_dir/$dir" *.sv *.v] {
        add_files $f
        set_property file_type SystemVerilog [get_files $f]
    }
}

set_property top Ed25519_TOP [current_fileset]
synth_design -top Ed25519_TOP -part xc7k160tffg676-2 -mode out_of_context
report_utilization -file "$proj_dir/utilization.rpt"
report_timing_summary -file "$proj_dir/timing_summary.rpt"
