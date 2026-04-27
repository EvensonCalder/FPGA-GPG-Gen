`timescale 1ns / 1ps

module gpg_vanity_backend_uart #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD   = 2000000,
    parameter DEBUG_ACCEPT_ALL = 1'b0
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [31:0]  timestamp,
    input  logic         candidate_valid,
    output logic         candidate_ready,
    input  logic [255:0] candidate_seed,
    input  logic [255:0] candidate_public_key,
    output logic         uart_tx
);
    logic hit_valid;
    logic hit_ready;
    logic filter_candidate_ready;
    logic [3:0] hit_class_id;
    logic [255:0] hit_seed;
    logic [255:0] hit_public_key;
    logic [159:0] hit_fingerprint;

    assign candidate_ready = filter_candidate_ready && hit_ready;

    gpg_vanity_filter #(
        .DEBUG_ACCEPT_ALL(DEBUG_ACCEPT_ALL)
    ) u_filter (
        .clk(clk),
        .rst_n(rst_n),
        .timestamp(timestamp),
        .candidate_valid(candidate_valid && hit_ready),
        .candidate_ready(filter_candidate_ready),
        .seed(candidate_seed),
        .public_key(candidate_public_key),
        .hit_valid(hit_valid),
        .hit_class_id(hit_class_id),
        .hit_seed(hit_seed),
        .hit_public_key(hit_public_key),
        .hit_fingerprint(hit_fingerprint)
    );

    gpg_vanity_hit_uart #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_hit_uart (
        .clk(clk),
        .rst_n(rst_n),
        .hit_valid(hit_valid),
        .hit_ready(hit_ready),
        .hit_class_id(hit_class_id),
        .hit_seed(hit_seed),
        .hit_public_key(hit_public_key),
        .uart_tx(uart_tx)
    );
endmodule
