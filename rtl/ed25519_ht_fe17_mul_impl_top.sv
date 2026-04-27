`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_mul_impl_top (
    input  logic clk,
    input  logic rst_n,
    output logic out_toggle
);
    fe17_t a;
    fe17_t b;
    fe17_t out;
    logic [31:0] ctr;
    logic out_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctr <= 32'd1;
            a <= '0;
            b <= '0;
            out_toggle <= 1'b0;
        end else begin
            ctr <= ctr + 32'd1;
            a <= {a[FE17_BITS-33:0], ctr[16:0], ctr[31:17]};
            b <= {b[FE17_BITS-35:0], ctr[14:0], ctr[31:15], ctr[0]};
            if (out_valid)
                out_toggle <= out_toggle ^ ^out;
        end
    end

    ed25519_ht_fe17_mul_pipe u_mul (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(1'b1),
        .a(a),
        .b(b),
        .out_valid(out_valid),
        .out(out)
    );
endmodule
