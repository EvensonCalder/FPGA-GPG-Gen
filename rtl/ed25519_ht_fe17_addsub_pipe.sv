`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_addsub_pipe (
    input  logic  clk,
    input  logic  rst_n,
    input  logic  in_valid,
    input  logic  sub,
    input  fe17_t a,
    input  fe17_t b,
    output logic  out_valid,
    output fe17_t out
);
    localparam logic [254:0] FIELD_P = (255'(1) << 255) - 255'd19;

    logic [255:0] add_raw;
    logic [255:0] sub_raw;
    logic [255:0] raw_q;
    logic         sub_q;
    logic [255:0] add_red1;
    logic [255:0] add_red2;
    logic [255:0] sub_red;
    logic [1:0] valid_pipe;

    always_comb begin
        add_raw = 256'(a) + 256'(b);
        sub_raw = (256'(a) >= 256'(b)) ? (256'(a) - 256'(b)) : (256'(a) + 256'(FIELD_P) - 256'(b));

        add_red1 = (raw_q >= 256'(FIELD_P)) ? (raw_q - 256'(FIELD_P)) : raw_q;
        add_red2 = (add_red1 >= 256'(FIELD_P)) ? (add_red1 - 256'(FIELD_P)) : add_red1;
        sub_red = raw_q;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 2'd0;
            out_valid <= 1'b0;
            raw_q <= 256'd0;
            sub_q <= 1'b0;
            out <= '0;
        end else begin
            valid_pipe <= {valid_pipe[0], in_valid};
            out_valid <= valid_pipe[1];
            raw_q <= sub ? sub_raw : add_raw;
            sub_q <= sub;
            out <= fe17_t'(sub_q ? sub_red[254:0] : add_red2[254:0]);
        end
    end
endmodule
