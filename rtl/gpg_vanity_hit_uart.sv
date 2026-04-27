`timescale 1ns / 1ps

module gpg_vanity_hit_uart #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD   = 2000000
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         hit_valid,
    output logic         hit_ready,
    input  logic [3:0]   hit_class_id,
    input  logic [255:0] hit_seed,
    input  logic [255:0] hit_public_key,
    output logic         uart_tx
);
    logic [7:0] uart_data;
    logic uart_valid;
    logic uart_ready;

    gpg_vanity_hit_uart_encoder u_encoder (
        .clk(clk),
        .rst_n(rst_n),
        .hit_valid(hit_valid),
        .hit_ready(hit_ready),
        .hit_class_id(hit_class_id),
        .hit_seed(hit_seed),
        .hit_public_key(hit_public_key),
        .uart_data(uart_data),
        .uart_valid(uart_valid),
        .uart_ready(uart_ready)
    );

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .data(uart_data),
        .valid(uart_valid),
        .ready(uart_ready),
        .tx(uart_tx)
    );
endmodule
