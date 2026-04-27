module fe_mul (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  signed [319:0] f,
    input  signed [319:0] g,
    output reg signed [319:0] h,
    output reg done
);

    localparam [2:0] IDLE              = 3'b000,
                     MULTIPLY_OPERANDS = 3'b001,
                     MULTIPLY_PRODUCTS = 3'b010,
                     MULTIPLY_SUM      = 3'b011,
                     CARRY_PROP        = 3'b100,
                     FINISHED          = 3'b101;

    reg [2:0] state, next_state;
    reg [3:0] counter;

    // Carry state
    reg [3:0] carry_stage;      // 0..11
    reg [1:0] carry_substep;    // 0: calc, 1: add, 2: sub

    // Extract elements
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
    reg signed [63:0] carry_temp;

    logic signed [63:0] product_term [0:9];
    logic signed [63:0] product_sum;
    logic signed [31:0] product_a [0:9];
    logic signed [31:0] product_b [0:9];
    reg signed [31:0] product_a_q [0:9];
    reg signed [31:0] product_b_q [0:9];
    reg signed [63:0] product_term_q [0:9];

    always_comb begin
        for (int term_idx = 0; term_idx < 10; term_idx++) begin
            logic signed [31:0] f_operand;
            logic signed [31:0] g_operand;
            logic signed [31:0] g_base;
            logic [4:0] idx_diff;
            logic use_g19;
            logic [3:0] g_index;

            f_operand = ((counter[0] == 1'b0) && (term_idx[0] == 1'b1)) ?
                        (f_elem[term_idx] << 1) : f_elem[term_idx];
            idx_diff = {1'b0, counter} - {1'b0, term_idx[3:0]};
            use_g19 = (idx_diff[4] == 1'b1);
            g_index = use_g19 ? (idx_diff[3:0] + 4'd10) : idx_diff[3:0];
            g_base = g_elem[g_index];
            g_operand = use_g19 ? ((g_base << 4) + (g_base << 1) + g_base) : g_base;
            product_a[term_idx] = f_operand;
            product_b[term_idx] = g_operand;
        end
    end

    generate
        for (i = 0; i < 10; i = i + 1) begin : multiply_terms
            assign product_term[i] = product_a_q[i] * product_b_q[i];
        end
    endgenerate

    always_comb begin
        product_sum = 64'sd0;
        for (int term_idx = 0; term_idx < 10; term_idx++) begin
            product_sum += product_term_q[term_idx];
        end
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

    // Carry propagation parameters
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

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            counter <= 0;
            carry_stage <= 0;
            carry_substep <= 0;
            done <= 0;
            h <= 0;
            carry_temp <= 0;
            for (integer j = 0; j < 10; j = j + 1) begin
                h_temp[j] <= 0;
                product_a_q[j] <= 0;
                product_b_q[j] <= 0;
                product_term_q[j] <= 0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 0;
                    counter <= 0;
                    carry_stage <= 0;
                    carry_substep <= 0;
                    if (start) begin
                        for (integer j = 0; j < 10; j = j + 1) begin
                            h_temp[j] <= 0;
                        end
                    end
                end

                MULTIPLY_OPERANDS: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        product_a_q[j] <= product_a[j];
                        product_b_q[j] <= product_b[j];
                    end
                end

                MULTIPLY_PRODUCTS: begin
                    for (integer j = 0; j < 10; j = j + 1) begin
                        product_term_q[j] <= product_term[j];
                    end
                end

                MULTIPLY_SUM: begin
                    h_temp[counter] <= product_sum;
                    if (counter != 9)
                        counter <= counter + 1;
                end

                CARRY_PROP: begin
                    logic signed [63:0] t [0:9];
                    logic signed [63:0] c;

                    for (int j = 0; j < 10; j++) t[j] = h_temp[j];

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

                    for (int j = 0; j < 10; j++) h_temp[j] <= t[j];
                    if (carry_stage == 4'd6)
                        carry_stage <= 0;
                    else
                        carry_stage <= carry_stage + 1;
                    carry_substep <= 0;
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
            IDLE: next_state = start ? MULTIPLY_OPERANDS : IDLE;
            MULTIPLY_OPERANDS: next_state = MULTIPLY_PRODUCTS;
            MULTIPLY_PRODUCTS: next_state = MULTIPLY_SUM;
            MULTIPLY_SUM: next_state = (counter == 9) ? CARRY_PROP : MULTIPLY_OPERANDS;
            CARRY_PROP: next_state = (carry_stage == 4'd6) ? FINISHED : CARRY_PROP;
            FINISHED: next_state = start ? FINISHED : IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule
