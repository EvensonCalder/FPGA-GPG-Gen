module ge_top_mux_wrapper(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [2:0]  sel_opcode, // select which op to run

    // All possible input sets for each op
    input  logic signed [319:0] p_X_add, p_Y_add, p_Z_add, p_T_add,
    input  logic signed [319:0] q_1_add, q_2_add, q_3_add, q_4_add,

    input  logic signed [319:0] p_X_madd, p_Y_madd, p_Z_madd, p_T_madd,
    input  logic signed [319:0] q_1_madd, q_2_madd, q_3_madd,

    input  logic signed [319:0] p_X_msub, p_Y_msub, p_Z_msub, p_T_msub,
    input  logic signed [319:0] q_1_msub, q_2_msub, q_3_msub,

    input  logic signed [319:0] p_X_p1p1top2, p_Y_p1p1top2, p_Z_p1p1top2, p_T_p1p1top2,

    input  logic signed [319:0] p_X_p1p1_to_p3, p_Y_p1p1_to_p3, p_Z_p1p1_to_p3, p_T_p1p1_to_p3,

    input  logic signed [319:0] p_X_p2_dbl, p_Y_p2_dbl, p_Z_p2_dbl,

    input  logic signed [319:0] p_X_p3_to_cached, p_Y_p3_to_cached, p_Z_p3_to_cached, p_T_p3_to_cached,

    input  logic signed [319:0] p_X_sub, p_Y_sub, p_Z_sub, p_T_sub,
    input  logic signed [319:0] q_1_sub, q_2_sub, q_3_sub, q_4_sub,

    // Simplified outputs - single set instead of per-operation
    output logic signed [319:0] result_x, result_y, result_z, result_t,
    output logic               operation_done,
    output logic [2:0]         completed_opcode  // Which operation just completed
);

    // Internal signals - much simpler
    logic signed [319:0] p_X, p_Y, p_Z, p_T;
    logic signed [319:0] q_1, q_2, q_3, q_4;
    logic [2:0] registered_opcode;
    logic [2:0] active_opcode;

    assign active_opcode = start ? sel_opcode : registered_opcode;
    
    // Simple input multiplexer - combinational to reduce register usage
    always_comb begin
        case (active_opcode)
            3'd0: begin // ge_add
                p_X = p_X_add; p_Y = p_Y_add; p_Z = p_Z_add; p_T = p_T_add;
                q_1 = q_1_add; q_2 = q_2_add; q_3 = q_3_add; q_4 = q_4_add;
            end
            3'd1: begin // ge_madd
                p_X = p_X_madd; p_Y = p_Y_madd; p_Z = p_Z_madd; p_T = p_T_madd;
                q_1 = q_1_madd; q_2 = q_2_madd; q_3 = q_3_madd; q_4 = '0;
            end
            3'd2: begin // ge_msub
                p_X = p_X_msub; p_Y = p_Y_msub; p_Z = p_Z_msub; p_T = p_T_msub;
                q_1 = q_1_msub; q_2 = q_2_msub; q_3 = q_3_msub; q_4 = '0;
            end
            3'd3: begin // ge_p1p1top2
                p_X = p_X_p1p1top2; p_Y = p_Y_p1p1top2; p_Z = p_Z_p1p1top2; p_T = p_T_p1p1top2;
                q_1 = '0; q_2 = '0; q_3 = '0; q_4 = '0;
            end
            3'd4: begin // ge_p1p1_to_p3
                p_X = p_X_p1p1_to_p3; p_Y = p_Y_p1p1_to_p3; p_Z = p_Z_p1p1_to_p3; p_T = p_T_p1p1_to_p3;
                q_1 = '0; q_2 = '0; q_3 = '0; q_4 = '0;
            end
            3'd5: begin // ge_p2_dbl
                p_X = p_X_p2_dbl; p_Y = p_Y_p2_dbl; p_Z = p_Z_p2_dbl; p_T = '0;
                q_1 = '0; q_2 = '0; q_3 = '0; q_4 = '0;
            end
            3'd6: begin // ge_p3_to_cached
                p_X = p_X_p3_to_cached; p_Y = p_Y_p3_to_cached; p_Z = p_Z_p3_to_cached; p_T = p_T_p3_to_cached;
                q_1 = '0; q_2 = '0; q_3 = '0; q_4 = '0;
            end
            3'd7: begin // ge_sub
                p_X = p_X_sub; p_Y = p_Y_sub; p_Z = p_Z_sub; p_T = p_T_sub;
                q_1 = q_1_sub; q_2 = q_2_sub; q_3 = q_3_sub; q_4 = q_4_sub;
            end
            default: begin
                p_X = '0; p_Y = '0; p_Z = '0; p_T = '0;
                q_1 = '0; q_2 = '0; q_3 = '0; q_4 = '0;
            end
        endcase
    end

    // Register the opcode to track which operation is running
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            registered_opcode <= '0;
        end else if (start) begin
            registered_opcode <= sel_opcode;
        end
    end

    // Instantiate ge_top
    ge_top u_ge_top (
        .clk(clk),
        .start(start),
        .rst_n(rst_n),
        .opcode_in(active_opcode),
        .p_X(p_X),
        .p_Y(p_Y),
        .p_Z(p_Z),
        .p_T(p_T),
        .q_1(q_1),
        .q_2(q_2),
        .q_3(q_3),
        .q_4(q_4),
        .r_x(result_x),
        .r_y(result_y),
        .r_z(result_z),
        .r_t(result_t),
        .done_TOP(operation_done)
    );

    // Simple output - no demux needed!
    assign completed_opcode = registered_opcode;

endmodule
