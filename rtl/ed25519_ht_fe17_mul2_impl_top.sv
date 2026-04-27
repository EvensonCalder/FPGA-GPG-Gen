`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_mul2_impl_top (
    input  logic clk,
    input  logic rst_n,
    output logic out_toggle
);
    fe17_t a0, b0, y0;
    fe17_t a1, b1, y1;
    logic [31:0] ctr;
    logic v0, v1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctr <= 32'd1;
            a0 <= '0;
            b0 <= '0;
            a1 <= '0;
            b1 <= '0;
            out_toggle <= 1'b0;
        end else begin
            ctr <= ctr + 32'd1;
            a0 <= {a0[FE17_BITS-33:0], ctr[16:0], ctr[31:17]};
            b0 <= {b0[FE17_BITS-35:0], ctr[14:0], ctr[31:15], ctr[0]};
            a1 <= {a1[FE17_BITS-37:0], ctr[12:0], ctr, ctr[7:0]};
            b1 <= {b1[FE17_BITS-39:0], ctr[10:0], ctr, ctr[12:0]};
            if (v0 || v1)
                out_toggle <= out_toggle ^ ^y0 ^ ^y1 ^ v0 ^ v1;
        end
    end

    ed25519_ht_fe17_mul_pipe u_mul0 (
        .clk(clk), .rst_n(rst_n), .in_valid(1'b1),
        .a(a0), .b(b0), .out_valid(v0), .out(y0)
    );

    ed25519_ht_fe17_mul_pipe u_mul1 (
        .clk(clk), .rst_n(rst_n), .in_valid(1'b1),
        .a(a1), .b(b1), .out_valid(v1), .out(y1)
    );
endmodule
