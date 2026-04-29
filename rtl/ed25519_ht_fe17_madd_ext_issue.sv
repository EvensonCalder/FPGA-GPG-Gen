`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;
import ed25519_ht_scalar_sched_pkg::*;

module ed25519_ht_fe17_madd_ext_issue #(
    parameter logic [4:0] CTX_ID = 5'd0
) (
    input  logic            clk,
    input  logic            rst_n,
    input  logic            start,
    input  fe17_t           p_X,
    input  fe17_t           p_Y,
    input  fe17_t           p_Z,
    input  fe17_t           p_T,
    input  fe17_t           q_yplusx,
    input  fe17_t           q_yminusx,
    input  fe17_t           q_xy2d,

    output logic            issue0_valid,
    output scalar_mul_tag_t issue0_tag,
    output fe17_t           issue0_a,
    output fe17_t           issue0_b,
    output logic            issue1_valid,
    output scalar_mul_tag_t issue1_tag,
    output fe17_t           issue1_a,
    output fe17_t           issue1_b,

    input  logic            retire0_valid,
    input  scalar_mul_tag_t retire0_tag,
    input  fe17_t           retire0_y,
    input  logic            retire1_valid,
    input  scalar_mul_tag_t retire1_tag,
    input  fe17_t           retire1_y,

    output logic            busy,
    output logic            done,
    output fe17_t           r_X,
    output fe17_t           r_Y,
    output fe17_t           r_Z,
    output fe17_t           r_T
);
    localparam logic [254:0] FIELD_P = (255'(1) << 255) - 255'd19;

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_INIT,
        ST_ISSUE_AB,
        ST_ISSUE_C,
        ST_WAIT_ABC,
        ST_EFGH,
        ST_ISSUE_XY,
        ST_ISSUE_ZT,
        ST_WAIT_XYZT,
        ST_DONE
    } state_t;

    state_t state;
    fe17_t yplusx;
    fe17_t yminusx;
    fe17_t a_reg, b_reg, c_reg, d_reg;
    fe17_t e_reg, f_reg, g_reg, h_reg;
    logic got_a, got_b, got_c;
    logic got_x, got_y, got_z, got_t;
    logic retire_a_now, retire_b_now, retire_c_now;
    logic retire_x_now, retire_y_now, retire_z_now, retire_t_now;

    assign busy = state != ST_IDLE;

    always_comb begin
        retire_a_now = 1'b0;
        retire_b_now = 1'b0;
        retire_c_now = 1'b0;
        retire_x_now = 1'b0;
        retire_y_now = 1'b0;
        retire_z_now = 1'b0;
        retire_t_now = 1'b0;
        if (retire0_valid && retire0_tag.ctx == CTX_ID) begin
            retire_a_now = retire0_tag.op == OP_MADD_A;
            retire_b_now = retire0_tag.op == OP_MADD_B;
            retire_c_now = retire0_tag.op == OP_MADD_C;
            retire_x_now = retire0_tag.op == OP_MADD_X;
            retire_y_now = retire0_tag.op == OP_MADD_Y;
            retire_z_now = retire0_tag.op == OP_MADD_Z;
            retire_t_now = retire0_tag.op == OP_MADD_T;
        end
        if (retire1_valid && retire1_tag.ctx == CTX_ID) begin
            retire_a_now |= retire1_tag.op == OP_MADD_A;
            retire_b_now |= retire1_tag.op == OP_MADD_B;
            retire_c_now |= retire1_tag.op == OP_MADD_C;
            retire_x_now |= retire1_tag.op == OP_MADD_X;
            retire_y_now |= retire1_tag.op == OP_MADD_Y;
            retire_z_now |= retire1_tag.op == OP_MADD_Z;
            retire_t_now |= retire1_tag.op == OP_MADD_T;
        end
    end

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

    always_comb begin
        issue0_valid = 1'b0;
        issue1_valid = 1'b0;
        issue0_tag = '{ctx: CTX_ID, op: OP_NONE};
        issue1_tag = '{ctx: CTX_ID, op: OP_NONE};
        issue0_a = '0; issue0_b = '0;
        issue1_a = '0; issue1_b = '0;

        unique case (state)
            ST_ISSUE_AB: begin
                issue0_valid = 1'b1;
                issue0_tag = '{ctx: CTX_ID, op: OP_MADD_B};
                issue0_a = yplusx;
                issue0_b = q_yplusx;
                issue1_valid = 1'b1;
                issue1_tag = '{ctx: CTX_ID, op: OP_MADD_A};
                issue1_a = yminusx;
                issue1_b = q_yminusx;
            end
            ST_ISSUE_C: begin
                issue0_valid = 1'b1;
                issue0_tag = '{ctx: CTX_ID, op: OP_MADD_C};
                issue0_a = p_T;
                issue0_b = q_xy2d;
            end
            ST_ISSUE_XY: begin
                issue0_valid = 1'b1;
                issue0_tag = '{ctx: CTX_ID, op: OP_MADD_X};
                issue0_a = e_reg;
                issue0_b = f_reg;
                issue1_valid = 1'b1;
                issue1_tag = '{ctx: CTX_ID, op: OP_MADD_Y};
                issue1_a = g_reg;
                issue1_b = h_reg;
            end
            ST_ISSUE_ZT: begin
                issue0_valid = 1'b1;
                issue0_tag = '{ctx: CTX_ID, op: OP_MADD_Z};
                issue0_a = f_reg;
                issue0_b = g_reg;
                issue1_valid = 1'b1;
                issue1_tag = '{ctx: CTX_ID, op: OP_MADD_T};
                issue1_a = e_reg;
                issue1_b = h_reg;
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            done <= 1'b0;
            yplusx <= '0; yminusx <= '0;
            a_reg <= '0; b_reg <= '0; c_reg <= '0; d_reg <= '0;
            e_reg <= '0; f_reg <= '0; g_reg <= '0; h_reg <= '0;
            got_a <= 1'b0; got_b <= 1'b0; got_c <= 1'b0;
            got_x <= 1'b0; got_y <= 1'b0; got_z <= 1'b0; got_t <= 1'b0;
            r_X <= '0; r_Y <= '0; r_Z <= '0; r_T <= '0;
        end else begin
            done <= 1'b0;

            if (retire0_valid && retire0_tag.ctx == CTX_ID) begin
                unique case (retire0_tag.op)
                    OP_MADD_A: begin a_reg <= retire0_y; got_a <= 1'b1; end
                    OP_MADD_B: begin b_reg <= retire0_y; got_b <= 1'b1; end
                    OP_MADD_C: begin c_reg <= retire0_y; got_c <= 1'b1; end
                    OP_MADD_X: begin r_X <= retire0_y; got_x <= 1'b1; end
                    OP_MADD_Y: begin r_Y <= retire0_y; got_y <= 1'b1; end
                    OP_MADD_Z: begin r_Z <= retire0_y; got_z <= 1'b1; end
                    OP_MADD_T: begin r_T <= retire0_y; got_t <= 1'b1; end
                    default: begin
                    end
                endcase
            end
            if (retire1_valid && retire1_tag.ctx == CTX_ID) begin
                unique case (retire1_tag.op)
                    OP_MADD_A: begin a_reg <= retire1_y; got_a <= 1'b1; end
                    OP_MADD_B: begin b_reg <= retire1_y; got_b <= 1'b1; end
                    OP_MADD_C: begin c_reg <= retire1_y; got_c <= 1'b1; end
                    OP_MADD_X: begin r_X <= retire1_y; got_x <= 1'b1; end
                    OP_MADD_Y: begin r_Y <= retire1_y; got_y <= 1'b1; end
                    OP_MADD_Z: begin r_Z <= retire1_y; got_z <= 1'b1; end
                    OP_MADD_T: begin r_T <= retire1_y; got_t <= 1'b1; end
                    default: begin
                    end
                endcase
            end

            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        got_a <= 1'b0; got_b <= 1'b0; got_c <= 1'b0;
                        got_x <= 1'b0; got_y <= 1'b0; got_z <= 1'b0; got_t <= 1'b0;
                        state <= ST_INIT;
                    end
                end
                ST_INIT: begin
                    yplusx <= fe_add(p_Y, p_X);
                    yminusx <= fe_sub(p_Y, p_X);
                    d_reg <= fe_add(p_Z, p_Z);
                    state <= ST_ISSUE_AB;
                end
                ST_ISSUE_AB: state <= ST_ISSUE_C;
                ST_ISSUE_C: state <= ST_WAIT_ABC;
                ST_WAIT_ABC: begin
                    if ((got_a || retire_a_now) && (got_b || retire_b_now) && (got_c || retire_c_now))
                        state <= ST_EFGH;
                end
                ST_EFGH: begin
                    e_reg <= fe_sub(b_reg, a_reg);
                    h_reg <= fe_add(b_reg, a_reg);
                    f_reg <= fe_sub(d_reg, c_reg);
                    g_reg <= fe_add(d_reg, c_reg);
                    got_x <= 1'b0; got_y <= 1'b0; got_z <= 1'b0; got_t <= 1'b0;
                    state <= ST_ISSUE_XY;
                end
                ST_ISSUE_XY: state <= ST_ISSUE_ZT;
                ST_ISSUE_ZT: state <= ST_WAIT_XYZT;
                ST_WAIT_XYZT: begin
                    if ((got_x || retire_x_now) && (got_y || retire_y_now) &&
                        (got_z || retire_z_now) && (got_t || retire_t_now))
                        state <= ST_DONE;
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
