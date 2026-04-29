`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_context #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1,
    parameter integer WINDOW_BITS = 9,
    parameter integer DIGITS = (256 + WINDOW_BITS - 1) / WINDOW_BITS
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
    localparam int LAST_DIGIT = DIGITS - 1;
    localparam int LAST_BITS = 256 - (WINDOW_BITS * LAST_DIGIT);
    localparam logic [4:0] LAST_DIGIT_IDX = 5'(LAST_DIGIT);

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_RECODE_STEP,
        ST_SELECT_START,
        ST_SELECT_WAIT,
        ST_MADD_START,
        ST_MADD_WAIT,
        ST_NEXT,
        ST_DONE
    } state_t;

    state_t state;
    logic [4:0] idx;
    logic [4:0] recode_idx;
    logic signed [10:0] recode_carry;
    logic [255:0] scalar_q;
    logic signed [10:0] digit [0:DIGITS-1];
    logic signed [11:0] recode_value;
    logic signed [11:0] recode_carry_next;
    logic signed [11:0] recode_digit_next;

    fe17_t h_X, h_Y, h_Z, h_T;
    logic select_start;
    logic select_done;
    logic select_prefetch;
    logic prefetch_started;
    logic [1:0] madd_wait_age;
    logic [4:0] select_pos;
    fe17_t sel_yplusx;
    fe17_t sel_yminusx;
    fe17_t sel_xy2d;

    logic engine_start;
    logic engine_done;
    logic engine_op_dbl;
    fe17_t engine_X, engine_Y, engine_Z, engine_T;

    ed25519_ht_fixedbase_table #(
        .INIT_FILE(INIT_FILE),
        .WINDOW_BITS(WINDOW_BITS),
        .DIGITS(DIGITS)
    ) u_select (
        .clk(clk),
        .rst_n(rst_n),
        .start(select_start),
        .pos(select_pos),
        .digit(digit[select_pos]),
        .yplusx(sel_yplusx),
        .yminusx(sel_yminusx),
        .xy2d(sel_xy2d),
        .done(select_done)
    );

    ed25519_ht_fe17_group_engine #(
        .MUL_LANES(MUL_LANES)
    ) u_engine (
        .clk(clk), .rst_n(rst_n), .start(engine_start), .op_dbl(engine_op_dbl),
        .p_X(h_X), .p_Y(h_Y), .p_Z(h_Z), .p_T(h_T),
        .q_yplusx(sel_yplusx), .q_yminusx(sel_yminusx), .q_xy2d(sel_xy2d),
        .busy(), .done(engine_done),
        .r_X(engine_X), .r_Y(engine_Y), .r_Z(engine_Z), .r_T(engine_T)
    );

    always_comb begin
        select_start = 1'b0;
        select_prefetch = 1'b0;
        engine_start = 1'b0;
        engine_op_dbl = 1'b0;
        unique case (state)
            ST_SELECT_START: select_start = 1'b1;
            ST_MADD_START: engine_start = 1'b1;
            ST_MADD_WAIT: begin
                if ((idx != LAST_DIGIT_IDX) && !prefetch_started && (madd_wait_age >= 2'd2)) begin
                    select_start = 1'b1;
                    select_prefetch = 1'b1;
                end
            end
            default: begin
            end
        endcase
    end

    always_comb begin
        select_pos = select_prefetch ? (idx + 5'd1) : idx;
    end

    always_comb begin
        recode_value = 12'sd0;
        recode_carry_next = 12'sd0;
        recode_digit_next = 12'sd0;
        if (recode_idx < LAST_DIGIT_IDX) begin
            recode_value = 12'({1'b0, scalar_q[WINDOW_BITS * recode_idx +: WINDOW_BITS]}) + 12'(recode_carry);
            recode_carry_next = (recode_value + (12'sd1 <<< (WINDOW_BITS - 1))) >>> WINDOW_BITS;
            recode_digit_next = recode_value - (recode_carry_next <<< WINDOW_BITS);
        end else begin
            recode_value = 12'({{(12-LAST_BITS){1'b0}}, scalar_q[WINDOW_BITS * LAST_DIGIT +: LAST_BITS]}) + 12'(recode_carry);
            recode_digit_next = recode_value;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            idx <= 5'd0;
            recode_idx <= 5'd0;
            recode_carry <= 11'sd0;
            scalar_q <= 256'd0;
            prefetch_started <= 1'b0;
            madd_wait_age <= 2'd0;
            h_X <= FE_ZERO; h_Y <= FE_ONE; h_Z <= FE_ONE; h_T <= FE_ZERO;
            r_X <= FE_ZERO; r_Y <= FE_ZERO; r_Z <= FE_ZERO; r_T <= FE_ZERO;
            for (int i = 0; i < DIGITS; i++)
                digit[i] <= 11'sd0;
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
                        recode_idx <= 5'd0;
                        recode_carry <= 11'sd0;
                        prefetch_started <= 1'b0;
                        madd_wait_age <= 2'd0;
                        state <= ST_RECODE_STEP;
                    end
                end
                ST_RECODE_STEP: begin
                    if (recode_idx < LAST_DIGIT_IDX) begin
                        digit[recode_idx] <= recode_digit_next[10:0];
                        recode_carry <= recode_carry_next[10:0];
                        recode_idx <= recode_idx + 5'd1;
                    end else begin
                        digit[LAST_DIGIT] <= recode_digit_next[10:0];
                        idx <= 5'd0;
                        state <= ST_SELECT_START;
                    end
                end
                ST_SELECT_START: state <= ST_SELECT_WAIT;
                ST_SELECT_WAIT: if (select_done) state <= ST_MADD_START;
                ST_MADD_START: begin
                    madd_wait_age <= 2'd0;
                    state <= ST_MADD_WAIT;
                end
                ST_MADD_WAIT: begin
                    if (madd_wait_age != 2'd3)
                        madd_wait_age <= madd_wait_age + 2'd1;
                    if (select_prefetch)
                        prefetch_started <= 1'b1;
                    if (engine_done) begin
                        h_X <= engine_X; h_Y <= engine_Y; h_Z <= engine_Z; h_T <= engine_T;
                        if (idx == LAST_DIGIT_IDX) begin
                            state <= ST_DONE;
                        end else begin
                            idx <= idx + 5'd1;
                            prefetch_started <= 1'b0;
                            madd_wait_age <= 2'd0;
                            state <= prefetch_started ? ST_MADD_START : ST_SELECT_START;
                        end
                    end
                end
                ST_NEXT: begin
                    if (idx == LAST_DIGIT_IDX) begin
                        state <= ST_DONE;
                    end else begin
                        idx <= idx + 5'd1;
                        state <= ST_SELECT_START;
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
