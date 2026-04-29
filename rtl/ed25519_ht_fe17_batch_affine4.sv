`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_batch_affine4 (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] seed_in [0:3],
    input  fe17_t        x_in [0:3],
    input  fe17_t        y_in [0:3],
    input  fe17_t        z_in [0:3],
    output logic         done,
    output logic [255:0] seed_out [0:3],
    output logic [255:0] public_key [0:3]
);
    typedef enum logic [4:0] {
        ST_IDLE,
        ST_P01_START,
        ST_P01_WAIT,
        ST_P23_START,
        ST_P23_WAIT,
        ST_ALL_START,
        ST_ALL_WAIT,
        ST_INV_START,
        ST_INV_WAIT,
        ST_TMP_START,
        ST_TMP_WAIT,
        ST_INVZ_HI_START,
        ST_INVZ_HI_WAIT,
        ST_INVZ_LO_START,
        ST_INVZ_LO_WAIT,
        ST_AFF_START,
        ST_AFF_WAIT,
        ST_DONE
    } state_t;

    state_t state;
    logic [1:0] aff_idx;
    fe17_t x_q [0:3], y_q [0:3], z_q [0:3];
    fe17_t p01, p23, all_z, inv_all;
    fe17_t tmp01, tmp23;
    fe17_t inv_z [0:3];
    fe17_t mul0_a, mul0_b, mul0_y;
    fe17_t mul1_a, mul1_b, mul1_y;
    logic mul0_valid, mul1_valid, mul0_done, mul1_done;
    logic inv_start, inv_done;
    logic [255:0] encoded_mul_public;

    ed25519_ht_fe17_mul_pipe u_mul0 (
        .clk(clk), .rst_n(rst_n), .in_valid(mul0_valid),
        .a(mul0_a), .b(mul0_b), .out_valid(mul0_done), .out(mul0_y)
    );

    ed25519_ht_fe17_mul_pipe u_mul1 (
        .clk(clk), .rst_n(rst_n), .in_valid(mul1_valid),
        .a(mul1_a), .b(mul1_b), .out_valid(mul1_done), .out(mul1_y)
    );

    ed25519_ht_fe17_invert_pow u_inv (
        .clk(clk), .rst_n(rst_n), .start(inv_start), .z(all_z),
        .busy(), .done(inv_done), .out(inv_all)
    );

    ed25519_ht_fe17_encode_public u_encode_mul (
        .x_affine(mul0_y), .y_affine(mul1_y), .public_key(encoded_mul_public)
    );

    always_comb begin
        mul0_valid = 1'b0;
        mul1_valid = 1'b0;
        inv_start = 1'b0;
        mul0_a = '0; mul0_b = '0;
        mul1_a = '0; mul1_b = '0;
        unique case (state)
            ST_P01_START: begin
                mul0_valid = 1'b1; mul0_a = z_q[0]; mul0_b = z_q[1];
            end
            ST_P23_START: begin
                mul0_valid = 1'b1; mul0_a = z_q[2]; mul0_b = z_q[3];
            end
            ST_ALL_START: begin
                mul0_valid = 1'b1; mul0_a = p01; mul0_b = p23;
            end
            ST_INV_START: inv_start = 1'b1;
            ST_TMP_START: begin
                mul0_valid = 1'b1; mul0_a = inv_all; mul0_b = p01;
                mul1_valid = 1'b1; mul1_a = inv_all; mul1_b = p23;
            end
            ST_INVZ_HI_START: begin
                mul0_valid = 1'b1; mul0_a = tmp01; mul0_b = z_q[2];
                mul1_valid = 1'b1; mul1_a = tmp01; mul1_b = z_q[3];
            end
            ST_INVZ_LO_START: begin
                mul0_valid = 1'b1; mul0_a = tmp23; mul0_b = z_q[0];
                mul1_valid = 1'b1; mul1_a = tmp23; mul1_b = z_q[1];
            end
            ST_AFF_START: begin
                mul0_valid = 1'b1; mul0_a = x_q[aff_idx]; mul0_b = inv_z[aff_idx];
                mul1_valid = 1'b1; mul1_a = y_q[aff_idx]; mul1_b = inv_z[aff_idx];
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            done <= 1'b0;
            aff_idx <= 2'd0;
            p01 <= '0; p23 <= '0; all_z <= '0; tmp01 <= '0; tmp23 <= '0;
            for (int i = 0; i < 4; i++) begin
                x_q[i] <= '0; y_q[i] <= '0; z_q[i] <= '0; inv_z[i] <= '0;
                seed_out[i] <= 256'd0;
                public_key[i] <= 256'd0;
            end
        end else begin
            done <= 1'b0;
            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        for (int i = 0; i < 4; i++) begin
                            seed_out[i] <= seed_in[i];
                            x_q[i] <= x_in[i]; y_q[i] <= y_in[i]; z_q[i] <= z_in[i];
                        end
                        state <= ST_P01_START;
                    end
                end
                ST_P01_START: state <= ST_P01_WAIT;
                ST_P01_WAIT: if (mul0_done) begin p01 <= mul0_y; state <= ST_P23_START; end
                ST_P23_START: state <= ST_P23_WAIT;
                ST_P23_WAIT: if (mul0_done) begin p23 <= mul0_y; state <= ST_ALL_START; end
                ST_ALL_START: state <= ST_ALL_WAIT;
                ST_ALL_WAIT: if (mul0_done) begin all_z <= mul0_y; state <= ST_INV_START; end
                ST_INV_START: state <= ST_INV_WAIT;
                ST_INV_WAIT: if (inv_done) state <= ST_TMP_START;
                ST_TMP_START: state <= ST_TMP_WAIT;
                ST_TMP_WAIT: if (mul0_done && mul1_done) begin
                    tmp01 <= mul0_y;
                    tmp23 <= mul1_y;
                    state <= ST_INVZ_HI_START;
                end
                ST_INVZ_HI_START: state <= ST_INVZ_HI_WAIT;
                ST_INVZ_HI_WAIT: if (mul0_done && mul1_done) begin
                    inv_z[3] <= mul0_y;
                    inv_z[2] <= mul1_y;
                    state <= ST_INVZ_LO_START;
                end
                ST_INVZ_LO_START: state <= ST_INVZ_LO_WAIT;
                ST_INVZ_LO_WAIT: if (mul0_done && mul1_done) begin
                    inv_z[1] <= mul0_y;
                    inv_z[0] <= mul1_y;
                    aff_idx <= 2'd0;
                    state <= ST_AFF_START;
                end
                ST_AFF_START: state <= ST_AFF_WAIT;
                ST_AFF_WAIT: if (mul0_done && mul1_done) begin
                    public_key[aff_idx] <= encoded_mul_public;
                    if (aff_idx == 2'd3)
                        state <= ST_DONE;
                    else begin
                        aff_idx <= aff_idx + 2'd1;
                        state <= ST_AFF_START;
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
