`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_batch8_compress_stage (
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
        ST_FILL,
        ST_BATCH_START,
        ST_BATCH_WAIT,
        ST_DRAIN
    } state_t;

    state_t state;
    logic [2:0] fill_idx;
    logic [2:0] drain_idx;
    logic batch_start;
    logic batch_done;
    logic [255:0] seed_buf [0:7];
    fe17_t x_buf [0:7];
    fe17_t y_buf [0:7];
    fe17_t z_buf [0:7];
    logic [255:0] batch_seed [0:7];
    logic [255:0] batch_public [0:7];

    assign in_ready = state == ST_FILL;
    assign out_valid = state == ST_DRAIN;
    assign out_seed = batch_seed[drain_idx];
    assign out_public_key = batch_public[drain_idx];

    ed25519_ht_fe17_batch_affine8 u_batch (
        .clk(clk), .rst_n(rst_n), .start(batch_start),
        .seed_in(seed_buf), .x_in(x_buf), .y_in(y_buf), .z_in(z_buf),
        .done(batch_done), .seed_out(batch_seed), .public_key(batch_public)
    );

    always_comb begin
        batch_start = state == ST_BATCH_START;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_FILL;
            fill_idx <= 3'd0;
            drain_idx <= 3'd0;
            for (int i = 0; i < 8; i++) begin
                seed_buf[i] <= 256'd0;
                x_buf[i] <= '0;
                y_buf[i] <= '0;
                z_buf[i] <= '0;
            end
        end else begin
            unique case (state)
                ST_FILL: begin
                    if (in_valid && in_ready) begin
                        seed_buf[fill_idx] <= in_seed;
                        x_buf[fill_idx] <= in_x;
                        y_buf[fill_idx] <= in_y;
                        z_buf[fill_idx] <= in_z;
                        if (fill_idx == 3'd7) begin
                            fill_idx <= 3'd0;
                            state <= ST_BATCH_START;
                        end else begin
                            fill_idx <= fill_idx + 3'd1;
                        end
                    end
                end
                ST_BATCH_START: state <= ST_BATCH_WAIT;
                ST_BATCH_WAIT: begin
                    if (batch_done) begin
                        drain_idx <= 3'd0;
                        state <= ST_DRAIN;
                    end
                end
                ST_DRAIN: begin
                    if (out_valid && out_ready) begin
                        if (drain_idx == 3'd7)
                            state <= ST_FILL;
                        else
                            drain_idx <= drain_idx + 3'd1;
                    end
                end
                default: state <= ST_FILL;
            endcase
        end
    end
endmodule
