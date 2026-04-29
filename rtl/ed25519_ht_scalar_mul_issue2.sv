`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;
import ed25519_ht_scalar_sched_pkg::*;

module ed25519_ht_scalar_mul_issue2 (
    input  logic            clk,
    input  logic            rst_n,

    input  logic            issue0_valid,
    input  scalar_mul_tag_t issue0_tag,
    input  fe17_t           issue0_a,
    input  fe17_t           issue0_b,

    input  logic            issue1_valid,
    input  scalar_mul_tag_t issue1_tag,
    input  fe17_t           issue1_a,
    input  fe17_t           issue1_b,

    output logic            retire0_valid,
    output scalar_mul_tag_t retire0_tag,
    output fe17_t           retire0_y,

    output logic            retire1_valid,
    output scalar_mul_tag_t retire1_tag,
    output fe17_t           retire1_y
);
    localparam int TAG_FIFO_DEPTH = 64;
    scalar_mul_tag_t tag0_fifo [0:TAG_FIFO_DEPTH-1];
    scalar_mul_tag_t tag1_fifo [0:TAG_FIFO_DEPTH-1];
    logic [5:0] tag0_wr_ptr, tag0_rd_ptr;
    logic [5:0] tag1_wr_ptr, tag1_rd_ptr;

    logic issue0_valid_q, issue1_valid_q;
    scalar_mul_tag_t issue0_tag_q, issue1_tag_q;
    fe17_t issue0_a_q, issue0_b_q, issue1_a_q, issue1_b_q;
    logic mul0_out_valid, mul1_out_valid;

    assign retire0_valid = mul0_out_valid;
    assign retire1_valid = mul1_out_valid;
    assign retire0_tag = tag0_fifo[tag0_rd_ptr];
    assign retire1_tag = tag1_fifo[tag1_rd_ptr];

    ed25519_ht_fe17_mul_pipe #(.CARRY_SHREG_EXTRACT("no")) u_mul0 (
        .clk(clk), .rst_n(rst_n), .in_valid(issue0_valid_q),
        .a(issue0_a_q), .b(issue0_b_q), .out_valid(mul0_out_valid), .out(retire0_y)
    );

    ed25519_ht_fe17_mul_pipe u_mul1 (
        .clk(clk), .rst_n(rst_n), .in_valid(issue1_valid_q),
        .a(issue1_a_q), .b(issue1_b_q), .out_valid(mul1_out_valid), .out(retire1_y)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tag0_wr_ptr <= 6'd0;
            tag0_rd_ptr <= 6'd0;
            tag1_wr_ptr <= 6'd0;
            tag1_rd_ptr <= 6'd0;
            issue0_valid_q <= 1'b0;
            issue1_valid_q <= 1'b0;
            issue0_tag_q <= '{ctx: 5'd0, op: OP_NONE};
            issue1_tag_q <= '{ctx: 5'd0, op: OP_NONE};
            issue0_a_q <= '0;
            issue0_b_q <= '0;
            issue1_a_q <= '0;
            issue1_b_q <= '0;
            for (int i = 0; i < TAG_FIFO_DEPTH; i++) begin
                tag0_fifo[i] <= '0;
                tag1_fifo[i] <= '0;
            end
        end else begin
            issue0_valid_q <= issue0_valid;
            issue1_valid_q <= issue1_valid;
            issue0_tag_q <= issue0_tag;
            issue1_tag_q <= issue1_tag;
            issue0_a_q <= issue0_a;
            issue0_b_q <= issue0_b;
            issue1_a_q <= issue1_a;
            issue1_b_q <= issue1_b;

            if (issue0_valid_q) begin
                tag0_fifo[tag0_wr_ptr] <= issue0_tag_q;
                tag0_wr_ptr <= tag0_wr_ptr + 6'd1;
            end
            if (issue1_valid_q) begin
                tag1_fifo[tag1_wr_ptr] <= issue1_tag_q;
                tag1_wr_ptr <= tag1_wr_ptr + 6'd1;
            end

            if (mul0_out_valid) begin
                tag0_rd_ptr <= tag0_rd_ptr + 6'd1;
            end

            if (mul1_out_valid) begin
                tag1_rd_ptr <= tag1_rd_ptr + 6'd1;
            end
        end
    end
endmodule
