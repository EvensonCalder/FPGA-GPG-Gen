`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_invert_pow (
    input  logic  clk,
    input  logic  rst_n,
    input  logic  start,
    input  fe17_t z,
    output logic  busy,
    output logic  done,
    output fe17_t out
);
    localparam logic [254:0] EXPONENT = ((255'(1) << 255) - 255'd21);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_SQ_START,
        ST_SQ_WAIT,
        ST_MUL_START,
        ST_MUL_WAIT,
        ST_NEXT,
        ST_DONE
    } state_t;

    state_t state;
    logic [8:0] bit_idx;
    fe17_t base_q;
    fe17_t acc_q;
    fe17_t mul_a_q;
    fe17_t sq_y;
    fe17_t mul_y;
    logic sq_valid, sq_done;
    logic mul_valid, mul_done;

    assign busy = state != ST_IDLE;

    ed25519_ht_fe17_square_pipe u_sq (
        .clk(clk), .rst_n(rst_n), .in_valid(sq_valid),
        .a(acc_q), .out_valid(sq_done), .out(sq_y)
    );

    ed25519_ht_fe17_mul_pipe u_mul (
        .clk(clk), .rst_n(rst_n), .in_valid(mul_valid),
        .a(mul_a_q), .b(base_q), .out_valid(mul_done), .out(mul_y)
    );

    always_comb begin
        sq_valid = 1'b0;
        mul_valid = 1'b0;
        unique case (state)
            ST_SQ_START: sq_valid = 1'b1;
            ST_MUL_START: mul_valid = 1'b1;
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            bit_idx <= 9'd0;
            base_q <= '0;
            acc_q <= fe17_t'(255'd1);
            mul_a_q <= '0;
            out <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        base_q <= z;
                        acc_q <= fe17_t'(255'd1);
                        bit_idx <= 9'd254;
                        state <= ST_SQ_START;
                    end
                end
                ST_SQ_START: state <= ST_SQ_WAIT;
                ST_SQ_WAIT: begin
                    if (sq_done) begin
                        acc_q <= sq_y;
                        mul_a_q <= sq_y;
                        if (EXPONENT[bit_idx])
                            state <= ST_MUL_START;
                        else
                            state <= ST_NEXT;
                    end
                end
                ST_MUL_START: state <= ST_MUL_WAIT;
                ST_MUL_WAIT: begin
                    if (mul_done) begin
                        acc_q <= mul_y;
                        state <= ST_NEXT;
                    end
                end
                ST_NEXT: begin
                    if (bit_idx == 9'd0) begin
                        out <= acc_q;
                        state <= ST_DONE;
                    end else begin
                        bit_idx <= bit_idx - 9'd1;
                        state <= ST_SQ_START;
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
