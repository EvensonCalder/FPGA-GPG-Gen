`timescale 1ns / 1ps

module kg_lane0 (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] seed,
    output logic         busy,
    output logic         done,
    output logic [255:0] seed_out,
    output logic [255:0] public_key
);
    ed25519_keygen_core u (
        .clk(clk), .rst_n(rst_n), .start(start),
        .seed(seed), .busy(busy), .done(done),
        .seed_out(seed_out), .expanded_secret(), .public_key(public_key)
    );
endmodule
