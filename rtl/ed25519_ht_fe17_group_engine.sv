`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_group_engine (
    input  logic  clk,
    input  logic  rst_n,
    input  logic  start,
    input  logic  op_dbl,
    input  fe17_t p_X,
    input  fe17_t p_Y,
    input  fe17_t p_Z,
    input  fe17_t p_T,
    input  fe17_t q_yplusx,
    input  fe17_t q_yminusx,
    input  fe17_t q_xy2d,
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
        ST_MADD_INIT,
        ST_MADD_MUL_B_START,
        ST_MADD_MUL_B_WAIT,
        ST_MADD_MUL_A_START,
        ST_MADD_MUL_A_WAIT,
        ST_MADD_MUL_C_START,
        ST_MADD_MUL_C_WAIT,
        ST_MADD_MUL_D_START,
        ST_MADD_MUL_D_WAIT,
        ST_MADD_EFGH,
        ST_MADD_MUL_X_START,
        ST_MADD_MUL_X_WAIT,
        ST_MADD_MUL_Y_START,
        ST_MADD_MUL_Y_WAIT,
        ST_MADD_MUL_Z_START,
        ST_MADD_MUL_Z_WAIT,
        ST_MADD_MUL_T_START,
        ST_MADD_MUL_T_WAIT,
        ST_DBL_SQ_START,
        ST_DBL_SQ_WAIT,
        ST_DBL_EGH,
        ST_DBL_EF,
        ST_DBL_MUL_X_START,
        ST_DBL_MUL_X_WAIT,
        ST_DBL_MUL_Y_START,
        ST_DBL_MUL_Y_WAIT,
        ST_DBL_MUL_Z_START,
        ST_DBL_MUL_Z_WAIT,
        ST_DBL_MUL_T_START,
        ST_DBL_MUL_T_WAIT,
        ST_DONE
    } state_t;

    state_t state;
    logic [1:0] sq_idx;

    fe17_t yplusx;
    fe17_t yminusx;
    fe17_t a_reg, b_reg, c_reg, d_reg;
    fe17_t e_reg, f_reg, g_reg, h_reg;
    fe17_t xx, yy, zz, xy2;
    fe17_t xy_minus_xx, zz2_reg;

    logic mul0_valid, sq_valid;
    logic mul0_done, sq_done;
    fe17_t mul0_a, mul0_b, mul0_y;
    fe17_t sq_a, sq_y;

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

    ed25519_ht_fe17_mul_pipe u_mul0 (
        .clk(clk), .rst_n(rst_n), .in_valid(mul0_valid),
        .a(mul0_a), .b(mul0_b), .out_valid(mul0_done), .out(mul0_y)
    );

    ed25519_ht_fe17_square_pipe u_square (
        .clk(clk), .rst_n(rst_n), .in_valid(sq_valid),
        .a(sq_a), .out_valid(sq_done), .out(sq_y)
    );

    always_comb begin
        mul0_valid = 1'b0;
        sq_valid = 1'b0;
        mul0_a = '0; mul0_b = '0;
        sq_a = '0;

        unique case (state)
            ST_MADD_MUL_B_START: begin
                mul0_valid = 1'b1; mul0_a = yplusx;  mul0_b = q_yplusx;
            end
            ST_MADD_MUL_A_START: begin
                mul0_valid = 1'b1; mul0_a = yminusx; mul0_b = q_yminusx;
            end
            ST_MADD_MUL_C_START: begin
                mul0_valid = 1'b1; mul0_a = p_T; mul0_b = q_xy2d;
            end
            ST_MADD_MUL_D_START: begin
                mul0_valid = 1'b1; mul0_a = p_Z; mul0_b = fe17_t'(255'd2);
            end
            ST_MADD_MUL_X_START,
            ST_DBL_MUL_X_START: begin
                mul0_valid = 1'b1; mul0_a = e_reg; mul0_b = f_reg;
            end
            ST_MADD_MUL_Y_START,
            ST_DBL_MUL_Y_START: begin
                mul0_valid = 1'b1; mul0_a = g_reg; mul0_b = h_reg;
            end
            ST_MADD_MUL_Z_START: begin
                mul0_valid = 1'b1; mul0_a = f_reg; mul0_b = g_reg;
            end
            ST_MADD_MUL_T_START: begin
                mul0_valid = 1'b1; mul0_a = e_reg; mul0_b = h_reg;
            end
            ST_DBL_MUL_Z_START: begin
                mul0_valid = 1'b1; mul0_a = h_reg; mul0_b = f_reg;
            end
            ST_DBL_MUL_T_START: begin
                mul0_valid = 1'b1; mul0_a = e_reg; mul0_b = g_reg;
            end
            ST_DBL_SQ_START: begin
                sq_valid = 1'b1;
                unique case (sq_idx)
                    2'd0: sq_a = p_X;
                    2'd1: sq_a = p_Y;
                    2'd2: sq_a = p_Z;
                    default: sq_a = fe_add(p_X, p_Y);
                endcase
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            sq_idx <= 2'd0;
            done <= 1'b0;
            yplusx <= '0; yminusx <= '0;
            a_reg <= '0; b_reg <= '0; c_reg <= '0; d_reg <= '0;
            e_reg <= '0; f_reg <= '0; g_reg <= '0; h_reg <= '0;
            xx <= '0; yy <= '0; zz <= '0; xy2 <= '0;
            xy_minus_xx <= '0; zz2_reg <= '0;
            r_X <= '0; r_Y <= '0; r_Z <= '0; r_T <= '0;
        end else begin
            done <= 1'b0;
            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        if (op_dbl) begin
                            sq_idx <= 2'd0;
                            xx <= '0; yy <= '0; zz <= '0; xy2 <= '0;
                            xy_minus_xx <= '0; zz2_reg <= '0;
                            state <= ST_DBL_SQ_START;
                        end else begin
                            state <= ST_MADD_INIT;
                        end
                    end
                end

                ST_MADD_INIT: begin
                    yplusx <= fe_add(p_Y, p_X);
                    yminusx <= fe_sub(p_Y, p_X);
                    state <= ST_MADD_MUL_B_START;
                end
                ST_MADD_MUL_B_START: state <= ST_MADD_MUL_B_WAIT;
                ST_MADD_MUL_B_WAIT: begin
                    if (mul0_done) begin
                        b_reg <= mul0_y;
                        state <= ST_MADD_MUL_A_START;
                    end
                end
                ST_MADD_MUL_A_START: state <= ST_MADD_MUL_A_WAIT;
                ST_MADD_MUL_A_WAIT: begin
                    if (mul0_done) begin
                        a_reg <= mul0_y;
                        state <= ST_MADD_MUL_C_START;
                    end
                end
                ST_MADD_MUL_C_START: state <= ST_MADD_MUL_C_WAIT;
                ST_MADD_MUL_C_WAIT: begin
                    if (mul0_done) begin
                        c_reg <= mul0_y;
                        state <= ST_MADD_MUL_D_START;
                    end
                end
                ST_MADD_MUL_D_START: state <= ST_MADD_MUL_D_WAIT;
                ST_MADD_MUL_D_WAIT: begin
                    if (mul0_done) begin
                        d_reg <= mul0_y;
                        state <= ST_MADD_EFGH;
                    end
                end
                ST_MADD_EFGH: begin
                    e_reg <= fe_sub(b_reg, a_reg);
                    h_reg <= fe_add(b_reg, a_reg);
                    f_reg <= fe_sub(d_reg, c_reg);
                    g_reg <= fe_add(d_reg, c_reg);
                    state <= ST_MADD_MUL_X_START;
                end
                ST_MADD_MUL_X_START: state <= ST_MADD_MUL_X_WAIT;
                ST_MADD_MUL_X_WAIT: begin
                    if (mul0_done) begin
                        r_X <= mul0_y;
                        state <= ST_MADD_MUL_Y_START;
                    end
                end
                ST_MADD_MUL_Y_START: state <= ST_MADD_MUL_Y_WAIT;
                ST_MADD_MUL_Y_WAIT: begin
                    if (mul0_done) begin
                        r_Y <= mul0_y;
                        state <= ST_MADD_MUL_Z_START;
                    end
                end
                ST_MADD_MUL_Z_START: state <= ST_MADD_MUL_Z_WAIT;
                ST_MADD_MUL_Z_WAIT: begin
                    if (mul0_done) begin
                        r_Z <= mul0_y;
                        state <= ST_MADD_MUL_T_START;
                    end
                end
                ST_MADD_MUL_T_START: state <= ST_MADD_MUL_T_WAIT;
                ST_MADD_MUL_T_WAIT: begin
                    if (mul0_done) begin
                        r_T <= mul0_y;
                        state <= ST_DONE;
                    end
                end

                ST_DBL_SQ_START: state <= ST_DBL_SQ_WAIT;
                ST_DBL_SQ_WAIT: begin
                    if (sq_done) begin
                        if (sq_idx == 2'd0) begin
                            xx <= sq_y;
                            sq_idx <= 2'd1;
                            state <= ST_DBL_SQ_START;
                        end else if (sq_idx == 2'd1) begin
                            yy <= sq_y;
                            sq_idx <= 2'd2;
                            state <= ST_DBL_SQ_START;
                        end else if (sq_idx == 2'd2) begin
                            zz <= sq_y;
                            sq_idx <= 2'd3;
                            state <= ST_DBL_SQ_START;
                        end else begin
                            xy2 <= sq_y;
                            state <= ST_DBL_EGH;
                        end
                    end
                end
                ST_DBL_EGH: begin
                    xy_minus_xx <= fe_sub(xy2, xx);
                    zz2_reg <= fe_add(zz, zz);
                    g_reg <= fe_add(yy, xx);
                    h_reg <= fe_sub(yy, xx);
                    state <= ST_DBL_EF;
                end
                ST_DBL_EF: begin
                    e_reg <= fe_sub(xy_minus_xx, yy);
                    f_reg <= fe_sub(zz2_reg, h_reg);
                    state <= ST_DBL_MUL_X_START;
                end
                ST_DBL_MUL_X_START: state <= ST_DBL_MUL_X_WAIT;
                ST_DBL_MUL_X_WAIT: begin
                    if (mul0_done) begin
                        r_X <= mul0_y;
                        state <= ST_DBL_MUL_Y_START;
                    end
                end
                ST_DBL_MUL_Y_START: state <= ST_DBL_MUL_Y_WAIT;
                ST_DBL_MUL_Y_WAIT: begin
                    if (mul0_done) begin
                        r_Y <= mul0_y;
                        state <= ST_DBL_MUL_Z_START;
                    end
                end
                ST_DBL_MUL_Z_START: state <= ST_DBL_MUL_Z_WAIT;
                ST_DBL_MUL_Z_WAIT: begin
                    if (mul0_done) begin
                        r_Z <= mul0_y;
                        state <= ST_DBL_MUL_T_START;
                    end
                end
                ST_DBL_MUL_T_START: state <= ST_DBL_MUL_T_WAIT;
                ST_DBL_MUL_T_WAIT: begin
                    if (mul0_done) begin
                        r_T <= mul0_y;
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
