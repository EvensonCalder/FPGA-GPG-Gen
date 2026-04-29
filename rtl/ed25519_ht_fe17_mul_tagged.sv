`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_mul_tagged #(
    parameter integer TAG_BITS = 4
) (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                in_valid,
    input  logic [TAG_BITS-1:0] in_tag,
    input  fe17_t               a,
    input  fe17_t               b,
    output logic                out_valid,
    output logic [TAG_BITS-1:0] out_tag,
    output fe17_t               out
);
    logic [TAG_BITS-1:0] tag_pipe [0:31];
    logic [TAG_BITS-1:0] tag_q;
    logic valid_q;

    ed25519_ht_fe17_mul_pipe u_mul (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .a(a), .b(b), .out_valid(out_valid), .out(out)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_tag <= '0;
            tag_q <= '0;
            valid_q <= 1'b0;
            for (int i = 0; i < 32; i++)
                tag_pipe[i] <= '0;
        end else begin
            valid_q <= in_valid;
            if (in_valid)
                tag_q <= in_tag;
            tag_pipe[0] <= valid_q ? tag_q : '0;
            for (int i = 1; i < 32; i++)
                tag_pipe[i] <= tag_pipe[i - 1];
            out_tag <= tag_pipe[31];
        end
    end
endmodule
