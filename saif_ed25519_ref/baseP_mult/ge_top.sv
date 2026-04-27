module ge_top (
input clk,
input start,
input rst_n,

input [2:0] opcode_in,
input signed [319:0] p_X,
input signed [319:0] p_Y,
input signed [319:0] p_Z,
input signed [319:0] p_T,
    
input signed [319:0] q_1,  // yplusx 
input signed [319:0] q_2,  // yminusx
input signed [319:0] q_3,  // xy2d , z
input signed [319:0] q_4,  // t2d

output  signed  [319:0] r_x,
output  signed  [319:0] r_y,
output  signed  [319:0] r_z,
output  signed  [319:0] r_t,
output reg done_TOP
);

typedef enum logic [2:0] {
  ge_add               = 3'd0,
  ge_madd              = 3'd1,
  ge_msub              = 3'd2,
  ge_p1p1top2          = 3'd3,
  ge_p1p1_to_p3        = 3'd4,
  ge_p2_dbl            = 3'd5,
  ge_p3_to_cached      = 3'd6,
  ge_sub               = 3'd7
} opcode_e;

typedef enum logic [2:0] {
  ST_IDLE              = 3'd0,
  ST_START             = 3'd1,
  ST_WAIT              = 3'd2
} state_e;     

state_e cs, ns;
logic start_fsm;
logic done;
opcode_e opcode;

// Store the opcode when operation starts
opcode_e current_opcode;

assign opcode = opcode_e'(opcode_in);

ge_fsm_top ge_fsm_top_instant(
 .clk(clk),
 .reset(rst_n),
 .start(start_fsm),

 .opcode_in(current_opcode),
 .p_X(p_X),
 .p_Y(p_Y),
 .p_Z(p_Z),
 .p_T(p_T),
    
 .q_1(q_1),  // yplusx 
 .q_2(q_2),  // yminusx
 .q_3(q_3),  // xy2d , z
 .q_4(q_4),  // t2d

.r_x(r_x),
.r_y(r_y),
.r_z(r_z),
.r_t(r_t),
.done(done)
);

// Simplified 3-state FSM
always @(*) begin
  ns = cs;  // Default: stay in current state
  case (cs)
    ST_IDLE: begin
      if (start) begin
        ns = ST_START;
      end
    end
    
    ST_START: begin
      // Always move to WAIT state after one clock cycle
      ns = ST_WAIT;
    end
    
    ST_WAIT: begin
      if (done) begin
        ns = ST_IDLE;
      end
    end
    
    default: ns = ST_IDLE;
  endcase
end

// Fixed Sequential Logic
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    cs <= ST_IDLE;
    done_TOP <= 0;
    current_opcode <= ge_add;  // Default opcode
  end 
  else begin
    cs <= ns;
    
    case (cs)
      ST_IDLE: begin
        done_TOP <= 0;
        if (start) begin
          current_opcode <= opcode;
        end
      end
      
      ST_START: begin
        // Keep done_TOP low during start phase
        done_TOP <= 0;
      end
      
      ST_WAIT: begin
        if (done) begin
          // Set done when operation completes
          done_TOP <= 1;
        end
      end
      
      default: begin
        done_TOP <= 0;
      end
    endcase
  end
end

// Generate start signal for sub-FSM
always @(*) begin
  start_fsm = (cs == ST_START);
end

endmodule