module Ed25519_TOP (
  input  logic         clk,
  input  logic         rst,         // Active low reset
  input  logic [1:0]   opmode,      // 00: KeyGen, 01: Sign, 10: Verify
  input  logic         start,       // Active high start signal
  input  logic [63:0]  data_in,     // 64-bit input data bus
  output logic         valid,       // Active high valid output
  output logic [63:0]  data_out     // 64-bit output data bus
);

  // State Enum for Top Module
  typedef enum logic [5:0] {
    ST_IDLE              = 6'd0,
    // Key Gen
    ST_KEYGEN_START      = 6'd1,
    ST_KEYGEN_WAIT       = 6'd2,
    ST_KEYGEN_STORE_PRIV = 6'd3,
    ST_KEYGEN_STORE_PUB  = 6'd4,
    ST_KEYGEN_OUT_0      = 6'd5,
    ST_KEYGEN_OUT_1      = 6'd6,
    ST_KEYGEN_OUT_2      = 6'd7,
    ST_KEYGEN_OUT_3      = 6'd8,
    // Sign
    ST_SIGN_MSG_IN_0     = 6'd9,
    ST_SIGN_MSG_IN_1     = 6'd10,
    ST_SIGN_MSG_IN_2     = 6'd11,
    ST_SIGN_MSG_IN_3     = 6'd12,
    ST_SIGN_MSG_IN_4     = 6'd13,
    ST_SIGN_MSG_IN_5     = 6'd14,
    ST_SIGN_MSG_IN_6     = 6'd15,
    ST_SIGN_MSG_IN_7     = 6'd16,
    ST_SIGN_START        = 6'd17,
    ST_SIGN_WAIT         = 6'd18,
    ST_SIGN_OUT_0        = 6'd19,
    ST_SIGN_OUT_1        = 6'd20,
    ST_SIGN_OUT_2        = 6'd21,
    ST_SIGN_OUT_3        = 6'd22,
    ST_SIGN_OUT_4        = 6'd23,
    ST_SIGN_OUT_5        = 6'd24,
    ST_SIGN_OUT_6        = 6'd25,
    ST_SIGN_OUT_7        = 6'd26,
    // Verify
    ST_VERIFY_PK_IN_0    = 6'd27,
    ST_VERIFY_PK_IN_1    = 6'd28,
    ST_VERIFY_PK_IN_2    = 6'd29,
    ST_VERIFY_PK_IN_3    = 6'd30,
    ST_VERIFY_MSG_IN_0   = 6'd31,
    ST_VERIFY_MSG_IN_1   = 6'd32,
    ST_VERIFY_MSG_IN_2   = 6'd33,
    ST_VERIFY_MSG_IN_3   = 6'd34,
    ST_VERIFY_MSG_IN_4   = 6'd35,
    ST_VERIFY_MSG_IN_5   = 6'd36,
    ST_VERIFY_MSG_IN_6   = 6'd37,
    ST_VERIFY_MSG_IN_7   = 6'd38,
    ST_VERIFY_SIG_IN_0   = 6'd39,
    ST_VERIFY_SIG_IN_1   = 6'd40,
    ST_VERIFY_SIG_IN_2   = 6'd41,
    ST_VERIFY_SIG_IN_3   = 6'd42,
    ST_VERIFY_SIG_IN_4   = 6'd43,
    ST_VERIFY_SIG_IN_5   = 6'd44,
    ST_VERIFY_SIG_IN_6   = 6'd45,
    ST_VERIFY_SIG_IN_7   = 6'd46,
    ST_VERIFY_START      = 6'd47,
    ST_VERIFY_WAIT       = 6'd48,
    ST_VERIFY_OUT        = 6'd49
  } state_e;
  
  state_e cs, ns;
  
  // Internal Buffers for data assembly/disassembly
  logic [511:0] sign_msg_buf, verify_msg_buf, verify_sig_buf;
  logic [255:0] verify_pk_buf, keygen_pubkey_buf, sign_out_buf;
  
  // Internal Signals
  logic         fsm_start, fsm_done, reg_write_en;
  logic [1:0]   fsm_opmode;
  logic [2:0]   reg_addr;
  logic [511:0] reg_write_data;
  logic [511:0] fsm_output_data;
  logic [255:0] fsm_pubkey_out;

  // Register File Wires
  logic [511:0] verify_message, verify_signature, generated_privkey, sign_message, generated_signature;
  logic [255:0] verify_pubkey, generated_pubkey;

  Reg_File u_Reg_File (
    .clk(clk),
    .rst(rst),
    .write_en(reg_write_en),
    .addr(reg_addr),
    .write_data(reg_write_data),
    .REG_A1(verify_message),    // 512-bit message for verification
    .REG_A2(verify_signature),  // 512-bit signature for verification
    .REG_A3(verify_pubkey),     // 256-bit public key for verification
    .REG_B1(generated_privkey), // 512-bit generated private key
    .REG_B2(generated_pubkey),  // 256-bit generated public key
    .REG_C1(sign_message),      // 512-bit message to be signed
    .REG_C2(generated_signature)// 512-bit generated signature
  );
  
  // ed25519_fsm_top Instance
  ed25519_fsm_top u_ed25519_fsm_top (
    .clk(clk),
    .rst(rst),
    .opmode(fsm_opmode),
    .start(fsm_start),
    .V_message(verify_message),
    .V_sig(verify_signature),
    .V_Pubkey(verify_pubkey),
    .Seckey(generated_privkey),
    .Pubkey(generated_pubkey),
    .S_message(sign_message),
    .done(fsm_done),
    .output_data(fsm_output_data),
    .pubkey_out(fsm_pubkey_out)
  );
  
  // Next-State Logic
  always @(*) begin
    ns = cs;  // Default: stay in current state
    case (cs)
      ST_IDLE: begin
        if (start) begin
          case (opmode)
            2'b00: ns = ST_KEYGEN_START;
            2'b01: ns = ST_SIGN_MSG_IN_0;
            2'b10: ns = ST_VERIFY_PK_IN_0;
            default: ns = ST_IDLE;
          endcase
        end
      end
      
      // Key Generation States
      ST_KEYGEN_START:      ns = ST_KEYGEN_WAIT;
      ST_KEYGEN_WAIT:       if (fsm_done) ns = ST_KEYGEN_STORE_PRIV;
      ST_KEYGEN_STORE_PRIV: ns = ST_KEYGEN_STORE_PUB;
      ST_KEYGEN_STORE_PUB:  ns = ST_KEYGEN_OUT_0;
      ST_KEYGEN_OUT_0:      ns = ST_KEYGEN_OUT_1;
      ST_KEYGEN_OUT_1:      ns = ST_KEYGEN_OUT_2;
      ST_KEYGEN_OUT_2:      ns = ST_KEYGEN_OUT_3;
      ST_KEYGEN_OUT_3:      ns = ST_IDLE;
      
      // Signing States - Input (8 cycles for 512-bit message)
      ST_SIGN_MSG_IN_0:     ns = ST_SIGN_MSG_IN_1;
      ST_SIGN_MSG_IN_1:     ns = ST_SIGN_MSG_IN_2;
      ST_SIGN_MSG_IN_2:     ns = ST_SIGN_MSG_IN_3;
      ST_SIGN_MSG_IN_3:     ns = ST_SIGN_MSG_IN_4;
      ST_SIGN_MSG_IN_4:     ns = ST_SIGN_MSG_IN_5;
      ST_SIGN_MSG_IN_5:     ns = ST_SIGN_MSG_IN_6;
      ST_SIGN_MSG_IN_6:     ns = ST_SIGN_MSG_IN_7;
      ST_SIGN_MSG_IN_7:     ns = ST_SIGN_START;
      ST_SIGN_START:        ns = ST_SIGN_WAIT;
      ST_SIGN_WAIT:         if (fsm_done) ns = ST_SIGN_OUT_0;
      // Signing States - Output (8 cycles for 512-bit signature)
      ST_SIGN_OUT_0:        ns = ST_SIGN_OUT_1;
      ST_SIGN_OUT_1:        ns = ST_SIGN_OUT_2;
      ST_SIGN_OUT_2:        ns = ST_SIGN_OUT_3;
      ST_SIGN_OUT_3:        ns = ST_SIGN_OUT_4;
      ST_SIGN_OUT_4:        ns = ST_SIGN_OUT_5;
      ST_SIGN_OUT_5:        ns = ST_SIGN_OUT_6;
      ST_SIGN_OUT_6:        ns = ST_SIGN_OUT_7;
      ST_SIGN_OUT_7:        ns = ST_IDLE;
      
      // Verification States - Public Key Input (4 cycles for 256-bit)
      ST_VERIFY_PK_IN_0:    ns = ST_VERIFY_PK_IN_1;
      ST_VERIFY_PK_IN_1:    ns = ST_VERIFY_PK_IN_2;
      ST_VERIFY_PK_IN_2:    ns = ST_VERIFY_PK_IN_3;
      ST_VERIFY_PK_IN_3:    ns = ST_VERIFY_MSG_IN_0;
      // Verification States - Message Input (8 cycles for 512-bit)
      ST_VERIFY_MSG_IN_0:   ns = ST_VERIFY_MSG_IN_1;
      ST_VERIFY_MSG_IN_1:   ns = ST_VERIFY_MSG_IN_2;
      ST_VERIFY_MSG_IN_2:   ns = ST_VERIFY_MSG_IN_3;
      ST_VERIFY_MSG_IN_3:   ns = ST_VERIFY_MSG_IN_4;
      ST_VERIFY_MSG_IN_4:   ns = ST_VERIFY_MSG_IN_5;
      ST_VERIFY_MSG_IN_5:   ns = ST_VERIFY_MSG_IN_6;
      ST_VERIFY_MSG_IN_6:   ns = ST_VERIFY_MSG_IN_7;
      ST_VERIFY_MSG_IN_7:   ns = ST_VERIFY_SIG_IN_0;
      // Verification States - Signature Input (8 cycles for 512-bit)
      ST_VERIFY_SIG_IN_0:   ns = ST_VERIFY_SIG_IN_1;
      ST_VERIFY_SIG_IN_1:   ns = ST_VERIFY_SIG_IN_2;
      ST_VERIFY_SIG_IN_2:   ns = ST_VERIFY_SIG_IN_3;
      ST_VERIFY_SIG_IN_3:   ns = ST_VERIFY_SIG_IN_4;
      ST_VERIFY_SIG_IN_4:   ns = ST_VERIFY_SIG_IN_5;
      ST_VERIFY_SIG_IN_5:   ns = ST_VERIFY_SIG_IN_6;
      ST_VERIFY_SIG_IN_6:   ns = ST_VERIFY_SIG_IN_7;
      ST_VERIFY_SIG_IN_7:   ns = ST_VERIFY_START;
      ST_VERIFY_START:      ns = ST_VERIFY_WAIT;
      ST_VERIFY_WAIT:       if (fsm_done) ns = ST_VERIFY_OUT;
      ST_VERIFY_OUT:        ns = ST_IDLE;

      default: ns = ST_IDLE;
    endcase
  end

  // Sequential Logic (State and Registers)
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      // Reset state to IDLE
      cs <= ST_IDLE;

      // Reset buffers
      sign_msg_buf <= 512'b0;
      verify_msg_buf <= 512'b0;
      verify_sig_buf <= 512'b0;
      verify_pk_buf <= 256'b0;
      keygen_pubkey_buf <= 256'b0;
      sign_out_buf <= 256'b0;
      
      // Reset outputs
      valid <= 1'b0;
      data_out <= 64'b0;
    end 
    else begin
      // State Transition
      cs <= ns;

      // Input Buffer Updates
      case (cs)
        // Sign message input buffering
        ST_SIGN_MSG_IN_0: sign_msg_buf[63:0]     <= data_in;
        ST_SIGN_MSG_IN_1: sign_msg_buf[127:64]   <= data_in;
        ST_SIGN_MSG_IN_2: sign_msg_buf[191:128]  <= data_in;
        ST_SIGN_MSG_IN_3: sign_msg_buf[255:192]  <= data_in;
        ST_SIGN_MSG_IN_4: sign_msg_buf[319:256]  <= data_in;
        ST_SIGN_MSG_IN_5: sign_msg_buf[383:320]  <= data_in;
        ST_SIGN_MSG_IN_6: sign_msg_buf[447:384]  <= data_in;
        ST_SIGN_MSG_IN_7: sign_msg_buf[511:448]  <= data_in;
        
        // Verify public key input buffering
        ST_VERIFY_PK_IN_0: verify_pk_buf[63:0]    <= data_in;
        ST_VERIFY_PK_IN_1: verify_pk_buf[127:64]  <= data_in;
        ST_VERIFY_PK_IN_2: verify_pk_buf[191:128] <= data_in;
        ST_VERIFY_PK_IN_3: verify_pk_buf[255:192] <= data_in;
        
        // Verify message input buffering
        ST_VERIFY_MSG_IN_0: verify_msg_buf[63:0]     <= data_in;
        ST_VERIFY_MSG_IN_1: verify_msg_buf[127:64]   <= data_in;
        ST_VERIFY_MSG_IN_2: verify_msg_buf[191:128]  <= data_in;
        ST_VERIFY_MSG_IN_3: verify_msg_buf[255:192]  <= data_in;
        ST_VERIFY_MSG_IN_4: verify_msg_buf[319:256]  <= data_in;
        ST_VERIFY_MSG_IN_5: verify_msg_buf[383:320]  <= data_in;
        ST_VERIFY_MSG_IN_6: verify_msg_buf[447:384]  <= data_in;
        ST_VERIFY_MSG_IN_7: verify_msg_buf[511:448]  <= data_in;
        
        // Verify signature input buffering
        ST_VERIFY_SIG_IN_0: verify_sig_buf[63:0]     <= data_in;
        ST_VERIFY_SIG_IN_1: verify_sig_buf[127:64]   <= data_in;
        ST_VERIFY_SIG_IN_2: verify_sig_buf[191:128]  <= data_in;
        ST_VERIFY_SIG_IN_3: verify_sig_buf[255:192]  <= data_in;
        ST_VERIFY_SIG_IN_4: verify_sig_buf[319:256]  <= data_in;
        ST_VERIFY_SIG_IN_5: verify_sig_buf[383:320]  <= data_in;
        ST_VERIFY_SIG_IN_6: verify_sig_buf[447:384]  <= data_in;
        ST_VERIFY_SIG_IN_7: verify_sig_buf[511:448]  <= data_in;
        
        // Store keygen output for later transmission
        ST_KEYGEN_STORE_PUB: keygen_pubkey_buf <= fsm_pubkey_out;
        
        default: begin
          // No buffer updates needed for other states
        end
      endcase

      // Output Logic
      case (cs)
        // Key generation output
        ST_KEYGEN_OUT_0: begin
          valid    <= 1'b1;
          data_out <= keygen_pubkey_buf[63:0];
        end
        ST_KEYGEN_OUT_1: begin
          valid    <= 1'b1;
          data_out <= keygen_pubkey_buf[127:64];
        end
        ST_KEYGEN_OUT_2: begin
          valid    <= 1'b1;
          data_out <= keygen_pubkey_buf[191:128];
        end
        ST_KEYGEN_OUT_3: begin
          valid    <= 1'b1;
          data_out <= keygen_pubkey_buf[255:192];
        end
        
        // Signing output
        ST_SIGN_OUT_0: begin
          valid    <= 1'b1;
          data_out <= generated_signature[63:0];
        end
        ST_SIGN_OUT_1: begin
          valid    <= 1'b1;
          data_out <= generated_signature[127:64];
        end
        ST_SIGN_OUT_2: begin
          valid    <= 1'b1;
          data_out <= generated_signature[191:128];
        end
        ST_SIGN_OUT_3: begin
          valid    <= 1'b1;
          data_out <= generated_signature[255:192];
        end
        ST_SIGN_OUT_4: begin
          valid    <= 1'b1;
          data_out <= generated_signature[319:256];
        end
        ST_SIGN_OUT_5: begin
          valid    <= 1'b1;
          data_out <= generated_signature[383:320];
        end
        ST_SIGN_OUT_6: begin
          valid    <= 1'b1;
          data_out <= generated_signature[447:384];
        end
        ST_SIGN_OUT_7: begin
          valid    <= 1'b1;
          data_out <= generated_signature[511:448];
        end
        
        // Verification output
        ST_VERIFY_OUT: begin
          valid    <= 1'b1;
          // Success indicated by fsm_output_data = 512'hFFFF...FFFF; outputs 64'hFFFF...FFFF if true, 0 otherwise
          data_out <= (fsm_output_data == {512{1'b1}}) ? {64{1'b1}} : 64'b0;
        end
        
        default: begin
          valid    <= 1'b0;
          data_out <= 64'b0;
        end
      endcase
    end
  end

  // Control Logic (Combinational)
  always @(*) begin
    fsm_start      = 1'b0;
    fsm_opmode     = 2'b00;
    reg_write_en   = 1'b0;
    reg_addr       = 3'b000;
    reg_write_data = 512'b0;

    case (cs)
      ST_KEYGEN_START: begin
        fsm_opmode = 2'b00;
        fsm_start  = 1'b1;
      end
      ST_KEYGEN_STORE_PRIV: begin
        reg_write_en   = 1'b1;
        reg_addr       = 3'b011;  // generated_privkey
        reg_write_data = fsm_output_data;
      end
      ST_KEYGEN_STORE_PUB: begin
        reg_write_en   = 1'b1;
        reg_addr       = 3'b100;  // generated_pubkey
        reg_write_data = {256'b0, fsm_pubkey_out};
      end
      
      ST_SIGN_START: begin
        // Write complete message to register before starting FSM
        reg_write_en   = 1'b1;
        reg_addr       = 3'b101;  // sign_message
        reg_write_data = sign_msg_buf;
        fsm_opmode     = 2'b01;
        fsm_start      = 1'b1;
      end
      ST_SIGN_WAIT: begin
        if (fsm_done) begin
          reg_write_en   = 1'b1;
          reg_addr       = 3'b110;  // generated_signature
          reg_write_data = fsm_output_data;
        end
      end
      
      ST_VERIFY_SIG_IN_7: begin
        // Write complete public key to register
        reg_write_en   = 1'b1;
        reg_addr       = 3'b010;  // verify_pubkey
        reg_write_data = {256'b0, verify_pk_buf};
      end
      ST_VERIFY_START: begin
        // Write complete message and signature to registers before starting FSM
        reg_write_en   = 1'b1;
        reg_addr       = 3'b000;  // verify_message
        reg_write_data = verify_msg_buf;
        fsm_opmode     = 2'b10;
        fsm_start      = 1'b1;
      end
      ST_VERIFY_WAIT: begin
        if (!fsm_start) begin  // Only write signature after message is written
          reg_write_en   = 1'b1;
          reg_addr       = 3'b001;  // verify_signature
          reg_write_data = verify_sig_buf;
        end
      end

      default: begin
        fsm_start      = 1'b0;
        fsm_opmode     = 2'b00;
        reg_write_en   = 1'b0;
        reg_addr       = 3'b000;
        reg_write_data = 512'b0;
      end
    endcase
  end

endmodule