module ge_fsm_top(
input clk,
input reset,
input start,

input [2:0] opcode_in,
input signed [319:0] p_X,
input signed [319:0] p_Y,
input signed [319:0] p_Z,
input signed [319:0] p_T,
        
input signed [319:0] q_1,  // yplusx 
input signed [319:0] q_2,  // yminusx
input signed [319:0] q_3,  // xy2d , z
input signed [319:0] q_4,  // t2d


output reg signed [319:0] r_x,
output reg signed [319:0] r_y,
output reg signed [319:0] r_z,
output reg signed [319:0] r_t,
output  done
);



//######################################## Combined ge_add_sub_madd_msub #############################################//

// Unified registers for both operation types
reg signed [319:0] YpX1_unified;
reg signed [319:0] YmX1_unified;
reg signed [319:0] A_unified;
reg signed [319:0] B_unified;
reg signed [319:0] C_unified;
reg signed [319:0] D_unified;
reg signed [319:0] ZZ_unified;  // Only used for add_sub operations
reg signed [319:0] r_x_unified;
reg signed [319:0] r_y_unified;
reg signed [319:0] r_z_unified;
reg signed [319:0] r_t_unified;
reg done_ge_unified;

// Unified control signals
logic [1:0] add_sel_unified;
logic [1:0] sub_sel_unified;
logic [2:0] mul_sel_unified;  // Extended to 3 bits to handle 5 cases
logic mul_start_unified;
reg mul_done_unified;

// Wire declarations for operation inputs
logic signed [319:0] add_f_unified;
logic signed [319:0] add_g_unified;
logic signed [319:0] sub_f_unified;
logic signed [319:0] sub_g_unified;
logic signed [319:0] mul_f_unified;
logic signed [319:0] mul_g_unified;



 typedef enum logic [2:0] {
    ge_add               = 3'd0,
    ge_madd              = 3'd1,
    ge_msub              = 3'd2,
    ge_p1p1_to_p2          = 3'd3,
    ge_p1p1_to_p3        = 3'd4,
    ge_p2_dbl            = 3'd5,
    ge_p3_to_cached      = 3'd6,
    ge_sub               = 3'd7
   
  } opcode_e;   // to define the opcode of the selected ge operation

    opcode_e opcode;
    assign opcode = opcode_e'(opcode_in);


// Helper signal to determine operation type
logic is_add_sub_op;
assign is_add_sub_op = (opcode == ge_add || opcode == ge_sub);



//######################################## ge madd ge msub #############################################/
reg signed [319:0] r_x_madd_msub;
reg signed [319:0] r_y_madd_msub;
reg signed [319:0] r_z_madd_msub;
reg signed [319:0] r_t_madd_msub;
reg done_ge_madd_msub;





////////////###########################################################################################/////////////


//######################################## ge add ge sub #############################################//
// Combined registers for both operations

reg signed [319:0] r_x_add_sub;
reg signed [319:0] r_y_add_sub;
reg signed [319:0] r_z_add_sub;
reg signed [319:0] r_t_add_sub;
reg done_ge_add_sub;



////////////###########################################################################################/////////////

//######################################## ge p1p1 to p3 ge p1p1 to p2 #############################################//

// Combined registers for both operations
reg signed [319:0] r_x_top2p3;
reg signed [319:0] r_y_top2p3;
reg signed [319:0] r_z_top2p3;
reg signed [319:0] r_t_top2p3;
reg done_ge_p1p1_to_p2_p3;

// Control signals
logic [1:0] mul_sel_top2p3;
logic mul_start_top2p3;
reg      mul_done_top2p3;

// Wire declarations for operation inputs
logic [319:0] mul_f_top2p3;
logic [319:0] mul_g_top2p3;
////////////###########################################################################################/////////////



// P2 Doubling (2dbl)
reg signed [319:0] r_x_2dbl, r_y_2dbl, r_z_2dbl, r_t_2dbl;
reg signed [319:0] add_f_2dbl, add_g_2dbl ;
reg signed [319:0] sub_f_2dbl, sub_g_2dbl ;
reg signed [319:0] sq_f_2dbl;
reg signed [319:0] sq2_f_2dbl;
reg signed [319:0] A_2dbl, B_2dbl;
reg signed [319:0] XX_2dbl, YY_2dbl, AA_2dbl;
reg [1:0] add_sel_2dbl, sub_sel_2dbl, sq_sel_2dbl, sq2_sel_2dbl;
reg       sq_start_2dbl, sq2_start_2dbl;
reg      sq_done_2dbl, sq2_done_2dbl;
logic  done_ge_p2_dbl;


// P3 to Cached Conversion
reg signed [319:0] r_x_cached, r_y_cached, r_z_cached, r_t_cached;
reg signed [319:0] add_f_cached, add_g_cached ;
reg signed [319:0] sub_f_cached, sub_g_cached ;
reg signed [319:0] mul_f_cached, mul_g_cached ;
reg signed [319:0] copy_f_cached ;
reg       add_sel_cached, sub_sel_cached; // for ge_p3_to_cached
reg       mul_start_cached;
reg      mul_done_cached;
logic done_ge_p3_cached;

