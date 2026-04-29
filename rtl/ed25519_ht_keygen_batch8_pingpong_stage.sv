`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_batch8_pingpong_stage (
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
    typedef enum logic [1:0] {PROC_IDLE, PROC_RUN, PROC_DONE} proc_state_t;

    logic fill_bank;
    logic proc_bank;
    logic [2:0] fill_idx;
    logic bank_full [0:1];
    proc_state_t proc_state;
    logic [2:0] drain_idx;

    logic [255:0] seed_buf [0:1][0:7];
    fe17_t x_buf [0:1][0:7];
    fe17_t y_buf [0:1][0:7];
    fe17_t z_buf [0:1][0:7];
    logic [255:0] batch_seed [0:7];
    logic [255:0] batch_public [0:7];
    logic batch_start;
    logic batch_done;

    assign in_ready = !bank_full[fill_bank];
    assign out_valid = proc_state == PROC_DONE;
    assign out_seed = batch_seed[drain_idx];
    assign out_public_key = batch_public[drain_idx];
    assign batch_start = proc_state == PROC_IDLE && bank_full[proc_bank];

    ed25519_ht_fe17_batch_affine8 u_batch (
        .clk(clk), .rst_n(rst_n), .start(batch_start),
        .seed_in(seed_buf[proc_bank]), .x_in(x_buf[proc_bank]), .y_in(y_buf[proc_bank]), .z_in(z_buf[proc_bank]),
        .done(batch_done), .seed_out(batch_seed), .public_key(batch_public)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_bank <= 1'b0;
            proc_bank <= 1'b0;
            fill_idx <= 3'd0;
            drain_idx <= 3'd0;
            bank_full[0] <= 1'b0;
            bank_full[1] <= 1'b0;
            proc_state <= PROC_IDLE;
            for (int b = 0; b < 2; b++) begin
                for (int i = 0; i < 8; i++) begin
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
                if (fill_idx == 3'd7) begin
                    bank_full[fill_bank] <= 1'b1;
                    fill_bank <= !fill_bank;
                    fill_idx <= 3'd0;
                end else begin
                    fill_idx <= fill_idx + 3'd1;
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
                        drain_idx <= 3'd0;
                        proc_state <= PROC_DONE;
                    end
                end
                PROC_DONE: begin
                    if (out_valid && out_ready) begin
                        if (drain_idx == 3'd7) begin
                            proc_bank <= !proc_bank;
                            proc_state <= PROC_IDLE;
                        end else begin
                            drain_idx <= drain_idx + 3'd1;
                        end
                    end
                end
                default: proc_state <= PROC_IDLE;
            endcase
        end
    end
endmodule
