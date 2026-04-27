package ed25519_pkg;

// Top Module State Parameters
parameter ST_IDLE              = 6'd0;
// Key Gen
parameter ST_KEYGEN_START      = 6'd1;
parameter ST_KEYGEN_WAIT       = 6'd2;
parameter ST_KEYGEN_STORE_PRIV = 6'd3;
parameter ST_KEYGEN_STORE_PUB  = 6'd4;
parameter ST_KEYGEN_OUT_0      = 6'd5;
parameter ST_KEYGEN_OUT_1      = 6'd6;
parameter ST_KEYGEN_OUT_2      = 6'd7;
parameter ST_KEYGEN_OUT_3      = 6'd8;
// Sign
parameter ST_SIGN_MSG_IN_0     = 6'd9;
parameter ST_SIGN_MSG_IN_1     = 6'd10;
parameter ST_SIGN_MSG_IN_2     = 6'd11;
parameter ST_SIGN_MSG_IN_3     = 6'd12;
parameter ST_SIGN_MSG_IN_4     = 6'd13;
parameter ST_SIGN_MSG_IN_5     = 6'd14;
parameter ST_SIGN_MSG_IN_6     = 6'd15;
parameter ST_SIGN_MSG_IN_7     = 6'd16;
parameter ST_SIGN_START        = 6'd17;
parameter ST_SIGN_WAIT         = 6'd18;
parameter ST_SIGN_OUT_0        = 6'd19;
parameter ST_SIGN_OUT_1        = 6'd20;
parameter ST_SIGN_OUT_2        = 6'd21;
parameter ST_SIGN_OUT_3        = 6'd22;
parameter ST_SIGN_OUT_4        = 6'd23;
parameter ST_SIGN_OUT_5        = 6'd24;
parameter ST_SIGN_OUT_6        = 6'd25;
parameter ST_SIGN_OUT_7        = 6'd26;
// Verify
parameter ST_VERIFY_PK_IN_0    = 6'd27;
parameter ST_VERIFY_PK_IN_1    = 6'd28;
parameter ST_VERIFY_PK_IN_2    = 6'd29;
parameter ST_VERIFY_PK_IN_3    = 6'd30;
parameter ST_VERIFY_MSG_IN_0   = 6'd31;
parameter ST_VERIFY_MSG_IN_1   = 6'd32;
parameter ST_VERIFY_MSG_IN_2   = 6'd33;
parameter ST_VERIFY_MSG_IN_3   = 6'd34;
parameter ST_VERIFY_MSG_IN_4   = 6'd35;
parameter ST_VERIFY_MSG_IN_5   = 6'd36;
parameter ST_VERIFY_MSG_IN_6   = 6'd37;
parameter ST_VERIFY_MSG_IN_7   = 6'd38;
parameter ST_VERIFY_SIG_IN_0   = 6'd39;
parameter ST_VERIFY_SIG_IN_1   = 6'd40;
parameter ST_VERIFY_SIG_IN_2   = 6'd41;
parameter ST_VERIFY_SIG_IN_3   = 6'd42;
parameter ST_VERIFY_SIG_IN_4   = 6'd43;
parameter ST_VERIFY_SIG_IN_5   = 6'd44;
parameter ST_VERIFY_SIG_IN_6   = 6'd45;
parameter ST_VERIFY_SIG_IN_7   = 6'd46;
parameter ST_VERIFY_START      = 6'd47;
parameter ST_VERIFY_WAIT       = 6'd48;
parameter ST_VERIFY_OUT        = 6'd49;

    // FSM State Parameters
    parameter FSM_ST_IDLE              = 6'd0;
    // KeyGen states
    parameter FSM_ST_KEYGEN_RNG        = 6'd1; parameter FSM_ST_KEYGEN_HASH = 6'd2; parameter FSM_ST_KEYGEN_CLAMP = 6'd3; parameter FSM_ST_KEYGEN_SCALARMULT = 6'd4; parameter FSM_ST_KEYGEN_TOBYTES = 6'd5; parameter FSM_ST_KEYGEN_FINALIZE = 6'd6;
    // Sign states
    parameter FSM_ST_SIGN_NONCE_HASH   = 6'd7; parameter FSM_ST_SIGN_NONCE_REDUCE = 6'd8; parameter FSM_ST_SIGN_SCALARMULT = 6'd9; parameter FSM_ST_SIGN_R_TOBYTES = 6'd10; parameter FSM_ST_SIGN_HRAM_HASH = 6'd11; parameter FSM_ST_SIGN_HRAM_REDUCE  = 6'd12; parameter FSM_ST_SIGN_MULADD_PREP = 6'd13; parameter FSM_ST_SIGN_MULADD = 6'd14; parameter FSM_ST_SIGN_FINALIZE = 6'd15;
    // Verify states
    parameter FSM_ST_VERIFY_FROMBYTES  = 6'd16; parameter FSM_ST_VERIFY_H_HASH = 6'd17; parameter FSM_ST_VERIFY_H_REDUCE = 6'd18;  parameter FSM_ST_VERIFY_DSCM = 6'd19; parameter FSM_ST_VERIFY_TOBYTES = 6'd20;  parameter FSM_ST_VERIFY_COMPARE = 6'd21; parameter FSM_ST_VERIFY_FINALIZE = 6'd22;

    class ed25519_class;
        bit clk;
        logic [5:0] top_state_cv;
        logic [5:0] fsm_state_cv;
        
        // Randomized inputs
        rand logic rst;
        rand logic [1:0] opmode;
        rand logic start;
        rand logic [511:0] data_in;

        constraint Input_c {
            // Reset constraint - mostly high
            rst dist {1'b1:=99, 1'b0:=1};
            
            // Operation mode distribution
            opmode dist {
                2'b00:=25,  // KeyGen
                2'b01:=35,  // Sign  
                2'b10:=35,  // Verify
                2'b11:=5    // Invalid
            };
            
            // Start signal constraints based on top module state
            if (top_state_cv == ST_IDLE) {
                start dist {1'b1:=90, 1'b0:=10};
            } else {
                start dist {1'b1:=5, 1'b0:=95};  // Low probability in other states
            }
        }

        covergroup cvr_gp @(posedge clk);
            
            // Top Module State Coverage
            top_state_cp: coverpoint top_state_cv {
                bins IDLE_state = {ST_IDLE};
                
                // KeyGen states
                bins KEYGEN_START_state      = {ST_KEYGEN_START};
                bins KEYGEN_WAIT_state       = {ST_KEYGEN_WAIT};
                bins KEYGEN_STORE_PRIV_state = {ST_KEYGEN_STORE_PRIV};
                bins KEYGEN_STORE_PUB_state  = {ST_KEYGEN_STORE_PUB};
                bins KEYGEN_OUT_0_state      = {ST_KEYGEN_OUT_0};
                bins KEYGEN_OUT_1_state      = {ST_KEYGEN_OUT_1};
                bins KEYGEN_OUT_2_state      = {ST_KEYGEN_OUT_2};
                bins KEYGEN_OUT_3_state      = {ST_KEYGEN_OUT_3};
            
                // Sign states
                bins SIGN_MSG_IN_0_state = {ST_SIGN_MSG_IN_0};
                bins SIGN_MSG_IN_1_state = {ST_SIGN_MSG_IN_1};
                bins SIGN_MSG_IN_2_state = {ST_SIGN_MSG_IN_2};
                bins SIGN_MSG_IN_3_state = {ST_SIGN_MSG_IN_3};
                bins SIGN_MSG_IN_4_state = {ST_SIGN_MSG_IN_4};
                bins SIGN_MSG_IN_5_state = {ST_SIGN_MSG_IN_5};
                bins SIGN_MSG_IN_6_state = {ST_SIGN_MSG_IN_6};
                bins SIGN_MSG_IN_7_state = {ST_SIGN_MSG_IN_7};
                bins SIGN_START_state    = {ST_SIGN_START};
                bins SIGN_WAIT_state     = {ST_SIGN_WAIT};
                bins SIGN_OUT_0_state    = {ST_SIGN_OUT_0};
                bins SIGN_OUT_1_state    = {ST_SIGN_OUT_1};
                bins SIGN_OUT_2_state    = {ST_SIGN_OUT_2};
                bins SIGN_OUT_3_state    = {ST_SIGN_OUT_3};
                bins SIGN_OUT_4_state    = {ST_SIGN_OUT_4};
                bins SIGN_OUT_5_state    = {ST_SIGN_OUT_5};
                bins SIGN_OUT_6_state    = {ST_SIGN_OUT_6};
                bins SIGN_OUT_7_state    = {ST_SIGN_OUT_7};
                
                // Verify states
                bins VERIFY_PK_IN_0_state   = {ST_VERIFY_PK_IN_0};
                bins VERIFY_PK_IN_1_state   = {ST_VERIFY_PK_IN_1};
                bins VERIFY_PK_IN_2_state   = {ST_VERIFY_PK_IN_2};
                bins VERIFY_PK_IN_3_state   = {ST_VERIFY_PK_IN_3};
                bins VERIFY_MSG_IN_0_state  = {ST_VERIFY_MSG_IN_0};
                bins VERIFY_MSG_IN_1_state  = {ST_VERIFY_MSG_IN_1};
                bins VERIFY_MSG_IN_2_state  = {ST_VERIFY_MSG_IN_2};
                bins VERIFY_MSG_IN_3_state  = {ST_VERIFY_MSG_IN_3};
                bins VERIFY_MSG_IN_4_state  = {ST_VERIFY_MSG_IN_4};
                bins VERIFY_MSG_IN_5_state  = {ST_VERIFY_MSG_IN_5};
                bins VERIFY_MSG_IN_6_state  = {ST_VERIFY_MSG_IN_6};
                bins VERIFY_MSG_IN_7_state  = {ST_VERIFY_MSG_IN_7};
                bins VERIFY_SIG_IN_0_state  = {ST_VERIFY_SIG_IN_0};
                bins VERIFY_SIG_IN_1_state  = {ST_VERIFY_SIG_IN_1};
                bins VERIFY_SIG_IN_2_state  = {ST_VERIFY_SIG_IN_2};
                bins VERIFY_SIG_IN_3_state  = {ST_VERIFY_SIG_IN_3};
                bins VERIFY_SIG_IN_4_state  = {ST_VERIFY_SIG_IN_4};
                bins VERIFY_SIG_IN_5_state  = {ST_VERIFY_SIG_IN_5};
                bins VERIFY_SIG_IN_6_state  = {ST_VERIFY_SIG_IN_6};
                bins VERIFY_SIG_IN_7_state  = {ST_VERIFY_SIG_IN_7};
                bins VERIFY_START_state     = {ST_VERIFY_START};
                bins VERIFY_WAIT_state      = {ST_VERIFY_WAIT};
                bins VERIFY_OUT_state       = {ST_VERIFY_OUT};
            }
        
            // Top Module State Transitions
            top_state_trans_cp: coverpoint top_state_cv {
                bins IDLE_to_KEYGEN_START = (ST_IDLE => ST_KEYGEN_START);
                bins IDLE_to_SIGN_MSG_IN_0 = (ST_IDLE => ST_SIGN_MSG_IN_0);
                bins IDLE_to_VERIFY_PK_IN_0 = (ST_IDLE => ST_VERIFY_PK_IN_0);
                
                // KeyGen flow
                bins KEYGEN_START_to_WAIT = (ST_KEYGEN_START => ST_KEYGEN_WAIT);
                bins KEYGEN_WAIT_to_STORE_PRIV = (ST_KEYGEN_WAIT => ST_KEYGEN_STORE_PRIV);
                bins KEYGEN_STORE_PRIV_to_STORE_PUB = (ST_KEYGEN_STORE_PRIV => ST_KEYGEN_STORE_PUB);
                bins KEYGEN_STORE_PUB_to_OUT_0 = (ST_KEYGEN_STORE_PUB => ST_KEYGEN_OUT_0);
                bins KEYGEN_OUT_0_to_OUT_1 = (ST_KEYGEN_OUT_0 => ST_KEYGEN_OUT_1);
                bins KEYGEN_OUT_1_to_OUT_2 = (ST_KEYGEN_OUT_1 => ST_KEYGEN_OUT_2);
                bins KEYGEN_OUT_2_to_OUT_3 = (ST_KEYGEN_OUT_2 => ST_KEYGEN_OUT_3);
                bins KEYGEN_OUT_3_to_IDLE = (ST_KEYGEN_OUT_3 => ST_IDLE);
                
                // Sign flow
                bins SIGN_MSG_IN_0_to_IN_1 = (ST_SIGN_MSG_IN_0 => ST_SIGN_MSG_IN_1);
                bins SIGN_MSG_IN_1_to_IN_2 = (ST_SIGN_MSG_IN_1 => ST_SIGN_MSG_IN_2);
                bins SIGN_MSG_IN_2_to_IN_3 = (ST_SIGN_MSG_IN_2 => ST_SIGN_MSG_IN_3);
                bins SIGN_MSG_IN_3_to_IN_4 = (ST_SIGN_MSG_IN_3 => ST_SIGN_MSG_IN_4);
                bins SIGN_MSG_IN_4_to_IN_5 = (ST_SIGN_MSG_IN_4 => ST_SIGN_MSG_IN_5);
                bins SIGN_MSG_IN_5_to_IN_6 = (ST_SIGN_MSG_IN_5 => ST_SIGN_MSG_IN_6);
                bins SIGN_MSG_IN_6_to_IN_7 = (ST_SIGN_MSG_IN_6 => ST_SIGN_MSG_IN_7);
                bins SIGN_MSG_IN_7_to_START = (ST_SIGN_MSG_IN_7 => ST_SIGN_START);
                bins SIGN_START_to_WAIT = (ST_SIGN_START => ST_SIGN_WAIT);
                bins SIGN_WAIT_to_OUT_0 = (ST_SIGN_WAIT => ST_SIGN_OUT_0);
                bins SIGN_OUT_0_to_OUT_1 = (ST_SIGN_OUT_0 => ST_SIGN_OUT_1);
                bins SIGN_OUT_1_to_OUT_2 = (ST_SIGN_OUT_1 => ST_SIGN_OUT_2);
                bins SIGN_OUT_2_to_OUT_3 = (ST_SIGN_OUT_2 => ST_SIGN_OUT_3);
                bins SIGN_OUT_3_to_OUT_4 = (ST_SIGN_OUT_3 => ST_SIGN_OUT_4);
                bins SIGN_OUT_4_to_OUT_5 = (ST_SIGN_OUT_4 => ST_SIGN_OUT_5);
                bins SIGN_OUT_5_to_OUT_6 = (ST_SIGN_OUT_5 => ST_SIGN_OUT_6);
                bins SIGN_OUT_6_to_OUT_7 = (ST_SIGN_OUT_6 => ST_SIGN_OUT_7);
                bins SIGN_OUT_7_to_IDLE = (ST_SIGN_OUT_7 => ST_IDLE);
                
                // Verify flow
                bins VERIFY_PK_IN_0_to_IN_1 = (ST_VERIFY_PK_IN_0 => ST_VERIFY_PK_IN_1);
                bins VERIFY_PK_IN_1_to_IN_2 = (ST_VERIFY_PK_IN_1 => ST_VERIFY_PK_IN_2);
                bins VERIFY_PK_IN_2_to_IN_3 = (ST_VERIFY_PK_IN_2 => ST_VERIFY_PK_IN_3);
                bins VERIFY_PK_IN_3_to_MSG_IN_0 = (ST_VERIFY_PK_IN_3 => ST_VERIFY_MSG_IN_0);
                bins VERIFY_MSG_IN_0_to_IN_1 = (ST_VERIFY_MSG_IN_0 => ST_VERIFY_MSG_IN_1);
                bins VERIFY_MSG_IN_1_to_IN_2 = (ST_VERIFY_MSG_IN_1 => ST_VERIFY_MSG_IN_2);
                bins VERIFY_MSG_IN_2_to_IN_3 = (ST_VERIFY_MSG_IN_2 => ST_VERIFY_MSG_IN_3);
                bins VERIFY_MSG_IN_3_to_IN_4 = (ST_VERIFY_MSG_IN_3 => ST_VERIFY_MSG_IN_4);
                bins VERIFY_MSG_IN_4_to_IN_5 = (ST_VERIFY_MSG_IN_4 => ST_VERIFY_MSG_IN_5);
                bins VERIFY_MSG_IN_5_to_IN_6 = (ST_VERIFY_MSG_IN_5 => ST_VERIFY_MSG_IN_6);
                bins VERIFY_MSG_IN_6_to_IN_7 = (ST_VERIFY_MSG_IN_6 => ST_VERIFY_MSG_IN_7);
                bins VERIFY_MSG_IN_7_to_SIG_IN_0 = (ST_VERIFY_MSG_IN_7 => ST_VERIFY_SIG_IN_0);
                bins VERIFY_SIG_IN_0_to_IN_1 = (ST_VERIFY_SIG_IN_0 => ST_VERIFY_SIG_IN_1);
                bins VERIFY_SIG_IN_1_to_IN_2 = (ST_VERIFY_SIG_IN_1 => ST_VERIFY_SIG_IN_2);
                bins VERIFY_SIG_IN_2_to_IN_3 = (ST_VERIFY_SIG_IN_2 => ST_VERIFY_SIG_IN_3);
                bins VERIFY_SIG_IN_3_to_IN_4 = (ST_VERIFY_SIG_IN_3 => ST_VERIFY_SIG_IN_4);
                bins VERIFY_SIG_IN_4_to_IN_5 = (ST_VERIFY_SIG_IN_4 => ST_VERIFY_SIG_IN_5);
                bins VERIFY_SIG_IN_5_to_IN_6 = (ST_VERIFY_SIG_IN_5 => ST_VERIFY_SIG_IN_6);
                bins VERIFY_SIG_IN_6_to_IN_7 = (ST_VERIFY_SIG_IN_6 => ST_VERIFY_SIG_IN_7);
                bins VERIFY_SIG_IN_7_to_START = (ST_VERIFY_SIG_IN_7 => ST_VERIFY_START);
                bins VERIFY_START_to_WAIT = (ST_VERIFY_START => ST_VERIFY_WAIT);
                bins VERIFY_WAIT_to_OUT = (ST_VERIFY_WAIT => ST_VERIFY_OUT);
                bins VERIFY_OUT_to_IDLE = (ST_VERIFY_OUT => ST_IDLE);
            }

            // FSM State Coverage
            fsm_state_cp: coverpoint fsm_state_cv {
                bins FSM_IDLE_state = {FSM_ST_IDLE};
                
                // KeyGen FSM states
                bins FSM_KEYGEN_RNG_state        = {FSM_ST_KEYGEN_RNG};
                bins FSM_KEYGEN_HASH_state       = {FSM_ST_KEYGEN_HASH};
                bins FSM_KEYGEN_CLAMP_state      = {FSM_ST_KEYGEN_CLAMP};
                bins FSM_KEYGEN_SCALARMULT_state = {FSM_ST_KEYGEN_SCALARMULT};
                bins FSM_KEYGEN_TOBYTES_state    = {FSM_ST_KEYGEN_TOBYTES};
                bins FSM_KEYGEN_FINALIZE_state   = {FSM_ST_KEYGEN_FINALIZE};
                
                // Sign FSM states
                bins FSM_SIGN_NONCE_HASH_state   = {FSM_ST_SIGN_NONCE_HASH};
                bins FSM_SIGN_NONCE_REDUCE_state = {FSM_ST_SIGN_NONCE_REDUCE};
                bins FSM_SIGN_SCALARMULT_state   = {FSM_ST_SIGN_SCALARMULT};
                bins FSM_SIGN_R_TOBYTES_state    = {FSM_ST_SIGN_R_TOBYTES};
                bins FSM_SIGN_HRAM_HASH_state    = {FSM_ST_SIGN_HRAM_HASH};
                bins FSM_SIGN_HRAM_REDUCE_state  = {FSM_ST_SIGN_HRAM_REDUCE};
                bins FSM_ST_SIGN_MULADD_PREP_state = {FSM_ST_SIGN_MULADD_PREP};
                bins FSM_SIGN_MULADD_state       = {FSM_ST_SIGN_MULADD};
                bins FSM_SIGN_FINALIZE_state     = {FSM_ST_SIGN_FINALIZE};
                
                // Verify FSM states
                bins FSM_VERIFY_FROMBYTES_state  = {FSM_ST_VERIFY_FROMBYTES};
                bins FSM_VERIFY_H_HASH_state     = {FSM_ST_VERIFY_H_HASH};
                bins FSM_VERIFY_H_REDUCE_state   = {FSM_ST_VERIFY_H_REDUCE};
                bins FSM_VERIFY_DSCM_state       = {FSM_ST_VERIFY_DSCM};
                bins FSM_VERIFY_TOBYTES_state    = {FSM_ST_VERIFY_TOBYTES};
                bins FSM_VERIFY_COMPARE_state    = {FSM_ST_VERIFY_COMPARE};
                bins FSM_VERIFY_FINALIZE_state   = {FSM_ST_VERIFY_FINALIZE};
            }
            
            // FSM State Transitions 
            fsm_state_trans_cp: coverpoint fsm_state_cv {
                // KeyGen FSM transitions
                bins FSM_IDLE_to_KEYGEN_RNG = (FSM_ST_IDLE => FSM_ST_KEYGEN_RNG);
                bins FSM_KEYGEN_RNG_to_HASH = (FSM_ST_KEYGEN_RNG => FSM_ST_KEYGEN_HASH);
                bins FSM_KEYGEN_HASH_to_CLAMP = (FSM_ST_KEYGEN_HASH => FSM_ST_KEYGEN_CLAMP);
                bins FSM_KEYGEN_CLAMP_to_SCALARMULT = (FSM_ST_KEYGEN_CLAMP => FSM_ST_KEYGEN_SCALARMULT);
                bins FSM_KEYGEN_SCALARMULT_to_TOBYTES = (FSM_ST_KEYGEN_SCALARMULT => FSM_ST_KEYGEN_TOBYTES);
                bins FSM_KEYGEN_TOBYTES_to_FINALIZE = (FSM_ST_KEYGEN_TOBYTES => FSM_ST_KEYGEN_FINALIZE);
                bins FSM_KEYGEN_FINALIZE_to_IDLE = (FSM_ST_KEYGEN_FINALIZE => FSM_ST_IDLE);
                
                // Sign FSM transitions
                bins FSM_IDLE_to_SIGN_NONCE_HASH = (FSM_ST_IDLE => FSM_ST_SIGN_NONCE_HASH);
                bins FSM_SIGN_NONCE_HASH_to_REDUCE = (FSM_ST_SIGN_NONCE_HASH => FSM_ST_SIGN_NONCE_REDUCE); 
                bins FSM_SIGN_NONCE_REDUCE_to_SCALARMULT = (FSM_ST_SIGN_NONCE_REDUCE => FSM_ST_SIGN_SCALARMULT);
                bins FSM_SIGN_SCALARMULT_to_R_TOBYTES = (FSM_ST_SIGN_SCALARMULT => FSM_ST_SIGN_R_TOBYTES);
                bins FSM_SIGN_R_TOBYTES_to_HRAM_HASH = (FSM_ST_SIGN_R_TOBYTES => FSM_ST_SIGN_HRAM_HASH);
                bins FSM_SIGN_HRAM_HASH_to_REDUCE = (FSM_ST_SIGN_HRAM_HASH => FSM_ST_SIGN_HRAM_REDUCE);
                bins FSM_SIGN_HRAM_REDUCE_to_MULADDPREP = (FSM_ST_SIGN_HRAM_REDUCE => FSM_ST_SIGN_MULADD_PREP);
                bins FSM_SIGN_MULADDPREP_to_MULADD = (FSM_ST_SIGN_MULADD_PREP => FSM_ST_SIGN_MULADD);
                bins FSM_SIGN_MULADD_to_FINALIZE = (FSM_ST_SIGN_MULADD => FSM_ST_SIGN_FINALIZE);
                bins FSM_SIGN_FINALIZE_to_IDLE = (FSM_ST_SIGN_FINALIZE => FSM_ST_IDLE);
                
                // Verify FSM transitions
                bins FSM_IDLE_to_VERIFY_FROMBYTES = (FSM_ST_IDLE => FSM_ST_VERIFY_FROMBYTES);
                bins FSM_VERIFY_FROMBYTES_to_H_HASH = (FSM_ST_VERIFY_FROMBYTES => FSM_ST_VERIFY_H_HASH);
                bins FSM_VERIFY_FROMBYTES_to_FINALIZE = (FSM_ST_VERIFY_FROMBYTES => FSM_ST_VERIFY_FINALIZE); // Error path
                bins FSM_VERIFY_H_HASH_to_REDUCE = (FSM_ST_VERIFY_H_HASH => FSM_ST_VERIFY_H_REDUCE);
                bins FSM_VERIFY_H_REDUCE_to_DSCM = (FSM_ST_VERIFY_H_REDUCE => FSM_ST_VERIFY_DSCM);
                bins FSM_VERIFY_DSCM_to_TOBYTES = (FSM_ST_VERIFY_DSCM => FSM_ST_VERIFY_TOBYTES);
                bins FSM_VERIFY_TOBYTES_to_COMPARE = (FSM_ST_VERIFY_TOBYTES => FSM_ST_VERIFY_COMPARE);
                bins FSM_VERIFY_COMPARE_to_FINALIZE = (FSM_ST_VERIFY_COMPARE => FSM_ST_VERIFY_FINALIZE);
                bins FSM_VERIFY_FINALIZE_to_IDLE = (FSM_ST_VERIFY_FINALIZE => FSM_ST_IDLE);
            }
            
            // Input Signal Coverage
            opcode_cp: coverpoint opmode {
                bins KEYGEN_op = {2'b00};
                bins SIGN_op   = {2'b01};
                bins VERIFY_op = {2'b10};
                bins INVALID_op = {2'b11};
            }
            
            start_cp: coverpoint start;
            rst_cp: coverpoint rst;
            
            // Cross Coverage - Operation mode with fsm States
            opmode_cross_fsm_state: cross opcode_cp, fsm_state_cp {
                // KeyGen operation should only see KeyGen states + IDLE
                ignore_bins invalid_keygen = binsof(opcode_cp.KEYGEN_op) && 
                    (binsof(fsm_state_cp.FSM_SIGN_NONCE_HASH_state)     || binsof(fsm_state_cp.FSM_SIGN_NONCE_REDUCE_state) ||
                     binsof(fsm_state_cp.FSM_SIGN_SCALARMULT_state)     || binsof(fsm_state_cp.FSM_SIGN_R_TOBYTES_state)   ||
                     binsof(fsm_state_cp.FSM_SIGN_HRAM_HASH_state)      || binsof(fsm_state_cp.FSM_SIGN_HRAM_REDUCE_state) ||
                     binsof(fsm_state_cp.FSM_SIGN_MULADD_state)         || binsof(fsm_state_cp.FSM_SIGN_FINALIZE_state)    ||
                     binsof(fsm_state_cp.FSM_VERIFY_FROMBYTES_state)    || binsof(fsm_state_cp.FSM_VERIFY_H_HASH_state)     ||
                     binsof(fsm_state_cp.FSM_VERIFY_H_REDUCE_state)     || binsof(fsm_state_cp.FSM_VERIFY_DSCM_state)       ||
                     binsof(fsm_state_cp.FSM_VERIFY_TOBYTES_state)      || binsof(fsm_state_cp.FSM_VERIFY_COMPARE_state)    || binsof(fsm_state_cp.FSM_ST_SIGN_MULADD_PREP_state)    ||
                     binsof(fsm_state_cp.FSM_VERIFY_FINALIZE_state));

                // SIGN operation should only see SIGN states + IDLE
                ignore_bins invalid_sign = binsof(opcode_cp.SIGN_op) &&
                    (binsof(fsm_state_cp.FSM_KEYGEN_RNG_state)          || binsof(fsm_state_cp.FSM_KEYGEN_HASH_state)      ||
                     binsof(fsm_state_cp.FSM_KEYGEN_CLAMP_state)        || binsof(fsm_state_cp.FSM_KEYGEN_SCALARMULT_state)||
                     binsof(fsm_state_cp.FSM_KEYGEN_TOBYTES_state)      || binsof(fsm_state_cp.FSM_KEYGEN_FINALIZE_state)  ||
                     binsof(fsm_state_cp.FSM_VERIFY_FROMBYTES_state)    || binsof(fsm_state_cp.FSM_VERIFY_H_HASH_state)     ||
                     binsof(fsm_state_cp.FSM_VERIFY_H_REDUCE_state)     || binsof(fsm_state_cp.FSM_VERIFY_DSCM_state)       ||
                     binsof(fsm_state_cp.FSM_VERIFY_TOBYTES_state)      || binsof(fsm_state_cp.FSM_VERIFY_COMPARE_state)    ||
                     binsof(fsm_state_cp.FSM_VERIFY_FINALIZE_state));
            
                // VERIFY operation should only see VERIFY states + IDLE
                ignore_bins invalid_verify = binsof(opcode_cp.VERIFY_op) &&
                    (binsof(fsm_state_cp.FSM_KEYGEN_RNG_state)          || binsof(fsm_state_cp.FSM_KEYGEN_HASH_state)      ||
                     binsof(fsm_state_cp.FSM_KEYGEN_CLAMP_state)        || binsof(fsm_state_cp.FSM_KEYGEN_SCALARMULT_state)||
                     binsof(fsm_state_cp.FSM_KEYGEN_TOBYTES_state)      || binsof(fsm_state_cp.FSM_KEYGEN_FINALIZE_state)  ||
                     binsof(fsm_state_cp.FSM_SIGN_NONCE_HASH_state)     || binsof(fsm_state_cp.FSM_SIGN_NONCE_REDUCE_state)||
                     binsof(fsm_state_cp.FSM_SIGN_SCALARMULT_state)     || binsof(fsm_state_cp.FSM_SIGN_R_TOBYTES_state)   ||
                     binsof(fsm_state_cp.FSM_SIGN_HRAM_HASH_state)      || binsof(fsm_state_cp.FSM_SIGN_HRAM_REDUCE_state) || binsof(fsm_state_cp.FSM_ST_SIGN_MULADD_PREP_state)    ||
                     binsof(fsm_state_cp.FSM_SIGN_MULADD_state)         || binsof(fsm_state_cp.FSM_SIGN_FINALIZE_state));
            
                // INVALID opcode should not hit anything
                ignore_bins invalid_opcode = binsof(opcode_cp.INVALID_op);
            }

            
            // Cross Coverage - Start signal with states
            start_cross_top_state: cross start_cp, top_state_cp;
        endgroup

        function new();
            cvr_gp = new();
        endfunction
        
    endclass

endpackage