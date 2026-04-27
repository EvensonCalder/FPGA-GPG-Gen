`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_dbl (
    input  logic  clk,
    input  logic  rst_n,
    input  logic  start,
    input  fe17_t p_X,
    input  fe17_t p_Y,
    input  fe17_t p_Z,
    input  fe17_t p_T,
    output logic  busy,
    output logic  done,
    output fe17_t r_X,
    output fe17_t r_Y,
    output fe17_t r_Z,
    output fe17_t r_T
);
    localparam logic [254:0] FIELD_P = (255'(1) << 255) - 255'd19;

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_SQ_START,
        ST_SQ_WAIT,
        ST_EFGH,
        ST_MUL_XY_START,
        ST_MUL_XY_WAIT,
        ST_MUL_ZT_START,
        ST_MUL_ZT_WAIT,
        ST_DONE
    } state_t;

    state_t state;
    logic [1:0] sq_idx;
    fe17_t xx, yy, zz, xy2;
    fe17_t a_reg, b_reg, c_reg;
    fe17_t e_reg, f_reg, g_reg, h_reg;

    logic sq_valid;
    logic sq_done;
    fe17_t sq_a, sq_y;
    logic mul0_valid, mul1_valid;
    logic mul0_done, mul1_done;
    fe17_t mul0_a, mul0_b, mul0_y;
    fe17_t mul1_a, mul1_b, mul1_y;

    assign busy = state != ST_IDLE;

    function automatic fe17_t fe_add(input fe17_t x, input fe17_t y);
        logic [255:0] raw, red1, red2;
        begin
            raw = 256'(x) + 256'(y);
            red1 = (raw >= 256'(FIELD_P)) ? (raw - 256'(FIELD_P)) : raw;
            red2 = (red1 >= 256'(FIELD_P)) ? (red1 - 256'(FIELD_P)) : red1;
            return fe17_t'(red2[254:0]);
        end
    endfunction

    function automatic fe17_t fe_sub(input fe17_t x, input fe17_t y);
        logic [255:0] raw;
        begin
            raw = (256'(x) >= 256'(y)) ? (256'(x) - 256'(y)) : (256'(x) + 256'(FIELD_P) - 256'(y));
            return fe17_t'(raw[254:0]);
        end
    endfunction

    ed25519_ht_fe17_square_pipe u_square (
        .clk(clk), .rst_n(rst_n), .in_valid(sq_valid),
        .a(sq_a), .out_valid(sq_done), .out(sq_y)
    );

    ed25519_ht_fe17_mul_pipe u_mul0 (
        .clk(clk), .rst_n(rst_n), .in_valid(mul0_valid),
        .a(mul0_a), .b(mul0_b), .out_valid(mul0_done), .out(mul0_y)
    );

    ed25519_ht_fe17_mul_pipe u_mul1 (
        .clk(clk), .rst_n(rst_n), .in_valid(mul1_valid),
        .a(mul1_a), .b(mul1_b), .out_valid(mul1_done), .out(mul1_y)
    );

    always_comb begin
        sq_valid = 1'b0;
        sq_a = '0;
        mul0_valid = 1'b0;
        mul1_valid = 1'b0;
        mul0_a = '0; mul0_b = '0; mul1_a = '0; mul1_b = '0;

        unique case (state)
            ST_SQ_START: begin
                sq_valid = 1'b1;
                unique case (sq_idx)
                    2'd0: sq_a = p_X;
                    2'd1: sq_a = p_Y;
                    2'd2: sq_a = p_Z;
                    default: sq_a = fe_add(p_X, p_Y);
                endcase
            end
            ST_MUL_XY_START: begin
                mul0_valid = 1'b1; mul0_a = e_reg; mul0_b = f_reg;
                mul1_valid = 1'b1; mul1_a = g_reg; mul1_b = h_reg;
            end
            ST_MUL_ZT_START: begin
                mul0_valid = 1'b1; mul0_a = f_reg; mul0_b = g_reg;
                mul1_valid = 1'b1; mul1_a = e_reg; mul1_b = h_reg;
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            done <= 1'b0;
            xx <= '0; yy <= '0; zz <= '0; xy2 <= '0;
            sq_idx <= 2'd0;
            a_reg <= '0; b_reg <= '0; c_reg <= '0;
            e_reg <= '0; f_reg <= '0; g_reg <= '0; h_reg <= '0;
            r_X <= '0; r_Y <= '0; r_Z <= '0; r_T <= '0;
        end else begin
            done <= 1'b0;
            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        xx <= '0;
                        yy <= '0;
                        zz <= '0;
                        xy2 <= '0;
                        sq_idx <= 2'd0;
                        state <= ST_SQ_START;
                    end
                end
                ST_SQ_START: state <= ST_SQ_WAIT;
                ST_SQ_WAIT: begin
                    if (sq_done) begin
                        if (sq_idx == 2'd0) begin
                            xx <= sq_y;
                            sq_idx <= 2'd1;
                            state <= ST_SQ_START;
                        end else if (sq_idx == 2'd1) begin
                            yy <= sq_y;
                            sq_idx <= 2'd2;
                            state <= ST_SQ_START;
                        end else if (sq_idx == 2'd2) begin
                            zz <= sq_y;
                            sq_idx <= 2'd3;
                            state <= ST_SQ_START;
                        end else begin
                            xy2 <= sq_y;
                            state <= ST_EFGH;
                        end
                    end
                end
                ST_EFGH: begin
                    a_reg <= xx;
                    b_reg <= yy;
                    c_reg <= fe_add(zz, zz);
                    e_reg <= fe_sub(fe_sub(xy2, xx), yy);
                    g_reg <= fe_add(yy, xx);
                    f_reg <= fe_sub(fe_add(yy, xx), fe_add(zz, zz));
                    h_reg <= fe_sub(yy, xx);
                    state <= ST_MUL_XY_START;
                end
                ST_MUL_XY_START: state <= ST_MUL_XY_WAIT;
                ST_MUL_XY_WAIT: begin
                    if (mul0_done && mul1_done) begin
                        r_X <= mul0_y;
                        r_Y <= mul1_y;
                        state <= ST_MUL_ZT_START;
                    end
                end
                ST_MUL_ZT_START: state <= ST_MUL_ZT_WAIT;
                ST_MUL_ZT_WAIT: begin
                    if (mul0_done && mul1_done) begin
                        r_Z <= mul0_y;
                        r_T <= mul1_y;
                        state <= ST_DONE;
                    end
                end
                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
