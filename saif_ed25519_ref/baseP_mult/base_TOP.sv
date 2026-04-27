module base_TOP (
    input clk,
    input reset,
    input start,
    input op_operand,
    input logic [255:0] a,
    input [255:0] b,
    input signed [319:0] A_X, A_Y, A_Z, A_T, // Input point A
    output logic signed [319:0] r_X, r_Y, r_Z,r_T, // Output point (ge_p2 format)
    output reg done
);


//----------------------------------------------------------
// Slide Modules (aslide/bslide)
//----------------------------------------------------------
wire slide_a_done, slide_b_done;
wire signed [4:0] aslide [0:255];
wire signed [4:0] bslide [0:255];

slide_rtl u_slide_a (
    .clk(clk),
    .rst(reset),
    .start(start),
    .a(a),
    .r(aslide),
    .done(slide_a_done)
);

slide_rtl u_slide_b (
    .clk(clk),
    .rst(reset),
    .start(start),
    .a(b),
    .r(bslide),
    .done(slide_b_done)
);

//----------------------------------------------------------
// Precomputed Bi Table (From base2.h)
//----------------------------------------------------------
wire signed [0:319] Bi_YplusX;
wire signed [0:319] Bi_YminusX;
wire signed [0:319] Bi_Z;
reg [3:0] bslide_idx;

bi_constants_rom bi_rom (
    .index(bslide_idx),
    .bi_yplus_x(Bi_YplusX),
    .bi_yminus_x(Bi_YminusX),
    .bi_z(Bi_Z)
);

//----------------------------------------------------------
// Storage for Ai precomputed values
//----------------------------------------------------------
reg signed [319:0] Ai_YplusX [0:7];
reg signed [319:0] Ai_YminusX [0:7];
reg signed [319:0] Ai_Z [0:7];
reg signed [319:0] Ai_T2d [0:7];

// Temporary point storage
reg signed [319:0] A2_X, A2_Y, A2_Z, A2_T;
reg signed [319:0] temp_X, temp_Y, temp_Z, temp_T;

//----------------------------------------------------------
// Internal signal declarations
//----------------------------------------------------------
// Internal signal declarations
    logic signed [7:0] e [0:63];         // Exponent array, 64 elements, each 8-bits  
    logic signed [511:0] e_packed;       // Packed version of e for the carry_prop module
    logic signed [511:0] e_prop_result;  // Result from carry_prop
    logic signed [7:0] e_decomp [0:63];  // Output from decompose module
    
    // Temporary p2 point
    logic signed [319:0] s_X, s_Y, s_Z, s_T;    // Temporary p2 point
    
    // Precomputed point
    logic signed [319:0] t_yplusx, t_yminusx, t_xy2d;
    logic signed [319:0] t_yplusx_abs_q, t_yminusx_abs_q, t_xy2d_abs_q;
    logic signed [319:0] t_yplusx_q, t_yminusx_q, t_xy2d_q;
    logic select_negative, select_negative_q;
    
    // Output registers
    logic signed [319:0] h_X_reg, h_Y_reg, h_Z_reg, h_T_reg;
    
    // Counter and control
    reg [7:0] i;  // Loop counter
    logic[6:0]new_i;
    logic done_reg;

    // Module control signals - now start/done instead of enable
    logic select_start; 


//----------------------------------------------------------
// State Machine Definitions
//----------------------------------------------------------
// FSM state declarations
    typedef enum logic [7:0] {
        IDLE,               // Waiting for start
        DECOMPOSE,          // Decompose scalar a into e
        PACK_E,             // Pack e array into e_packed for carry_prop
        CARRY_PROP,         // Carry propagation
        UNPACK_E,           // Unpack e_prop_result into e array
        INIT_P3_0,          // Initialize h to neutral point
        INIT_ODD_LOOP,      // Initialize odd indices loop
        SELECT_ODD,         // Select for odd index
        SELECT_ODD_APPLY_SIGN,
        MADD_ODD,           // ge_madd for odd index
        WAIT_MADD_ODD,      // Wait for ge_madd completion
        TO_P3_ODD,          // Convert to p3 after odd operation
        WAIT_P3_ODD,        // Wait for p1p1_to_p3 completion
        NEXT_ODD,           // Move to next odd index
        INIT_DBL,           // Initialize doubling sequence
        DBL1,               // First doubling
        WAIT_DBL1,          // Wait for first doubling completion
        TO_P2_1,            // Convert to p2 after first doubling
        WAIT_P2_1,          // Wait for p1p1_to_p2 completion
        DBL2,               // Second doubling
        WAIT_DBL2,          // Wait for second doubling completion
        TO_P2_2,            // Convert to p2 after second doubling
        WAIT_P2_2,          // Wait for p1p1_to_p2 completion
        DBL3,               // Third doubling
        WAIT_DBL3,          // Wait for third doubling completion
        TO_P2_3,            // Convert to p2 after third doubling
        WAIT_P2_3,          // Wait for p1p1_to_p2 completion
        DBL4,               // Fourth doubling
        WAIT_DBL4,          // Wait for fourth doubling completion
        TO_P3_DBL,          // Convert to p3 after fourth doubling
        WAIT_P3_DBL,        // Wait for p1p1_to_p3 completion
        INIT_EVEN_LOOP,     // Initialize even indices loop
        SELECT_EVEN,        // Select for even index
        SELECT_EVEN_APPLY_SIGN,
        MADD_EVEN,          // ge_madd for even index
        WAIT_MADD_EVEN,     // Wait for ge_madd completion
        TO_P3_EVEN,         // Convert to p3 after even operation
        WAIT_P3_EVEN,       // Wait for p1p1_to_p3 completion
        NEXT_EVEN,          // Move to next even index
        WAIT_SLIDES ,
        PRECOMP_CONV0 ,
        PRECOMP_DBL ,
        PRECOMP_CONV_A2 ,
        PRECOMP_ADD_1 , PRECOMP_CONV_1 , PRECOMP_CACHE_1 ,
        PRECOMP_ADD_2 , PRECOMP_CONV_2 , PRECOMP_CACHE_2 ,
        PRECOMP_ADD_3 , PRECOMP_CONV_3 , PRECOMP_CACHE_3 ,
        PRECOMP_ADD_4 , PRECOMP_CONV_4 , PRECOMP_CACHE_4 ,
        PRECOMP_ADD_5 , PRECOMP_CONV_5 , PRECOMP_CACHE_5 ,
        PRECOMP_ADD_6 , PRECOMP_CONV_6 , PRECOMP_CACHE_6 ,
        PRECOMP_ADD_7 , PRECOMP_CONV_7 , PRECOMP_CACHE_7 ,
        FIND_MSB ,
        DBL ,
        P1P1_TO_P3_A ,
        ADD_SUB_A ,
        P1P1_TO_P3_B ,
        ADD_SUB_B ,
        P1P1_TO_P2 ,
        UPDATE ,
        DONE_ST ,
        DONE                // Operation complete
    } state_t;
    
    state_t state, prev_state;

//----------------------------------------------------------
// Control registers
//----------------------------------------------------------
reg [2:0] precomp_idx; // For precomputation loop
reg signed [3:0] aslide_idx;
reg signed [319:0] r_X_next, r_Y_next, r_Z_next, r_T_next;

