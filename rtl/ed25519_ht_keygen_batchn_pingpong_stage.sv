`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_batchn_pingpong_stage #(
    parameter integer BATCH_SIZE = 64
) (
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
    localparam int IDX_BITS = (BATCH_SIZE <= 1) ? 1 : $clog2(BATCH_SIZE);
    localparam logic [IDX_BITS-1:0] LAST_IDX = IDX_BITS'(BATCH_SIZE - 1);

    typedef enum logic [1:0] {PROC_IDLE, PROC_RUN, PROC_DONE} proc_state_t;

    logic fill_bank;
    logic proc_bank;
    logic [IDX_BITS-1:0] fill_idx;
    logic bank_full [0:1];
    proc_state_t proc_state;
    logic [IDX_BITS-1:0] drain_idx;

    logic [255:0] seed_buf [0:1][0:BATCH_SIZE-1];
    fe17_t x_buf [0:1][0:BATCH_SIZE-1];
    fe17_t y_buf [0:1][0:BATCH_SIZE-1];
    fe17_t z_buf [0:1][0:BATCH_SIZE-1];
    logic [255:0] batch_seed [0:BATCH_SIZE-1];
    logic [255:0] batch_public [0:BATCH_SIZE-1];
    logic batch_start;
    logic batch_done;

    assign in_ready = !bank_full[fill_bank];
    assign out_valid = proc_state == PROC_DONE;
    assign out_seed = batch_seed[drain_idx];
    assign out_public_key = batch_public[drain_idx];
    assign batch_start = proc_state == PROC_IDLE && bank_full[proc_bank];

    ed25519_ht_fe17_batch_affine_n #(
        .BATCH_SIZE(BATCH_SIZE)
    ) u_batch (
        .clk(clk), .rst_n(rst_n), .start(batch_start),
        .seed_in(seed_buf[proc_bank]), .x_in(x_buf[proc_bank]), .y_in(y_buf[proc_bank]), .z_in(z_buf[proc_bank]),
        .done(batch_done), .seed_out(batch_seed), .public_key(batch_public)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_bank <= 1'b0;
            proc_bank <= 1'b0;
            fill_idx <= '0;
            drain_idx <= '0;
            bank_full[0] <= 1'b0;
            bank_full[1] <= 1'b0;
            proc_state <= PROC_IDLE;
            for (int b = 0; b < 2; b++) begin
                for (int i = 0; i < BATCH_SIZE; i++) begin
                    seed_buf[b][i] <= 256'd0;
                    x_buf[b][i] <= '0;
                    y_buf[b][i] <= '0;
                    z_buf[b][i] <= '0;
                end
            end
        end else begin
            if (in_valid && in_ready) begin
                seed_buf[fill_bank][fill_idx] <= in_seed;
                x_buf[fill_bank][fill_idx] <= in_x;
                y_buf[fill_bank][fill_idx] <= in_y;
                z_buf[fill_bank][fill_idx] <= in_z;
                if (fill_idx == LAST_IDX) begin
                    bank_full[fill_bank] <= 1'b1;
                    fill_bank <= !fill_bank;
                    fill_idx <= '0;
                end else begin
                    fill_idx <= fill_idx + IDX_BITS'(1);
                end
            end

            unique case (proc_state)
                PROC_IDLE: begin
                    if (bank_full[proc_bank])
                        proc_state <= PROC_RUN;
                    else if (bank_full[!proc_bank])
                        proc_bank <= !proc_bank;
                end
                PROC_RUN: begin
                    if (batch_done) begin
                        bank_full[proc_bank] <= 1'b0;
                        drain_idx <= '0;
                        proc_state <= PROC_DONE;
                    end
                end
                PROC_DONE: begin
                    if (out_valid && out_ready) begin
                        if (drain_idx == LAST_IDX) begin
                            proc_bank <= !proc_bank;
                            proc_state <= PROC_IDLE;
                        end else begin
                            drain_idx <= drain_idx + IDX_BITS'(1);
                        end
                    end
                end
                default: proc_state <= PROC_IDLE;
            endcase
        end
    end
endmodule
