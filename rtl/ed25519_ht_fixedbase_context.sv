`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_context #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] scalar,
    output fe17_t        r_X,
    output fe17_t        r_Y,
    output fe17_t        r_Z,
    output fe17_t        r_T,
    output logic         done
);
    localparam fe17_t FE_ZERO = '0;
    localparam fe17_t FE_ONE  = fe17_t'(255'd1);

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_RECODE_STEP,
        ST_SELECT_ODD_START,
        ST_SELECT_ODD_WAIT,
        ST_MADD_ODD_START,
        ST_MADD_ODD_WAIT,
        ST_NEXT_ODD,
        ST_DBL_START,
        ST_DBL_WAIT,
        ST_NEXT_DBL,
        ST_SELECT_EVEN_START,
        ST_SELECT_EVEN_WAIT,
        ST_MADD_EVEN_START,
        ST_MADD_EVEN_WAIT,
        ST_NEXT_EVEN,
        ST_DONE
    } state_t;

    state_t state;
    logic [5:0] idx;
    logic [5:0] recode_idx;
    logic signed [8:0] recode_carry;
    logic [255:0] scalar_q;
    logic [1:0] dbl_count;
    logic signed [7:0] digit [0:63];
    logic signed [8:0] recode_value;
    logic signed [8:0] recode_carry_next;
    logic signed [8:0] recode_digit_next;

    fe17_t h_X, h_Y, h_Z, h_T;
    logic select_start;
    logic select_done;
    fe17_t sel_yplusx;
    fe17_t sel_yminusx;
    fe17_t sel_xy2d;

    logic engine_start;
    logic engine_done;
    logic engine_op_dbl;
    fe17_t engine_X, engine_Y, engine_Z, engine_T;

    ed25519_ht_fixedbase_table #(
        .INIT_FILE(INIT_FILE)
    ) u_select (
        .clk(clk),
        .rst_n(rst_n),
        .start(select_start),
        .pos(idx[5:1]),
        .digit(digit[idx]),
        .yplusx(sel_yplusx),
        .yminusx(sel_yminusx),
        .xy2d(sel_xy2d),
        .done(select_done)
    );

    ed25519_ht_fe17_group_engine u_engine (
        .clk(clk), .rst_n(rst_n), .start(engine_start), .op_dbl(engine_op_dbl),
        .p_X(h_X), .p_Y(h_Y), .p_Z(h_Z), .p_T(h_T),
        .q_yplusx(sel_yplusx), .q_yminusx(sel_yminusx), .q_xy2d(sel_xy2d),
        .busy(), .done(engine_done),
        .r_X(engine_X), .r_Y(engine_Y), .r_Z(engine_Z), .r_T(engine_T)
    );

    always_comb begin
        select_start = 1'b0;
        engine_start = 1'b0;
        engine_op_dbl = 1'b0;
        unique case (state)
            ST_SELECT_ODD_START,
            ST_SELECT_EVEN_START: select_start = 1'b1;
            ST_MADD_ODD_START,
            ST_MADD_EVEN_START: engine_start = 1'b1;
            ST_DBL_START: begin
                engine_start = 1'b1;
                engine_op_dbl = 1'b1;
            end
            default: begin
            end
        endcase
    end

    always_comb begin
        recode_value = 9'sd0;
        recode_carry_next = 9'sd0;
        recode_digit_next = 9'sd0;
        if (recode_idx < 6'd63) begin
            recode_value = 9'({5'd0, scalar_q[4 * recode_idx +: 4]}) + recode_carry;
            recode_carry_next = (recode_value + 9'sd8) >>> 4;
            recode_digit_next = recode_value - (recode_carry_next <<< 4);
        end else begin
            recode_value = 9'({5'd0, scalar_q[252 +: 4]}) + recode_carry;
            recode_digit_next = recode_value;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            idx <= 6'd0;
            recode_idx <= 6'd0;
            recode_carry <= 9'sd0;
            scalar_q <= 256'd0;
            dbl_count <= 2'd0;
            h_X <= FE_ZERO; h_Y <= FE_ONE; h_Z <= FE_ONE; h_T <= FE_ZERO;
            r_X <= FE_ZERO; r_Y <= FE_ZERO; r_Z <= FE_ZERO; r_T <= FE_ZERO;
            for (int i = 0; i < 64; i++)
                digit[i] <= 8'sd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        h_X <= FE_ZERO;
                        h_Y <= FE_ONE;
                        h_Z <= FE_ONE;
                        h_T <= FE_ZERO;
                        scalar_q <= scalar;
                        recode_idx <= 6'd0;
                        recode_carry <= 9'sd0;
                        state <= ST_RECODE_STEP;
                    end
                end
                ST_RECODE_STEP: begin
                    if (recode_idx < 6'd63) begin
                        digit[recode_idx] <= recode_digit_next[7:0];
                        recode_carry <= recode_carry_next;
                        recode_idx <= recode_idx + 6'd1;
                    end else begin
                        digit[63] <= recode_value[7:0];
                        idx <= 6'd1;
                        state <= ST_SELECT_ODD_START;
                    end
                end
                ST_SELECT_ODD_START: state <= ST_SELECT_ODD_WAIT;
                ST_SELECT_ODD_WAIT: if (select_done) state <= ST_MADD_ODD_START;
                ST_MADD_ODD_START: state <= ST_MADD_ODD_WAIT;
                ST_MADD_ODD_WAIT: begin
                    if (engine_done) begin
                        h_X <= engine_X; h_Y <= engine_Y; h_Z <= engine_Z; h_T <= engine_T;
                        state <= ST_NEXT_ODD;
                    end
                end
                ST_NEXT_ODD: begin
                    if (idx == 6'd63) begin
                        dbl_count <= 2'd0;
                        state <= ST_DBL_START;
                    end else begin
                        idx <= idx + 6'd2;
                        state <= ST_SELECT_ODD_START;
                    end
                end
                ST_DBL_START: state <= ST_DBL_WAIT;
                ST_DBL_WAIT: begin
                    if (engine_done) begin
                        h_X <= engine_X; h_Y <= engine_Y; h_Z <= engine_Z; h_T <= engine_T;
                        state <= ST_NEXT_DBL;
                    end
                end
                ST_NEXT_DBL: begin
                    if (dbl_count == 2'd3) begin
                        idx <= 6'd0;
                        state <= ST_SELECT_EVEN_START;
                    end else begin
                        dbl_count <= dbl_count + 2'd1;
                        state <= ST_DBL_START;
                    end
                end
                ST_SELECT_EVEN_START: state <= ST_SELECT_EVEN_WAIT;
                ST_SELECT_EVEN_WAIT: if (select_done) state <= ST_MADD_EVEN_START;
                ST_MADD_EVEN_START: state <= ST_MADD_EVEN_WAIT;
                ST_MADD_EVEN_WAIT: begin
                    if (engine_done) begin
                        h_X <= engine_X; h_Y <= engine_Y; h_Z <= engine_Z; h_T <= engine_T;
                        state <= ST_NEXT_EVEN;
                    end
                end
                ST_NEXT_EVEN: begin
                    if (idx == 6'd62) begin
                        state <= ST_DONE;
                    end else begin
                        idx <= idx + 6'd2;
                        state <= ST_SELECT_EVEN_START;
                    end
                end
                ST_DONE: begin
                    r_X <= h_X; r_Y <= h_Y; r_Z <= h_Z; r_T <= h_T;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
