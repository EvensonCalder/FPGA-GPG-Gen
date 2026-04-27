onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group TB -color Yellow /Ed25519_TOP_TB/clk
add wave -noupdate -group TB -color Red /Ed25519_TOP_TB/rst
add wave -noupdate -group TB -expand -group TOP_CS /Ed25519_TOP_TB/DUT/cs
add wave -noupdate -group TB -expand -group FSM_CS /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/cs
add wave -noupdate -group TB -color Cyan /Ed25519_TOP_TB/start
add wave -noupdate -group TB /Ed25519_TOP_TB/data_in
add wave -noupdate -group TB /Ed25519_TOP_TB/opmode
add wave -noupdate -group TB -color {Green Yellow} /Ed25519_TOP_TB/valid
add wave -noupdate -group TB /Ed25519_TOP_TB/data_out
add wave -noupdate -group TB -expand -group results /Ed25519_TOP_TB/pubkey_out
add wave -noupdate -group TB -expand -group results /Ed25519_TOP_TB/privkey_out
add wave -noupdate -group TB -expand -group results /Ed25519_TOP_TB/sig_out
add wave -noupdate -group TB -expand -group results /Ed25519_TOP_TB/result_out
add wave -noupdate -group TB /Ed25519_TOP_TB/correct_count
add wave -noupdate -group TB /Ed25519_TOP_TB/fail_count
add wave -noupdate -group TOP -expand -group STATE /Ed25519_TOP_TB/DUT/cs
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/clk
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/rst
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/opmode
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/start
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/data_in
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/valid
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/data_out
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/fsm_opmode
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/fsm_output_data
add wave -noupdate -group TOP /Ed25519_TOP_TB/DUT/fsm_pubkey_out
add wave -noupdate -group REG_VALUES /Ed25519_TOP_TB/DUT/verify_message
add wave -noupdate -group REG_VALUES /Ed25519_TOP_TB/DUT/verify_signature
add wave -noupdate -group REG_VALUES /Ed25519_TOP_TB/DUT/generated_privkey
add wave -noupdate -group REG_VALUES /Ed25519_TOP_TB/DUT/sign_message
add wave -noupdate -group REG_VALUES /Ed25519_TOP_TB/DUT/generated_signature
add wave -noupdate -group REG_VALUES /Ed25519_TOP_TB/DUT/verify_pubkey
add wave -noupdate -group REG_VALUES /Ed25519_TOP_TB/DUT/generated_pubkey
add wave -noupdate -expand -group FSM -expand -group STATE /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/cs
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/opmode
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/start
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/V_message
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/V_sig
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/V_Pubkey
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/Seckey
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/Pubkey
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/S_message
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/done
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/output_data
add wave -noupdate -expand -group FSM /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/pubkey_out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group Hash -color Magenta /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/start_hash
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group Hash /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/hash_out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group Hash -color Cyan /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/hash_done
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group P3_tobytes -color Magenta /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/start_tobytes
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group P3_tobytes /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/R_bytes
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group P3_tobytes -color Cyan /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/tobytes_done
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group SC_MulAdd -color Magenta /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/start_muladd
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group SC_MulAdd /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/muladd_out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group SC_MulAdd -color Cyan /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/muladd_done
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_frombytes -color Magenta /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/start_frombytes
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_frombytes /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/frombytes_X
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_frombytes /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/frombytes_Y
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_frombytes /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/frombytes_Z
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_frombytes /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/frombytes_T
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_frombytes -color Red /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/error_frombytes
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_frombytes -color Cyan /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/frombytes_done
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/clk
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/reset
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/start
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/op_operand
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/a
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/b
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/A_X
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/A_Y
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/A_Z
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/A_T
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/r_X
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/r_Y
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/r_Z
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/r_T
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group ge_Top /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/u_ge_TOP/done
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/clk
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/rst
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/start
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/A
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/B
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/C
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/done
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group MulAdd_Prep /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/MulAdd_In/state
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group Reduce_64to32 -color Magenta /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/start_reduce
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group Reduce_64to32 /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/reduced_out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig -group Reduce_64to32 -color Cyan /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/reduce_done
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/lfsr_out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/RNG_out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/sha512_mux_mode
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/clamped_seckey
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/tobytes_out
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/nonce_reduced
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/hram_reduced
add wave -noupdate -expand -group FSM -expand -group SubModuleContSig /Ed25519_TOP_TB/DUT/u_ed25519_fsm_top/verify_h_reduced
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4161 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 171
configure wave -valuecolwidth 152
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {10395 ns}
