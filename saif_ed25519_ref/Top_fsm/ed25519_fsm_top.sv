module ed25519_fsm_top (
    input  logic          clk,
    input  logic          rst,          // Active low reset
    input  logic [1:0]    opmode,       // 00: KeyGen, 01: Sign, 10: Verify
    input  logic          start,        // Active high start signal
    input  logic [511:0]  V_message,    // Input message for verification
    input  logic [511:0]  V_sig,        // Signature to be verified
    input  logic [255:0]  V_Pubkey,     // Public key for signature verification
    input  logic [511:0]  Seckey,       // Generated private key (512-bit)
    input  logic [255:0]  Pubkey,       // Generated public key (from keygen)
    input  logic [511:0]  S_message,    // Input message for signature
    output logic          done,         // Active high done signal
    output logic [511:0]  output_data,  // KeyGen: private key; Sign: signature; Verify: 512'hFFFF... if valid, else 0.
    output logic [255:0]  pubkey_out    // Used in KeyGen mode (public key)
);

  //===========================================================================
  // State Declaration
  //===========================================================================
  typedef enum logic [5:0] {
    ST_IDLE              = 6'd0,
    // KeyGen states (opmode == 00)
    ST_KEYGEN_RNG        = 6'd1,
    ST_KEYGEN_HASH       = 6'd2,
    ST_KEYGEN_CLAMP      = 6'd3,
    ST_KEYGEN_SCALARMULT = 6'd4,
    ST_KEYGEN_TOBYTES    = 6'd5,
    ST_KEYGEN_FINALIZE   = 6'd6,
    // Sign states (opmode == 01)
    ST_SIGN_NONCE_HASH   = 6'd7,
    ST_SIGN_NONCE_REDUCE = 6'd8,
    ST_SIGN_SCALARMULT   = 6'd9,
    ST_SIGN_R_TOBYTES    = 6'd10,
    ST_SIGN_HRAM_HASH    = 6'd11,
    ST_SIGN_HRAM_REDUCE  = 6'd12,
    ST_SIGN_MULADD_PREP  = 6'd13,
    ST_SIGN_MULADD       = 6'd14,
    ST_SIGN_FINALIZE     = 6'd15,
    // Verify states (opmode == 10)
    ST_VERIFY_FROMBYTES  = 6'd16,
    ST_VERIFY_H_HASH     = 6'd17,
    ST_VERIFY_H_REDUCE   = 6'd18,
    ST_VERIFY_DSCM       = 6'd19,
    ST_VERIFY_TOBYTES    = 6'd20,
    ST_VERIFY_COMPARE    = 6'd21,
    ST_VERIFY_FINALIZE   = 6'd22
  } state_e;
  
  state_e cs, ns, prev_cs;

  //===========================================================================
  // Internal Control Signals
  //===========================================================================
  // Start signals for submodules
  logic start_hash, start_ge_top, start_tobytes;
  logic start_muladd, start_frombytes;
  // Use separate reduce start signals for different phases:
  logic start_reduce;
  
  // Done signals from submodules
  logic hash_done, ge_top_done, tobytes_done;
  logic muladd_done, frombytes_done;
  logic reduce_done;

  //===========================================================================
  // Internal Data Wires
  //===========================================================================
  // LFSR
  logic [255:0] lfsr_out;
  logic [255:0] RNG_out;
  always_ff @(posedge clk or negedge rst) begin
    if(~rst) begin
      RNG_out <= 256'b0;
    end 
    else if (cs == ST_KEYGEN_RNG) begin
      // Take The random seed 
      RNG_out <= lfsr_out;
    end
  end

  // Muladd out
  logic [255:0] muladd_out;

  // SHA512
  logic [511:0] hash_out;     // SHA512 hash output

  // MulAdd
  logic [511:0] muladd_in;
  
  // Mode for SHA512_Mux: 
  //  2'b00 for keygen, 2'b01 for nonce hash, 2'b10 for hram/verification hash.
  logic [1:0] sha512_mux_mode;
  always @(*) begin
    case (cs)
      ST_KEYGEN_HASH:       sha512_mux_mode = 2'b00;
      ST_SIGN_NONCE_HASH:   sha512_mux_mode = 2'b01;
      ST_SIGN_HRAM_HASH:    sha512_mux_mode = 2'b10;
      ST_VERIFY_H_HASH:     sha512_mux_mode = 2'b10;
      default:              sha512_mux_mode = 2'b00;
    endcase
  end
  
  // Output of seckey clamp
  logic [511:0] clamped_seckey;
  
  // ge_TOP output (point format)
  logic signed [319:0] ge_top_out_X, ge_top_out_Y, ge_top_out_Z, ge_top_out_T;
  
  // ge_TOP operation mode control
  logic ge_top_op_operand;
  always @(*) begin
    case (cs)
      ST_KEYGEN_SCALARMULT: ge_top_op_operand = 1'b1;  // ge_scalarmult_base operation
      ST_SIGN_SCALARMULT:   ge_top_op_operand = 1'b1;  // ge_scalarmult_base operation
      ST_VERIFY_DSCM:       ge_top_op_operand = 1'b0;  // ge_double_scalarmult operation
      ST_VERIFY_TOBYTES:    ge_top_op_operand = 1'b0;  
      default:              ge_top_op_operand = 1'b1;
    endcase
  end

  logic [255:0] nonce_reduced, hram_reduced, verify_h_reduced;
  // ge_TOP input control for scalar 'a'
  logic [255:0] ge_top_scalar_a;
  always @(*) begin
    case (cs)
      ST_KEYGEN_SCALARMULT: ge_top_scalar_a = clamped_seckey[255:0];  // Lower 256 bits of clamped secret key
      ST_SIGN_SCALARMULT:   ge_top_scalar_a = nonce_reduced;          // Nonce for signing
      ST_VERIFY_DSCM:       ge_top_scalar_a = verify_h_reduced;       // Hash for verification
      default:              ge_top_scalar_a = 256'b0;
    endcase
  end
  
  // ge_TOP input control for scalar 'b' (only used in double_scalarmult)
  logic [255:0] ge_top_scalar_b;
  always @(*) begin
    case (cs)
      ST_VERIFY_DSCM:       ge_top_scalar_b = V_sig[511:256];  // Second part of signature S
      default:              ge_top_scalar_b = 256'b0;
    endcase
  end
  
  // ge_p3_tobytes output
  logic [7:0] tobytes_out [31:0];
  // We'll use the lower 256 bits as the compressed representation (R_bytes)
  logic [255:0] R_bytes;
  assign R_bytes = {tobytes_out[31], tobytes_out[30], tobytes_out[29], tobytes_out[28],
                    tobytes_out[27], tobytes_out[26], tobytes_out[25], tobytes_out[24],
                    tobytes_out[23], tobytes_out[22], tobytes_out[21], tobytes_out[20],
                    tobytes_out[19], tobytes_out[18], tobytes_out[17], tobytes_out[16],
                    tobytes_out[15], tobytes_out[14], tobytes_out[13], tobytes_out[12],
                    tobytes_out[11], tobytes_out[10], tobytes_out[9],  tobytes_out[8],
                    tobytes_out[7],  tobytes_out[6],  tobytes_out[5],  tobytes_out[4],
                    tobytes_out[3],  tobytes_out[2],  tobytes_out[1],  tobytes_out[0]};
  
  // sc_reduce outputs (for nonce, hram, and verification)
  
  logic [255:0] reduced_out;
  
  // ge_frombytes_negate_vartime outputs (for verification)
  logic signed [319:0] frombytes_X, frombytes_Y, frombytes_Z, frombytes_T;
  logic                error_frombytes; // Error flag from ge_frombytes_negate_vartime

  //===========================================================================
  // State Transition Logic
  //===========================================================================
  always_ff @(posedge clk or negedge rst) begin
    if(~rst) begin
      cs <= ST_IDLE;
    end 
    else begin
      cs <= ns;  // Update state
    end
  end

  //===========================================================================
  // Next-State Logic (Combinational)
  //===========================================================================
  always @(*) begin
    ns = cs;  // Default: stay in current state
    case (cs)
      ST_IDLE: begin
        if (start) begin
          case (opmode)
            2'b00: ns = ST_KEYGEN_RNG ;
            2'b01: ns = ST_SIGN_NONCE_HASH;
            2'b10: ns = ST_VERIFY_FROMBYTES;
            default: ns = ST_IDLE;
          endcase
        end
        else ns = ST_IDLE;
      end

      // -------- Key Generation Flow (opmode == 00) --------
      ST_KEYGEN_RNG : ns = ST_KEYGEN_HASH;  // LFSR runs continuously
      ST_KEYGEN_HASH:    if (hash_done) ns = ST_KEYGEN_CLAMP;
      ST_KEYGEN_CLAMP:                   ns = ST_KEYGEN_SCALARMULT;
      ST_KEYGEN_SCALARMULT: if (ge_top_done) ns = ST_KEYGEN_TOBYTES;
      ST_KEYGEN_TOBYTES: if (tobytes_done) ns = ST_KEYGEN_FINALIZE;
      ST_KEYGEN_FINALIZE:                ns = ST_IDLE;
      
      // -------- Signing Flow (opmode == 01) --------
      ST_SIGN_NONCE_HASH:   if (hash_done) ns = ST_SIGN_NONCE_REDUCE;
      ST_SIGN_NONCE_REDUCE: if (reduce_done) ns = ST_SIGN_SCALARMULT;
      ST_SIGN_SCALARMULT:   if (ge_top_done) ns = ST_SIGN_R_TOBYTES;
      ST_SIGN_R_TOBYTES:    if (tobytes_done) ns = ST_SIGN_HRAM_HASH;
      ST_SIGN_HRAM_HASH:     if (hash_done) ns = ST_SIGN_HRAM_REDUCE;
      ST_SIGN_HRAM_REDUCE:   if (reduce_done) ns = ST_SIGN_MULADD_PREP;
      ST_SIGN_MULADD_PREP:   if (muladd_done) ns = ST_SIGN_MULADD;
      ST_SIGN_MULADD:        if (reduce_done) ns = ST_SIGN_FINALIZE;
      ST_SIGN_FINALIZE:                      ns = ST_IDLE;
      
      // -------- Verification Flow (opmode == 10) --------
      ST_VERIFY_FROMBYTES: begin
          if(frombytes_done) begin
            if( (error_frombytes) || ( (V_sig[511:504] & 8'b11100000) != 8'b0 ) )
              ns = ST_VERIFY_FINALIZE; // Abort verification on error.
            else
              ns = ST_VERIFY_H_HASH;
          end
      end
      ST_VERIFY_H_HASH:     if (hash_done) ns = ST_VERIFY_H_REDUCE;
      ST_VERIFY_H_REDUCE:   if (reduce_done) ns = ST_VERIFY_DSCM;
      ST_VERIFY_DSCM:       if (ge_top_done) ns = ST_VERIFY_TOBYTES;
      ST_VERIFY_TOBYTES:    if (tobytes_done) ns = ST_VERIFY_COMPARE;
      ST_VERIFY_COMPARE:                     ns = ST_VERIFY_FINALIZE;
      ST_VERIFY_FINALIZE:                    ns = ST_IDLE;
      
      default: ns = ST_IDLE;
    endcase
  end

  //===========================================================================
  // Sequential Output & Control Signals Logic
  //===========================================================================
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      // Clear all start signals
      start_hash         <= 1'b0;
      start_ge_top       <= 1'b0;
      start_tobytes      <= 1'b0;
      start_reduce       <= 1'b0;
      start_muladd       <= 1'b0;
      start_frombytes    <= 1'b0;
      // Clear Reduce saved values
      nonce_reduced      <= 256'b0;
      hram_reduced       <= 256'b0;
      verify_h_reduced   <= 256'b0;
      muladd_out         <= 256'b0;
      // Clear outputs
      done               <= 1'b0;
      output_data        <= 512'b0;
      pubkey_out         <= 256'b0;
    end
    else begin
      // Default: deassert all start signals and done
      start_hash         <= 1'b0;
      start_ge_top       <= 1'b0;
      start_tobytes      <= 1'b0;
      start_reduce       <= 1'b0;
      start_muladd       <= 1'b0;
      start_frombytes    <= 1'b0;
      done               <= 1'b0;
      
      case (cs)
        ST_IDLE: begin
          // Remain idle.
        end

        // -------- Key Generation Flow --------
        ST_KEYGEN_RNG : begin
          // LFSR runs continuously.
        end
        ST_KEYGEN_HASH: begin
          start_hash <= (prev_cs != ST_KEYGEN_HASH);
          // SHA512_Mux in keygen mode uses:
          //    sha512_mux_random = lfsr_out, mode = 2'b00.
        end
        ST_KEYGEN_CLAMP: begin
          // Clamp the hash_out to produce the expanded secret key.
        end
        ST_KEYGEN_SCALARMULT: begin
          start_ge_top <= (prev_cs != ST_KEYGEN_SCALARMULT);
          // Use lower 256 bits of clamped_seckey as scalar input.
        end
        ST_KEYGEN_TOBYTES: begin
          start_tobytes <= (prev_cs != ST_KEYGEN_TOBYTES);
          // Convert the ge_p3 point to byte format.
        end
        ST_KEYGEN_FINALIZE: begin
          // Finalize keygen: output clamped secret key and computed public key.
          output_data <= clamped_seckey;
          pubkey_out  <= R_bytes;
          done        <= 1'b1;
        end

        // -------- Signing Flow --------
        ST_SIGN_NONCE_HASH: begin
          start_hash <= (prev_cs != ST_SIGN_NONCE_HASH);
          // SHA512_Mux in nonce mode:
          //    message = S_message,
          //    seckey32_in = Seckey[511:256],
          //    mode = 2'b01.
        end
        ST_SIGN_NONCE_REDUCE: begin
          start_reduce <= (prev_cs != ST_SIGN_NONCE_REDUCE);
          // Reduce hash_out -> nonce_reduced.
          if (reduce_done) begin
            nonce_reduced <= reduced_out;
          end
        end
        ST_SIGN_SCALARMULT: begin
          start_ge_top <= (prev_cs != ST_SIGN_SCALARMULT);
          // Compute R = nonce_reduced * base.
        end
        ST_SIGN_R_TOBYTES: begin
          start_tobytes <= (prev_cs != ST_SIGN_R_TOBYTES);
          // Convert R to compressed form.
        end
        ST_SIGN_HRAM_HASH: begin
          start_hash <= (prev_cs != ST_SIGN_HRAM_HASH);
          // SHA512_Mux in hram mode:
          //    message = S_message,
          //    hash_pubkey_in = Pubkey,
          //    R = tobytes_out[255:0],
          //    mode = 2'b10.
        end
        ST_SIGN_HRAM_REDUCE: begin
          start_reduce <= (prev_cs != ST_SIGN_HRAM_REDUCE);
          // Reduce hash_out -> hram_reduced.
          if (reduce_done) begin
            hram_reduced <= reduced_out;
          end
        end
        ST_SIGN_MULADD_PREP: begin
          start_muladd <= (prev_cs != ST_SIGN_MULADD_PREP);
        end
        ST_SIGN_MULADD: begin
                    start_reduce <= (prev_cs != ST_SIGN_MULADD);
          // Compute S = hram_reduced * (clamped_seckey[255:0]) + nonce_reduced.
          if (reduce_done) begin
            muladd_out <= reduced_out;
          end
        end
        ST_SIGN_FINALIZE: begin
          // Form signature as {R_bytes, muladd_out}
          output_data <= {muladd_out, R_bytes};
          done        <= 1'b1;
        end

        // -------- Verification Flow --------
        ST_VERIFY_FROMBYTES: begin
          start_frombytes <= (prev_cs != ST_VERIFY_FROMBYTES);
          // Process V_Pubkey through ge_frombytes_negate_vartime.
        end
        ST_VERIFY_H_HASH: begin
          start_hash <= (prev_cs != ST_VERIFY_H_HASH);
          // SHA512_Mux in verify mode:
          //    message = V_message,
          //    hash_pubkey_in = V_Pubkey,
          //    R = V_sig[255:0],
          //    mode = 2'b10.
        end
        ST_VERIFY_H_REDUCE: begin
          start_reduce <= (prev_cs != ST_VERIFY_H_REDUCE);
          // Reduce hash_out -> verify_h_reduced.
          if (reduce_done) begin
            verify_h_reduced <= reduced_out;
          end
        end
        ST_VERIFY_DSCM: begin
          start_ge_top <= (prev_cs != ST_VERIFY_DSCM);
          // Compute R' = verify_h_reduced * (-A) + (V_sig[511:256])*base.
        end
        ST_VERIFY_TOBYTES: begin
          start_tobytes <= (prev_cs != ST_VERIFY_TOBYTES);
          // Convert DSCM result to bytes.
        end
        ST_VERIFY_COMPARE: begin
          // Compare computed R_bytes with V_sig[255:0]
          if (R_bytes == V_sig[255:0])
            output_data <= {512{1'b1}}; // valid indicator (all ones)
          else
            output_data <= 512'b0;
        end
        ST_VERIFY_FINALIZE: begin
          done <= 1'b1;
        end
        
        default: begin
          // Default: no action.
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst) begin 
    if(~rst) begin
      prev_cs <= ST_IDLE;
    end else begin
      prev_cs <= cs;
    end
  end

  //===========================================================================
  // Submodule Instantiations
  //===========================================================================

  // --- LFSR for KeyGen ---
  LFSR_256bit u_LFSR (
      .clk(clk),
      .rst(rst),
      .random_num(lfsr_out)
  );

  // --- SHA512_Mux ---
  SHA512_wrapper_mux u_SHA512_Wrapper (
      .clk(clk),
      .rst(rst),
      .start_sha512(start_hash),
      .sha512_mode(sha512_mux_mode), // selects Mux mode *and* is passed to the SHA core
      .hash_message_in( (cs == ST_VERIFY_H_HASH)? V_message : S_message),
      .random_number(RNG_out),
      .hash_pubkey_in( (cs == ST_SIGN_HRAM_HASH) ? Pubkey : V_Pubkey),
      .R((cs == ST_SIGN_HRAM_HASH) ? R_bytes : V_sig[255:0]),
      .seckey32_in(Seckey[511:256]),
      .end_sha512(hash_done),
      .hash(hash_out)
  );
  
  // --- seckey_clamp ---
  seckey_clamp u_seckey_clamp (
      .input_hashed_seckey(hash_out),
      .output_sk(clamped_seckey)
  );
  
  // --- ge_TOP (combined ge_scalarmult_base and ge_double_scalarmult) ---
  base_TOP u_ge_TOP (
      .clk(clk),
      .reset(rst),
      .start(start_ge_top),
      .op_operand(ge_top_op_operand),
      .a(ge_top_scalar_a),
      .b(ge_top_scalar_b),
      .A_X(frombytes_X),
      .A_Y(frombytes_Y),
      .A_Z(frombytes_Z),
      .A_T(frombytes_T),
      .r_X(ge_top_out_X),
      .r_Y(ge_top_out_Y),
      .r_Z(ge_top_out_Z),
      .r_T(ge_top_out_T),
      .done(ge_top_done)
  );
  
  // --- ge_p3_tobytes ---
  ge_p3_tobytes u_ge_p3_tobytes (
      .clk(clk),
      .rst(rst),
      .start(start_tobytes),
      .X(ge_top_out_X),
      .Y(ge_top_out_Y),
      .Z(ge_top_out_Z),
      .s(tobytes_out),
      .done(tobytes_done)
  );

  // MulAdd prep , prepares the input of Sc_MulAdd
  muladd_serial MulAdd_In (
      .clk  (clk),
      .rst  (rst),
      .start(start_muladd),
      .done (muladd_done),
      .A    (hram_reduced),
      .B    (Seckey[255:0]),
      .C    (nonce_reduced),
      .out  (muladd_in)
    );
  
  // --- sc_reduce for Nonce (in signing) ---, Hram (in signing) --- and for Hash reduce (in verify)
  sc_reduce u_sc_reduce (
      .clk(clk),
      .rst(rst),
      .start(start_reduce),
      .data_in((cs==ST_SIGN_MULADD)? muladd_in : hash_out),
      .data_out(reduced_out),
      .done(reduce_done)
  );
  
  // --- ge_frombytes_negate_vartime (for verification) ---
  ge_frombytes_negate_vartime u_ge_frombytes_negate_vartime (
      .clk(clk),
      .reset(rst),
      .start(start_frombytes),
      .s(V_Pubkey),
      .h_X(frombytes_X),
      .h_Y(frombytes_Y),
      .h_Z(frombytes_Z),
      .h_T(frombytes_T),
      .done(frombytes_done),
      .error(error_frombytes)
  );

endmodule