// signals to add sub squaring and squaring 2 and copy and mul units
reg signed [319:0] add_f, add_g, add_h;
reg signed [319:0] sub_f, sub_g, sub_h;
reg signed [319:0] mul_f, mul_g, mul_h;
reg signed [319:0] mul_f_q, mul_g_q;
reg signed [319:0] sq_f, sq_h;
reg signed [319:0] sq2_f, sq2_h;
reg signed [319:0] copy_f, copy_h;

reg mul_start;
reg mul_start_q;
reg mul_done;
reg sq_start, sq2_start;
reg sq_done, sq2_done;



/// fe units instants///

 fe_add add_unit (
        .f(add_f), 
        .g(add_g), 
        .h(add_h)
    );
    
    fe_sub sub_unit (
        .f(sub_f), 
        .g(sub_g), 
        .h(sub_h)
    );
    
    // Sequential multiplier with control signals
    fe_mul mul_unit (
        .clk(clk),
        .reset(reset),
        .start(mul_start_q),
        .done(mul_done),
        .f(mul_f_q), 
        .g(mul_g_q), 
        .h(mul_h)
    );

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            mul_start_q <= 1'b0;
            mul_f_q <= 320'b0;
            mul_g_q <= 320'b0;
        end else begin
            mul_start_q <= mul_start;
            if (mul_start) begin
                mul_f_q <= mul_f;
                mul_g_q <= mul_g;
            end
        end
    end

 fe_sq sq_unit (
        .clk(clk),
        .reset(reset),
        .start(sq_start),
        .done(sq_done),
        .f(sq_f), 
        .h(sq_h)
    );
    
    // Sequential double squaring unit with control signals  
    fe_sq2 sq2_unit (
        .clk(clk),
        .reset(reset),
        .start(sq2_start),
        .done(sq2_done),
        .f(sq2_f), 
        .h(sq2_h)
    );

fe_copy copy_unit (
        .f(copy_f),
        .h(copy_h)
    );





typedef enum logic [6:0] {
    IDLE             ,
   // ge_add_sub_START
    CALC_YpX1_YmX1,      // Combined initial calculation
    CALC_A_START,
    CALC_A_WAIT,
    CALC_B_START,
    CALC_B_WAIT,
    CALC_C_START,
    CALC_C_WAIT,
    CALC_ZZ_START,       // Only for add_sub operations
    CALC_ZZ_WAIT,        // Only for add_sub operations
    CALC_D,              // Different calculations based on operation type
    CALC_XY,
    CALC_ZT,


   
   // ge_p1p1_to_p3_to_p2_START      
    CALC_X_START_top2p3,
    CALC_X_WAIT_top2p3,
    CALC_Y_START_top2p3,
    CALC_Y_WAIT_top2p3,
    CALC_Z_START_top2p3,
    CALC_Z_WAIT_top2p3,
    CALC_T_START_top2p3,
    CALC_T_WAIT_top2p3,

   // ge_p2_dbl_START      
        CALC_XX_START_2dbl,
        CALC_XX_WAIT_2dbl,
        CALC_YY_START_2dbl,
        CALC_YY_WAIT_2dbl,
        CALC_B_START_2dbl,
        CALC_B_WAIT_2dbl,
        CALC_A_2dbl,
        CALC_AA_START_2dbl,
        CALC_AA_WAIT_2dbl,
        CALC_RY_RZ_2dbl,
        CALC_SETTLE_2dbl,
        CALC_RX_2dbl,
        CALC_RT_2dbl,

   // ge_p3_to_cached_START      
        CALC_YPLUS_YMINUS_cached,
        CALC_T2D_START_cached,
        CALC_T2D_WAIT_cached,
        COPY_Z_cached,

    DONE_STATE
 
  } state_e;

state_e      cs_top2p3   ,cs_2dbl, cs_cached ;

state_e      ns_top2p3   ,ns_2dbl, ns_cached ;

state_e cs_unified, ns_unified;


// Input multiplexer for add unit
always_comb begin
    case (add_sel_unified)
        2'b00: begin // YpX1 = p_Y + p_X
            add_f_unified = p_Y;
            add_g_unified = p_X;
        end
        2'b01: begin 
            if (is_add_sub_op) begin // D = ZZ + ZZ (for add_sub)
                add_f_unified = ZZ_unified;
                add_g_unified = ZZ_unified;
            end else begin // D = p_Z + p_Z (for madd_msub)
                add_f_unified = p_Z;
                add_g_unified = p_Z;
            end
        end
        2'b10: begin // r_Y = A + B
            add_f_unified = A_unified;
            add_g_unified = B_unified;
        end
        2'b11: begin // r_Z/r_T = D + C
            add_f_unified = D_unified;
            add_g_unified = C_unified;
        end
        default: begin
            add_f_unified = 320'b0;
            add_g_unified = 320'b0;
        end
    endcase
end

// Input multiplexer for sub unit
always_comb begin
    case (sub_sel_unified)
        2'b00: begin // YmX1 = p_Y - p_X
            sub_f_unified = p_Y;
            sub_g_unified = p_X;
        end
        2'b01: begin // r_X = A - B
            sub_f_unified = A_unified;
            sub_g_unified = B_unified;
        end
        2'b10: begin // r_Z/r_T = D - C
            sub_f_unified = D_unified;
            sub_g_unified = C_unified;
        end
        default: begin
            sub_f_unified = 320'b0;
            sub_g_unified = 320'b0;
        end
    endcase
end