//----------------------------------------------------------
// Input Multiplexers for Shared Modules
//----------------------------------------------------------
// Multiplexer inputs for ge_p3_to_cached
reg signed [319:0] cache_p_X, cache_p_Y, cache_p_Z, cache_p_T;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        cache_p_X <= 0; cache_p_Y <= 0; cache_p_Z <= 0; cache_p_T <= 0;
    end else if (state == PRECOMP_CONV0) begin
        cache_p_X <= A_X; cache_p_Y <= A_Y; cache_p_Z <= A_Z; cache_p_T <= A_T;
    end else if (state >= PRECOMP_CACHE_1 && state <= PRECOMP_CACHE_7) begin
        cache_p_X <= temp_X; cache_p_Y <= temp_Y; cache_p_Z <= temp_Z; cache_p_T <= temp_T;
    end
end

// Multiplexer inputs for ge_add
reg signed [319:0] add_p_X, add_p_Y, add_p_Z, add_p_T;
reg signed [319:0] add_q_YplusX, add_q_YminusX, add_q_Z, add_q_T2d;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        add_p_X <= 0; add_p_Y <= 0; add_p_Z <= 0; add_p_T <= 0;
        add_q_YplusX <= 0; add_q_YminusX <= 0; add_q_Z <= 0; add_q_T2d <= 0;
    end else begin
        case (state)
            PRECOMP_ADD_1: begin
                add_p_X <= A2_X; add_p_Y <= A2_Y; add_p_Z <= A2_Z; add_p_T <= A2_T;
                add_q_YplusX <= Ai_YplusX[0]; add_q_YminusX <= Ai_YminusX[0];
                add_q_Z <= Ai_Z[0]; add_q_T2d <= Ai_T2d[0];
            end
            PRECOMP_ADD_2: begin
                add_p_X <= A2_X; add_p_Y <= A2_Y; add_p_Z <= A2_Z; add_p_T <= A2_T;
                add_q_YplusX <= Ai_YplusX[1]; add_q_YminusX <= Ai_YminusX[1];
                add_q_Z <= Ai_Z[1]; add_q_T2d <= Ai_T2d[1];
            end
            PRECOMP_ADD_3: begin
                add_p_X <= A2_X; add_p_Y <= A2_Y; add_p_Z <= A2_Z; add_p_T <= A2_T;
                add_q_YplusX <= Ai_YplusX[2]; add_q_YminusX <= Ai_YminusX[2];
                add_q_Z <= Ai_Z[2]; add_q_T2d <= Ai_T2d[2];
            end
            PRECOMP_ADD_4: begin
                add_p_X <= A2_X; add_p_Y <= A2_Y; add_p_Z <= A2_Z; add_p_T <= A2_T;
                add_q_YplusX <= Ai_YplusX[3]; add_q_YminusX <= Ai_YminusX[3];
                add_q_Z <= Ai_Z[3]; add_q_T2d <= Ai_T2d[3];
            end
            PRECOMP_ADD_5: begin
                add_p_X <= A2_X; add_p_Y <= A2_Y; add_p_Z <= A2_Z; add_p_T <= A2_T;
                add_q_YplusX <= Ai_YplusX[4]; add_q_YminusX <= Ai_YminusX[4];
                add_q_Z <= Ai_Z[4]; add_q_T2d <= Ai_T2d[4];
            end
            PRECOMP_ADD_6: begin
                add_p_X <= A2_X; add_p_Y <= A2_Y; add_p_Z <= A2_Z; add_p_T <= A2_T;
                add_q_YplusX <= Ai_YplusX[5]; add_q_YminusX <= Ai_YminusX[5];
                add_q_Z <= Ai_Z[5]; add_q_T2d <= Ai_T2d[5];
            end
            PRECOMP_ADD_7: begin
                add_p_X <= A2_X; add_p_Y <= A2_Y; add_p_Z <= A2_Z; add_p_T <= A2_T;
                add_q_YplusX <= Ai_YplusX[6]; add_q_YminusX <= Ai_YminusX[6];
                add_q_Z <= Ai_Z[6]; add_q_T2d <= Ai_T2d[6];
            end
            ADD_SUB_A: begin
                add_p_X <= temp_X; add_p_Y <= temp_Y; add_p_Z <= temp_Z; add_p_T <= temp_T;
                add_q_YplusX <= Ai_YplusX[aslide_idx]; add_q_YminusX <= Ai_YminusX[aslide_idx];
                add_q_Z <= Ai_Z[aslide_idx]; add_q_T2d <= Ai_T2d[aslide_idx];
            end
        endcase
    end
end

// Multiplexer inputs for ge_sub
reg signed [319:0] sub_p_X, sub_p_Y, sub_p_Z, sub_p_T;
reg signed [319:0] sub_q_YplusX, sub_q_YminusX, sub_q_Z, sub_q_T2d;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        sub_p_X <= 0; sub_p_Y <= 0; sub_p_Z <= 0; sub_p_T <= 0;
        sub_q_YplusX <= 0; sub_q_YminusX <= 0; sub_q_Z <= 0; sub_q_T2d <= 0;
    end else if (state == ADD_SUB_A) begin
        sub_p_X <= temp_X; sub_p_Y <= temp_Y; sub_p_Z <= temp_Z; sub_p_T <= temp_T;
        sub_q_YplusX <= Ai_YplusX[aslide_idx]; sub_q_YminusX <= Ai_YminusX[aslide_idx];
        sub_q_Z <= Ai_Z[aslide_idx]; sub_q_T2d <= Ai_T2d[aslide_idx];
    end
end

//----------------------------------------------------------
// Sequential Module Control Signals
//----------------------------------------------------------
reg start_cache, start_dbl, start_p2_dbl, start_add, start_sub;
reg start_madd, start_msub, start_p1p1_to_p3, start_p1p1_to_p2;

//logic done_cache, done_dbl, done_p2_dbl, done_add, done_sub;
//logic done_madd, done_msub, done_p1p1_to_p3, done_p1p1_to_p2;
//logic done_madd_multbase, done_p1p1_to_p3_multbase, done_dbl_multbase, done_p1p1_to_p2_multbase, done_p2_dbl_multbase;
logic  done_dbl;

//----------------------------------------------------------
// Modified Shared Module Instances (Sequential)
//----------------------------------------------------------
logic signed [319:0] madd_p_X, madd_p_Y, madd_p_Z, madd_p_T;
// Shared ge_p3_dbl
logic signed [319:0] dbl_X, dbl_Y, dbl_Z, dbl_T;
/*
// Shared ge_p3_to_cached
logic signed [319:0] cache_YplusX, cache_YminusX, cache_Z, cache_T2d;



// Shared ge_p2_dbl for main loop
logic signed [319:0] p2_dbl_X, p2_dbl_Y, p2_dbl_Z, p2_dbl_T;



// Shared ge_add
logic signed [319:0] add_X, add_Y, add_Z, add_T;

// Shared ge_sub
logic signed [319:0] sub_X, sub_Y, sub_Z, sub_T;

// Shared ge_madd
logic signed [319:0] madd_X, madd_Y, madd_Z, madd_T;

// Shared ge_msub
logic signed [319:0] msub_X, msub_Y, msub_Z, msub_T;

// Shared ge_p1p1_to_p3
logic signed [319:0] p3_X, p3_Y, p3_Z, p3_T;

// Shared ge_p1p1_to_p2
logic signed [319:0] p2_X, p2_Y, p2_Z;*/


