`timescale 1ns / 1ps

module gpg_vanity_uart_soak_top #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 2000000,
    parameter integer EMIT_INTERVAL_CYCLES = 50000000
) (
    input  logic clk_50m,
    input  logic key2_reset_n,
    output logic uart_tx
);
    logic hit_valid;
    logic hit_ready;
    logic [3:0] hit_class_id;
    logic [255:0] hit_seed;
    logic [255:0] hit_public_key;
    logic [31:0] interval_count;
    logic [7:0] seq;

    integer i;

    always_comb begin
        hit_class_id = {3'd0, seq[0]};
        for (i = 0; i < 32; i = i + 1) begin
            hit_seed[i * 8 +: 8] = seq + i[7:0];
            hit_public_key[i * 8 +: 8] = 8'ha0 + seq + i[7:0];
        end
    end

    gpg_vanity_hit_uart #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_hit_uart (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .hit_valid(hit_valid),
        .hit_ready(hit_ready),
        .hit_class_id(hit_class_id),
        .hit_seed(hit_seed),
        .hit_public_key(hit_public_key),
        .uart_tx(uart_tx)
    );

    always_ff @(posedge clk_50m or negedge key2_reset_n) begin
        if (!key2_reset_n) begin
            interval_count <= 32'd0;
            seq <= 8'd0;
            hit_valid <= 1'b0;
        end else begin
            hit_valid <= 1'b0;
            if (interval_count == EMIT_INTERVAL_CYCLES - 1) begin
                if (hit_ready) begin
                    interval_count <= 32'd0;
                    seq <= seq + 1'b1;
                    hit_valid <= 1'b1;
                end
            end else begin
                interval_count <= interval_count + 1'b1;
            end
        end
    end
endmodule