// Input multiplexer for mul unit (extended to handle both operation types)
always_comb begin
    case (mul_sel_unified)
        3'b000: begin // A calculation
            mul_f_unified = YpX1_unified;
            if (is_add_sub_op) begin
                // For ge_add: A = YpX1 * q_YplusX, For ge_sub: A = YpX1 * q_YminusX
                mul_g_unified = (opcode == ge_add) ? q_1 : q_2;
            end else begin
                // For ge_madd: A = YpX1 * q_yplusx, For ge_msub: A = YpX1 * q_yminusx
                mul_g_unified = (opcode == ge_madd) ? q_1 : q_2;
            end
        end
        3'b001: begin // B calculation
            mul_f_unified = YmX1_unified;
            if (is_add_sub_op) begin
                // For ge_add: B = YmX1 * q_YminusX, For ge_sub: B = YmX1 * q_YplusX
                mul_g_unified = (opcode == ge_add) ? q_2 : q_1;
            end else begin
                // For ge_madd: B = YmX1 * q_yminusx, For ge_msub: B = YmX1 * q_yplusx
                mul_g_unified = (opcode == ge_madd) ? q_2 : q_1;
            end
        end
        3'b010: begin // C calculation
            if (is_add_sub_op) begin
                // C = q_T2d * p_T (for add_sub)
                mul_f_unified = q_4;
                mul_g_unified = p_T;
            end else begin
                // C = q_xy2d * p_T (for madd_msub)
                mul_f_unified = q_3;
                mul_g_unified = p_T;
            end
        end
        3'b011: begin // ZZ = p_Z * q_Z (only for add_sub)
            mul_f_unified = p_Z;
            mul_g_unified = q_3;
        end
        default: begin
            mul_f_unified = 320'b0;
            mul_g_unified = 320'b0;
        end
    endcase
end

// State machine sequential logic
always_ff @(posedge clk or negedge reset) begin
    if (!reset) begin
        cs_unified <= IDLE;
        YpX1_unified <= 320'b0;
        YmX1_unified <= 320'b0;
        A_unified <= 320'b0;
        B_unified <= 320'b0;
        C_unified <= 320'b0;
        D_unified <= 320'b0;
        ZZ_unified <= 320'b0;
        r_x_unified <= 320'b0;
        r_y_unified <= 320'b0;
        r_z_unified <= 320'b0;
        r_t_unified <= 320'b0;
        done_ge_unified <= 1'b0;
    end else begin
        cs_unified <= ns_unified;

        // Register intermediate results based on current state
        case (cs_unified)
            CALC_YpX1_YmX1: begin
                YpX1_unified <= add_h;   // YpX1 = p_Y + p_X
                YmX1_unified <= sub_h;   // YmX1 = p_Y - p_X
            end
            CALC_A_WAIT: begin
                if (mul_done_unified) begin
                    A_unified <= mul_h;
                end
            end
            CALC_B_WAIT: begin
                if (mul_done_unified) begin
                    B_unified <= mul_h;
                end
            end
            CALC_C_WAIT: begin
                if (mul_done_unified) begin
                    C_unified <= mul_h;
                end
            end
            CALC_ZZ_WAIT: begin // Only for add_sub operations
                if (mul_done_unified) begin
                    ZZ_unified <= mul_h;
                end
            end
            CALC_D: begin
                D_unified <= add_h;
            end
            CALC_XY: begin
                r_x_unified <= sub_h;    // r_X = A - B
                r_y_unified <= add_h;    // r_Y = A + B
            end
            CALC_ZT: begin
                // Results assignment based on operation type
                if (is_add_sub_op) begin
                    if (opcode == ge_add) begin
                        r_z_unified <= add_h;    // r_Z = D + C
                        r_t_unified <= sub_h;    // r_T = D - C
                    end else begin // ge_sub
                        r_z_unified <= sub_h;    // r_Z = D - C
                        r_t_unified <= add_h;    // r_T = D + C
                    end
                end else begin // madd_msub operations
                    if (opcode == ge_madd) begin
                        r_z_unified <= add_h;    // r_Z = D + C
                        r_t_unified <= sub_h;    // r_T = D - C
                    end else begin // ge_msub
                        r_z_unified <= sub_h;    // r_Z = D - C
                        r_t_unified <= add_h;    // r_T = D + C
                    end
                end
            end
            DONE_STATE: begin
                done_ge_unified <= 1'b1;
            end
            default: begin
                done_ge_unified <= 1'b0;
            end
        endcase
    end
end