//----------------------------------------------------------
// Modified Shared Module Instances scalar_multbase
//----------------------------------------------------------
// Instantiate submodules
    decompose decomp_inst (
        .a(a),
        .e(e_decomp)
    );

    logic carry_prop_start;
    logic carry_prop_done;
    logic carry_prop_busy;

    assign carry_prop_start = (state == CARRY_PROP) && (prev_state != CARRY_PROP);

    carry_prop_seq carry_inst (
        .clk(clk),
        .reset(reset),
        .start(carry_prop_start),
        .e_in(e_packed),
        .e_out(e_prop_result),
        .busy(carry_prop_busy),
        .done(carry_prop_done)
    );

    wire [4:0]  pos;
    assign pos = new_i/2;

    select select_inst (
        .pos(pos),
        .b(e[new_i]),
        .t_yplusx(t_yplusx),
        .t_yminusx(t_yminusx),
        .t_xy2d(t_xy2d),
        .bnegative(select_negative)
    );

    wire signed [319:0] t_xy2d_abs_neg;
    fe_neg neg_selected_xy2d (
        .f(t_xy2d_abs_q),
        .h(t_xy2d_abs_neg)
    );
    
    // Need intermediate registers to hold r values for p1p1_to_p3 input
    logic signed [319:0] r_X_reg, r_Y_reg, r_Z_reg, r_T_reg;
    


//----------------------------------------------------------
// Modified Input Multiplexers for Shared Modules
//----------------------------------------------------------

// Multiplexer inputs for ge_madd/ge_msub (now handles both operations)
reg signed [319:0] madd_q_yplusx, madd_q_yminusx, madd_q_xy2d;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        madd_p_X <= 320'd0; madd_p_Y <= 320'd0; madd_p_Z <= 320'd0; madd_p_T <= 320'd0;
        madd_q_yplusx <= 320'd0; madd_q_yminusx <= 320'd0; madd_q_xy2d <= 320'd0;
    end else begin
        case (state)
            ADD_SUB_B: begin
                madd_p_X <= temp_X; madd_p_Y <= temp_Y; madd_p_Z <= temp_Z; madd_p_T <= temp_T;
                madd_q_yplusx <= Bi_YplusX; madd_q_yminusx <= Bi_YminusX; madd_q_xy2d <= Bi_Z;
            end
            // For multbase operations
            MADD_ODD, MADD_EVEN: begin
                madd_p_X <= h_X_reg; madd_p_Y <= h_Y_reg; madd_p_Z <= h_Z_reg; madd_p_T <= h_T_reg;
                madd_q_yplusx <= t_yplusx_q; madd_q_yminusx <= t_yminusx_q; madd_q_xy2d <= t_xy2d_q;
            end
        endcase
    end
end

// Multiplexer inputs for ge_p3_dbl (now handles both operations)
reg signed [319:0] dbl_p_X, dbl_p_Y, dbl_p_Z, dbl_p_T;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        dbl_p_X <= 320'd0; dbl_p_Y <= 320'd0; dbl_p_Z <= 320'd0; dbl_p_T <= 320'd0;
    end else begin
        case (state)
            PRECOMP_DBL: begin
                dbl_p_X <= A_X; dbl_p_Y <= A_Y; dbl_p_Z <= A_Z; dbl_p_T <= A_T;
            end
            DBL1: begin
                dbl_p_X <= h_X_reg; dbl_p_Y <= h_Y_reg; dbl_p_Z <= h_Z_reg; dbl_p_T <= h_T_reg;
            end
        endcase
    end
end

// Multiplexer inputs for ge_p2_dbl (now handles both operations)
reg signed [319:0] p2_dbl_p_X, p2_dbl_p_Y, p2_dbl_p_Z;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        p2_dbl_p_X <= 320'd0; p2_dbl_p_Y <= 320'd0; p2_dbl_p_Z <= 320'd0;
    end else begin
        case (state)
            DBL: begin
                p2_dbl_p_X <= r_X; p2_dbl_p_Y <= r_Y; p2_dbl_p_Z <= r_Z;
            end
            DBL2, DBL3, DBL4: begin
                p2_dbl_p_X <= s_X; p2_dbl_p_Y <= s_Y; p2_dbl_p_Z <= s_Z;
            end
        endcase
    end
end

// Multiplexer inputs for ge_p1p1_to_p3 (now handles all operations)
reg signed [319:0] p1p1_p3_p_X, p1p1_p3_p_Y, p1p1_p3_p_Z, p1p1_p3_p_T;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        p1p1_p3_p_X <= 320'd0; p1p1_p3_p_Y <= 320'd0; p1p1_p3_p_Z <= 320'd0; p1p1_p3_p_T <= 320'd0;
    end else begin
        case (state)
            PRECOMP_CONV_A2, PRECOMP_CONV_1, PRECOMP_CONV_2, PRECOMP_CONV_3,
            PRECOMP_CONV_4, PRECOMP_CONV_5, PRECOMP_CONV_6, PRECOMP_CONV_7: begin
                p1p1_p3_p_X <= temp_X; p1p1_p3_p_Y <= temp_Y; p1p1_p3_p_Z <= temp_Z; p1p1_p3_p_T <= temp_T;
            end
            P1P1_TO_P3_A, P1P1_TO_P3_B: begin
                p1p1_p3_p_X <= r_X_next; p1p1_p3_p_Y <= r_Y_next; p1p1_p3_p_Z <= r_Z_next; p1p1_p3_p_T <= r_T_next;
            end
            TO_P3_ODD, TO_P3_EVEN, TO_P3_DBL: begin
                p1p1_p3_p_X <= r_X_reg; p1p1_p3_p_Y <= r_Y_reg; p1p1_p3_p_Z <= r_Z_reg; p1p1_p3_p_T <= r_T_reg;
            end
        endcase
    end
end

// Multiplexer inputs for ge_p1p1_to_p2 (now handles all operations)
reg signed [319:0] p1p1_p2_p_X, p1p1_p2_p_Y, p1p1_p2_p_Z, p1p1_p2_p_T;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        p1p1_p2_p_X <= 320'd0; p1p1_p2_p_Y <= 320'd0; p1p1_p2_p_Z <= 320'd0; p1p1_p2_p_T <= 320'd0;
    end else begin
        case (state)
            P1P1_TO_P2: begin
                p1p1_p2_p_X <= r_X_next; p1p1_p2_p_Y <= r_Y_next; p1p1_p2_p_Z <= r_Z_next; p1p1_p2_p_T <= r_T_next;
            end
            TO_P2_1, TO_P2_2, TO_P2_3: begin
                p1p1_p2_p_X <= r_X_reg; p1p1_p2_p_Y <= r_Y_reg; p1p1_p2_p_Z <= r_Z_reg; p1p1_p2_p_T <= r_T_reg;
            end
        endcase
    end
end

//----------------------------------------------------------
// Modified Single Shared Module Instances
//----------------------------------------------------------

// Single ge_p3_dbl instance (replaces both u_shared_dbl and ge_p3_dbl_inst)
ge_p3_dbl u_shared_dbl (
    .clk(clk),
    .reset(reset),
    .start(start_dbl),
    .p_X(dbl_p_X), .p_Y(dbl_p_Y), .p_Z(dbl_p_Z), .p_T(dbl_p_T),
    .r_X(dbl_X), .r_Y(dbl_Y), .r_Z(dbl_Z), .r_T(dbl_T),
    .done(done_dbl)
);




