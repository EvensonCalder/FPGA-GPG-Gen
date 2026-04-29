`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_native_compress_lane (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         in_valid,
    output logic         in_ready,
    input  logic [255:0] in_seed,
    input  fe17_t        in_x,
    input  fe17_t        in_y,
    input  fe17_t        in_z,

    output logic         out_valid,
    input  logic         out_ready,
    output logic [255:0] out_seed,
    output logic [255:0] out_public_key
);
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_INV_START,
        ST_INV_WAIT,
        ST_MUL_X_START,
        ST_MUL_X_WAIT,
        ST_MUL_Y_START,
        ST_MUL_Y_WAIT,
        ST_DONE
    } state_t;

    state_t state;
    logic [255:0] seed_q;
    fe17_t x_q, y_q, z_q;
    fe17_t inv_z;
    fe17_t x_affine, y_affine;
    logic inv_done;
    logic inv_start;
    logic mul_valid;
    logic mul_done;
    fe17_t mul_a, mul_y;
    logic [255:0] encoded_public;

    assign in_ready = state == ST_IDLE && (!out_valid || out_ready);

    ed25519_ht_fe17_invert_pow u_inv (
        .clk(clk), .rst_n(rst_n), .start(inv_start), .z(z_q),
        .busy(), .done(inv_done), .out(inv_z)
    );

    ed25519_ht_fe17_mul_pipe u_mul (
        .clk(clk), .rst_n(rst_n), .in_valid(mul_valid),
        .a(mul_a), .b(inv_z), .out_valid(mul_done), .out(mul_y)
    );

    ed25519_ht_fe17_encode_public u_encode (
        .x_affine(x_affine), .y_affine(y_affine), .public_key(encoded_public)
    );

    always_comb begin
        inv_start = state == ST_INV_START;
        mul_valid = state == ST_MUL_X_START || state == ST_MUL_Y_START;
        mul_a = (state == ST_MUL_X_START) ? x_q : y_q;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            seed_q <= 256'd0;
            x_q <= '0;
            y_q <= '0;
            z_q <= '0;
            x_affine <= '0;
            y_affine <= '0;
            out_valid <= 1'b0;
            out_seed <= 256'd0;
            out_public_key <= 256'd0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;

            unique case (state)
                ST_IDLE: begin
                    if (in_valid && in_ready) begin
                        seed_q <= in_seed;
                        x_q <= in_x;
                        y_q <= in_y;
                        z_q <= in_z;
                        state <= ST_INV_START;
                    end
                end
                ST_INV_START: state <= ST_INV_WAIT;
                ST_INV_WAIT: begin
                    if (inv_done)
                        state <= ST_MUL_X_START;
                end
                ST_MUL_X_START: state <= ST_MUL_X_WAIT;
                ST_MUL_X_WAIT: begin
                    if (mul_done) begin
                        x_affine <= mul_y;
                        state <= ST_MUL_Y_START;
                    end
                end
                ST_MUL_Y_START: state <= ST_MUL_Y_WAIT;
                ST_MUL_Y_WAIT: begin
                    if (mul_done) begin
                        y_affine <= mul_y;
                        state <= ST_DONE;
                    end
                end
                ST_DONE: begin
                    out_seed <= seed_q;
                    out_public_key <= encoded_public;
                    out_valid <= 1'b1;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