// State machine combinational logic
always_comb begin
    ns_unified = cs_unified;
    add_sel_unified = 2'b00;
    sub_sel_unified = 2'b00;
    mul_sel_unified = 3'b000;
    mul_start_unified = 1'b0;

    case (cs_unified)
        IDLE: begin
            if (start) begin
                if (opcode == ge_add || opcode == ge_sub || opcode == ge_madd || opcode == ge_msub) begin
                    ns_unified = CALC_YpX1_YmX1;
                end else begin
                    ns_unified = IDLE;  // Other operations handled by other FSMs
                end
            end
        end

        CALC_YpX1_YmX1: begin
            add_sel_unified = 2'b00; // YpX1 = p_Y + p_X
            sub_sel_unified = 2'b00; // YmX1 = p_Y - p_X
            ns_unified = CALC_A_START;
        end

        CALC_A_START: begin
            mul_sel_unified = 3'b000;
            mul_start_unified = 1'b1;
            ns_unified = CALC_A_WAIT;
        end

        CALC_A_WAIT: begin
            mul_sel_unified = 3'b000;
            if (mul_done_unified) begin
                ns_unified = CALC_B_START;
            end
        end

        CALC_B_START: begin
            mul_sel_unified = 3'b001;
            mul_start_unified = 1'b1;
            ns_unified = CALC_B_WAIT;
        end

        CALC_B_WAIT: begin
            mul_sel_unified = 3'b001;
            if (mul_done_unified) begin
                ns_unified = CALC_C_START;
            end
        end

        CALC_C_START: begin
            mul_sel_unified = 3'b010;
            mul_start_unified = 1'b1;
            ns_unified = CALC_C_WAIT;
        end

        CALC_C_WAIT: begin
            mul_sel_unified = 3'b010;
            if (mul_done_unified) begin
                if (is_add_sub_op) begin
                    ns_unified = CALC_ZZ_START;  // Need ZZ calculation for add_sub
                end else begin
                    ns_unified = CALC_D;         // Skip ZZ for madd_msub
                end
            end
        end

        CALC_ZZ_START: begin // Only for add_sub operations
            mul_sel_unified = 3'b011;
            mul_start_unified = 1'b1;
            ns_unified = CALC_ZZ_WAIT;
        end

        CALC_ZZ_WAIT: begin // Only for add_sub operations
            mul_sel_unified = 3'b011;
            if (mul_done_unified) begin
                ns_unified = CALC_D;
            end
        end

        CALC_D: begin
            add_sel_unified = 2'b01; // Different D calculations based on operation type
            ns_unified = CALC_XY;
        end

        CALC_XY: begin
            sub_sel_unified = 2'b01; // r_X = A - B
            add_sel_unified = 2'b10; // r_Y = A + B
            ns_unified = CALC_ZT;
        end

        CALC_ZT: begin
            add_sel_unified = 2'b11; // D + C
            sub_sel_unified = 2'b10; // D - C
            ns_unified = DONE_STATE;
        end

        DONE_STATE: begin
            if (!start) begin
                ns_unified = IDLE;
            end
        end

        default: begin
            ns_unified = IDLE;
        end
    endcase
end

// Connect the unified outputs to the original output signals
// You'll need to add logic to route these based on the operation type
assign r_x_add_sub = (is_add_sub_op) ? r_x_unified : 320'b0;
assign r_y_add_sub = (is_add_sub_op) ? r_y_unified : 320'b0;
assign r_z_add_sub = (is_add_sub_op) ? r_z_unified : 320'b0;
assign r_t_add_sub = (is_add_sub_op) ? r_t_unified : 320'b0;
assign done_ge_add_sub = (is_add_sub_op) ? done_ge_unified : 1'b0;

assign r_x_madd_msub = (!is_add_sub_op && (opcode == ge_madd || opcode == ge_msub)) ? r_x_unified : 320'b0;
assign r_y_madd_msub = (!is_add_sub_op && (opcode == ge_madd || opcode == ge_msub)) ? r_y_unified : 320'b0;
assign r_z_madd_msub = (!is_add_sub_op && (opcode == ge_madd || opcode == ge_msub)) ? r_z_unified : 320'b0;
assign r_t_madd_msub = (!is_add_sub_op && (opcode == ge_madd || opcode == ge_msub)) ? r_t_unified : 320'b0;
assign done_ge_madd_msub = (!is_add_sub_op && (opcode == ge_madd || opcode == ge_msub)) ? done_ge_unified : 1'b0;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////p1p1top2_top3///////////////////////////////////////////////////

// Input multiplexer for mul unit
always_comb begin
    case (mul_sel_top2p3)
        2'b00: begin // r_X = p_X * p_T
            mul_f_top2p3 = p_X;
            mul_g_top2p3 = p_T;
        end
        2'b01: begin // r_Y = p_Y * p_Z
            mul_f_top2p3 = p_Y;
            mul_g_top2p3 = p_Z;
        end
        2'b10: begin // r_Z = p_Z * p_T
            mul_f_top2p3 = p_Z;
            mul_g_top2p3 = p_T;
        end
        2'b11: begin // r_T = p_X * p_Y
            mul_f_top2p3 = p_X;
            mul_g_top2p3 = p_Y;
        end
        default: begin
            mul_f_top2p3 = 320'b0;
            mul_g_top2p3 = 320'b0;
        end
    endcase
end

// State machine sequential logic
always_ff @(posedge clk or negedge reset) begin
    if (!reset) begin
        cs_top2p3 <= IDLE;
        r_x_top2p3 <= 320'b0;
        r_y_top2p3 <= 320'b0;
        r_z_top2p3 <= 320'b0;
        r_t_top2p3 <= 320'b0;
        done_ge_p1p1_to_p2_p3 <= 1'b0;
    end else begin
        cs_top2p3 <= ns_top2p3;

        // Register results based on current state
        case (cs_top2p3)
            CALC_X_WAIT_top2p3: begin
                if (mul_done_top2p3) begin
                    r_x_top2p3 <= mul_h;    // r_X = p_X * p_T
                end
            end
            CALC_Y_WAIT_top2p3: begin
                if (mul_done_top2p3) begin
                    r_y_top2p3 <= mul_h;    // r_Y = p_Y * p_Z
                end
            end
            CALC_Z_WAIT_top2p3: begin
                if (mul_done_top2p3) begin
                    r_z_top2p3 <= mul_h;    // r_Z = p_Z * p_T
                end
            end
            CALC_T_WAIT_top2p3: begin
                if (mul_done_top2p3) begin
                    r_t_top2p3 <= mul_h;    // r_T = p_X * p_Y
                end
            end
            DONE_STATE: begin
                done_ge_p1p1_to_p2_p3 <= 1'b1;
            end
            default: begin
                done_ge_p1p1_to_p2_p3 <= 1'b0;
            end
        endcase
    end
