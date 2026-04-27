module fe_sq (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  signed [319:0] f,
    output reg signed [319:0] h,
    output reg done
);

    // State machine states
    localparam [2:0] 
        IDLE              = 3'b000,
        PRECOMPUTE        = 3'b001,
        MULT_ACC_OPERANDS = 3'b010,
        MULT_ACC_PRODUCTS = 3'b011,
        MULT_ACC_SUM      = 3'b100,
        CARRY_PROP        = 3'b101,
        FINISH            = 3'b110;

    reg [2:0] state;
    reg [3:0] precomp_count;  // 0-12 (13 cycles)
    reg [7:0] mult_acc_count; // 0-109 (110 cycles)
    reg [3:0] target_H_index_reg; // Registered target index

    // Carry state (similar to fe_mul)
    reg [3:0] carry_stage;      // 0..11
    reg [1:0] carry_substep;    // 0: calc, 1: add, 2: sub

    // Latch input field element
    reg signed [319:0] f_reg;
    wire signed [31:0] f0 = f_reg[31:0];
    wire signed [31:0] f1 = f_reg[63:32];
    wire signed [31:0] f2 = f_reg[95:64];
    wire signed [31:0] f3 = f_reg[127:96];
    wire signed [31:0] f4 = f_reg[159:128];
    wire signed [31:0] f5 = f_reg[191:160];
    wire signed [31:0] f6 = f_reg[223:192];
    wire signed [31:0] f7 = f_reg[255:224];
    wire signed [31:0] f8 = f_reg[287:256];
    wire signed [31:0] f9 = f_reg[319:288];

    // Precomputed terms
    reg signed [31:0] f0_2, f1_2, f2_2, f3_2, f4_2, f5_2, f6_2, f7_2;
    reg signed [31:0] f5_38, f6_19, f7_38, f8_19, f9_38;
    reg signed [63:0] carry_temp;
    
    // Accumulator array
    reg signed [63:0] H [0:9];
    reg signed [63:0] mul_product_reg;
    reg signed [31:0] mul_a, mul_b;
    reg [3:0] next_target_H_index;
    logic signed [31:0] sum_a0, sum_a1, sum_a2, sum_a3, sum_a4, sum_a5;
    logic signed [31:0] sum_b0, sum_b1, sum_b2, sum_b3, sum_b4, sum_b5;
    logic signed [63:0] square_term [0:5];
    reg signed [31:0] square_a_q [0:5];
    reg signed [31:0] square_b_q [0:5];
    reg signed [63:0] square_term_q [0:5];
    logic signed [63:0] square_sum;

    // Multiplier (combinational)
    wire signed [63:0] mul_product = mul_a * mul_b;

    assign square_term[0] = square_a_q[0] * square_b_q[0];
    assign square_term[1] = square_a_q[1] * square_b_q[1];
    assign square_term[2] = square_a_q[2] * square_b_q[2];
    assign square_term[3] = square_a_q[3] * square_b_q[3];
    assign square_term[4] = square_a_q[4] * square_b_q[4];
    assign square_term[5] = square_a_q[5] * square_b_q[5];

    always_comb begin
        square_sum = 64'sd0;
        for (int term_idx = 0; term_idx < 6; term_idx++) begin
            square_sum += square_term_q[term_idx];
        end
    end

    always_comb begin
        sum_a0 = 0; sum_a1 = 0; sum_a2 = 0; sum_a3 = 0; sum_a4 = 0; sum_a5 = 0;
        sum_b0 = 0; sum_b1 = 0; sum_b2 = 0; sum_b3 = 0; sum_b4 = 0; sum_b5 = 0;
        case (mult_acc_count[3:0])
            4'd0: begin
                sum_a0 = f0;   sum_b0 = f0;
                sum_a1 = f1_2; sum_b1 = f9_38;
                sum_a2 = f2_2; sum_b2 = f8_19;
                sum_a3 = f3_2; sum_b3 = f7_38;
                sum_a4 = f4_2; sum_b4 = f6_19;
                sum_a5 = f5;   sum_b5 = f5_38;
            end
            4'd1: begin
                sum_a0 = f0_2; sum_b0 = f1;
                sum_a1 = f2;   sum_b1 = f9_38;
                sum_a2 = f3_2; sum_b2 = f8_19;
                sum_a3 = f4;   sum_b3 = f7_38;
                sum_a4 = f5_2; sum_b4 = f6_19;
            end
            4'd2: begin
                sum_a0 = f0_2; sum_b0 = f2;
                sum_a1 = f1_2; sum_b1 = f1;
                sum_a2 = f3_2; sum_b2 = f9_38;
                sum_a3 = f4_2; sum_b3 = f8_19;
                sum_a4 = f5_2; sum_b4 = f7_38;
                sum_a5 = f6;   sum_b5 = f6_19;
            end
            4'd3: begin
                sum_a0 = f0_2; sum_b0 = f3;
                sum_a1 = f1_2; sum_b1 = f2;
                sum_a2 = f4;   sum_b2 = f9_38;
                sum_a3 = f5_2; sum_b3 = f8_19;
                sum_a4 = f6;   sum_b4 = f7_38;
            end
            4'd4: begin
                sum_a0 = f0_2; sum_b0 = f4;
                sum_a1 = f1_2; sum_b1 = f3_2;
                sum_a2 = f2;   sum_b2 = f2;
                sum_a3 = f5_2; sum_b3 = f9_38;
                sum_a4 = f6_2; sum_b4 = f8_19;
                sum_a5 = f7;   sum_b5 = f7_38;
            end
            4'd5: begin
                sum_a0 = f0_2; sum_b0 = f5;
                sum_a1 = f1_2; sum_b1 = f4;
                sum_a2 = f2_2; sum_b2 = f3;
                sum_a3 = f6;   sum_b3 = f9_38;
                sum_a4 = f7_2; sum_b4 = f8_19;
            end
            4'd6: begin
                sum_a0 = f0_2; sum_b0 = f6;
                sum_a1 = f1_2; sum_b1 = f5_2;
                sum_a2 = f2_2; sum_b2 = f4;
                sum_a3 = f3_2; sum_b3 = f3;
                sum_a4 = f7_2; sum_b4 = f9_38;
                sum_a5 = f8;   sum_b5 = f8_19;
            end
            4'd7: begin
                sum_a0 = f0_2; sum_b0 = f7;
                sum_a1 = f1_2; sum_b1 = f6;
                sum_a2 = f2_2; sum_b2 = f5;
                sum_a3 = f3_2; sum_b3 = f4;
                sum_a4 = f8;   sum_b4 = f9_38;
            end
            4'd8: begin
                sum_a0 = f0_2; sum_b0 = f8;
                sum_a1 = f1_2; sum_b1 = f7_2;
                sum_a2 = f2_2; sum_b2 = f6;
                sum_a3 = f3_2; sum_b3 = f5_2;
                sum_a4 = f4;   sum_b4 = f4;
                sum_a5 = f9;   sum_b5 = f9_38;
            end
            4'd9: begin
                sum_a0 = f0_2; sum_b0 = f9;
                sum_a1 = f1_2; sum_b1 = f8;
                sum_a2 = f2_2; sum_b2 = f7;
                sum_a3 = f3_2; sum_b3 = f6;
                sum_a4 = f4_2; sum_b4 = f5;
            end
        endcase
    end

    // SHL64 function for compatibility
    function signed [63:0] SHL64;
        input signed [63:0] s;
        input [5:0] lshift;
        reg [63:0] unsigned_s;
        begin
            unsigned_s = s;
            SHL64 = (unsigned_s << lshift);
        end
    endfunction

    function signed [31:0] MUL19_32;
        input signed [31:0] x;
        begin
            MUL19_32 = (x <<< 4) + (x <<< 1) + x;
        end
    endfunction

    function signed [31:0] MUL38_32;
        input signed [31:0] x;
        begin
            MUL38_32 = (x <<< 5) + (x <<< 2) + (x <<< 1);
        end
    endfunction

    // Carry propagation parameters (same pattern as fe_mul)
    reg [3:0] src_idx, dst_idx;
    reg [5:0] shift_amt;
    reg       is_final_stage;
    reg       is_mult19;

    always @(*) begin
        // Default values
        src_idx = 0;
        dst_idx = 0;
        shift_amt = 0;
        is_final_stage = 0;
        is_mult19 = 0;
        case (carry_stage)
            0:  begin src_idx = 0; dst_idx = 1; shift_amt = 26; is_mult19 = 0; end
            1:  begin src_idx = 4; dst_idx = 5; shift_amt = 26; is_mult19 = 0; end
            2:  begin src_idx = 1; dst_idx = 2; shift_amt = 25; is_mult19 = 0; end
            3:  begin src_idx = 5; dst_idx = 6; shift_amt = 25; is_mult19 = 0; end
            4:  begin src_idx = 2; dst_idx = 3; shift_amt = 26; is_mult19 = 0; end
            5:  begin src_idx = 6; dst_idx = 7; shift_amt = 26; is_mult19 = 0; end
            6:  begin src_idx = 3; dst_idx = 4; shift_amt = 25; is_mult19 = 0; end
            7:  begin src_idx = 7; dst_idx = 8; shift_amt = 25; is_mult19 = 0; end
            8:  begin src_idx = 4; dst_idx = 5; shift_amt = 26; is_mult19 = 0; end
            9:  begin src_idx = 8; dst_idx = 9; shift_amt = 26; is_mult19 = 0; end
            10: begin src_idx = 9; dst_idx = 0; shift_amt = 25; is_mult19 = 1; end
            11: begin src_idx = 0; dst_idx = 1; shift_amt = 26; is_mult19 = 0; is_final_stage = 1; end
        endcase
    end

    // State machine and main computation
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            done <= 0;
            precomp_count <= 0;
            mult_acc_count <= 0;
            carry_stage <= 0;
            carry_substep <= 0;
            H[0] <= 0; H[1] <= 0; H[2] <= 0; H[3] <= 0; H[4] <= 0;
            H[5] <= 0; H[6] <= 0; H[7] <= 0; H[8] <= 0; H[9] <= 0;
            f_reg <= 0;
            target_H_index_reg <= 0;
            carry_temp <= 0;
            for (int j = 0; j < 6; j++) begin
                square_a_q[j] <= 0;
                square_b_q[j] <= 0;
                square_term_q[j] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        f_reg <= f;
                        state <= PRECOMPUTE;
                        precomp_count <= 0;
                        carry_stage <= 0;
                        carry_substep <= 0;
                        H[0] <= 0; H[1] <= 0; H[2] <= 0; H[3] <= 0; H[4] <= 0;
                        H[5] <= 0; H[6] <= 0; H[7] <= 0; H[8] <= 0; H[9] <= 0;
                    end
                end

                PRECOMPUTE: begin
                    case (precomp_count)
                        0: f0_2 <= f0 <<< 1;
                        1: f1_2 <= f1 <<< 1;
                        2: f2_2 <= f2 <<< 1;
                        3: f3_2 <= f3 <<< 1;
                        4: f4_2 <= f4 <<< 1;
                        5: f5_2 <= f5 <<< 1;
                        6: f6_2 <= f6 <<< 1;
                        7: f7_2 <= f7 <<< 1;
                        8: f5_38 <= MUL38_32(f5);
                        9: f6_19 <= MUL19_32(f6);
                        10: f7_38 <= MUL38_32(f7);
                        11: f8_19 <= MUL19_32(f8);
                        12: f9_38 <= MUL38_32(f9);
                    endcase
                    precomp_count <= precomp_count + 1;
                    if (precomp_count == 12) begin
                        state <= MULT_ACC_OPERANDS;
                        mult_acc_count <= 0;
                    end
                end

                MULT_ACC_OPERANDS: begin
                    square_a_q[0] <= sum_a0; square_b_q[0] <= sum_b0;
                    square_a_q[1] <= sum_a1; square_b_q[1] <= sum_b1;
                    square_a_q[2] <= sum_a2; square_b_q[2] <= sum_b2;
                    square_a_q[3] <= sum_a3; square_b_q[3] <= sum_b3;
                    square_a_q[4] <= sum_a4; square_b_q[4] <= sum_b4;
                    square_a_q[5] <= sum_a5; square_b_q[5] <= sum_b5;
                    state <= MULT_ACC_PRODUCTS;
                end

                MULT_ACC_PRODUCTS: begin
                    for (int j = 0; j < 6; j++) square_term_q[j] <= square_term[j];
                    state <= MULT_ACC_SUM;
                end

                MULT_ACC_SUM: begin
                    H[mult_acc_count[3:0]] <= square_sum;
                    mult_acc_count <= mult_acc_count + 1;
                    if (mult_acc_count == 8'd9) begin
                        state <= CARRY_PROP;
                        carry_stage <= 0;
                        carry_substep <= 0;
                    end else begin
                        state <= MULT_ACC_OPERANDS;
                    end
                end

                CARRY_PROP: begin
                    logic signed [63:0] t [0:9];
                    logic signed [63:0] c;

                    for (int j = 0; j < 10; j++) t[j] = H[j];

                    case (carry_stage)
                        4'd0: begin
                            c = (t[0] + (64'sd1 << 25)) >>> 26; t[1] = t[1] + c;      t[0] = t[0] - SHL64(c, 6'd26);
                            c = (t[4] + (64'sd1 << 25)) >>> 26; t[5] = t[5] + c;      t[4] = t[4] - SHL64(c, 6'd26);
                        end
                        4'd1: begin
                            c = (t[1] + (64'sd1 << 24)) >>> 25; t[2] = t[2] + c;      t[1] = t[1] - SHL64(c, 6'd25);
                            c = (t[5] + (64'sd1 << 24)) >>> 25; t[6] = t[6] + c;      t[5] = t[5] - SHL64(c, 6'd25);
                        end
                        4'd2: begin
                            c = (t[2] + (64'sd1 << 25)) >>> 26; t[3] = t[3] + c;      t[2] = t[2] - SHL64(c, 6'd26);
                            c = (t[6] + (64'sd1 << 25)) >>> 26; t[7] = t[7] + c;      t[6] = t[6] - SHL64(c, 6'd26);
                        end
                        4'd3: begin
                            c = (t[3] + (64'sd1 << 24)) >>> 25; t[4] = t[4] + c;      t[3] = t[3] - SHL64(c, 6'd25);
                            c = (t[7] + (64'sd1 << 24)) >>> 25; t[8] = t[8] + c;      t[7] = t[7] - SHL64(c, 6'd25);
                        end
                        4'd4: begin
                            c = (t[4] + (64'sd1 << 25)) >>> 26; t[5] = t[5] + c;      t[4] = t[4] - SHL64(c, 6'd26);
                            c = (t[8] + (64'sd1 << 25)) >>> 26; t[9] = t[9] + c;      t[8] = t[8] - SHL64(c, 6'd26);
                        end
                        4'd5: begin
                            c = (t[9] + (64'sd1 << 24)) >>> 25; t[0] = t[0] + c * 19; t[9] = t[9] - SHL64(c, 6'd25);
                        end
                        4'd6: begin
                            c = (t[0] + (64'sd1 << 25)) >>> 26; t[1] = t[1] + c;      t[0] = t[0] - SHL64(c, 6'd26);
                        end
                    endcase

                    for (int j = 0; j < 10; j++) H[j] <= t[j];
                    if (carry_stage == 4'd6) begin
                        carry_stage <= 0;
                        state <= FINISH;
                    end else begin
                        carry_stage <= carry_stage + 1;
                    end
                    carry_substep <= 0;
                end

                FINISH: begin
                    h <= {H[9][31:0], H[8][31:0], H[7][31:0], H[6][31:0], H[5][31:0],
                          H[4][31:0], H[3][31:0], H[2][31:0], H[1][31:0], H[0][31:0]};
                    done <= 1;
                    if (~start) state <= IDLE;
                end
            endcase
        end
    end

    // Multiplier input selection and target index
    always @(*) begin
        mul_a = 0;
        mul_b = 0;
        next_target_H_index = 0;
        case (state)
            PRECOMPUTE: begin
                case (precomp_count)
                    0: begin mul_a = 2;     mul_b = f0; end
                    1: begin mul_a = 2;     mul_b = f1; end
                    2: begin mul_a = 2;     mul_b = f2; end
                    3: begin mul_a = 2;     mul_b = f3; end
                    4: begin mul_a = 2;     mul_b = f4; end
                    5: begin mul_a = 2;     mul_b = f5; end
                    6: begin mul_a = 2;     mul_b = f6; end
                    7: begin mul_a = 2;     mul_b = f7; end
                    8: begin mul_a = 38;    mul_b = f5; end
                    9: begin mul_a = 19;    mul_b = f6; end
                    10: begin mul_a = 38;   mul_b = f7; end
                    11: begin mul_a = 19;   mul_b = f8; end
                    12: begin mul_a = 38;   mul_b = f9; end
                endcase
            end
            endcase
        end

endmodule