////////////////////////////////////////////////////////////////////////////////////////////////////////////
localparam [2:0]
    GE_ADD            = 3'd0,
    GE_MADD           = 3'd1,
    GE_MSUB           = 3'd2,
    GE_P1P1TOP2       = 3'd3,
    GE_P1P1_TO_P3     = 3'd4,
    GE_P2_DBL         = 3'd5,
    GE_P3_TO_CACHED   = 3'd6,
    GE_SUB            = 3'd7;

// Control signals for mux wrapper
logic [2:0] ge_sel_opcode;
logic ge_start;

     logic signed [319:0] result_x, result_y, result_z, result_t;
     logic               operation_done;
     logic [2:0]         completed_opcode;  // Which operation just completed

// Example: assign ge_sel_opcode and ge_start based on your FSM state
// always_comb or always_ff: set ge_sel_opcode and ge_start according to state

ge_top_mux_wrapper u_ge_top_mux_wrapper (
    .clk(clk),
    .rst_n(reset), // or .rst_n(reset) depending on your reset polarity
    .start(ge_start),
    .sel_opcode(ge_sel_opcode),

    // Connect all input sets for each op
    .p_X_add(add_p_X), .p_Y_add(add_p_Y), .p_Z_add(add_p_Z), .p_T_add(add_p_T),
    .q_1_add(add_q_YplusX), .q_2_add(add_q_YminusX), .q_3_add(add_q_Z), .q_4_add(add_q_T2d),

    .p_X_madd(madd_p_X), .p_Y_madd(madd_p_Y), .p_Z_madd(madd_p_Z), .p_T_madd(madd_p_T),
    .q_1_madd(madd_q_yplusx), .q_2_madd(madd_q_yminusx), .q_3_madd(madd_q_xy2d),

    .p_X_msub(madd_p_X), .p_Y_msub(madd_p_Y), .p_Z_msub(madd_p_Z), .p_T_msub(madd_p_T),
    .q_1_msub(Bi_YplusX), .q_2_msub(Bi_YminusX), .q_3_msub(Bi_Z),

    .p_X_p1p1top2(p1p1_p2_p_X), .p_Y_p1p1top2(p1p1_p2_p_Y), .p_Z_p1p1top2(p1p1_p2_p_Z), .p_T_p1p1top2(p1p1_p2_p_T),

    .p_X_p1p1_to_p3(p1p1_p3_p_X), .p_Y_p1p1_to_p3(p1p1_p3_p_Y), .p_Z_p1p1_to_p3(p1p1_p3_p_Z), .p_T_p1p1_to_p3(p1p1_p3_p_T),

    .p_X_p2_dbl(p2_dbl_p_X), .p_Y_p2_dbl(p2_dbl_p_Y), .p_Z_p2_dbl(p2_dbl_p_Z),

    .p_X_p3_to_cached(cache_p_X), .p_Y_p3_to_cached(cache_p_Y), .p_Z_p3_to_cached(cache_p_Z), .p_T_p3_to_cached(cache_p_T),

    .p_X_sub(sub_p_X), .p_Y_sub(sub_p_Y), .p_Z_sub(sub_p_Z), .p_T_sub(sub_p_T),
    .q_1_sub(sub_q_YplusX), .q_2_sub(sub_q_YminusX), .q_3_sub(sub_q_Z), .q_4_sub(sub_q_T2d),

    // Outputs for each opcode
        .result_x(result_x), .result_y(result_y), .result_z(result_z), .result_t(result_t),
                  .operation_done(operation_done),
             .completed_opcode(completed_opcode)  // Which operation just completed
);
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
// Sequential output assignment for ge_top_mux_wrapper results
always_ff @(posedge clk or negedge reset) begin
    if (!reset) begin
        add_X <= 0; add_Y <= 0; add_Z <= 0; add_T <= 0;
        madd_X <= 0; madd_Y <= 0; madd_Z <= 0; madd_T <= 0;
        msub_X <= 0; msub_Y <= 0; msub_Z <= 0; msub_T <= 0;
        p2_X <= 0; p2_Y <= 0; p2_Z <= 0;
        p3_X <= 0; p3_Y <= 0; p3_Z <= 0; p3_T <= 0;
        p2_dbl_X <= 0; p2_dbl_Y <= 0; p2_dbl_Z <= 0; p2_dbl_T <= 0;
        cache_YplusX <= 0; cache_YminusX <= 0; cache_Z <= 0; cache_T2d <= 0;
        sub_X <= 0; sub_Y <= 0; sub_Z <= 0; sub_T <= 0;
        done_add <= 1'b0;
        done_madd <= 1'b0;
        done_msub <= 1'b0;
        done_p1p1_to_p2 <= 1'b0;
        done_p1p1_to_p3 <= 1'b0;
        done_p2_dbl <= 1'b0;
        done_cache <= 1'b0;
        done_sub <= 1'b0;
    end else begin
        // Default values each cycle
        add_X <= 0; add_Y <= 0; add_Z <= 0; add_T <= 0;
        madd_X <= 0; madd_Y <= 0; madd_Z <= 0; madd_T <= 0;
        msub_X <= 0; msub_Y <= 0; msub_Z <= 0; msub_T <= 0;
        p2_X <= 0; p2_Y <= 0; p2_Z <= 0;
        p3_X <= 0; p3_Y <= 0; p3_Z <= 0; p3_T <= 0;
        p2_dbl_X <= 0; p2_dbl_Y <= 0; p2_dbl_Z <= 0; p2_dbl_T <= 0;
        cache_YplusX <= 0; cache_YminusX <= 0; cache_Z <= 0; cache_T2d <= 0;
        sub_X <= 0; sub_Y <= 0; sub_Z <= 0; sub_T <= 0;
        done_add <= 1'b0;
        done_madd <= 1'b0;
        done_msub <= 1'b0;
        done_p1p1_to_p2 <= 1'b0;
        done_p1p1_to_p3 <= 1'b0;
        done_p2_dbl <= 1'b0;
        done_cache <= 1'b0;
        done_sub <= 1'b0;

        case (completed_opcode)
            GE_ADD: begin
                add_X <= result_x; add_Y <= result_y; add_Z <= result_z; add_T <= result_t;
                done_add <= operation_done;
            end
            GE_MADD: begin
                madd_X <= result_x; madd_Y <= result_y; madd_Z <= result_z; madd_T <= result_t;
                done_madd <= operation_done;
            end
            GE_MSUB: begin
                msub_X <= result_x; msub_Y <= result_y; msub_Z <= result_z; msub_T <= result_t;
                done_msub <= operation_done;
            end
            GE_P1P1TOP2: begin
                p2_X <= result_x; p2_Y <= result_y; p2_Z <= result_z;
                done_p1p1_to_p2 <= operation_done;
            end
            GE_P1P1_TO_P3: begin
                p3_X <= result_x; p3_Y <= result_y; p3_Z <= result_z; p3_T <= result_t;
                done_p1p1_to_p3 <= operation_done;
            end
            GE_P2_DBL: begin
                p2_dbl_X <= result_x; p2_dbl_Y <= result_y; p2_dbl_Z <= result_z; p2_dbl_T <= result_t;
                done_p2_dbl <= operation_done;
            end
            GE_P3_TO_CACHED: begin
                cache_YplusX <= result_x; cache_YminusX <= result_y;
                cache_Z <= result_z; cache_T2d <= result_t;
                done_cache <= operation_done;
            end
            GE_SUB: begin
                sub_X <= result_x; sub_Y <= result_y; sub_Z <= result_z; sub_T <= result_t;
                done_sub <= operation_done;
            end
        endcase
    end