end

// State machine combinational logic
always_comb begin
    ns_top2p3 = cs_top2p3;
    mul_sel_top2p3 = 2'b00;
    mul_start_top2p3 = 1'b0;

    case (cs_top2p3)
        IDLE: begin
            if (start) begin
                if (opcode == ge_p1p1_to_p2 || opcode == ge_p1p1_to_p3) begin
                    ns_top2p3 = CALC_X_START_top2p3;
                end else begin
                    ns_top2p3 = IDLE;
                end
            end
        end

        CALC_X_START_top2p3: begin
            mul_sel_top2p3 = 2'b00; // r_X = p_X * p_T
            mul_start_top2p3 = 1'b1;
            ns_top2p3 = CALC_X_WAIT_top2p3;
        end

        CALC_X_WAIT_top2p3: begin
            mul_sel_top2p3 = 2'b00; // Keep inputs stable
            if (mul_done_top2p3) begin
                ns_top2p3 = CALC_Y_START_top2p3;
            end
        end

        CALC_Y_START_top2p3: begin
            mul_sel_top2p3 = 2'b01; // r_Y = p_Y * p_Z
            mul_start_top2p3 = 1'b1;
            ns_top2p3 = CALC_Y_WAIT_top2p3;
        end

        CALC_Y_WAIT_top2p3: begin
            mul_sel_top2p3 = 2'b01; // Keep inputs stable
            if (mul_done_top2p3) begin
                ns_top2p3 = CALC_Z_START_top2p3;
            end
        end

        CALC_Z_START_top2p3: begin
            mul_sel_top2p3 = 2'b10; // r_Z = p_Z * p_T
            mul_start_top2p3 = 1'b1;
            ns_top2p3 = CALC_Z_WAIT_top2p3;
        end

        CALC_Z_WAIT_top2p3: begin
            mul_sel_top2p3 = 2'b10; // Keep inputs stable
            if (mul_done_top2p3) begin
                // For ge_p1p1_to_p2: skip T calculation and go to DONE
                // For ge_p1p1_to_p3: continue to T calculation
                if (opcode == ge_p1p1_to_p2) begin
                    ns_top2p3 = DONE_STATE;
                end else begin // opcode == ge_p1p1_to_p3
                    ns_top2p3 = CALC_T_START_top2p3;
                end
            end
        end

        CALC_T_START_top2p3: begin
            mul_sel_top2p3 = 2'b11; // r_T = p_X * p_Y
            mul_start_top2p3 = 1'b1;
            ns_top2p3 = CALC_T_WAIT_top2p3;
        end

        CALC_T_WAIT_top2p3: begin
            mul_sel_top2p3 = 2'b11; // Keep inputs stable
            if (mul_done_top2p3) begin
                ns_top2p3 = DONE_STATE;
            end
        end

        DONE_STATE: begin
            if (!start) begin
                ns_top2p3 = IDLE;
            end
        end

        default: begin
            ns_top2p3 = IDLE;
        end
    endcase
end

///////////////////////////////////////////////////p2dbl//////////////////////////////////////////////

// Input multiplexers for add unit
always_comb begin
    case (add_sel_2dbl)
        2'b00: begin // A = p_X + p_Y
            add_f_2dbl = p_X;
            add_g_2dbl = p_Y;
        end
        2'b01: begin // r_Y = YY + XX
            add_f_2dbl = YY_2dbl;
            add_g_2dbl = XX_2dbl;
        end
        default: begin
            add_f_2dbl = 320'b0;
            add_g_2dbl = 320'b0;
        end
    endcase
end

// Input multiplexers for sub unit
always_comb begin
    case (sub_sel_2dbl)
        2'b00: begin // r_Z = YY - XX
            sub_f_2dbl = YY_2dbl;
            sub_g_2dbl = XX_2dbl;
        end
        2'b01: begin // r_X = AA - r_Y
            sub_f_2dbl = AA_2dbl;
            sub_g_2dbl = r_y_2dbl;
        end
        2'b10: begin // r_T = B - r_Z
            sub_f_2dbl = B_2dbl;
            sub_g_2dbl = r_z_2dbl;
        end
        default: begin
            sub_f_2dbl = 320'b0;
            sub_g_2dbl = 320'b0;
        end
    endcase
end

// Input multiplexers for sq unit
always_comb begin
    case (sq_sel_2dbl)
        2'b00: begin // XX = p_X^2
            sq_f_2dbl = p_X;
        end
        2'b01: begin // YY = p_Y^2
            sq_f_2dbl = p_Y;
        end
        2'b10: begin // AA = A^2
            sq_f_2dbl = A_2dbl;
        end
        default: begin
            sq_f_2dbl = 320'b0;
        end
    endcase
