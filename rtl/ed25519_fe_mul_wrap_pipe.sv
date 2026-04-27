module ed25519_fe_mul_wrap_pipe (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  signed [319:0] f,
    input  signed [319:0] g,
    output reg signed [319:0] h,
    output reg done
);

    localparam [3:0] IDLE               = 4'd0,
                     PRECOMPUTE_G19_0   = 4'd1,
                     PRECOMPUTE_G19_1   = 4'd2,
                     MULTIPLY_OPERANDS  = 4'd3,
                     MULTIPLY_PRODUCTS0 = 4'd4,
                     MULTIPLY_PRODUCTS1 = 4'd5,
                     MULTIPLY_PRODUCTS2 = 4'd6,
                     MULTIPLY_SUM0      = 4'd7,
                     MULTIPLY_SUM1      = 4'd8,
                     MULTIPLY_SUM2      = 4'd9,
                     CARRY_PROP         = 4'd10,
                     FINISHED           = 4'd11;

    reg [3:0] state, next_state;
    reg [3:0] counter;
    reg [3:0] carry_stage;

    wire signed [31:0] f_elem [0:9];
    wire signed [31:0] g_elem [0:9];
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : extract_elements
            assign f_elem[i] = f[32*i+31:32*i];
            assign g_elem[i] = g[32*i+31:32*i];
        end
    endgenerate

    reg signed [63:0] h_temp [0:9];
    reg signed [63:0] carry0_temp;
    reg signed [63:0] carry1_temp;
    reg signed [63:0] carry19_temp;
    reg signed [31:0] f_elem_q [0:9];
    reg signed [31:0] g_elem_q [0:9];
    reg signed [31:0] g19_part_q [0:9];
    reg signed [31:0] g19_elem_q [0:9];

    logic signed [33:0] product_ll [0:9];
    logic signed [32:0] product_lh [0:9];
    logic signed [32:0] product_hl [0:9];
    logic signed [31:0] product_hh [0:9];
    logic signed [63:0] product_sum0;
    logic signed [63:0] product_sum1;
    logic signed [63:0] product_sum2;
    logic signed [63:0] product_sum3;
    logic signed [31:0] product_a [0:9];
    logic signed [31:0] product_b [0:9];
    reg signed [31:0] product_a_q [0:9];
    reg signed [31:0] product_b_q [0:9];
    reg signed [33:0] product_ll_q [0:9];
    reg signed [32:0] product_lh_q [0:9];
    reg signed [32:0] product_hl_q [0:9];
    reg signed [31:0] product_hh_q [0:9];
    reg signed [33:0] product_mid_q [0:9];
    reg signed [63:0] product_term_q [0:9];
    reg signed [63:0] product_sum0_q;
    reg signed [63:0] product_sum1_q;
    reg signed [63:0] product_sum2_q;
    reg signed [63:0] product_sum3_q;
    reg signed [63:0] product_sum_lo_q;
    reg signed [63:0] product_sum_hi_q;

    always_comb begin
        for (int term_idx = 0; term_idx < 10; term_idx++) begin
            logic signed [31:0] f_operand;
            logic signed [31:0] g_operand;
            logic [4:0] idx_diff;
            logic use_g19;
            logic [3:0] g_index;

            f_operand = ((counter[0] == 1'b0) && (term_idx[0] == 1'b1)) ?
                        (f_elem_q[term_idx] << 1) : f_elem_q[term_idx];
            idx_diff = {1'b0, counter} - {1'b0, term_idx[3:0]};
            use_g19 = (idx_diff[4] == 1'b1);
            g_index = use_g19 ? (idx_diff[3:0] + 4'd10) : idx_diff[3:0];
            g_operand = use_g19 ? g19_elem_q[g_index] : g_elem_q[g_index];
            product_a[term_idx] = f_operand;
            product_b[term_idx] = g_operand;
        end
    end

    generate
        for (i = 0; i < 10; i = i + 1) begin : multiply_terms
            wire signed [15:0] a_hi = product_a_q[i][31:16];
            wire        [15:0] a_lo = product_a_q[i][15:0];
            wire signed [15:0] b_hi = product_b_q[i][31:16];
            wire        [15:0] b_lo = product_b_q[i][15:0];

            assign product_ll[i] = $signed({1'b0, a_lo}) * $signed({1'b0, b_lo});
            assign product_lh[i] = a_hi * $signed({1'b0, b_lo});
            assign product_hl[i] = b_hi * $signed({1'b0, a_lo});
            assign product_hh[i] = a_hi * b_hi;
        end
    endgenerate

    always_comb begin
        product_sum0 = product_term_q[0] + product_term_q[1] + product_term_q[2];
        product_sum1 = product_term_q[3] + product_term_q[4];
        product_sum2 = product_term_q[5] + product_term_q[6] + product_term_q[7];
        product_sum3 = product_term_q[8] + product_term_q[9];
    end

    function signed [63:0] reduce_limb_26;
        input signed [63:0] s;
        begin
            reduce_limb_26 = {{38{s[25]}}, s[25:0]};
        end
    endfunction

    function signed [63:0] reduce_limb_25;
        input signed [63:0] s;
        begin
            reduce_limb_25 = {{39{s[24]}}, s[24:0]};
        end
    endfunction

    function signed [63:0] mul19_64;
        input signed [63:0] s;
        begin
            mul19_64 = (s <<< 4) + (s <<< 1) + s;
        end
    endfunction

    function signed [63:0] combine_product;
        input signed [33:0] ll;
        input signed [33:0] mid;
        input signed [31:0] hh;
        reg signed [63:0] ll_ext;
        reg signed [63:0] mid_ext;
        reg signed [63:0] hh_ext;
        begin
            ll_ext = {{30{ll[33]}}, ll};
            mid_ext = {{30{mid[33]}}, mid};
            hh_ext = {{32{hh[31]}}, hh};
            combine_product = ll_ext + (mid_ext <<< 16) + (hh_ext <<< 32);
        end
    endfunction

    always @(posedge clk) begin
        if (!reset) begin
            state <= IDLE;
            counter <= 0;
            carry_stage <= 0;
            done <= 0;
            h <= 0;
            carry0_temp <= 0;
            carry1_temp <= 0;
            carry19_temp <= 0;
            product_sum0_q <= 0;
            product_sum1_q <= 0;
            product_sum2_q <= 0;
            product_sum3_q <= 0;
            product_sum_lo_q <= 0;
            product_sum_hi_q <= 0;
            for (integer j = 0; j < 10; j = j + 1) begin
                h_temp[j] <= 0;
                f_elem_q[j] <= 0;
                g_elem_q[j] <= 0;
                g19_part_q[j] <= 0;
                g19_elem_q[j] <= 0;
                product_a_q[j] <= 0;
                product_b_q[j] <= 0;
                product_ll_q[j] <= 0;
                product_lh_q[j] <= 0;
                product_hl_q[j] <= 0;
                product_hh_q[j] <= 0;
                product_mid_q[j] <= 0;
                product_term_q[j] <= 0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 0;
                    counter <= 0;
                    carry_stage <= 0;
                    carry0_temp <= 0;
                    carry1_temp <= 0;
                    carry19_temp <= 0;
                    if (start) begin
                        for (integer j = 0; j < 10; j = j + 1) begin
                            h_temp[j] <= 0;
                            f_elem_q[j] <= f_elem[j];
                            g_elem_q[j] <= g_elem[j];
                        end
                    end
                end

                PRECOMPUTE_G19_0: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        g19_part_q[j] <= (g_elem_q[j] <<< 4) + (g_elem_q[j] <<< 1);
                    end
                end

                PRECOMPUTE_G19_1: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        g19_elem_q[j] <= g19_part_q[j] + g_elem_q[j];
                    end
                end

                MULTIPLY_OPERANDS: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        product_a_q[j] <= product_a[j];
                        product_b_q[j] <= product_b[j];
                    end
                end

                MULTIPLY_PRODUCTS0: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        product_ll_q[j] <= product_ll[j];
                        product_lh_q[j] <= product_lh[j];
                        product_hl_q[j] <= product_hl[j];
                        product_hh_q[j] <= product_hh[j];
                    end
                end

                MULTIPLY_PRODUCTS1: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        product_mid_q[j] <= product_lh_q[j] + product_hl_q[j];
                    end
                end

                MULTIPLY_PRODUCTS2: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        product_term_q[j] <= combine_product(product_ll_q[j], product_mid_q[j], product_hh_q[j]);
                    end
                end

                MULTIPLY_SUM0: begin
                    product_sum0_q <= product_sum0;
                    product_sum1_q <= product_sum1;
                    product_sum2_q <= product_sum2;
                    product_sum3_q <= product_sum3;
                end

                MULTIPLY_SUM1: begin
                    product_sum_lo_q <= product_sum0_q + product_sum1_q;
                    product_sum_hi_q <= product_sum2_q + product_sum3_q;
                end

                MULTIPLY_SUM2: begin
                    h_temp[counter] <= product_sum_lo_q + product_sum_hi_q;
                    if (counter != 9)
                        counter <= counter + 1;
                end

                CARRY_PROP: begin
                    logic signed [63:0] c0;
                    logic signed [63:0] c1;

                    case (carry_stage)
                        4'd0: begin
                            c0 = (h_temp[0] + (64'sd1 << 25)) >>> 26;
                            c1 = (h_temp[4] + (64'sd1 << 25)) >>> 26;
                            carry0_temp <= c0;
                            carry1_temp <= c1;
                            h_temp[0] <= reduce_limb_26(h_temp[0]);
                            h_temp[4] <= reduce_limb_26(h_temp[4]);
                        end
                        4'd1: begin
                            h_temp[1] <= h_temp[1] + carry0_temp;
                            h_temp[5] <= h_temp[5] + carry1_temp;
                        end
                        4'd2: begin
                            c0 = (h_temp[1] + (64'sd1 << 24)) >>> 25;
                            c1 = (h_temp[5] + (64'sd1 << 24)) >>> 25;
                            carry0_temp <= c0;
                            carry1_temp <= c1;
                            h_temp[1] <= reduce_limb_25(h_temp[1]);
                            h_temp[5] <= reduce_limb_25(h_temp[5]);
                        end
                        4'd3: begin
                            h_temp[2] <= h_temp[2] + carry0_temp;
                            h_temp[6] <= h_temp[6] + carry1_temp;
                        end
                        4'd4: begin
                            c0 = (h_temp[2] + (64'sd1 << 25)) >>> 26;
                            c1 = (h_temp[6] + (64'sd1 << 25)) >>> 26;
                            carry0_temp <= c0;
                            carry1_temp <= c1;
                            h_temp[2] <= reduce_limb_26(h_temp[2]);
                            h_temp[6] <= reduce_limb_26(h_temp[6]);
                        end
                        4'd5: begin
                            h_temp[3] <= h_temp[3] + carry0_temp;
                            h_temp[7] <= h_temp[7] + carry1_temp;
                        end
                        4'd6: begin
                            c0 = (h_temp[3] + (64'sd1 << 24)) >>> 25;
                            c1 = (h_temp[7] + (64'sd1 << 24)) >>> 25;
                            carry0_temp <= c0;
                            carry1_temp <= c1;
                            h_temp[3] <= reduce_limb_25(h_temp[3]);
                            h_temp[7] <= reduce_limb_25(h_temp[7]);
                        end
                        4'd7: begin
                            h_temp[4] <= h_temp[4] + carry0_temp;
                            h_temp[8] <= h_temp[8] + carry1_temp;
                        end
                        4'd8: begin
                            c0 = (h_temp[4] + (64'sd1 << 25)) >>> 26;
                            c1 = (h_temp[8] + (64'sd1 << 25)) >>> 26;
                            carry0_temp <= c0;
                            carry1_temp <= c1;
                            h_temp[4] <= reduce_limb_26(h_temp[4]);
                            h_temp[8] <= reduce_limb_26(h_temp[8]);
                        end
                        4'd9: begin
                            h_temp[5] <= h_temp[5] + carry0_temp;
                            h_temp[9] <= h_temp[9] + carry1_temp;
                        end
                        4'd10: begin
                            c0 = (h_temp[9] + (64'sd1 << 24)) >>> 25;
                            carry0_temp <= c0;
                            h_temp[9] <= reduce_limb_25(h_temp[9]);
                        end
                        4'd11: begin
                            carry19_temp <= mul19_64(carry0_temp);
                        end
                        4'd12: begin
                            h_temp[0] <= h_temp[0] + carry19_temp;
                        end
                        4'd13: begin
                            c0 = (h_temp[0] + (64'sd1 << 25)) >>> 26;
                            carry0_temp <= c0;
                            h_temp[0] <= reduce_limb_26(h_temp[0]);
                        end
                        4'd14: begin
                            h_temp[1] <= h_temp[1] + carry0_temp;
                        end
                        default: begin
                        end
                    endcase

                    if (carry_stage == 4'd14)
                        carry_stage <= 0;
                    else
                        carry_stage <= carry_stage + 1;
                end

                FINISHED: begin
                    h <= {h_temp[9][31:0], h_temp[8][31:0], h_temp[7][31:0],
                          h_temp[6][31:0], h_temp[5][31:0], h_temp[4][31:0],
                          h_temp[3][31:0], h_temp[2][31:0], h_temp[1][31:0],
                          h_temp[0][31:0]};
                    done <= 1;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: next_state = start ? PRECOMPUTE_G19_0 : IDLE;
            PRECOMPUTE_G19_0: next_state = PRECOMPUTE_G19_1;
            PRECOMPUTE_G19_1: next_state = MULTIPLY_OPERANDS;
            MULTIPLY_OPERANDS: next_state = MULTIPLY_PRODUCTS0;
            MULTIPLY_PRODUCTS0: next_state = MULTIPLY_PRODUCTS1;
            MULTIPLY_PRODUCTS1: next_state = MULTIPLY_PRODUCTS2;
            MULTIPLY_PRODUCTS2: next_state = MULTIPLY_SUM0;
            MULTIPLY_SUM0: next_state = MULTIPLY_SUM1;
            MULTIPLY_SUM1: next_state = MULTIPLY_SUM2;
            MULTIPLY_SUM2: next_state = (counter == 9) ? CARRY_PROP : MULTIPLY_OPERANDS;
            CARRY_PROP: next_state = (carry_stage == 4'd14) ? FINISHED : CARRY_PROP;
            FINISHED: next_state = start ? FINISHED : IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule
