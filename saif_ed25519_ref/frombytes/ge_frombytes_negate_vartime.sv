module ge_frombytes_negate_vartime (
    input clk,
    input reset,
    input start,
    input [255:0] s,
    output reg [319:0] h_X, h_Y, h_Z, h_T,
    output reg error,
    output reg done
);

// Field element constants
localparam [319:0] d = {-32'd12055116, -32'd18696448, -32'd3247719, -32'd6275908, -32'd8787816, 32'd114729, 32'd6949391, -32'd15372611, 32'd13857413, -32'd10913610};
localparam [319:0] sqrtm1 = {32'd11406482, 32'd326686, -32'd2005654, -32'd25146209, -32'd272473, 32'd12389472, 32'd3500415, 32'd9377950, -32'd7943725, -32'd32595792};

// State machine parameters
typedef enum logic [5:0] {
    IDLE, LOAD_Y, SET_Z, 
    // Square operations
    START_SQUARE_Y, WAIT_SQUARE_Y,
    START_MUL_U_D, WAIT_MUL_U_D,
    SUB_U_Z, ADD_V_Z,
    START_SQUARE_V, WAIT_SQUARE_V,
    START_MUL_V3_V, WAIT_MUL_V3_V,
    START_SQUARE_V3, WAIT_SQUARE_V3,
    START_MUL_X_V, WAIT_MUL_X_V,
    START_MUL_X_U, WAIT_MUL_X_U,
    // Power operation
    START_POW, WAIT_POW, 
    START_MUL_X_V3, WAIT_MUL_X_V3,
    START_MUL_X_U2, WAIT_MUL_X_U2,
    START_SQUARE_X, WAIT_SQUARE_X,
    START_MUL_VXX_V, WAIT_MUL_VXX_V,
    SUB_CHECK, ADD_CHECK,
    // Check operations
    CHECK_NZ, CHECK_NZ2, CHECK_SIGN,
    START_MUL_X_SQRTM1, WAIT_MUL_X_SQRTM1,
    // Negation and completion
    NEG_X, 
    START_MUL_T, WAIT_MUL_T,
    DONE
} state_t;
state_t state;

// Intermediate registers
reg [319:0] u, v, v3, vxx, check;
reg sq_start, mul_start, pow_start;
reg [255:0] current_s;

//------------------------------
// Module Instances (now sequential)
//------------------------------

// fe_frombytes (still combinatorial)
wire [319:0] fe_frombytes_out;
fe_frombytes frombytes_unit (.s(current_s), .h(fe_frombytes_out));

// Sequential fe_sq
wire [319:0] sq_out;
reg [319:0] sq_in;  // Input set in state machine

wire sq_done;
fe_sq sq_unit (
    .clk(clk),
    .reset(reset),
    .start(sq_start),
    .f(sq_in),
    .h(sq_out),
    .done(sq_done)
);

// Sequential fe_mul
wire [319:0] mul_out;
reg [319:0] mul_in_a, mul_in_b;  // Inputs set in state machine

wire mul_done;
fe_mul mul_unit (
    .clk(clk),
    .reset(reset),
    .start(mul_start),
    .f(mul_in_a),
    .g(mul_in_b),
    .h(mul_out),
    .done(mul_done)
);

// fe_sub (still combinatorial)
// Muxes for add/sub inputs (combinatorial)
reg [319:0] sub_in_a, sub_in_b;
reg [319:0] add_in_a, add_in_b;

wire [319:0] sub_out;
fe_sub sub_unit (.f(sub_in_a), .g(sub_in_b), .h(sub_out));

// fe_add (still combinatorial)
wire [319:0] add_out;
fe_add add_unit (.f(add_in_a), .g(add_in_b), .h(add_out));

// fe_neg (still combinatorial)
wire [319:0] neg_X_out;
fe_neg neg_X (.f(h_X), .h(neg_X_out));

// Sequential fe_pow (already sequential)
wire [319:0] fe_pow_out;
wire pow_done;
fe_pow pow_unit (
    .clk(clk),
    .reset(reset),
    .start(pow_start),
    .z(h_X),
    .out(fe_pow_out),
    .done(pow_done)
);