end

// Input multiplexers for sq2 unit
always_comb begin
    case (sq2_sel_2dbl)
        2'b00: begin // B = 2*(p_Z^2)
            sq2_f_2dbl = p_Z;
        end
        default: begin
            sq2_f_2dbl = 320'b0;
        end
    endcase
end

// State machine sequential logic
always_ff @(posedge clk or negedge reset) begin
    if (!reset) begin
        cs_2dbl <= IDLE;
        XX_2dbl <= 320'b0;
        YY_2dbl <= 320'b0;
        B_2dbl <= 320'b0;
        A_2dbl <= 320'b0;
        AA_2dbl <= 320'b0;
        r_x_2dbl <= 320'b0;
        r_y_2dbl <= 320'b0;
        r_z_2dbl <= 320'b0;
        r_t_2dbl <= 320'b0;
        done_ge_p2_dbl <= 1'b0;
    end else begin
        cs_2dbl <= ns_2dbl;
        
        // Register intermediate results based on current state
        case (cs_2dbl)
            CALC_XX_WAIT_2dbl: begin
                if (sq_done_2dbl) begin
                    XX_2dbl <= sq_h;    // XX = p_X^2
                end
            end
            CALC_YY_WAIT_2dbl: begin
                if (sq_done_2dbl) begin
                    YY_2dbl <= sq_h;    // YY = p_Y^2
                end
            end
            CALC_B_WAIT_2dbl: begin
                if (sq2_done_2dbl) begin
                    B_2dbl <= sq2_h;   // B = 2*(p_Z^2)
                end
            end
            CALC_A_2dbl: begin
                A_2dbl <= add_h;    // A = p_X + p_Y
            end
            CALC_AA_WAIT_2dbl: begin
                if (sq_done_2dbl) begin
                    AA_2dbl <= sq_h;   // AA = A^2
                end
            end
            CALC_RY_RZ_2dbl: begin
                r_y_2dbl <= add_h;  // r_Y = YY + XX
                r_z_2dbl <= sub_h;  // r_Z = YY - XX
            end
            CALC_SETTLE_2dbl: begin
                // Values r_Y and r_Z are now stable, no register updates
            end
            CALC_RX_2dbl: begin
                r_x_2dbl <= sub_h;  // r_X = AA - r_Y
            end
            CALC_RT_2dbl: begin
                r_t_2dbl <= sub_h;  // r_T = B - r_Z                    
            end
            DONE_STATE: begin
                done_ge_p2_dbl <= 1'b1;
            end
            default: begin
                done_ge_p2_dbl <= 1'b0;
            end
        endcase
    end
end

// State machine combinational logic
always_comb begin
    ns_2dbl = cs_2dbl;
    add_sel_2dbl = 2'b00;
    sub_sel_2dbl = 2'b00;
    sq_sel_2dbl = 2'b00;
    sq2_sel_2dbl = 2'b00;
    sq_start_2dbl = 1'b0;
    sq2_start_2dbl = 1'b0;
    
    case (cs_2dbl)
        IDLE: begin
            if (start) begin
                if(opcode == ge_p2_dbl) begin
                    ns_2dbl = CALC_XX_START_2dbl;
                end
                else ns_2dbl=IDLE;
            end
        end
        
        CALC_XX_START_2dbl: begin
            sq_sel_2dbl = 2'b00; // XX = p_X^2
            sq_start_2dbl = 1'b1;
            ns_2dbl = CALC_XX_WAIT_2dbl;
        end
        
        CALC_XX_WAIT_2dbl: begin
            sq_sel_2dbl = 2'b00; // Keep inputs stable
            if (sq_done_2dbl) begin
                ns_2dbl = CALC_YY_START_2dbl;
            end
        end
        
        CALC_YY_START_2dbl: begin
            sq_sel_2dbl = 2'b01; // YY = p_Y^2
            sq_start_2dbl = 1'b1;
            ns_2dbl = CALC_YY_WAIT_2dbl;
        end
        
        CALC_YY_WAIT_2dbl: begin
            sq_sel_2dbl = 2'b01; // Keep inputs stable
            if (sq_done_2dbl) begin
                ns_2dbl = CALC_B_START_2dbl;
            end
        end
        
        CALC_B_START_2dbl: begin
            sq2_sel_2dbl = 2'b00; // B = 2*(p_Z^2)
            sq2_start_2dbl = 1'b1;
            ns_2dbl = CALC_B_WAIT_2dbl;
        end
        
        CALC_B_WAIT_2dbl: begin
            sq2_sel_2dbl = 2'b00; // Keep inputs stable
            if (sq2_done_2dbl) begin
                ns_2dbl = CALC_A_2dbl;
            end
        end
        
        CALC_A_2dbl: begin
            add_sel_2dbl = 2'b00; // A = p_X + p_Y
            ns_2dbl = CALC_AA_START_2dbl;
        end
        
        CALC_AA_START_2dbl: begin
            sq_sel_2dbl = 2'b10; // AA = A^2
            sq_start_2dbl = 1'b1;
            ns_2dbl = CALC_AA_WAIT_2dbl;
        end
        
        CALC_AA_WAIT_2dbl: begin
            sq_sel_2dbl = 2'b10; // Keep inputs stable
            if (sq_done_2dbl) begin
                ns_2dbl = CALC_RY_RZ_2dbl;
            end
        end
        
        CALC_RY_RZ_2dbl: begin
            add_sel_2dbl = 2'b01; // r_Y = YY + XX
            sub_sel_2dbl = 2'b00; // r_Z = YY - XX
            ns_2dbl = CALC_SETTLE_2dbl;
        end
        
        CALC_SETTLE_2dbl: begin
            // Give r_Y and r_Z one cycle to settle
            ns_2dbl = CALC_RX_2dbl;
        end
        
        CALC_RX_2dbl: begin
            sub_sel_2dbl = 2'b01; // r_X = AA - r_Y
            ns_2dbl = CALC_RT_2dbl;
        end
        
        CALC_RT_2dbl: begin
            sub_sel_2dbl = 2'b10; // r_T = B - r_Z
            ns_2dbl = DONE_STATE;
        end
        
        DONE_STATE: begin
            if (!start) begin
                ns_2dbl = IDLE;
            end
        end
        
        default: begin
            ns_2dbl = IDLE;
        end
    endcase
