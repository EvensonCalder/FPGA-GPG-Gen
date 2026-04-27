`timescale 1ns / 1ps

module trng_uart_top (
    input  wire clk_50m,
    input  wire key2_reset_n,
    output wire uart_tx
);
    wire [7:0] random_byte;
    wire random_valid;
    wire random_ready;
    wire health_fail;
    wire startup_done;

    trng_core #(
        .RO_COUNT(32),
        .STARTUP_SAMPLES(65536),
        .RCT_CUTOFF(64),
        .APT_WINDOW(512),
        .APT_LOW(160),
        .APT_HIGH(352),
        .SAMPLE_DIV(8),
        .CONDITIONER_BITS(32)
    ) trng_core_inst (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .random_ready(random_ready),
        .random_byte(random_byte),
        .random_valid(random_valid),
        .health_fail(health_fail),
        .startup_done(startup_done),
        .raw_bit()
    );

    uart_tx #(
        .CLK_HZ(50000000),
        .BAUD(2000000)
    ) uart_tx_inst (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .data(random_byte),
        .valid(random_valid && startup_done && !health_fail),
        .ready(random_ready),
        .tx(uart_tx)
    );
endmodule