end
*/


//----------------------------------------------------------
// Start Signal Control Logic
//----------------------------------------------------------
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        start_cache <= 1'b0;
       start_dbl <= 1'b0;
       start_p2_dbl <= 1'b0;
       start_add <= 1'b0;
       start_sub <= 1'b0;
       start_madd <= 1'b0;
       start_msub <= 1'b0;
       start_p1p1_to_p3 <= 1'b0;
       start_p1p1_to_p2 <= 1'b0;
    end
    else begin
        // Default all start signals to 0
        start_cache <= 1'b0;
        start_dbl <= 1'b0;
        start_p2_dbl <= 1'b0;
        start_add <= 1'b0;
        start_sub <= 1'b0;
        start_madd <= 1'b0;
        start_msub <= 1'b0;
        start_p1p1_to_p3 <= 1'b0;
        start_p1p1_to_p2 <= 1'b0;
        
        case (state)
            PRECOMP_CONV0: start_cache <= 1'b1;
            PRECOMP_CACHE_1, PRECOMP_CACHE_2, PRECOMP_CACHE_3,
            PRECOMP_CACHE_4, PRECOMP_CACHE_5, PRECOMP_CACHE_6, PRECOMP_CACHE_7:
                start_cache <= 1'b1;
            PRECOMP_DBL, DBL1: start_dbl <= 1'b1;
            DBL: start_p2_dbl <= 1'b1;
            PRECOMP_ADD_1, PRECOMP_ADD_2, PRECOMP_ADD_3, PRECOMP_ADD_4,
            PRECOMP_ADD_5, PRECOMP_ADD_6, PRECOMP_ADD_7: start_add <= 1'b1;
            ADD_SUB_A: begin
                if (aslide[i] > 0) start_add <= 1'b1;
                else if (aslide[i] < 0) start_sub <= 1'b1;
            end
            ADD_SUB_B: begin
                if (bslide[i] > 0) start_madd <= 1'b1;
                else if (bslide[i] < 0) start_msub <= 1'b1;
            end
            PRECOMP_CONV_A2, PRECOMP_CONV_1, PRECOMP_CONV_2, PRECOMP_CONV_3,
            PRECOMP_CONV_4, PRECOMP_CONV_5, PRECOMP_CONV_6, PRECOMP_CONV_7,
            P1P1_TO_P3_A, P1P1_TO_P3_B: start_p1p1_to_p3 <= 1'b1;
            P1P1_TO_P2: start_p1p1_to_p2 <= 1'b1;
        endcase
    end
end



// Control logic for ge_top_mux_wrapper //////////////////////////
always_comb begin
    ge_sel_opcode = 3'd0;
    ge_start = 1'b0;

    case (op_operand)
        1'b0: begin // First operand FSM
            case (state)
                PRECOMP_ADD_1, PRECOMP_ADD_2, PRECOMP_ADD_3, PRECOMP_ADD_4,
                PRECOMP_ADD_5, PRECOMP_ADD_6, PRECOMP_ADD_7: begin
                    ge_sel_opcode = GE_ADD;
                    if (state != prev_state) ge_start = 1'b1;
                end
                ADD_SUB_A: begin
                    if (aslide[i] > 0) begin
                        ge_sel_opcode = GE_ADD;
                        if (state != prev_state) ge_start = 1'b1;
                    end else if (aslide[i] < 0) begin
                        ge_sel_opcode = GE_SUB;
                        if (state != prev_state) ge_start = 1'b1;
                    end
                end
                ADD_SUB_B: begin
                    if (bslide[i] > 0) begin
                        ge_sel_opcode = GE_MADD;
                        if (state != prev_state) ge_start = 1'b1;
                    end else if (bslide[i] < 0) begin
                        ge_sel_opcode = GE_MSUB;
                        if (state != prev_state) ge_start = 1'b1;
                    end
                end
                PRECOMP_CONV0, PRECOMP_CACHE_1, PRECOMP_CACHE_2, PRECOMP_CACHE_3,
                PRECOMP_CACHE_4, PRECOMP_CACHE_5, PRECOMP_CACHE_6, PRECOMP_CACHE_7: begin
                    ge_sel_opcode = GE_P3_TO_CACHED;
                    if (state != prev_state) ge_start = 1'b1;
                end
                // PRECOMP_DBL: begin
                //     ge_sel_opcode = GE_P2_DBL;
                //     ge_start = 1'b1;
                // end
                PRECOMP_CONV_A2, PRECOMP_CONV_1, PRECOMP_CONV_2, PRECOMP_CONV_3,
                PRECOMP_CONV_4, PRECOMP_CONV_5, PRECOMP_CONV_6, PRECOMP_CONV_7,
                P1P1_TO_P3_A, P1P1_TO_P3_B: begin
                    ge_sel_opcode = GE_P1P1_TO_P3;
                    if (state != prev_state) ge_start = 1'b1;
                end
                P1P1_TO_P2: begin
                    ge_sel_opcode = GE_P1P1TOP2;
                    if (state != prev_state) ge_start = 1'b1;
                end
                DBL: begin
                    ge_sel_opcode = GE_P2_DBL;
                    if (state != prev_state) ge_start = 1'b1;
                end
                default: begin
                    ge_sel_opcode = 3'd0;
                    ge_start = 1'b0;
                end
            endcase
        end

        1'b1: begin // Second operand FSM (multbase loop)
            case (state)
                MADD_ODD, MADD_EVEN: begin
                    ge_sel_opcode = GE_MADD;
                    if (state != prev_state) ge_start = 1'b1;
                end
                WAIT_MADD_ODD, WAIT_MADD_EVEN: begin
                    ge_sel_opcode = GE_MADD;
                    ge_start = 1'b0;
                end

                TO_P3_ODD, TO_P3_EVEN, TO_P3_DBL: begin
                    ge_sel_opcode = GE_P1P1_TO_P3;
                    if (state != prev_state) ge_start = 1'b1;
                end
                WAIT_P3_ODD, WAIT_P3_EVEN, WAIT_P3_DBL: begin
                    ge_sel_opcode = GE_P1P1_TO_P3;
                    ge_start = 1'b0;
                end

                DBL1, DBL2, DBL3, DBL4: begin
                    ge_sel_opcode = GE_P2_DBL;
                    if (state != prev_state) ge_start = 1'b1;
                end
                WAIT_DBL1, WAIT_DBL2, WAIT_DBL3, WAIT_DBL4: begin
                    ge_sel_opcode = GE_P2_DBL;
                    ge_start = 1'b0;
                end

                TO_P2_1, TO_P2_2, TO_P2_3: begin
                    ge_sel_opcode = GE_P1P1TOP2;
                    if (state != prev_state) ge_start = 1'b1;
                end
                WAIT_P2_1, WAIT_P2_2, WAIT_P2_3: begin
                    ge_sel_opcode = GE_P1P1TOP2;
                    ge_start = 1'b0;
                end

                default: begin
                    ge_sel_opcode = 3'd0;
                    ge_start = 1'b0;
                end
            endcase
        end

        default: begin
            ge_sel_opcode = 3'd0;
            ge_start = 1'b0;
        end
    endcase
