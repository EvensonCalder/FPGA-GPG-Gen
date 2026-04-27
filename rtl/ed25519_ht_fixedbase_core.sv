`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_core #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] scalar,
    output logic signed [319:0] r_X,
    output logic signed [319:0] r_Y,
    output logic signed [319:0] r_Z,
    output logic signed [319:0] r_T,
    output logic         done
);
    fe17_t x17, y17, z17, t17;

    ed25519_ht_fixedbase_context #(
        .INIT_FILE(INIT_FILE)
    ) u_context (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .scalar(scalar),
        .r_X(x17), .r_Y(y17), .r_Z(z17), .r_T(t17),
        .done(done)
    );

    ed25519_ht_fe17_to_fe10 cX(.fe17(x17), .fe10(r_X));
    ed25519_ht_fe17_to_fe10 cY(.fe17(y17), .fe10(r_Y));
    ed25519_ht_fe17_to_fe10 cZ(.fe17(z17), .fe10(r_Z));
    ed25519_ht_fe17_to_fe10 cT(.fe17(t17), .fe10(r_T));
endmodule
