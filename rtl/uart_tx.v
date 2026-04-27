`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD   = 2000000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data,
    input  wire       valid,
    output wire       ready,
    output reg        tx
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;

    reg [15:0] baud_count;
    reg [3:0] bit_index;
    reg [9:0] shifter;
    reg busy;

    assign ready = !busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_count <= 16'd0;
            bit_index  <= 4'd0;
            shifter    <= 10'h3ff;
            busy       <= 1'b0;
            tx         <= 1'b1;
        end else begin
            if (!busy) begin
                tx <= 1'b1;

                if (valid) begin
                    shifter    <= {1'b1, data, 1'b0};
                    baud_count <= 16'd0;
                    bit_index  <= 4'd0;
                    busy       <= 1'b1;
                    tx         <= 1'b0;
                end
            end else begin
                if (baud_count == CLKS_PER_BIT - 1) begin
                    baud_count <= 16'd0;
                    shifter    <= {1'b1, shifter[9:1]};

                    if (bit_index == 4'd9) begin
                        busy      <= 1'b0;
                        bit_index <= 4'd0;
                        tx        <= 1'b1;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                        tx        <= shifter[1];
                    end
                end else begin
                    baud_count <= baud_count + 1'b1;
                end
            end
        end
    end
endmodule
