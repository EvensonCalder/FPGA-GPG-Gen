`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_context (
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
    logic [1:0] dbl_count;
    logic signed [7:0] digit [0:63];

    fe17_t h_X, h_Y, h_Z, h_T;
    logic select_start;
    logic select_done;
    fe17_t sel_yplusx;
    fe17_t sel_yminusx;
    fe17_t sel_xy2d;

    logic madd_start;
    logic madd_done;
    fe17_t madd_X, madd_Y, madd_Z, madd_T;
    logic dbl_start;
    logic dbl_done;
    fe17_t dbl_X, dbl_Y, dbl_Z, dbl_T;

    ed25519_scalar_recode_4bit u_recode (
        .scalar(scalar),
        .digit(digit)
    );

    ed25519_ht_fixedbase_table u_select (
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

    ed25519_ht_fe17_madd u_madd (
        .clk(clk), .rst_n(rst_n), .start(madd_start),
        .p_X(h_X), .p_Y(h_Y), .p_Z(h_Z), .p_T(h_T),
        .q_yplusx(sel_yplusx), .q_yminusx(sel_yminusx), .q_xy2d(sel_xy2d),
        .busy(), .done(madd_done),
        .r_X(madd_X), .r_Y(madd_Y), .r_Z(madd_Z), .r_T(madd_T)
    );

    ed25519_ht_fe17_dbl u_dbl (
        .clk(clk), .rst_n(rst_n), .start(dbl_start),
        .p_X(h_X), .p_Y(h_Y), .p_Z(h_Z), .p_T(h_T),
        .busy(), .done(dbl_done),
        .r_X(dbl_X), .r_Y(dbl_Y), .r_Z(dbl_Z), .r_T(dbl_T)
    );

    always_comb begin
        select_start = 1'b0;
        madd_start = 1'b0;
        dbl_start = 1'b0;
        unique case (state)
            ST_SELECT_ODD_START,
            ST_SELECT_EVEN_START: select_start = 1'b1;
            ST_MADD_ODD_START,
            ST_MADD_EVEN_START: madd_start = 1'b1;
            ST_DBL_START: dbl_start = 1'b1;
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            idx <= 6'd0;
            dbl_count <= 2'd0;
            h_X <= FE_ZERO; h_Y <= FE_ONE; h_Z <= FE_ONE; h_T <= FE_ZERO;
            r_X <= FE_ZERO; r_Y <= FE_ZERO; r_Z <= FE_ZERO; r_T <= FE_ZERO;
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
                        idx <= 6'd1;
                        state <= ST_SELECT_ODD_START;
                    end
                end
                ST_SELECT_ODD_START: state <= ST_SELECT_ODD_WAIT;
                ST_SELECT_ODD_WAIT: if (select_done) state <= ST_MADD_ODD_START;
                ST_MADD_ODD_START: state <= ST_MADD_ODD_WAIT;
                ST_MADD_ODD_WAIT: begin
                    if (madd_done) begin
                        h_X <= madd_X; h_Y <= madd_Y; h_Z <= madd_Z; h_T <= madd_T;
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
                    if (dbl_done) begin
                        h_X <= dbl_X; h_Y <= dbl_Y; h_Z <= dbl_Z; h_T <= dbl_T;
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
                    if (madd_done) begin
                        h_X <= madd_X; h_Y <= madd_Y; h_Z <= madd_Z; h_T <= madd_T;
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