end

///////////////////////////////////////////////////


//----------------------------------------------------------
// State Machine
//----------------------------------------------------------
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        state <= IDLE;
        prev_state <= IDLE;
        r_X <= 320'd0;
        r_Y <= 320'd0; // Initialize Y to 1
        r_Z <= 320'd0; // Initialize Z to 1
        r_T <= 320'd0;
        r_X_next <= 320'd0; r_Y_next <= 320'd0; r_Z_next <= 320'd0; r_T_next <= 320'd0;
        temp_X <= 320'd0; temp_Y <= 320'd0; temp_Z <= 320'd0; temp_T <= 320'd0;
        A2_X <= 320'd0; A2_Y <= 320'd0; A2_Z <= 320'd0; A2_T <= 320'd0;
        i <= 8'd255;
        precomp_idx <= 3'd0;
        aslide_idx <= 4'd0;
        bslide_idx <= 4'd0;
        done <= 1'b0;
        // Clear Ai arrays
        for (int j = 0; j < 8; j++) begin
            Ai_YplusX[j] <= 320'd0;
            Ai_YminusX[j] <= 320'd0;
            Ai_Z[j] <= 320'd0;
            Ai_T2d[j] <= 320'd0;
        end
//----------------------------------------------------------
// reset multbase
//----------------------------------------------------------
            new_i <= 0;
            done_reg <= 0;
            h_X_reg <= 0;
            h_Y_reg <= 0;
            h_Z_reg <= 0;
            h_T_reg <= 0;
            t_yplusx_abs_q <= 0;
            t_yminusx_abs_q <= 0;
            t_xy2d_abs_q <= 0;
            t_yplusx_q <= 0;
            t_yminusx_q <= 0;
            t_xy2d_q <= 0;
            select_negative_q <= 0;
            e_packed <= 0;
            s_X <= 0;
            s_Y <= 0;
            s_Z <= 0;
            s_T <= 0;
            r_X_reg <= 0;
            r_Y_reg <= 0;
            r_Z_reg <= 0;
            r_T_reg <= 0;
 
            for (int j = 0; j < 64; j++) begin
                e[j] <= 0;
            end
    end else  begin
        prev_state <= state;
        case (op_operand)
            1'b0: begin // First operand case
        case (state)
             IDLE: begin
                done <= 1'b0;
                if (start && op_operand == 1'b0) begin
                    // CRITICAL FIX: Reset all state for new computation
                    r_X <= 320'd0;
                    r_Y <= {288'd0, 32'd1}; // Initialize Y to 1
                    r_Z <= {288'd0, 32'd1}; // Initialize Z to 1
                    r_X_next <= 320'd0; 
                    r_Y_next <= 320'd0; 
                    r_Z_next <= 320'd0; 
                    r_T_next <= 320'd0;
                    temp_X <= 320'd0; 
                    temp_Y <= 320'd0; 
                    temp_Z <= 320'd0; 
                    temp_T <= 320'd0;
                    A2_X <= 320'd0; 
                    A2_Y <= 320'd0; 
                    A2_Z <= 320'd0; 
                    A2_T <= 320'd0;
                    i <= 8'd255;
                    precomp_idx <= 3'd0;
                    aslide_idx <= 4'd0;
                    bslide_idx <= 4'd0;
                    
                    // Clear Ai arrays for new computation
                    for (int j = 0; j < 8; j++) begin
                        Ai_YplusX[j] <= 320'd0;
                        Ai_YminusX[j] <= 320'd0;
                        Ai_Z[j] <= 320'd0;
                        Ai_T2d[j] <= 320'd0;
                    end
                    
                    state <= WAIT_SLIDES;
                end
            end
            
            WAIT_SLIDES: begin
                if (slide_a_done && slide_b_done) begin
                    state <= PRECOMP_CONV0;
                end
            end
            
            // Precomputation states
            PRECOMP_CONV0: begin
                if (operation_done) begin
                    Ai_YplusX[0] <= result_x;
                    Ai_YminusX[0] <= result_y;
                    Ai_Z[0] <= result_z;
                    Ai_T2d[0] <= result_t;
                    state <= PRECOMP_DBL;
                end
            end
            
            PRECOMP_DBL: begin
                if (done_dbl) begin
                    temp_X <= dbl_X;
                    temp_Y <= dbl_Y;
                    temp_Z <= dbl_Z;
                    temp_T <= dbl_T;
                    state <= PRECOMP_CONV_A2;
                end
            end
            
            PRECOMP_CONV_A2: begin
                if (operation_done) begin
                    A2_X <= result_x;
                    A2_Y <= result_y;
                    A2_Z <= result_z;
                    A2_T <= result_t;
                    precomp_idx <= 3'd1;
                    state <= PRECOMP_ADD_1;
                end
            end
            
            PRECOMP_ADD_1: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CONV_1;
                end
            end
            
            PRECOMP_CONV_1: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CACHE_1;
                end
            end
            
            PRECOMP_CACHE_1: begin
                if (operation_done) begin
                    Ai_YplusX[1] <= result_x; Ai_YminusX[1] <= result_y;
                    Ai_Z[1] <= result_z; Ai_T2d[1] <= result_t;
                    state <= PRECOMP_ADD_2;
                end
            end
            
            PRECOMP_ADD_2: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CONV_2;
                end
            end
            
            PRECOMP_CONV_2: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CACHE_2;
                end
            end
            
            PRECOMP_CACHE_2: begin
                if (operation_done) begin
                    Ai_YplusX[2] <= result_x; Ai_YminusX[2] <= result_y;
                    Ai_Z[2] <= result_z; Ai_T2d[2] <= result_t;
                    state <= PRECOMP_ADD_3;
                end
            end
            
            PRECOMP_ADD_3: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CONV_3;
                end
            end
            
            PRECOMP_CONV_3: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CACHE_3;
                end
            end
            
            PRECOMP_CACHE_3: begin
                if (operation_done) begin
                    Ai_YplusX[3] <= result_x; Ai_YminusX[3] <= result_y;
                    Ai_Z[3] <= result_z; Ai_T2d[3] <= result_t;
                    state <= PRECOMP_ADD_4;
                end
            end
            
            PRECOMP_ADD_4: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CONV_4;
                end
            end
            
            PRECOMP_CONV_4: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CACHE_4;
                end
            end
            
            PRECOMP_CACHE_4: begin
                if (operation_done) begin
                    Ai_YplusX[4] <= result_x; Ai_YminusX[4] <= result_y;
                    Ai_Z[4] <= result_z; Ai_T2d[4] <= result_t;
                    state <= PRECOMP_ADD_5;
                end
            end
            
            PRECOMP_ADD_5: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CONV_5;
                end
            end
            
            PRECOMP_CONV_5: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CACHE_5;
                end
            end
            
            PRECOMP_CACHE_5: begin
                if (operation_done) begin
                    Ai_YplusX[5] <= result_x; Ai_YminusX[5] <= result_y;
                    Ai_Z[5] <= result_z; Ai_T2d[5] <= result_t;
                    state <= PRECOMP_ADD_6;
                end
            end
            
            PRECOMP_ADD_6: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CONV_6;
                end
            end
            
            PRECOMP_CONV_6: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CACHE_6;
                end
            end
            
            PRECOMP_CACHE_6: begin
                if (operation_done) begin
                    Ai_YplusX[6] <= result_x; Ai_YminusX[6] <= result_y;
                    Ai_Z[6] <= result_z; Ai_T2d[6] <= result_t;
                    state <= PRECOMP_ADD_7;
                end
            end
            
            PRECOMP_ADD_7: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CONV_7;
                end
            end
            
            PRECOMP_CONV_7: begin
                if (operation_done) begin
                    temp_X <= result_x; temp_Y <= result_y; temp_Z <= result_z; temp_T <= result_t;
                    state <= PRECOMP_CACHE_7;
                end
            end
            
            PRECOMP_CACHE_7: begin
                if (operation_done) begin
                    Ai_YplusX[7] <= result_x; Ai_YminusX[7] <= result_y;
                    Ai_Z[7] <= result_z; Ai_T2d[7] <= result_t;
                    state <= FIND_MSB;
                end    
            end

            FIND_MSB: begin
                if (aslide[i] != 0 || bslide[i] != 0) begin
                    state <= DBL;
                end else if (i == 0) begin
                    state <= DONE_ST;
                end else begin
                    i <= i - 1;
                    state <= FIND_MSB;
                end
            end
            
            DBL: begin
                if (operation_done) begin
                    r_X_next <= result_x;
                    r_Y_next <= result_y;
                    r_Z_next <= result_z;
                    r_T_next <= result_t;
                    if (aslide[i] > 0)
                        aslide_idx <= (aslide[i] >> 1);
                    else if (aslide[i] < 0)
                        aslide_idx <= ((-aslide[i]) >> 1);
                    if (bslide[i] > 0)
                        bslide_idx <= (bslide[i] >> 1);
                    else if (bslide[i] < 0)
                        bslide_idx <= ((-bslide[i]) >> 1);
                    state <= P1P1_TO_P3_A;
                end
            end
            
            P1P1_TO_P3_A: begin
                if (operation_done) begin
                    temp_X <= result_x;
                    temp_Y <= result_y;
                    temp_Z <= result_z;
                    temp_T <= result_t;
                    if (aslide[i] != 0) begin
                        state <= ADD_SUB_A;
                    end else begin
                        state <= P1P1_TO_P3_B;
                    end
                end
            end
            
            ADD_SUB_A: begin
                if ((aslide[i] > 0 && operation_done) || (aslide[i] < 0 && operation_done)) begin
                    if (aslide[i] > 0) begin
                        r_X_next <= result_x;
                        r_Y_next <= result_y;
                        r_Z_next <= result_z;
                        r_T_next <= result_t;
                    end else if (aslide[i] < 0) begin
                        r_X_next <= result_x;
                        r_Y_next <= result_y;
                        r_Z_next <= result_z;
                        r_T_next <= result_t;
                    end
                    state <= P1P1_TO_P3_B;
                end
            end
            
            P1P1_TO_P3_B: begin
                if (operation_done) begin
                    temp_X <= result_x;
                    temp_Y <= result_y;
                    temp_Z <= result_z;
                    temp_T <= result_t;
                    if (bslide[i] != 0) begin
                        state <= ADD_SUB_B;
                    end else begin
                        state <= P1P1_TO_P2;
                    end
                end
            end
            
            ADD_SUB_B: begin
                if ((bslide[i] > 0 && operation_done) || (bslide[i] < 0 && operation_done)) begin
                    if (bslide[i] > 0) begin
                        r_X_next <= result_x;
                        r_Y_next <= result_y;
                        r_Z_next <= result_z;
                        r_T_next <= result_t;
                    end else if (bslide[i] < 0) begin
                        r_X_next <= result_x;
                        r_Y_next <= result_y;
                        r_Z_next <= result_z;
                        r_T_next <= result_t;
                    end
                    state <= P1P1_TO_P2;
                end
            end
            
            P1P1_TO_P2: begin
                if (operation_done) begin
                    r_X <= result_x;
                    r_Y <= result_y;
                    r_Z <= result_z;
                    state <= UPDATE;
                end
            end
            
            UPDATE: begin
                if (i == 0) begin
                    state <= DONE_ST;
                end else begin
                    i <= i - 1;
                    state <= DBL;
                end
            end
            
             DONE_ST: begin
                done <= 1'b1;
                // CRITICAL FIX: Stay in DONE_ST until start is deasserted
                if (!start) begin
                    state <= IDLE;
                end
            end

            default: begin
                state <= IDLE;
                // Reset everything in default case
                r_X_next <= 320'd0; r_Y_next <= 320'd0; r_Z_next <= 320'd0; r_T_next <= 320'd0;
                temp_X <= 320'd0; temp_Y <= 320'd0; temp_Z <= 320'd0; temp_T <= 320'd0;
                A2_X <= 320'd0; A2_Y <= 320'd0; A2_Z <= 320'd0; A2_T <= 320'd0;
                i <= 8'd255;
                precomp_idx <= 3'd0;
                aslide_idx <= 4'd0;
                bslide_idx <= 4'd0;
                done <= 1'b0;
                for (int j = 0; j < 8; j++) begin
                    Ai_YplusX[j] <= 320'd0;
                    Ai_YminusX[j] <= 320'd0;
                    Ai_Z[j] <= 320'd0;
                    Ai_T2d[j] <= 320'd0;
                end
            end
        endcase
    end
    1'b1: begin // Second operand case
             r_X <= h_X_reg;
             r_Y <= h_Y_reg;
             r_Z <= h_Z_reg;
             r_T <= h_T_reg;
             done <= done_reg;
        case (state)
                IDLE: begin
                    done_reg <= 0;
                    if (start && op_operand) begin
                        new_i <= 0;
                        state <= DECOMPOSE;
                    end
                    else begin
                        state <= IDLE;
                    end
                end
                
                DECOMPOSE: begin
                    for (int j = 0; j < 64; j++) begin
                        e[j] <= e_decomp[j];
                    end
                    state <= PACK_E;
                end
                
                PACK_E: begin
                    for (int j = 0; j < 64; j++) begin
                        e_packed[511 - 8*j -: 8] <= e[j];
                    end
                    state <= CARRY_PROP;
                end
                
                CARRY_PROP: begin
                    if (carry_prop_done)
                        state <= UNPACK_E;
                    else
                        state <= CARRY_PROP;
                end
                
                UNPACK_E: begin
                    for (int j = 0; j < 64; j++) begin
                        e[j] <= e_prop_result[511 - 8*j -: 8];
                    end
                    state <= INIT_P3_0;
                end
                
                INIT_P3_0: begin
                    h_X_reg <= 320'h0;
                    h_Y_reg <= 320'h1;
                    h_Z_reg <= 320'h1;
                    h_T_reg <= 320'h0;
                    state <= INIT_ODD_LOOP;
                end
                
                INIT_ODD_LOOP: begin
                    new_i <= 1;
                    state <= SELECT_ODD;
                end
                
                SELECT_ODD: begin
                    t_yplusx_abs_q <= t_yplusx;
                    t_yminusx_abs_q <= t_yminusx;
                    t_xy2d_abs_q <= t_xy2d;
                    select_negative_q <= select_negative;
                    state <= SELECT_ODD_APPLY_SIGN;
                end

                SELECT_ODD_APPLY_SIGN: begin
                    t_yplusx_q <= select_negative_q ? t_yminusx_abs_q : t_yplusx_abs_q;
                    t_yminusx_q <= select_negative_q ? t_yplusx_abs_q : t_yminusx_abs_q;
                    t_xy2d_q <= select_negative_q ? t_xy2d_abs_neg : t_xy2d_abs_q;
                    state <= MADD_ODD;
                end
                
                MADD_ODD: begin
                    state <= WAIT_MADD_ODD;
                    start_madd <= 1'b1;
                end
                
                WAIT_MADD_ODD: begin
                    if (operation_done) begin
                        r_X_reg <= result_x;
                        r_Y_reg <= result_y;
                        r_Z_reg <= result_z;
                        r_T_reg <= result_t;
                        state <= TO_P3_ODD;
                    end
                    else begin
                        state <= WAIT_MADD_ODD;
                    end
                end
                
                TO_P3_ODD: begin
                    state <= WAIT_P3_ODD;
                    start_p1p1_to_p3 <= 1'b1;
                end
                
                WAIT_P3_ODD: begin
                    if (operation_done) begin
                        h_X_reg <= result_x;
                        h_Y_reg <= result_y;
                        h_Z_reg <= result_z;
                        h_T_reg <= result_t;
                    state <= NEXT_ODD;
                    end
                    else begin
                        state <= WAIT_P3_ODD;
                    end
                end
                
                NEXT_ODD: begin
                 if (new_i < 63) begin
                     new_i <= new_i + 2;
                     state <= SELECT_ODD;
                 end else begin
                     state <= INIT_DBL;
                 end
             end
                
                INIT_DBL: begin
                   state <= DBL1;
                end
                
                DBL1: begin
                    state <= WAIT_DBL1;
                end
                
                WAIT_DBL1: begin
                    if (done_dbl) begin
                        r_X_reg <= dbl_X;
                        r_Y_reg <= dbl_Y;
                        r_Z_reg <= dbl_Z;
                        r_T_reg <= dbl_T;
                    state <= TO_P2_1;
                    end
                    else begin
                        state <= WAIT_DBL1;
                    end
                end
                
                TO_P2_1: begin
                    state <= WAIT_P2_1;
                     start_p1p1_to_p2 <= 1'b1;
                end
                
                WAIT_P2_1: begin
                    if (operation_done) begin
                        s_X <= result_x;
                        s_Y <= result_y;
                        s_Z <= result_z;
                    state <= DBL2;
                    end
                    else begin
                        state <= WAIT_P2_1;
                    end
                end
                
                DBL2: begin
                    state <= WAIT_DBL2;
                    start_p2_dbl <= 1'b1;
                end
                
                WAIT_DBL2: begin
                    if (operation_done) begin
                        r_X_reg <= result_x;
                        r_Y_reg <= result_y;
                        r_Z_reg <= result_z;
                        r_T_reg <= result_t;
                    state <= TO_P2_2;
                    end
                    else begin
                        state <= WAIT_DBL2;
                    end
                end
                
                TO_P2_2: begin
                    state <= WAIT_P2_2;
                    start_p1p1_to_p2 <= 1'b1;
                end
                
                WAIT_P2_2: begin
                    if (operation_done) begin
                        s_X <= result_x;
                        s_Y <= result_y;
                        s_Z <= result_z;
                    state <= DBL3;
                    end
                    else begin
                        state <= WAIT_P2_2;
                    end
                end
                
                DBL3: begin
                    state <= WAIT_DBL3;
                    start_p2_dbl <= 1'b1;
                end
                
                WAIT_DBL3: begin
                    if (operation_done) begin
                        r_X_reg <= result_x;
                        r_Y_reg <= result_y;
                        r_Z_reg <= result_z;
                        r_T_reg <= result_t;
                    state <= TO_P2_3;
                    end
                    else begin
                        state <= WAIT_DBL3;
                    end
                end
                
                TO_P2_3: begin
                    state <= WAIT_P2_3;
                    start_p1p1_to_p2 <= 1'b1;
                end
                
                WAIT_P2_3: begin
                    if (operation_done) begin
                        s_X <= result_x;
                        s_Y <= result_y;
                        s_Z <= result_z;
                    state <= DBL4;
                    end
                    else begin
                        state <= WAIT_P2_3;
                    end
                end
                
                DBL4: begin
                    state <= WAIT_DBL4;
                    start_p2_dbl <= 1'b1;
                end
                
                WAIT_DBL4: begin
                    if (operation_done) begin
                        r_X_reg <= result_x;
                        r_Y_reg <= result_y;
                        r_Z_reg <= result_z;
                        r_T_reg <= result_t;
                    state <= TO_P3_DBL;
                    end
                    else begin
                        state <= WAIT_DBL4;
                    end
                end
                
                TO_P3_DBL: begin
                    state <= WAIT_P3_DBL;
                    start_p1p1_to_p3 <= 1'b1;
                end
                
                WAIT_P3_DBL: begin
                    if (operation_done) begin
                        h_X_reg <= result_x;
                        h_Y_reg <= result_y;
                        h_Z_reg <= result_z;
                        h_T_reg <= result_t;
                    state <= INIT_EVEN_LOOP;
                    end
                    else begin
                        state <= WAIT_P3_DBL;
                    end
                end
                
                INIT_EVEN_LOOP: begin
                    new_i <= 0;
                    state <= SELECT_EVEN;
                end
                
                SELECT_EVEN: begin
                    t_yplusx_abs_q <= t_yplusx;
                    t_yminusx_abs_q <= t_yminusx;
                    t_xy2d_abs_q <= t_xy2d;
                    select_negative_q <= select_negative;
                    state <= SELECT_EVEN_APPLY_SIGN;
                end

                SELECT_EVEN_APPLY_SIGN: begin
                    t_yplusx_q <= select_negative_q ? t_yminusx_abs_q : t_yplusx_abs_q;
                    t_yminusx_q <= select_negative_q ? t_yplusx_abs_q : t_yminusx_abs_q;
                    t_xy2d_q <= select_negative_q ? t_xy2d_abs_neg : t_xy2d_abs_q;
                    state <= MADD_EVEN;
                end
                
                MADD_EVEN: begin
                    state <= WAIT_MADD_EVEN;
                    start_madd <= 1'b1;
                end
                
                WAIT_MADD_EVEN: begin
                    if (operation_done) begin
                        r_X_reg <= result_x;
                        r_Y_reg <= result_y;
                        r_Z_reg <= result_z;
                        r_T_reg <= result_t;
                    state <= TO_P3_EVEN;
                    end
                    else begin
                        state <= WAIT_MADD_EVEN;
                    end
                end
                
                TO_P3_EVEN: begin
                    state <= WAIT_P3_EVEN;
                    start_p1p1_to_p3 <= 1'b1;
                end
                
                WAIT_P3_EVEN: begin
                    if (operation_done) begin
                        h_X_reg <= result_x;
                        h_Y_reg <= result_y;
                        h_Z_reg <= result_z;
                        h_T_reg <= result_t;
                    state <= NEXT_EVEN;
                    end
                    else begin
                        state <= WAIT_P3_EVEN;
                    end
                end
                
                NEXT_EVEN: begin
                if (new_i < 62) begin
                    new_i <= new_i + 2;
                    state <= SELECT_EVEN;
                end else begin
                    state <= DONE;
                end
            end
                
                DONE: begin
                    done_reg <= 1;
                    state <= IDLE;
                end
          endcase
        end
      endcase
    end
end



endmodule