// fe_isnonzero & fe_isnegative (still combinatorial)
wire fe_isnonzero, fe_isnegative;
fe_isnonzero isnonzero_unit (.f_in(check), .nz(fe_isnonzero));
fe_isnegative isneg_unit (.h(h_X), .is_negative(fe_isnegative));


always @(*) begin
    // Default assignments
    sub_in_a = 0;
    sub_in_b = 0;
    add_in_a = 0;
    add_in_b = 0;
    
    case (state)
        SUB_U_Z:   begin sub_in_a = u; sub_in_b = h_Z; end
        SUB_CHECK: begin sub_in_a = vxx; sub_in_b = u; end
        ADD_V_Z:   begin add_in_a = v; add_in_b = h_Z; end
        ADD_CHECK: begin add_in_a = vxx; add_in_b = u; end
    endcase
end

//------------------------------
// State Machine
//------------------------------
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        state <= IDLE;
        h_X <= 0; h_Y <= 0; h_Z <= 0; h_T <= 0;
        u <= 0; v <= 0; v3 <= 0; vxx <= 0; check <= 0;
        error <= 0; done <= 0; 
        sq_start <= 0; mul_start <= 0; pow_start <= 0;
        current_s <= 0;
    end else begin
        // Default control signals
        sq_start <= 0;
        mul_start <= 0;
        pow_start <= 0;
        
        case (state)
            IDLE: begin
                done <= 0;
                error <= 0;
                if (start) begin
                    current_s <= s;
                    u <= 0; v <= 0; v3 <= 0; vxx <= 0; check <= 0;
                    h_X <= 0; h_Z <= 0; h_T <= 0;
                    state <= LOAD_Y;
                end
            end
             
            LOAD_Y: begin
                h_Y <= fe_frombytes_out;
                state <= SET_Z;
            end

            SET_Z: begin
                h_Z <= 320'h1;
                state <= START_SQUARE_Y;
            end

            START_SQUARE_Y: begin
                sq_in <= h_Y;
                sq_start <= 1;
                state <= WAIT_SQUARE_Y;
            end
            WAIT_SQUARE_Y: begin
                if (sq_done) begin
                    u <= sq_out;  // u = Y^2
                    state <= START_MUL_U_D;
                end
            end

            START_MUL_U_D: begin
                mul_in_a <= u;
                mul_in_b <= d;
                mul_start <= 1;
                state <= WAIT_MUL_U_D;
            end
            WAIT_MUL_U_D: begin
                if (mul_done) begin
                    v <= mul_out;  // v = u*d
                    state <= SUB_U_Z;
                end
            end

            SUB_U_Z: begin
                u <= sub_out;  // u = u - Z
                state <= ADD_V_Z;
            end

            ADD_V_Z: begin
                v <= add_out;  // v = v + Z
                state <= START_SQUARE_V;
            end

            START_SQUARE_V: begin
                sq_in <= v;
                sq_start <= 1;
                state <= WAIT_SQUARE_V;
            end
            WAIT_SQUARE_V: begin
                if (sq_done) begin
                    v3 <= sq_out;  // v3 = v^2
                    state <= START_MUL_V3_V;
                end
            end

            START_MUL_V3_V: begin
                mul_in_a <= v3;
                mul_in_b <= v;
                mul_start <= 1;
                state <= WAIT_MUL_V3_V;
            end
            WAIT_MUL_V3_V: begin
                if (mul_done) begin
                    v3 <= mul_out;  // v3 = v3*v
                    state <= START_SQUARE_V3;
                end
            end

            START_SQUARE_V3: begin
                sq_in <= v3;
                sq_start <= 1;
                state <= WAIT_SQUARE_V3;
            end
            WAIT_SQUARE_V3: begin
                if (sq_done) begin
                    h_X <= sq_out;  // X = v3^2
                    state <= START_MUL_X_V;
                end
            end

            START_MUL_X_V: begin
                mul_in_a <= h_X;
                mul_in_b <= v;
                mul_start <= 1;
                state <= WAIT_MUL_X_V;
            end
            WAIT_MUL_X_V: begin
                if (mul_done) begin
                    h_X <= mul_out;  // X = X*v
                    state <= START_MUL_X_U;
                end
            end

            START_MUL_X_U: begin
                mul_in_a <= h_X;
                mul_in_b <= u;
                mul_start <= 1;
                state <= WAIT_MUL_X_U;
            end
            WAIT_MUL_X_U: begin
                if (mul_done) begin
                    h_X <= mul_out;  // X = X*u
                    pow_start <= 1;
                    state <= START_POW;
                end
            end

            START_POW: begin
                // pow_start was set in previous state
                state <= WAIT_POW;
            end
            WAIT_POW: begin
                if (pow_done) begin
                    h_X <= fe_pow_out;
                    state <= START_MUL_X_V3;
                end
            end

            START_MUL_X_V3: begin
                mul_in_a <= h_X;
                mul_in_b <= v3;
                mul_start <= 1;
                state <= WAIT_MUL_X_V3;
            end
            WAIT_MUL_X_V3: begin
                if (mul_done) begin
                    h_X <= mul_out;  // X = X*v3
                    state <= START_MUL_X_U2;
                end
            end

            START_MUL_X_U2: begin
                mul_in_a <= h_X;
                mul_in_b <= u;
                mul_start <= 1;
                state <= WAIT_MUL_X_U2;
            end
            WAIT_MUL_X_U2: begin
                if (mul_done) begin
                    h_X <= mul_out;  // X = X*u
                    state <= START_SQUARE_X;
                end
            end

            START_SQUARE_X: begin
                sq_in <= h_X;
                sq_start <= 1;
                state <= WAIT_SQUARE_X;
            end
            WAIT_SQUARE_X: begin
                if (sq_done) begin
                    vxx <= sq_out;  // vxx = X^2
                    state <= START_MUL_VXX_V;
                end
            end

            START_MUL_VXX_V: begin
                mul_in_a <= vxx;
                mul_in_b <= v;
                mul_start <= 1;
                state <= WAIT_MUL_VXX_V;
            end
            WAIT_MUL_VXX_V: begin
                if (mul_done) begin
                    vxx <= mul_out;  // vxx = vxx*v
                    state <= SUB_CHECK;
                end
            end

            SUB_CHECK: begin
                check <= sub_out;  // check = vxx - u
                state <= CHECK_NZ;
            end

            CHECK_NZ: begin
                if (fe_isnonzero) begin
                    state <= ADD_CHECK;
                end else begin
                    state <= CHECK_SIGN;
                end
            end

            ADD_CHECK: begin
                check <= add_out;  // check = vxx + u
                state <= CHECK_NZ2;
            end

            CHECK_NZ2: begin
                if (fe_isnonzero) begin
                    error <= 1;
                    state <= DONE;
                end else begin
                    state <= START_MUL_X_SQRTM1;
                end
            end

            START_MUL_X_SQRTM1: begin
                mul_in_a <= h_X;
                mul_in_b <= sqrtm1;
                mul_start <= 1;
                state <= WAIT_MUL_X_SQRTM1;
            end
            WAIT_MUL_X_SQRTM1: begin
                if (mul_done) begin
                    h_X <= mul_out;  // X = X*sqrtm1
                    state <= CHECK_SIGN;
                end
            end

            CHECK_SIGN: begin
                if (fe_isnegative == s[255]) begin  // s[255] is MSB
                    state <= NEG_X;
                end else begin
                    state <= START_MUL_T;
                end
            end

            NEG_X: begin
                h_X <= neg_X_out;  // X = -X
                state <= START_MUL_T;
            end

            START_MUL_T: begin
                mul_in_a <= h_X;
                mul_in_b <= h_Y;
                mul_start <= 1;
                state <= WAIT_MUL_T;
            end
            WAIT_MUL_T: begin
                if (mul_done) begin
                    h_T <= mul_out;  // T = X*Y
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end
endmodule