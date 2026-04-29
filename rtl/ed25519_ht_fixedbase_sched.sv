`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_sched #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer CONTEXTS = 16,
    parameter integer TAG_WIDTH = 1,
    parameter integer WINDOW_BITS = 9,
    parameter integer DIGITS = (256 + WINDOW_BITS - 1) / WINDOW_BITS
) (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         scalar_valid,
    output logic         scalar_ready,
    input  logic [255:0] scalar,
    input  logic [TAG_WIDTH-1:0] scalar_tag,

    output logic         point_valid,
    input  logic         point_ready,
    output logic [TAG_WIDTH-1:0] point_tag,
    output fe17_t        point_x,
    output fe17_t        point_y,
    output fe17_t        point_z
);
    localparam fe17_t FE_ZERO = '0;
    localparam fe17_t FE_ONE  = fe17_t'(255'd1);
    localparam int CTX_BITS = (CONTEXTS <= 1) ? 1 : $clog2(CONTEXTS);
    localparam int LAST_DIGIT = DIGITS - 1;
    localparam int LAST_BITS = 256 - (WINDOW_BITS * LAST_DIGIT);
    localparam logic [4:0] LAST_DIGIT_IDX = 5'(LAST_DIGIT);

    typedef enum logic [3:0] {
        C_EMPTY,
        C_RECODE,
        C_NEED_SELECT,
        C_SELECTING,
        C_READY_MADD,
        C_MADD_BUSY,
        C_DONE
    } ctx_state_t;

    ctx_state_t ctx_state [0:CONTEXTS-1];
    logic [255:0] scalar_q [0:CONTEXTS-1];
    logic [TAG_WIDTH-1:0] tag_q [0:CONTEXTS-1];
    logic [4:0] idx [0:CONTEXTS-1];
    logic [4:0] recode_idx [0:CONTEXTS-1];
    logic signed [10:0] recode_carry [0:CONTEXTS-1];
    logic signed [10:0] digit [0:CONTEXTS-1][0:DIGITS-1];
    fe17_t h_X [0:CONTEXTS-1], h_Y [0:CONTEXTS-1], h_Z [0:CONTEXTS-1], h_T [0:CONTEXTS-1];
    fe17_t q_yplusx_q [0:CONTEXTS-1], q_yminusx_q [0:CONTEXTS-1], q_xy2d_q [0:CONTEXTS-1];

    logic [CTX_BITS-1:0] alloc_ptr, retire_ptr, select_ptr;
    logic [CTX_BITS-1:0] alloc_idx, retire_idx, select_idx;
    logic alloc_found, retire_found, select_found;

    logic table_start, table_done;
    logic table_busy;
    logic [CTX_BITS-1:0] table_ctx;
    fe17_t table_yplusx, table_yminusx, table_xy2d;

    logic [CONTEXTS-1:0] madd_start, madd_ready, madd_done;
    fe17_t madd_p_X [0:CONTEXTS-1], madd_p_Y [0:CONTEXTS-1], madd_p_Z [0:CONTEXTS-1], madd_p_T [0:CONTEXTS-1];
    fe17_t madd_q_yplusx [0:CONTEXTS-1], madd_q_yminusx [0:CONTEXTS-1], madd_q_xy2d [0:CONTEXTS-1];
    fe17_t madd_r_X [0:CONTEXTS-1], madd_r_Y [0:CONTEXTS-1], madd_r_Z [0:CONTEXTS-1], madd_r_T [0:CONTEXTS-1];

    function automatic logic [CTX_BITS-1:0] wrap_ctx(input int unsigned value);
        int unsigned v;
        begin
            v = value;
            if (value >= CONTEXTS)
                v = value - CONTEXTS;
            return v[CTX_BITS-1:0];
        end
    endfunction

    function automatic logic signed [11:0] recode_value(input int unsigned c);
        if (recode_idx[c] < LAST_DIGIT_IDX)
            return 12'({1'b0, scalar_q[c][WINDOW_BITS * recode_idx[c] +: WINDOW_BITS]}) + 12'(recode_carry[c]);
        else
            return 12'({{(12-LAST_BITS){1'b0}}, scalar_q[c][WINDOW_BITS * LAST_DIGIT +: LAST_BITS]}) + 12'(recode_carry[c]);
    endfunction

    function automatic logic signed [11:0] recode_carry_next(input int unsigned c);
        return (recode_value(c) + (12'sd1 <<< (WINDOW_BITS - 1))) >>> WINDOW_BITS;
    endfunction

    function automatic logic signed [11:0] recode_digit_next(input int unsigned c);
        if (recode_idx[c] < LAST_DIGIT_IDX)
            return recode_value(c) - (recode_carry_next(c) <<< WINDOW_BITS);
        else
            return recode_value(c);
    endfunction

    always_comb begin
        alloc_found = 1'b0;
        alloc_idx = alloc_ptr;
        for (int n = 0; n < CONTEXTS; n++) begin
            logic [CTX_BITS-1:0] probe;
            probe = wrap_ctx(alloc_ptr + n);
            if (!alloc_found && ctx_state[probe] == C_EMPTY) begin
                alloc_found = 1'b1;
                alloc_idx = probe;
            end
        end

        retire_found = 1'b0;
        retire_idx = retire_ptr;
        for (int n = 0; n < CONTEXTS; n++) begin
            logic [CTX_BITS-1:0] probe;
            probe = wrap_ctx(retire_ptr + n);
            if (!retire_found && ctx_state[probe] == C_DONE) begin
                retire_found = 1'b1;
                retire_idx = probe;
            end
        end

        select_found = 1'b0;
        select_idx = select_ptr;
        for (int n = 0; n < CONTEXTS; n++) begin
            logic [CTX_BITS-1:0] probe;
            probe = wrap_ctx(select_ptr + n);
            if (!select_found && ctx_state[probe] == C_NEED_SELECT) begin
                select_found = 1'b1;
                select_idx = probe;
            end
        end
    end

    assign scalar_ready = alloc_found;
    assign point_valid = retire_found;
    assign point_tag = tag_q[retire_idx];
    assign point_x = h_X[retire_idx];
    assign point_y = h_Y[retire_idx];
    assign point_z = h_Z[retire_idx];
    assign table_start = select_found && !table_busy;

    ed25519_ht_fixedbase_table #(
        .INIT_FILE(INIT_FILE),
        .WINDOW_BITS(WINDOW_BITS),
        .DIGITS(DIGITS)
    ) u_table (
        .clk(clk), .rst_n(rst_n), .start(table_start),
        .pos(idx[select_idx]), .digit(digit[select_idx][idx[select_idx]]),
        .yplusx(table_yplusx), .yminusx(table_yminusx), .xy2d(table_xy2d), .done(table_done)
    );

    ed25519_ht_fe17_madd_sched #(
        .CONTEXTS(CONTEXTS)
    ) u_madd_sched (
        .clk(clk), .rst_n(rst_n),
        .start(madd_start), .start_ready(madd_ready),
        .p_X(madd_p_X), .p_Y(madd_p_Y), .p_Z(madd_p_Z), .p_T(madd_p_T),
        .q_yplusx(madd_q_yplusx), .q_yminusx(madd_q_yminusx), .q_xy2d(madd_q_xy2d),
        .done(madd_done), .r_X(madd_r_X), .r_Y(madd_r_Y), .r_Z(madd_r_Z), .r_T(madd_r_T)
    );

    always_comb begin
        madd_start = '0;
        for (int i = 0; i < CONTEXTS; i++) begin
            madd_p_X[i] = h_X[i];
            madd_p_Y[i] = h_Y[i];
            madd_p_Z[i] = h_Z[i];
            madd_p_T[i] = h_T[i];
            madd_q_yplusx[i] = q_yplusx_q[i];
            madd_q_yminusx[i] = q_yminusx_q[i];
            madd_q_xy2d[i] = q_xy2d_q[i];
            if (ctx_state[i] == C_READY_MADD && madd_ready[i])
                madd_start[i] = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alloc_ptr <= '0;
            retire_ptr <= '0;
            select_ptr <= '0;
            table_ctx <= '0;
            table_busy <= 1'b0;
            for (int i = 0; i < CONTEXTS; i++) begin
                ctx_state[i] <= C_EMPTY;
                scalar_q[i] <= 256'd0;
                tag_q[i] <= '0;
                idx[i] <= 5'd0;
                recode_idx[i] <= 5'd0;
                recode_carry[i] <= 11'sd0;
                h_X[i] <= FE_ZERO; h_Y[i] <= FE_ONE; h_Z[i] <= FE_ONE; h_T[i] <= FE_ZERO;
                q_yplusx_q[i] <= '0; q_yminusx_q[i] <= '0; q_xy2d_q[i] <= '0;
                for (int j = 0; j < DIGITS; j++)
                    digit[i][j] <= 11'sd0;
            end
        end else begin
            if (scalar_valid && scalar_ready) begin
                scalar_q[alloc_idx] <= scalar;
                tag_q[alloc_idx] <= scalar_tag;
                idx[alloc_idx] <= 5'd0;
                recode_idx[alloc_idx] <= 5'd0;
                recode_carry[alloc_idx] <= 11'sd0;
                h_X[alloc_idx] <= FE_ZERO;
                h_Y[alloc_idx] <= FE_ONE;
                h_Z[alloc_idx] <= FE_ONE;
                h_T[alloc_idx] <= FE_ZERO;
                ctx_state[alloc_idx] <= C_RECODE;
                alloc_ptr <= wrap_ctx(alloc_idx + 1);
            end

            if (point_valid && point_ready) begin
                ctx_state[retire_idx] <= C_EMPTY;
                retire_ptr <= wrap_ctx(retire_idx + 1);
            end

            if (table_start) begin
                table_ctx <= select_idx;
                table_busy <= 1'b1;
                ctx_state[select_idx] <= C_SELECTING;
                select_ptr <= wrap_ctx(select_idx + 1);
            end

            if (table_done) begin
                table_busy <= 1'b0;
                q_yplusx_q[table_ctx] <= table_yplusx;
                q_yminusx_q[table_ctx] <= table_yminusx;
                q_xy2d_q[table_ctx] <= table_xy2d;
                ctx_state[table_ctx] <= C_READY_MADD;
            end

            for (int i = 0; i < CONTEXTS; i++) begin
                unique case (ctx_state[i])
                    C_RECODE: begin
                        digit[i][recode_idx[i]] <= recode_digit_next(i);
                        if (recode_idx[i] < LAST_DIGIT_IDX) begin
                            recode_carry[i] <= recode_carry_next(i);
                            recode_idx[i] <= recode_idx[i] + 5'd1;
                        end else begin
                            idx[i] <= 5'd0;
                            ctx_state[i] <= C_NEED_SELECT;
                        end
                    end
                    C_READY_MADD: begin
                        if (madd_start[i])
                            ctx_state[i] <= C_MADD_BUSY;
                    end
                    C_MADD_BUSY: begin
                        if (madd_done[i]) begin
                            h_X[i] <= madd_r_X[i];
                            h_Y[i] <= madd_r_Y[i];
                            h_Z[i] <= madd_r_Z[i];
                            h_T[i] <= madd_r_T[i];
                            if (idx[i] == LAST_DIGIT_IDX) begin
                                ctx_state[i] <= C_DONE;
                            end else begin
                                idx[i] <= idx[i] + 5'd1;
                                ctx_state[i] <= C_NEED_SELECT;
                            end
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
    end
endmodule