end

///////////////////////////////////////////////p3 cached//////////////////////////////////////////

// d2 constant from d2.h
localparam [319:0] d2 = { 
    32'd9444199,   // d2[319:288]
    32'd29715968,  // d2[287:256]
    -32'd6495438,  // d2[255:224]
    -32'd12551817, // d2[223:192]
    32'd15978800,  // d2[191:160]
    32'd229458,    // d2[159:128]
    32'd13898782,  // d2[127:96]
    -32'd30745221, // d2[95:64]
    -32'd5839606,  // d2[63:32]
    -32'd21827239  // d2[31:0]
};

// Input multiplexers for add unit
always_comb begin
    case (add_sel_cached)
        1'b0: begin // r_YplusX = p_Y + p_X
            add_f_cached = p_Y;
            add_g_cached = p_X;
        end
        default: begin
            add_f_cached = 320'b0;
            add_g_cached = 320'b0;
        end
    endcase
end

// Input multiplexers for sub unit
always_comb begin
    case (sub_sel_cached)
        1'b0: begin // r_YminusX = p_Y - p_X
            sub_f_cached = p_Y;
            sub_g_cached = p_X;
        end
        default: begin
            sub_f_cached = 320'b0;
            sub_g_cached = 320'b0;
        end
    endcase
end

// Input multiplexers for mul unit
always_comb begin
    mul_f_cached = p_T;
    mul_g_cached = d2;
end

// Input for copy unit
always_comb begin
    copy_f_cached = p_Z;
end

// State machine sequential logic
always_ff @(posedge clk or negedge reset) begin
    if (!reset) begin
        cs_cached <= IDLE;
        r_x_cached <= 320'b0;
        r_y_cached <= 320'b0;
        r_z_cached <= 320'b0;
        r_t_cached <= 320'b0;
        done_ge_p3_cached <= 1'b0;
    end else begin
        cs_cached <= ns_cached;

        // Register results based on current state
        case (cs_cached)
            CALC_YPLUS_YMINUS_cached: begin
                r_x_cached <= add_h;  // r_YplusX = p_Y + p_X
                r_y_cached <= sub_h;  // r_YminusX = p_Y - p_X
            end
            CALC_T2D_WAIT_cached: begin
                if (mul_done_cached) begin
                    r_t_cached <= mul_h; // r_T2d = p_T * d2
                end
            end
            COPY_Z_cached: begin
                r_z_cached <= copy_h;  // r_Z = p_Z (using fe_copy)
            end
            DONE_STATE: begin
                done_ge_p3_cached <= 1'b1;
            end
            default: begin
                done_ge_p3_cached <= 1'b0;
            end
        endcase
    end
end

// State machine combinational logic
always_comb begin
    ns_cached = cs_cached;
    add_sel_cached = 1'b0;
    sub_sel_cached = 1'b0;
    mul_start_cached = 1'b0;

    case (cs_cached)
        IDLE: begin
            if (start) begin
                if (opcode == ge_p3_to_cached) begin
                    ns_cached = CALC_YPLUS_YMINUS_cached;
                end
                else ns_cached=IDLE;
            end
        end

        CALC_YPLUS_YMINUS_cached: begin
            add_sel_cached = 1'b0; // r_YplusX = p_Y + p_X
            sub_sel_cached = 1'b0; // r_YminusX = p_Y - p_X
            ns_cached = CALC_T2D_START_cached;
        end

        CALC_T2D_START_cached: begin
            mul_start_cached = 1'b1; // Start r_T2d = p_T * d2
            ns_cached = CALC_T2D_WAIT_cached;
        end

        CALC_T2D_WAIT_cached: begin
            if (mul_done_cached) begin
                ns_cached = COPY_Z_cached;
            end
        end

        COPY_Z_cached: begin
            ns_cached = DONE_STATE;
        end

        DONE_STATE: begin
            if (!start) begin
                ns_cached = IDLE;
            end
        end

        default: begin
            ns_cached = IDLE;
        end
    endcase
end


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Output multiplexer
always_comb begin
    case (opcode)
 ge_add: begin
    r_x = r_x_add_sub;  // Changed from r_x_add
    r_y = r_y_add_sub;  // Changed from r_y_add
    r_z = r_z_add_sub;  // Changed from r_z_add
    r_t = r_t_add_sub;  // Changed from r_t_add
end
ge_sub: begin
    r_x = r_x_add_sub;  // Changed from r_x_sub
    r_y = r_y_add_sub;  // Changed from r_y_sub
    r_z = r_z_add_sub;  // Changed from r_z_sub
    r_t = r_t_add_sub;  // Changed from r_t_sub
end       
        ge_madd: begin
            r_x = r_x_madd_msub;
            r_y = r_y_madd_msub;
            r_z = r_z_madd_msub;
            r_t = r_t_madd_msub;
        end
        ge_msub: begin
            r_x = r_x_madd_msub;
            r_y = r_y_madd_msub;
            r_z = r_z_madd_msub;
            r_t = r_t_madd_msub;
        end
        ge_p1p1_to_p2: begin
            r_x = r_x_top2p3;
            r_y = r_y_top2p3;
            r_z = r_z_top2p3;
            r_t = r_t_top2p3;
        end
        ge_p1p1_to_p3: begin
            r_x = r_x_top2p3;
            r_y = r_y_top2p3;
            r_z = r_z_top2p3;
            r_t = r_t_top2p3;
        end
        ge_p2_dbl: begin
            r_x = r_x_2dbl;
            r_y = r_y_2dbl;
            r_z = r_z_2dbl;
            r_t = r_t_2dbl;
        end
        ge_p3_to_cached: begin
            r_x = r_x_cached;
            r_y = r_y_cached;
            r_z = r_z_cached;
            r_t = r_t_cached;
        end

        default: begin
            r_x = 320'b0;
            r_y = 320'b0;
            r_z = 320'b0;
            r_t = 320'b0;
        end
    endcase
end








// Multiplexer for operation inputs and control signals
always_comb begin

        mul_done_cached=0;
        mul_done_top2p3=0;
        mul_done_unified=0;
        sq_done_2dbl=0;
        sq2_done_2dbl=0;
        add_f = 320'b0;
        add_g = 320'b0;
        sub_f = 320'b0;
        sub_g = 320'b0;
        mul_f = 320'b0;
        mul_g = 320'b0;
        sq_f = 320'b0;
        sq2_f = 320'b0;
        copy_f = 320'b0;
        mul_start = 1'b0;
        sq_start = 1'b0;
        sq2_start = 1'b0;


        case (opcode)
            ge_add, ge_sub: begin
                add_f    = add_f_unified;
                add_g    = add_g_unified;
                sub_f    = sub_f_unified;
                sub_g    = sub_g_unified;
                mul_f    = mul_f_unified;
                mul_g    = mul_g_unified;
                mul_start = mul_start_unified;
                mul_done_unified = mul_done;
                sq_f     = 320'b0;
                sq2_f    = 320'b0;
                copy_f   = 320'b0;
                sq_start = 1'b0;
                sq2_start = 1'b0;
            end
            ge_madd, ge_msub: begin
                add_f    = add_f_unified;
                add_g    = add_g_unified;
                sub_f    = sub_f_unified;
                sub_g    = sub_g_unified;
                mul_f    = mul_f_unified;
                mul_g    = mul_g_unified;
                mul_start = mul_start_unified;
                mul_done_unified = mul_done;
                sq_f     = 320'b0;
                sq2_f    = 320'b0;
                copy_f   = 320'b0;
                sq_start = 1'b0;
                sq2_start = 1'b0;
            end
            ge_p1p1_to_p2, ge_p1p1_to_p3: begin
                add_f    = 320'b0;
                add_g    = 320'b0;
                sub_f    = 320'b0;
                sub_g    = 320'b0;
                mul_f    = mul_f_top2p3;
                mul_g    = mul_g_top2p3;
                mul_start = mul_start_top2p3;
                mul_done_top2p3 = mul_done;
                sq_f     = 320'b0;
                sq2_f    = 320'b0;
                copy_f   = 320'b0;
                sq_start = 1'b0;
                sq2_start = 1'b0;
            end
            ge_p2_dbl: begin
                add_f    = add_f_2dbl;
                add_g    = add_g_2dbl;
                sub_f    = sub_f_2dbl;
                sub_g    = sub_g_2dbl;
                mul_f    = 320'b0;
                mul_g    = 320'b0;
                sq_f     = sq_f_2dbl;
                sq2_f    = sq2_f_2dbl;
                copy_f   = 320'b0;
                mul_start = 1'b0;
                sq_start = sq_start_2dbl;
                sq2_start = sq2_start_2dbl;
                sq_done_2dbl = sq_done;
                sq2_done_2dbl = sq2_done;
            end
            ge_p3_to_cached: begin
                add_f    = add_f_cached;
                add_g    = add_g_cached;
                sub_f    = sub_f_cached;
                sub_g    = sub_g_cached;
                mul_f    = mul_f_cached;
                mul_g    = mul_g_cached;
                mul_start = mul_start_cached;
                mul_done_cached = mul_done;
                sq_f     = 320'b0;
                sq2_f    = 320'b0;
                copy_f   = copy_f_cached;
                sq_start = 1'b0;
                sq2_start = 1'b0;
            end

        endcase
end

assign done = done_ge_add_sub || done_ge_madd_msub || done_ge_p1p1_to_p2_p3   || done_ge_p2_dbl || done_ge_p3_cached ;


endmodule
